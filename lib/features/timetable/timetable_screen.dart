import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final supabase = Supabase.instance.client;

  Map<String, List> timetableByDay = {};
  List overrides = [];

  bool isLoading = true;

  final days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  /// 🌸 THEME COLORS

  static const bgBlack = Color.fromARGB(255, 0, 0, 0);
  static const surface = Color(0xFF212121);
  static const divider = Color(0xFF535353);

  static const primaryPink = Color(0xFF1DB954);
  static const accentPink = Color(0xFF1DB954);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);

  static const warning = Color(0xFFF4C06A);

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  /// 🚀 FAST FETCH
  Future<void> fetchAll() async {
    setState(() => isLoading = true);

    await Future.wait([fetchTimetable(), fetchOverrides()]);

    setState(() => isLoading = false);
  }

  /// 📅 TIMETABLE
  Future<void> fetchTimetable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('timetable')
          .select('id, day, time_slot, subjects!inner(name)')
          .eq('user_id', user.uid);

      Map<String, List> grouped = {};

      for (var day in days) {
        grouped[day] = [];
      }

      for (var item in data) {
        final day = item['day'];

        if (grouped.containsKey(day)) {
          grouped[day]!.add(item);
        }
      }

      timetableByDay = grouped;
    } catch (e) {
      print("ERROR timetable: $e");
    }
  }

  /// 🔁 OVERRIDES
  Future<void> fetchOverrides() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toString().split(' ')[0];

    try {
      final data = await supabase
          .from('timetable_overrides')
          .select('time_slot, date, day, subjects(name)')
          .eq('user_id', user.uid)
          .eq('date', today);

      overrides = data;
    } catch (e) {
      print("ERROR override: $e");
    }
  }

  /// SUBJECT NAME
  String getSubjectName(List items, int slot, String day) {
    final today = DateTime.now().toString().split(' ')[0];

    final overrideList = overrides.where(
      (o) => o['time_slot'] == slot && o['date'] == today && o['day'] == day,
    );

    final override = overrideList.isNotEmpty ? overrideList.first : null;

    if (override != null) {
      return override['subjects']['name'];
    }

    for (var item in items) {
      final itemSlot = int.tryParse(item['time_slot'].toString());

      if (itemSlot == slot) {
        return item['subjects']?['name'] ?? "-";
      }
    }

    return "-";
  }

  /// OVERRIDE COLOR
  bool isOverridden(int slot, String day) {
    final today = DateTime.now().toString().split(' ')[0];

    return overrides.any(
      (o) => o['time_slot'] == slot && o['date'] == today && o['day'] == day,
    );
  }

  /// REPLACE SUBJECT
  Future<void> showReplaceDialog(int slot, String day) async {
    String? selectedSubjectId;

    final subjects = await supabase.from('subjects').select();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: surface,

          title: const Text(
            "Replace for today",
            style: TextStyle(color: textPrimary),
          ),

          content: DropdownButtonFormField<String>(
            dropdownColor: surface,

            hint: const Text(
              "Select Subject",
              style: TextStyle(color: textSecondary),
            ),

            items: subjects.map<DropdownMenuItem<String>>((s) {
              return DropdownMenuItem(
                value: s['id'].toString(),
                child: Text(
                  s['name'],
                  style: const TextStyle(color: textPrimary),
                ),
              );
            }).toList(),

            onChanged: (value) {
              selectedSubjectId = value;
            },
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),

              child: const Text(
                "Cancel",
                style: TextStyle(color: textSecondary),
              ),
            ),

            TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (selectedSubjectId == null || user == null) return;

                final today = DateTime.now().toString().split(' ')[0];

                await supabase.from('timetable_overrides').upsert({
                  'user_id': user.uid,
                  'date': today,
                  'day': day,
                  'time_slot': slot,
                  'subject_id': selectedSubjectId,
                });

                Navigator.pop(context);

                await fetchOverrides();

                setState(() {});
              },

              child: const Text("Save", style: TextStyle(color: primaryPink)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,

      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryPink,

        onPressed: () async {
          await context.push('/add-timetable');
          await fetchAll();
        },

        child: const Icon(Icons.add, color: Colors.black),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: days.map((day) {
                  final items = timetableByDay[day] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// DAY TITLE
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// PERIOD ROW
                        Row(
                          children: List.generate(6, (index) {
                            final slot = index + 1;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => showReplaceDialog(slot, day),

                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),

                                  decoration: BoxDecoration(
                                    color: isOverridden(slot, day)
                                        ? warning.withOpacity(0.25)
                                        : bgBlack,

                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: Column(
                                    children: [
                                      /// PERIOD LABEL
                                      Text(
                                        "P$slot",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: textSecondary,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      /// SUBJECT
                                      Text(
                                        getSubjectName(items, slot, day),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
