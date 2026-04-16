import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final supabase = Supabase.instance.client;

  List subjects = [];

  Map<String, List<Map<String, dynamic>>> subjectAttendanceHistory = {};

  bool isLoading = true;

  /// 🌸 SAKURA THEME COLORS

  static const backgroundColor = Color(0xFF0E0E11); // Ink Black

  static const surfaceColor = Color(0xFF16161B); // Charcoal Night

  static const primaryColor = Color(0xFFF2A7B8); // Powdered Sakura Pink

  static const accentColor = Color(0xFFE58A9B); // Soft Rose Pink

  static const textPrimary = Color(0xFFFFFFFF); // White

  static const textSecondary = Color(0xFFB8B8C7); // Dusty Lavender

  static const errorColor = Color(0xFFE57373); // Muted Sakura Red

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  bool isSameMonth(String dateStr) {
    final date = DateTime.parse(dateStr);

    final now = DateTime.now();

    return date.month == now.month && date.year == now.year;
  }

  bool isWithinSemester(String dateStr) {
    final date = DateTime.parse(dateStr);

    final now = DateTime.now();

    final start = DateTime(now.year, now.month - 4, 1);

    return date.isAfter(start);
  }

  Future<void> fetchData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final subjectsData = await supabase
          .from('subjects')
          .select()
          .eq('user_id', user.uid);

      final attendanceData = await supabase
          .from('attendance')
          .select('subject_id, present, date, time_slot')
          .eq('user_id', user.uid);

      Map<String, List<Map<String, dynamic>>> tempHistory = {};

      for (var a in attendanceData) {
        final subjectId = a['subject_id']?.toString();

        final date = a['date']?.toString();

        final timeSlot = a['time_slot'];

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

      setState(() {
        subjects = subjectsData;

        subjectAttendanceHistory = tempHistory;

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  double calculateAttendance(String subjectId, String type) {
    final history = subjectAttendanceHistory[subjectId] ?? [];

    if (history.isEmpty) return 0.0;

    List filtered;

    if (type == 'Theory') {
      filtered = history.where((v) => isSameMonth(v['date'])).toList();
    } else {
      filtered = history.where((v) => isWithinSemester(v['date'])).toList();
    }

    int attended = filtered.where((v) => v['status'] == 'present').length;

    int total = filtered.where((v) => v['status'] != 'cancelled').length;

    if (total == 0) return 0.0;

    return (attended / total) * 100;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,

        child: const Icon(Icons.add),

        onPressed: () async {
          await context.push('/add-subject');

          fetchData();
        },
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: subjects.length,

              itemBuilder: (context, index) {
                final subject = subjects[index];

                final subjectId = subject['id'].toString();

                final type = subject['type'] ?? 'Theory';

                final target = subject['target'] ?? 75;

                final percent = calculateAttendance(subjectId, type);

                final present = getPresent(subjectId);

                final total = getTotal(subjectId);

                final mustAttend = getMustAttend(present, total, target);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      /// SUBJECT + %
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          Text(
                            subject['name'],

                            style: TextStyle(
                              fontSize: 18,

                              fontWeight: FontWeight.bold,

                              color: percent < 75 ? errorColor : textPrimary,
                            ),
                          ),

                          Text(
                            "${percent.toStringAsFixed(1)}%",

                            style: TextStyle(
                              fontSize: 16,

                              fontWeight: FontWeight.bold,

                              color: percent < 75 ? errorColor : primaryColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      /// MUST ATTEND
                      Text(
                        "Must attend: $mustAttend",

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
    );
  }
}
