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

  /// 🌸 SPOTIFY THEME COLORS

  static const backgroundColor = Color.fromARGB(255, 0, 0, 0);
  static const surfaceColor = Color(0xFF212121);
  static const primaryColor = Color(0xFF1DB954);
  static const accentColor = Color(0xFF1DB954);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const errorColor = Color(0xFFE57373);

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

  /// ✅ Yearly filter for practicals
  bool isWithinYear(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    return date.year == now.year;
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

  /// ✅ CENTRAL FIX: filtered stats (used everywhere)
  Map<String, int> getFilteredStats(String subjectId, String type) {
    final history = subjectAttendanceHistory[subjectId] ?? [];

    if (history.isEmpty) {
      return {'present': 0, 'total': 0};
    }

    List filtered;

    if (type == 'Theory') {
      filtered = history.where((v) => isSameMonth(v['date'])).toList();
    } else {
      filtered = history.where((v) => isWithinYear(v['date'])).toList();
    }

    int present = filtered.where((v) => v['status'] == 'present').length;
    int total = filtered.where((v) => v['status'] != 'cancelled').length;

    return {'present': present, 'total': total};
  }

  double calculateAttendance(String subjectId, String type) {
    final stats = getFilteredStats(subjectId, type);

    int present = stats['present']!;
    int total = stats['total']!;

    if (total == 0) return 0.0;

    return (present / total) * 100;
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

                /// ✅ FIXED: use filtered stats instead of full history
                final stats = getFilteredStats(subjectId, type);
                final present = stats['present']!;
                final total = stats['total']!;
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
