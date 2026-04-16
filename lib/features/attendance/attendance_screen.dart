import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  List todaysSubjects = [];
  List allSubjects = [];

  Map<String, String> attendanceMap = {};
  Map<String, String> attendanceIdMap = {};
  Map<String, List<Map<String, dynamic>>> subjectAttendanceHistory = {};

  // ================= THEME =================

  static const bgBlack = Color(0xFF0E0E11);

  static const cardStart = Color(0xFF1C1C24);
  static const cardEnd = Color(0xFF2A2A36);

  static const borderColor = Color(0xFF2F2F3A);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB8B8C7);

  static const success = Color(0xFF7BD3A8);
  static const warning = Color(0xFFF4C06A);
  static const error = Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // ================= DATE =================

  String getIndianWeekday() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );

    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ][now.weekday - 1];
  }

  // ================= FETCH =================

  Future<void> fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final weekday = getIndianWeekday();
    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));

    try {
      /// 1️⃣ Timetable (unchanged)
      final timetable = await supabase
          .from('timetable')
          .select('id, time_slot, subjects!fk_subject(*)')
          .eq('user_id', user.uid)
          .eq('day', weekday)
          .order('time_slot', ascending: true);

      /// 2️⃣ Subjects (unchanged)
      final subjects = await supabase
          .from('subjects')
          .select('id, name, type')
          .eq('user_id', user.uid);

      /// 3️⃣ ALL-TIME THEORY (for overall)
      final overallData = await supabase
          .from('attendance')
          .select('subject_id, present, date, time_slot, type')
          .eq('user_id', user.uid)
          .eq('type', 'Theory');

      /// 4️⃣ MONTH THEORY (for monthly)
      final monthlyData = await supabase
          .from('attendance')
          .select('subject_id, present, date, time_slot, type')
          .eq('user_id', user.uid)
          .eq('type', 'Theory')
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String());

      /// 5️⃣ TODAY (for toggles, ALL types)
      final todayData = await supabase
          .from('attendance')
          .select('id, subject_id, present, date, time_slot')
          .eq('user_id', user.uid)
          .eq('date', todayDate);

      Map<String, String> tempMap = {};
      Map<String, String> tempIdMap = {};
      Map<String, List<Map<String, dynamic>>> tempHistory = {};

      /// 🔹 Build FULL history (from overallData)
      for (var a in overallData) {
        final subjectId = a['subject_id']?.toString();
        final timeSlot = a['time_slot'];
        final date = a['date']?.toString();

        if (subjectId == null || date == null) continue;

        final value = a['present'] ?? 'cancelled';

        tempHistory.putIfAbsent(subjectId, () => []);

        if (!tempHistory[subjectId]!.any(
          (e) => e['date'] == date && e['time_slot'] == timeSlot,
        )) {
          tempHistory[subjectId]!.add({
            'date': date,
            'time_slot': timeSlot,
            'status': value,
          });
        }
      }

      /// 🔹 TODAY map (for UI buttons)
      for (var a in todayData) {
        final subjectId = a['subject_id']?.toString();
        final attId = a['id']?.toString();
        final timeSlot = a['time_slot'];

        if (subjectId == null || attId == null) continue;

        final value = a['present'] ?? 'cancelled';

        tempMap["$subjectId-$timeSlot"] = value;
        tempIdMap["$subjectId-$timeSlot"] = attId;
      }

      setState(() {
        todaysSubjects = timetable;
        allSubjects = subjects;

        attendanceMap = tempMap;
        attendanceIdMap = tempIdMap;
        subjectAttendanceHistory = tempHistory;

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }
  // ================= TOGGLE =================

  Future<void> toggleAttendance(
    String subjectId,
    String value,
    int timeSlot,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    final key = "$subjectId-$timeSlot";

    try {
      if (attendanceIdMap.containsKey(key)) {
        await supabase
            .from('attendance')
            .update({'present': value})
            .eq('id', attendanceIdMap[key]!);
      } else {
        final response = await supabase.from('attendance').insert({
          'user_id': user.uid,
          'subject_id': subjectId,
          'present': value,
          'date': todayDate,
          'time_slot': timeSlot,
        }).select();

        final newId = response[0]['id'].toString();

        attendanceIdMap[key] = newId;
      }

      // UPDATE HISTORY LOCALLY

      subjectAttendanceHistory.putIfAbsent(subjectId, () => []);

      final historyList = subjectAttendanceHistory[subjectId]!;

      final existingIndex = historyList.indexWhere(
        (e) => e['date'] == todayDate && e['time_slot'] == timeSlot,
      );

      if (existingIndex != -1) {
        historyList[existingIndex]['status'] = value;
      } else {
        historyList.add({
          'date': todayDate,
          'time_slot': timeSlot,
          'status': value,
        });
      }

      setState(() {
        attendanceMap[key] = value;
      });
    } catch (e) {
      debugPrint("Attendance error: $e");
    }
  }

  double calculateMonthlyAttendance() {
    int attended = 0;
    int total = 0;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    for (var subject in allSubjects) {
      // keep same rule → only theory
      if (subject['type'] != 'Theory') continue;

      final subjectId = subject['id'].toString();
      final history = subjectAttendanceHistory[subjectId];

      if (history == null) continue;

      for (var entry in history) {
        final entryDate = DateTime.parse(entry['date']);

        if (entryDate.isBefore(startOfMonth) || entryDate.isAfter(endOfMonth))
          continue;

        if (entry['status'] == 'present') attended++;

        if (entry['status'] != 'cancelled') total++;
      }
    }

    if (total == 0) return 0;

    return (attended / total) * 100;
  }

  // ================= CALCULATIONS =================

  // ================= CALCULATIONS =================

  int getPresent(String subjectId) {
    final data = subjectAttendanceHistory[subjectId] ?? [];

    return data.where((e) => e['status'] == 'present').length;
  }

  int getTotal(String subjectId) {
    final data = subjectAttendanceHistory[subjectId] ?? [];

    return data.where((e) => e['status'] != 'cancelled').length;
  }

  int getMustAttend(int present, int total, int target) {
    if (total == 0) return 0;

    double value = (target * total - 100 * present) / (100 - target);

    if (value < 0) return 0;

    return value.ceil();
  }

  double calculateSubjectAttendance(String subjectId) {
    final history = subjectAttendanceHistory[subjectId] ?? [];

    if (history.isEmpty) return 0;

    int attended = history.where((v) => v['status'] == 'present').length;

    int total = history.where((v) => v['status'] != 'cancelled').length;

    if (total == 0) return 0;

    return (attended / total) * 100;
  }

  // 🔥 UPDATED FUNCTION
  double calculateOverallAttendance() {
    int attended = 0;
    int total = 0;

    for (var subject in allSubjects) {
      // ✅ Only count THEORY subjects
      if (subject['type'] != 'Theory') continue;

      final subjectId = subject['id'].toString();

      final history = subjectAttendanceHistory[subjectId];

      if (history == null) continue;

      attended += history.where((v) => v['status'] == 'present').length;

      total += history.where((v) => v['status'] != 'cancelled').length;
    }

    if (total == 0) return 0;

    return (attended / total) * 100;
  }

  // ================= ICONS =================

  Widget attendanceIcons(String subjectId, int timeSlot) {
    final key = "$subjectId-$timeSlot";

    final state = attendanceMap[key] ?? 'cancelled';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_rounded),
          color: state == 'present' ? success : textSecondary,
          onPressed: () => toggleAttendance(subjectId, 'present', timeSlot),
        ),

        IconButton(
          icon: const Icon(Icons.cancel_rounded),
          color: state == 'absent' ? error : textSecondary,
          onPressed: () => toggleAttendance(subjectId, 'absent', timeSlot),
        ),

        IconButton(
          icon: const Icon(Icons.block_rounded),
          color: state == 'cancelled' ? warning : textSecondary,
          onPressed: () => toggleAttendance(subjectId, 'cancelled', timeSlot),
        ),
      ],
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final overall = calculateOverallAttendance();
    final monthly = calculateMonthlyAttendance();

    return Scaffold(
      backgroundColor: bgBlack,

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: success))
          : Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    "Overall Attendance: ${overall.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    "Monthly Attendance: ${monthly.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView.builder(
                      itemCount: todaysSubjects.length,

                      itemBuilder: (context, index) {
                        final item = todaysSubjects[index];

                        final subject = item['subjects'];

                        final subjectId = subject['id'].toString();

                        final timeSlot = item['time_slot'] as int;

                        final percent = calculateSubjectAttendance(subjectId);

                        final present = getPresent(subjectId);

                        final total = getTotal(subjectId);

                        final mustAttend = getMustAttend(present, total, 75);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),

                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [cardStart, cardEnd],
                            ),

                            borderRadius: BorderRadius.circular(14),

                            border: Border.all(
                              color: percent < 75 ? error : borderColor,
                              width: 2,
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${subject['name']} (${subject['type']})",

                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),

                                  attendanceIcons(subjectId, timeSlot),
                                ],
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Attendance: ${percent.toStringAsFixed(1)}%",
                                style: const TextStyle(color: textSecondary),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                "Must attend next: $mustAttend classes",
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
