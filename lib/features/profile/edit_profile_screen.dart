import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;

  final name = TextEditingController();
  final branch = TextEditingController();
  final semester = TextEditingController();
  final target = TextEditingController();

  bool isLoading = true;

  /// 🎨 THEME
  static const bgBlack = Color(0xFF0E0E11);
  static const surface = Color(0xFF16161B);

  static const gradientStart = Color(0xFF1C1C24);
  static const gradientEnd = Color(0xFF2A2A36);

  static const divider = Color(0xFF2F2F3A);

  static const primaryPink = Color(0xFFF2A7B8);
  static const accentPink = Color(0xFFE58A9B);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB8B8C7);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final user = FirebaseAuth.instance.currentUser;

    final data = await supabase
        .from('users')
        .select()
        .eq('id', user!.uid)
        .single();

    name.text = data['name'];
    branch.text = data['branch'];
    semester.text = data['semester'];
    target.text = data['target_percentage'].toString();

    setState(() => isLoading = false);
  }

  Future<void> update() async {
    final user = FirebaseAuth.instance.currentUser;

    await supabase
        .from('users')
        .update({
          'name': name.text,
          'branch': branch.text,
          'semester': semester.text,
          'target_percentage': int.parse(target.text),
        })
        .eq('id', user!.uid);

    Navigator.pop(context);
  }

  Widget buildField(
    String hint,
    IconData icon,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: bgBlack,
        body: Center(child: CircularProgressIndicator(color: primaryPink)),
      );
    }

    return Scaffold(
      backgroundColor: bgBlack,

      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            /// 🧾 FORM CARD
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
                  buildField("Full Name", Icons.person, name),
                  const SizedBox(height: 16),

                  buildField("Branch", Icons.school, branch),
                  const SizedBox(height: 16),

                  buildField(
                    "Semester",
                    Icons.calendar_today,
                    semester,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  buildField(
                    "Target Attendance (%)",
                    Icons.flag,
                    target,
                    type: TextInputType.number,
                  ),
                ],
              ),
            ),

            const Spacer(),

            /// 💾 SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: update,

                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),

                child: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
