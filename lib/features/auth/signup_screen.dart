import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  /// 🎨 THEME COLORS
  static const Color primary = Color(0xFFF2A7B8);
  static const Color accent = Color(0xFFE58A9B);
  static const Color background = Color(0xFF0E0E11);
  static const Color surface = Color(0xFF16161B);
  static const Color border = Color(0xFF2F2F3A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8C7);
  static const Color error = Color(0xFFE57373);

  /// SIGNUP LOGIC (UNCHANGED)
  Future<void> signupUser() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: error,
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (mounted) {
        context.go('/profile-setup');
      }
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";

      if (e.code == 'weak-password') {
        message = "Password is too weak";
      } else if (e.code == 'email-already-in-use') {
        message = "Email already exists";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const SizedBox(height: 70),

                /// TITLE
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                /// SUBTEXT
                const Text(
                  "Sign up to get started with Echo",
                  style: TextStyle(fontSize: 15, color: textSecondary),
                ),

                const SizedBox(height: 40),

                /// FULL NAME (UI ONLY)
                TextField(
                  style: const TextStyle(color: textPrimary),
                  decoration: _inputDecoration(
                    "Full Name",
                    Icons.person_outline,
                  ),
                ),

                const SizedBox(height: 16),

                /// EMAIL
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: textPrimary),
                  decoration: _inputDecoration("Email", Icons.email_outlined),
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: textPrimary),
                  decoration: _inputDecoration("Password", Icons.lock_outline),
                ),

                const SizedBox(height: 16),

                /// CONFIRM PASSWORD
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: textPrimary),
                  decoration: _inputDecoration(
                    "Confirm Password",
                    Icons.lock_outline,
                  ),
                ),

                const SizedBox(height: 32),

                /// SIGNUP BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : signupUser,

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
                            "SIGN UP",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                /// LOGIN REDIRECT
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),

                    child: RichText(
                      text: const TextSpan(
                        text: "Already have an account? ",

                        style: TextStyle(color: textSecondary),

                        children: [
                          TextSpan(
                            text: "Login",
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// INPUT FIELD STYLE
  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,

      hintStyle: const TextStyle(color: textSecondary),

      prefixIcon: Icon(icon, color: primary),

      filled: true,
      fillColor: surface,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: border),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    );
  }
}
