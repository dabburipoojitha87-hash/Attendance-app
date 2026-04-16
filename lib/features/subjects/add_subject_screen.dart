import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSubjectScreen extends StatefulWidget {
  const AddSubjectScreen({super.key});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final nameController = TextEditingController();

  bool isLoading = false;

  final List<String> subjectTypes = ['Theory', 'Practical', 'Lab'];

  String selectedType = 'Theory';

  /// 🎨 THEME COLORS
  static const Color primary = Color(0xFFF2A7B8);
  static const Color accent = Color(0xFFE58A9B);
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF16161B);
  static const Color border = Color(0xFF2F2F3A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8C7);
  static const Color error = Color(0xFFE57373);

  /// ADD SUBJECT LOGIC (UNCHANGED)
  Future<void> addSubject() async {
    if (isLoading) return;

    final name = nameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    /// EMPTY CHECK
    if (name.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter subject name"),
          backgroundColor: error,
        ),
      );

      return;
    }

    /// USER CHECK
    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User not logged in"),
          backgroundColor: error,
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('subjects').insert({
        'user_id': user.uid,
        'name': name,
        'type': selectedType,
      });

      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error adding subject"),
          backgroundColor: error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        title: const Text(
          "Add Subject",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),

        backgroundColor: background,

        foregroundColor: primary,

        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            /// SUBJECT NAME
            TextField(
              controller: nameController,

              style: const TextStyle(color: textPrimary),

              decoration: InputDecoration(
                hintText: "Subject Name",

                hintStyle: const TextStyle(color: textSecondary),

                filled: true,

                fillColor: surface,

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),

                  borderSide: const BorderSide(color: border),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),

                  borderSide: const BorderSide(color: primary, width: 1.4),
                ),
              ),
            ),

            const SizedBox(height: 32),

            /// LABEL
            const Text(
              'Select Subject Type',

              style: TextStyle(
                fontWeight: FontWeight.bold,

                color: textPrimary,

                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            /// DROPDOWN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              decoration: BoxDecoration(
                color: surface,

                borderRadius: BorderRadius.circular(15),

                border: Border.all(color: border),
              ),

              child: DropdownButton<String>(
                value: selectedType,

                isExpanded: true,

                dropdownColor: surface,

                icon: const Icon(Icons.keyboard_arrow_down, color: primary),

                underline: const SizedBox(),

                style: const TextStyle(color: textPrimary, fontSize: 16),

                items: subjectTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),

                onChanged: (val) {
                  if (val != null) {
                    setState(() => selectedType = val);
                  }
                },
              ),
            ),

            const SizedBox(height: 40),

            /// ADD BUTTON
            SizedBox(
              width: double.infinity,

              height: 55,

              child: ElevatedButton(
                onPressed: isLoading ? null : addSubject,

                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                child: isLoading
                    ? const SizedBox(
                        height: 22,

                        width: 22,

                        child: CircularProgressIndicator(
                          color: Colors.white,

                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ADD SUBJECT",

                        style: TextStyle(
                          fontWeight: FontWeight.bold,

                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
