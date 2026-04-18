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

  // Date range filter
  DateTime? filterStart;
  DateTime? filterEnd;

  // ─── Color Palette (Spotify theme) ────────────────────────────────────────
  static const bgBlack = Color.fromARGB(255, 0, 0, 0);
  static const cardStart = Color.fromARGB(255, 0, 0, 0);
  static const cardEnd = Color.fromARGB(255, 0, 0, 0);
  static const borderColor = Color.fromARGB(255, 0, 0, 0);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);

  // Green accent (primary)
  static const pink = Color(0xFF1DB954);
  static const pinkLight = Color(0xFF1DB954);
  static const pinkDark = Color(0xFF1DB954);
  static const pinkSurface = Color.fromARGB(255, 0, 0, 0);

  // Status colours
  static const success = Color(0xFF1DB954);
  static const warning = Color.fromARGB(255, 248, 153, 1);
  static const error = Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

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

  Future<void> fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final weekday = getIndianWeekday();
    final todayDate = DateTime.now().toIso8601String().split('T')[0];

    try {
      final timetable = await supabase
          .from('timetable')
          .select('id, time_slot, subjects!fk_subject(*)')
          .eq('user_id', user.uid)
          .eq('day', weekday)
          .order('time_slot', ascending: true);

      final overrides = await supabase
          .from('timetable_overrides')
          .select('time_slot, subjects(*)')
          .eq('user_id', user.uid)
          .eq('date', todayDate)
          .eq('day', weekday);

      final Map<int, dynamic> overrideMap = {};
      for (var o in overrides) {
        overrideMap[o['time_slot'] as int] = o['subjects'];
      }

      final List mergedTimetable = timetable.map((item) {
        final slot = item['time_slot'] as int;
        if (overrideMap.containsKey(slot)) {
          return {
            ...Map<String, dynamic>.from(item),
            'subjects': overrideMap[slot],
            'is_override': true,
          };
        }
        return {...Map<String, dynamic>.from(item), 'is_override': false};
      }).toList();

      final subjects = await supabase
          .from('subjects')
          .select('id, name, type')
          .eq('user_id', user.uid);

      final overallData = await supabase
          .from('attendance')
          .select('subject_id, present, date, time_slot, type')
          .eq('user_id', user.uid)
          .eq('type', 'Theory');

      final todayData = await supabase
          .from('attendance')
          .select('id, subject_id, present, date, time_slot')
          .eq('user_id', user.uid)
          .eq('date', todayDate);

      Map<String, String> tempMap = {};
      Map<String, String> tempIdMap = {};
      Map<String, List<Map<String, dynamic>>> tempHistory = {};

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
        todaysSubjects = mergedTimetable;
        allSubjects = subjects;
        attendanceMap = tempMap;
        attendanceIdMap = tempIdMap;
        subjectAttendanceHistory = tempHistory;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("fetchData error: $e");
      setState(() => isLoading = false);
    }
  }

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

        attendanceIdMap[key] = response[0]['id'].toString();
      }

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

      setState(() => attendanceMap[key] = value);
    } catch (e) {
      debugPrint("Attendance toggle error: $e");
    }
  }

  // ─── Filtered history helper ───────────────────────────────────────────────
  List<Map<String, dynamic>> _filteredHistory(String subjectId) {
    final history = subjectAttendanceHistory[subjectId] ?? [];
    if (filterStart == null && filterEnd == null) return history;

    return history.where((e) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date == null) return false;
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (filterStart != null && dateOnly.isBefore(filterStart!)) return false;
      if (filterEnd != null && dateOnly.isAfter(filterEnd!)) return false;
      return true;
    }).toList();
  }

  // ─── Stats (filter-aware) ─────────────────────────────────────────────────
  double calculateFilteredOverallAttendance() {
    int attended = 0, total = 0;
    for (var subject in allSubjects) {
      if (subject['type'] != 'Theory') continue;
      final history = _filteredHistory(subject['id'].toString());
      attended += history.where((v) => v['status'] == 'present').length;
      total += history.where((v) => v['status'] != 'cancelled').length;
    }
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  double calculateFilteredMonthlyAttendance() {
    if (filterStart != null || filterEnd != null) {
      return calculateFilteredOverallAttendance();
    }
    int attended = 0, total = 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    for (var subject in allSubjects) {
      if (subject['type'] != 'Theory') continue;
      final history = subjectAttendanceHistory[subject['id'].toString()] ?? [];
      for (var entry in history) {
        final entryDate = DateTime.tryParse(entry['date'] ?? '');
        if (entryDate == null) continue;
        final dateOnly = DateTime(
          entryDate.year,
          entryDate.month,
          entryDate.day,
        );
        if (dateOnly.isBefore(startOfMonth) || dateOnly.isAfter(endOfMonth))
          continue;
        if (entry['status'] == 'present') attended++;
        if (entry['status'] != 'cancelled') total++;
      }
    }
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  double calculateSubjectAttendance(String subjectId) {
    final history = _filteredHistory(subjectId);
    if (history.isEmpty) return 0;
    int attended = history.where((v) => v['status'] == 'present').length;
    int total = history.where((v) => v['status'] != 'cancelled').length;
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  int getPresent(String subjectId) =>
      _filteredHistory(subjectId).where((e) => e['status'] == 'present').length;

  int getTotal(String subjectId) => _filteredHistory(
    subjectId,
  ).where((e) => e['status'] != 'cancelled').length;

  int getMustAttend(int present, int total, int target) {
    if (total == 0) return 0;
    double value = (target * total - 100 * present) / (100 - target);
    return value < 0 ? 0 : value.ceil();
  }

  // ─── Pink-themed date range picker ───────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: filterStart != null && filterEnd != null
          ? DateTimeRange(start: filterStart!, end: filterEnd!)
          : null,
      // ── Pink & Black theme ──────────────────────────────────────────────
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // Scaffold / dialog background
            scaffoldBackgroundColor: bgBlack,
            dialogBackgroundColor: bgBlack,
            colorScheme: const ColorScheme.dark(
              // Primary = pink (selected circles, range highlight, buttons)
              primary: pink,
              onPrimary: Colors.white,

              // Surface = dark card
              surface: cardEnd,
              onSurface: Colors.white,

              // Secondary / outline
              secondary: pinkLight,
              onSecondary: Colors.white,

              // Background
              background: bgBlack,
              onBackground: Colors.white,

              // Error
              error: error,
              onError: Colors.white,

              // The range selection fill colour
              primaryContainer: pinkSurface,
              onPrimaryContainer: pinkLight,
            ),

            // Header text style
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),

            // AppBar inside the picker (month header)
            appBarTheme: const AppBarTheme(
              backgroundColor: bgBlack,
              foregroundColor: textPrimary,
              elevation: 0,
            ),

            // "CANCEL" / "SAVE" text buttons
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: pink,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Icon colours (nav arrows)
            iconTheme: const IconThemeData(color: pink),

            // Divider
            dividerColor: borderColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        filterStart = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        filterEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }

  void _clearFilter() => setState(() {
    filterStart = null;
    filterEnd = null;
  });

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  // ─── Date range filter bar ─────────────────────────────────────────────────
  Widget _buildDateRangeBar() {
    final bool isFiltered = filterStart != null && filterEnd != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFiltered
              ? [pinkSurface, const Color(0xFF1A0D14)]
              : [cardStart, cardEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFiltered ? pink : borderColor,
          width: isFiltered ? 1.5 : 1,
        ),
        boxShadow: isFiltered
            ? [
                BoxShadow(
                  color: pink.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Calendar icon with pink glow when active
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isFiltered ? pink.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: isFiltered ? pink : textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),

          // Date label
          Expanded(
            child: isFiltered
                ? RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatDate(filterStart!),
                          style: const TextStyle(
                            color: pinkLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text: '  →  ',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        TextSpan(
                          text: _formatDate(filterEnd!),
                          style: const TextStyle(
                            color: pinkLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Text(
                    "All time  ·  tap to filter by date",
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
          ),

          // Select / Change button
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [pink, pinkDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: pink.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                isFiltered ? "Change" : "Select",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          // Clear button (only when filtered)
          if (isFiltered) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearFilter,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: error.withOpacity(0.4)),
                ),
                child: const Icon(Icons.close_rounded, color: error, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final bool isFiltered = filterStart != null && filterEnd != null;
    final overall = calculateFilteredOverallAttendance();
    final monthly = calculateFilteredMonthlyAttendance();

    return Scaffold(
      backgroundColor: bgBlack,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: pink, strokeWidth: 2.5),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date range filter bar ──────────────────────────────
                  _buildDateRangeBar(),

                  // ── Stats header ───────────────────────────────────────
                  _buildStatRow(
                    label: isFiltered
                        ? "Range Attendance"
                        : "Overall Attendance",
                    value: "${overall.toStringAsFixed(1)}%",
                    isPrimary: true,
                  ),
                  if (!isFiltered) ...[
                    const SizedBox(height: 4),
                    _buildStatRow(
                      label: "Monthly Attendance",
                      value: "${monthly.toStringAsFixed(1)}%",
                      isPrimary: false,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Subject cards ──────────────────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: fetchData,
                      color: pink,
                      child: ListView.builder(
                        itemCount: todaysSubjects.length,
                        itemBuilder: (context, index) {
                          final item = todaysSubjects[index];
                          final subject = item['subjects'];
                          final subjectId = subject['id'].toString();
                          final timeSlot = item['time_slot'] as int;
                          final isOverride = item['is_override'] == true;

                          final percent = calculateSubjectAttendance(subjectId);
                          final present = getPresent(subjectId);
                          final total = getTotal(subjectId);
                          final mustAttend = getMustAttend(present, total, 75);

                          // Border colour logic
                          final borderC = isOverride
                              ? warning
                              : percent < 75
                              ? error
                              : borderColor;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [cardStart, cardEnd],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderC, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              "${subject['name']} (${subject['type']})",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (isOverride) ...[
                                            const SizedBox(width: 8),
                                            _pill("Override", warning),
                                          ],
                                        ],
                                      ),
                                    ),
                                    attendanceIcons(subjectId, timeSlot),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Attendance % with pink accent bar
                                _buildAttendanceBar(percent),
                                const SizedBox(height: 6),

                                Text(
                                  isFiltered
                                      ? "Range: ${percent.toStringAsFixed(1)}%  ·  $present / $total"
                                      : "Attendance: ${percent.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Must attend next: $mustAttend classes",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildStatRow({
    required String label,
    required String value,
    required bool isPrimary,
  }) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: isPrimary ? pink : textSecondary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 15,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isPrimary ? pinkLight : textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceBar(double percent) {
    final Color barColor = percent >= 75 ? pink : error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (percent / 100).clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: borderColor,
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
