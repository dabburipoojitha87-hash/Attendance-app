import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  final supabase = Supabase.instance.client;

  Map<DateTime, List<String>> events = {};
  Map<String, double> monthlyAttendance = {};

  bool isLoading = true;

  DateTime focusedMonth = DateTime.now();

  /// 🎨 OFFICIAL THEME
  static const Color primary = Color(0xFFF2A7B8);
  static const Color accent = Color(0xFFE58A9B);
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF16161B);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8C7);

  static const Color success = Color(0xFF7BD3A8);
  static const Color warning = Color(0xFFF4C06A);
  static const Color error = Color(0xFFE57373);
  static const Color info = Color(0xFF89B4FA);

  @override
  void initState() {
    super.initState();
    fetchAttendance(focusedMonth);
  }

  DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String monthKey(DateTime dt) => "${dt.year}-${dt.month}";

  Future<void> fetchAttendance(DateTime month) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final data = await supabase
          .from('attendance')
          .select('date, present, subject_id, type')
          .eq('user_id', user.uid)
          .eq('type', 'Theory') // ✅ DB-level filter
          .gte('date', startOfMonth.toIso8601String())
          .lte('date', endOfMonth.toIso8601String());

      Map<DateTime, List<String>> tempEvents = {};
      Map<String, int> presentCount = {};
      Map<String, int> totalCount = {};

      for (var record in data) {
        final rawDate = DateTime.parse(record['date']).toLocal();
        final date = normalizeDate(rawDate);
        final key = monthKey(date);

        final status =
            record['present']?.toString().toLowerCase().trim() ?? 'cancelled';

        /// Store markers
        if (!tempEvents.containsKey(date)) {
          tempEvents[date] = [];
        }

        tempEvents[date]!.add(status);

        /// Monthly stats (already filtered)
        if (status != 'cancelled') {
          totalCount[key] = (totalCount[key] ?? 0) + 1;

          if (status == 'present') {
            presentCount[key] = (presentCount[key] ?? 0) + 1;
          }
        }
      }

      Map<String, double> monthPercent = {};

      for (var key in totalCount.keys) {
        final total = totalCount[key] ?? 0;
        final present = presentCount[key] ?? 0;

        if (total == 0) continue;

        monthPercent[key] = (present / total) * 100;
      }

      setState(() {
        events = tempEvents;
        monthlyAttendance = monthPercent;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      setState(() => isLoading = false);
    }
  }

  /// Dot Colors
  Color getColor(List<String> statuses) {
    final filtered = statuses.where((s) => s != 'cancelled').toList();

    if (filtered.isEmpty) return warning;

    if (filtered.every((s) => s == 'present')) return success;

    if (filtered.every((s) => s == 'absent')) return error;

    return info;
  }

  double getMonthPercentage(DateTime month) {
    final key = monthKey(month);

    return monthlyAttendance[key] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,

        elevation: 0,

        title: const Text(
          "Attendance Calendar",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

              child: TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),

                lastDay: DateTime.utc(2030, 12, 31),

                focusedDay: focusedMonth,

                onPageChanged: (focusedDay) {
                  setState(() {
                    focusedMonth = focusedDay;
                  });

                  fetchAttendance(focusedDay); // 🔥 THIS WAS MISSING
                },

                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,

                  titleCentered: true,

                  titleTextStyle: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),

                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: textSecondary,
                  ),

                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: textSecondary,
                  ),
                ),

                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: textSecondary),

                  weekendStyle: TextStyle(color: textSecondary),
                ),

                calendarStyle: const CalendarStyle(
                  defaultTextStyle: TextStyle(color: textPrimary),

                  weekendTextStyle: TextStyle(color: textPrimary),

                  outsideTextStyle: TextStyle(color: textSecondary),

                  todayDecoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),

                eventLoader: (day) {
                  final normalizedDay = normalizeDate(day);

                  return events[normalizedDay] ?? [];
                },

                calendarBuilders: CalendarBuilders(
                  /// Monthly %
                  headerTitleBuilder: (context, day) {
                    final percent = getMonthPercentage(day);

                    final percentColor = percent < 75 ? error : success;

                    final monthName = "${_monthName(day.month)} ${day.year}";

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Text(
                          monthName,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          "${percent.toStringAsFixed(0)}%",
                          style: TextStyle(
                            color: percentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },

                  /// Daily dots
                  markerBuilder: (context, day, eventsList) {
                    if (eventsList.isEmpty) {
                      return const SizedBox();
                    }

                    final color = getColor(eventsList.cast<String>());

                    return Positioned(
                      bottom: 4,

                      child: Container(
                        width: 7,

                        height: 7,

                        decoration: BoxDecoration(
                          color: color,

                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  String _monthName(int month) {
    const months = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return months[month];
  }
}
