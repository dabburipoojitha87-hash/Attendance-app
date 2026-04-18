import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AddTimetableScreen extends StatefulWidget {
  const AddTimetableScreen({super.key});

  @override
  State<AddTimetableScreen> createState() => _AddTimetableScreenState();
}

class _AddTimetableScreenState extends State<AddTimetableScreen> {
  final supabase = Supabase.instance.client;

  List subjects = [];
  String? selectedSubjectId;
  String? selectedDay;
  int? selectedSlot;

  bool isLoading = true;

  final days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  final slots = [1, 2, 3, 4, 5, 6];

  /// 🎨 THEME COLORS
  static const bgBlack = Color.fromARGB(255, 0, 0, 0);
  static const surface = Color(0xFF212121);

  static const gradientStart = Color(0xFF212121);
  static const gradientEnd = Color(0xFF212121);

  static const divider = Color(0xFF535353);

  static const primaryPink = Color(0xFF1DB954);
  static const accentPink = Color(0xFF1DB954);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);

  @override
  void initState() {
    super.initState();
    fetchSubjects();
  }

  Future<void> fetchSubjects() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('subjects')
          .select()
          .eq('user_id', user.uid);

      setState(() {
        subjects = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> addTimetable() async {
    if (selectedSubjectId == null ||
        selectedDay == null ||
        selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select subject, day & slot")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    try {
      await supabase.from('timetable').insert({
        'user_id': user.uid,
        'subject_id': selectedSubjectId,
        'day': selectedDay,
        'time_slot': selectedSlot,
      });

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error adding timetable")));
    }
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: surface,

      hint: Text(hint, style: const TextStyle(color: textSecondary)),

      items: items,
      onChanged: onChanged,

      style: const TextStyle(color: textPrimary),

      decoration: InputDecoration(
        filled: true,
        fillColor: surface,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentPink, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,

      appBar: AppBar(
        title: const Text("Add Timetable"),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: textPrimary,
        elevation: 0,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : Padding(
              padding: const EdgeInsets.all(20),

              child: Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: divider),
                ),

                child: Column(
                  children: [
                    /// SUBJECT
                    _buildDropdown<String>(
                      value: selectedSubjectId,
                      hint: "Select Subject",
                      items: subjects.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text(s['name']),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => selectedSubjectId = val),
                    ),

                    const SizedBox(height: 16),

                    /// DAY
                    _buildDropdown<String>(
                      value: selectedDay,
                      hint: "Select Day",
                      items: days.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedDay = val),
                    ),

                    const SizedBox(height: 16),

                    /// SLOT
                    _buildDropdown<int>(
                      value: selectedSlot,
                      hint: "Select Time Slot",
                      items: slots.map((slot) {
                        return DropdownMenuItem(
                          value: slot,
                          child: Text("Period $slot"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedSlot = val),
                    ),

                    const SizedBox(height: 28),

                    /// SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: addTimetable,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),

                        child: const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
