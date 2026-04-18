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
  DateTime? selectedDay;

  DateTimeRange? selectedRange;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFF2A7B8);
  static const Color accent = Color(0xFFE58A9B);
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF16161B);
  static const Color cardStart = Color(0xFF1C1C24);
  static const Color cardEnd = Color(0xFF2A2A36);
  static const Color borderColor = Color(0xFF2F2F3A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8C7);

  static const Color success = Color(0xFF7BD3A8);
  static const Color warning = Color(0xFFF4C06A);
  static const Color error = Color(0xFFE57373);
  static const Color info = Color(0xFF89B4FA);
  static const Color holiday = Color(0xFFCE93D8);

  // ── Indian Public Holidays (2024, 2025 & 2026) ────────────────────────────
  static final Map<DateTime, String> indianHolidays = {
    // 2024
    DateTime(2024, 1, 26): "Republic Day",
    DateTime(2024, 3, 25): "Holi",
    DateTime(2024, 3, 29): "Good Friday",
    DateTime(2024, 4, 14): "Dr. Ambedkar Jayanti",
    DateTime(2024, 4, 17): "Ram Navami",
    DateTime(2024, 4, 21): "Mahavir Jayanti",
    DateTime(2024, 5, 23): "Buddha Purnima",
    DateTime(2024, 6, 17): "Eid ul-Adha",
    DateTime(2024, 7, 17): "Muharram",
    DateTime(2024, 8, 15): "Independence Day",
    DateTime(2024, 9, 16): "Milad-un-Nabi",
    DateTime(2024, 10, 2): "Gandhi Jayanti",
    DateTime(2024, 10, 12): "Dussehra",
    DateTime(2024, 10, 31): "Sardar Patel Jayanti",
    DateTime(2024, 11, 1): "Diwali",
    DateTime(2024, 11, 15): "Guru Nanak Jayanti",
    DateTime(2024, 12, 25): "Christmas",

    // 2025
    DateTime(2025, 1, 26): "Republic Day",
    DateTime(2025, 3, 14): "Holi",
    DateTime(2025, 3, 31): "Id-ul-Fitr (Eid)",
    DateTime(2025, 4, 10): "Mahavir Jayanti",
    DateTime(2025, 4, 14): "Dr. Ambedkar Jayanti",
    DateTime(2025, 4, 18): "Good Friday",
    DateTime(2025, 5, 12): "Buddha Purnima",
    DateTime(2025, 6, 7): "Eid ul-Adha",
    DateTime(2025, 7, 6): "Muharram",
    DateTime(2025, 8, 15): "Independence Day",
    DateTime(2025, 8, 16): "Janmashtami",
    DateTime(2025, 9, 5): "Milad-un-Nabi",
    DateTime(2025, 10, 2): "Gandhi Jayanti / Dussehra",
    DateTime(2025, 10, 20): "Diwali",
    DateTime(2025, 11, 5): "Guru Nanak Jayanti",
    DateTime(2025, 12, 25): "Christmas",

    // 2026
    DateTime(2026, 1, 26): "Republic Day",
    DateTime(2026, 3, 3): "Holi",
    DateTime(2026, 3, 20): "Id-ul-Fitr (Eid)",
    DateTime(2026, 3, 29): "Mahavir Jayanti",
    DateTime(2026, 4, 3): "Good Friday",
    DateTime(2026, 4, 14): "Dr. Ambedkar Jayanti",
    DateTime(2026, 5, 1): "Buddha Purnima",
    DateTime(2026, 5, 27): "Eid ul-Adha",
    DateTime(2026, 8, 15): "Independence Day",
    DateTime(2026, 10, 2): "Gandhi Jayanti",
    DateTime(2026, 11, 8): "Diwali",
    DateTime(2026, 12, 25): "Christmas",
  };

  @override
  void initState() {
    super.initState();
    fetchAttendance(focusedMonth);
  }

  DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  String monthKey(DateTime dt) => "${dt.year}-${dt.month}";

  bool isHoliday(DateTime day) =>
      indianHolidays.containsKey(normalizeDate(day));

  String? holidayName(DateTime day) => indianHolidays[normalizeDate(day)];

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
          .eq('type', 'Theory')
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

        tempEvents.putIfAbsent(date, () => []);
        tempEvents[date]!.add(status);

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
        if (total > 0) monthPercent[key] = (present / total) * 100;
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

  Color getColor(List<String> statuses) {
    final filtered = statuses.where((s) => s != 'cancelled').toList();
    if (filtered.isEmpty) return warning;
    if (filtered.every((s) => s == 'present')) return success;
    if (filtered.every((s) => s == 'absent')) return error;
    return info;
  }

  double getMonthPercentage(DateTime month) =>
      monthlyAttendance[monthKey(month)] ?? 0;

  // ── Open Themed Date Range Picker ─────────────────────────────────────────
  Future<void> _openDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: selectedRange,
      helpText: 'SELECT RANGE',
      saveText: 'SAVE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // ── Scaffold / Dialog background ────────────────────────────
            scaffoldBackgroundColor: background,
            dialogBackgroundColor: background,

            colorScheme: ColorScheme.dark(
              primary: accent,
              onPrimary: Colors.white,
              surface: surface,
              onSurface: textPrimary,
              background: background,
              onBackground: textPrimary,
              secondary: accent,
              onSecondary: Colors.white,
              error: error,
              onError: Colors.white,
              outline: borderColor,
              surfaceVariant: cardStart,
              onSurfaceVariant: textSecondary,
              primaryContainer: accent.withOpacity(0.18),
              onPrimaryContainer: accent,
            ),

            // ── AppBar (top header of picker) ───────────────────────────
            appBarTheme: const AppBarTheme(
              backgroundColor: surface,
              foregroundColor: textPrimary,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: textSecondary),
              actionsIconTheme: IconThemeData(color: accent),
              titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),

            // ── Text ────────────────────────────────────────────────────
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: textPrimary),
              bodyMedium: TextStyle(color: textPrimary),
              bodySmall: TextStyle(color: textSecondary),
              labelLarge: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
              labelMedium: TextStyle(color: textSecondary),
              labelSmall: TextStyle(color: textSecondary),
              titleMedium: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
              titleSmall: TextStyle(color: textSecondary),
              titleLarge: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              headlineSmall: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
              headlineMedium: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),

            // ── Divider ─────────────────────────────────────────────────
            dividerColor: borderColor,
            dividerTheme: const DividerThemeData(
              color: borderColor,
              thickness: 0.5,
            ),

            // ── Input fields (Start Date – End Date) ─────────────────────
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: cardStart,
              hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
              labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
              prefixIconColor: textSecondary,
              suffixIconColor: accent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: accent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: error),
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: const BorderSide(color: accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(foregroundColor: textSecondary),
            ),

            // ── Icon ─────────────────────────────────────────────────────
            iconTheme: const IconThemeData(color: textSecondary, size: 20),

            // ── Card / Dialog ─────────────────────────────────────────────
            cardTheme: CardThemeData(
              // ✅ FIXED
              color: surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: borderColor, width: 1),
              ),
            ),
            dialogTheme: DialogThemeData(
              // ✅ FIXED
              backgroundColor: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),

            // ── Chip (used for year/mode chips in some pickers) ───────────
            chipTheme: ChipThemeData(
              backgroundColor: cardStart,
              selectedColor: accent.withOpacity(0.2),
              labelStyle: const TextStyle(color: textPrimary),
              secondaryLabelStyle: const TextStyle(color: accent),
              side: const BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedRange = picked);
      // TODO: use selectedRange.start and selectedRange.end as needed
    }
  }

  // ── Legend row ─────────────────────────────────────────────────────────────
  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
    ],
  );

  Widget _legendBadge() => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: holiday.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: holiday.withOpacity(0.6), width: 0.8),
        ),
        child: const Text(
          "H",
          style: TextStyle(
            color: holiday,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 5),
      const Text(
        "Holiday",
        style: TextStyle(color: textSecondary, fontSize: 11),
      ),
    ],
  );

  // ── Holiday banner ─────────────────────────────────────────────────────────
  Widget _holidayBanner(String name) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [holiday.withOpacity(0.15), holiday.withOpacity(0.05)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: holiday.withOpacity(0.4), width: 1),
    ),
    child: Row(
      children: [
        const Icon(Icons.celebration_rounded, color: holiday, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: holiday,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const Text(
          "Public Holiday",
          style: TextStyle(color: textSecondary, fontSize: 11),
        ),
      ],
    ),
  );

  // ── Selected Range banner ──────────────────────────────────────────────────
  Widget _rangeBanner() {
    if (selectedRange == null) return const SizedBox.shrink();
    final start = selectedRange!.start;
    final end = selectedRange!.end;
    final days = end.difference(start).inDays + 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${_formatDate(start)}  →  ${_formatDate(end)}",
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            "$days days",
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${d.day} ${_monthName(d.month).substring(0, 3)} ${d.year}";

  @override
  Widget build(BuildContext context) {
    final percent = getMonthPercentage(focusedMonth);
    final selectedHoliday = selectedDay != null
        ? holidayName(selectedDay!)
        : null;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          "Attendance Calendar",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          // ── Date Range Picker button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openDateRangePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.date_range_rounded, color: accent, size: 15),
                    SizedBox(width: 5),
                    Text(
                      "Range",
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Calendar card ────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cardStart, cardEnd],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: focusedMonth,
                        selectedDayPredicate: (day) =>
                            selectedDay != null && isSameDay(day, selectedDay!),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            selectedDay = normalizeDate(selected);
                            focusedMonth = focused;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            focusedMonth = focusedDay;
                            selectedDay = null;
                          });
                          fetchAttendance(focusedDay);
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: textSecondary,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: textSecondary,
                          ),
                          headerPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                          weekendStyle: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                          ),
                          outsideTextStyle: TextStyle(
                            color: textSecondary.withOpacity(0.4),
                            fontSize: 13,
                          ),
                          todayDecoration: BoxDecoration(
                            color: accent.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent, width: 1.5),
                          ),
                          todayTextStyle: const TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          markersMaxCount: 1,
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          cellMargin: const EdgeInsets.all(4),
                        ),
                        eventLoader: (day) => events[normalizeDate(day)] ?? [],
                        calendarBuilders: CalendarBuilders(
                          // ── Header ────────────────────────────────────
                          headerTitleBuilder: (context, day) {
                            final pct = getMonthPercentage(day);
                            final pctColor = pct < 75 ? error : success;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${_monthName(day.month)} ${day.year}",
                                  style: const TextStyle(
                                    color: textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pctColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: pctColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    "${pct.toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      color: pctColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },

                          // ── Day cells ─────────────────────────────────
                          defaultBuilder: (context, day, focusedDay) =>
                              _buildDayCell(
                                day,
                                isToday: false,
                                isSelected: false,
                              ),
                          todayBuilder: (context, day, focusedDay) =>
                              _buildDayCell(
                                day,
                                isToday: true,
                                isSelected: false,
                              ),
                          selectedBuilder: (context, day, focusedDay) =>
                              _buildDayCell(
                                day,
                                isToday: false,
                                isSelected: true,
                              ),
                          outsideBuilder: (context, day, focusedDay) =>
                              _buildDayCell(
                                day,
                                isToday: false,
                                isSelected: false,
                                isOutside: true,
                              ),

                          // ── Attendance dot marker ─────────────────────
                          markerBuilder: (context, day, eventsList) {
                            if (eventsList.isEmpty) return const SizedBox();
                            final color = getColor(eventsList.cast<String>());
                            return Positioned(
                              bottom: 5,
                              child: Container(
                                width: 6,
                                height: 6,
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
                  ),

                  // ── Holiday banner ───────────────────────────────────
                  if (selectedHoliday != null) _holidayBanner(selectedHoliday),

                  // ── Date range banner ────────────────────────────────
                  _rangeBanner(),

                  // ── Legend ───────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _legendDot(success, "Present"),
                        _legendDot(error, "Absent"),
                        _legendDot(info, "Mixed"),
                        _legendDot(warning, "Cancelled"),
                        _legendBadge(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Day cell builder ────────────────────────────────────────────────────────
  Widget _buildDayCell(
    DateTime day, {
    required bool isToday,
    required bool isSelected,
    bool isOutside = false,
  }) {
    final isHol = isHoliday(day);
    final textColor = isOutside
        ? textSecondary.withOpacity(0.35)
        : isSelected
        ? Colors.white
        : isToday
        ? accent
        : textPrimary;

    BoxDecoration? bgDecoration;
    if (isSelected) {
      bgDecoration = const BoxDecoration(color: accent, shape: BoxShape.circle);
    } else if (isToday) {
      bgDecoration = BoxDecoration(
        color: accent.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: bgDecoration,
          alignment: Alignment.center,
          child: Text(
            "${day.day}",
            style: TextStyle(
              color: isHol && !isSelected && !isToday ? holiday : textColor,
              fontWeight: isSelected || isToday || isHol
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),

        // Holiday "H" badge
        if (isHol && !isOutside)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: holiday.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(color: holiday, width: 0.8),
              ),
              alignment: Alignment.center,
              child: const Text(
                "H",
                style: TextStyle(
                  color: holiday,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
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
