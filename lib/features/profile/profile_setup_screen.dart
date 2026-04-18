import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final branchController = TextEditingController();
  final semesterController = TextEditingController();

  final semesterDurationController = TextEditingController(text: "5");
  final courseDurationController = TextEditingController(text: "4");
  final targetController = TextEditingController(text: "75");

  bool isLoading = false;

  /// 🎨 THEME
  static const bgBlack = Color(0xFF121212);
  static const surface = Color(0xFF212121);

  static const gradientStart = Color(0xFF212121);
  static const gradientEnd = Color(0xFF212121);

  static const divider = Color(0xFF535353);

  static const primaryPink = Color(0xFF1DB954);
  static const accentPink = Color(0xFF1DB954);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);

  Future<void> saveProfile() async {
    if (nameController.text.isEmpty ||
        branchController.text.isEmpty ||
        semesterController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;
    final user = FirebaseAuth.instance.currentUser;

    try {
      await supabase.from('users').insert({
        'id': user!.uid,
        'email': user.email,
        'name': nameController.text.trim(),
        'branch': branchController.text.trim(),
        'semester': semesterController.text.trim(),
        'semester_duration': int.parse(semesterDurationController.text),
        'course_duration': int.parse(courseDurationController.text),
        'target_percentage': int.parse(targetController.text),
      });

      context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    branchController.dispose();
    semesterController.dispose();
    semesterDurationController.dispose();
    courseDurationController.dispose();
    targetController.dispose();
    super.dispose();
  }

  Widget buildField(
    String hint,
    IconData icon,
    TextEditingController c, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: textPrimary),

      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSecondary),

        prefixIcon: Icon(icon, color: accentPink),

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

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: ListView(
            children: [
              const SizedBox(height: 20),

              /// TITLE
              const Text(
                "Setup Profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Let’s get your academic details in place",
                style: TextStyle(color: textSecondary),
              ),

              const SizedBox(height: 24),

              /// CARD CONTAINER
              Container(
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
                    buildField("Full Name", Icons.person, nameController),
                    const SizedBox(height: 16),

                    buildField("Branch", Icons.school, branchController),
                    const SizedBox(height: 16),

                    buildField(
                      "Semester",
                      Icons.calendar_today,
                      semesterController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    buildField(
                      "Semester Duration (months)",
                      Icons.timer,
                      semesterDurationController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    buildField(
                      "Course Duration (years)",
                      Icons.timeline,
                      courseDurationController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    buildField(
                      "Target Attendance (%)",
                      Icons.flag,
                      targetController,
                      type: TextInputType.number,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveProfile,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Continue",
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
