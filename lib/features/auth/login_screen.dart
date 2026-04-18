import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  /// 🎨 THEME COLORS
  static const Color primary = Color(0xFF1DB954);
  static const Color accent = Color(0xFF1DB954);
  static const Color background = Color.fromARGB(255, 0, 0, 0);
  static const Color surface = Color(0xFF212121);
  static const Color border = Color(0xFF535353);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color error = Color(0xFFE57373);

  /// LOGIN LOGIC (UNCHANGED)
  Future<void> loginUser() async {
    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";

      if (e.code == 'user-not-found') {
        message = "No user found";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login error"), backgroundColor: error),
      );
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

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 90),

              /// TITLE
              const Text(
                "ECHO",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              /// SUBTEXT (cleaned — no // nonsense)
              const Text(
                "Login to continue",
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),

              const SizedBox(height: 60),

              /// EMAIL FIELD
              TextField(
                controller: emailController,
                style: const TextStyle(color: textPrimary),
                decoration: _inputDecoration("Email", Icons.email_outlined),
              ),

              const SizedBox(height: 20),

              /// PASSWORD FIELD
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: textPrimary),
                decoration: _inputDecoration("Password", Icons.lock_outline),
              ),

              const SizedBox(height: 40),

              /// LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: isLoading ? null : loginUser,

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
                          "LOGIN",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              /// SIGNUP LINK
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signup'),

                  child: RichText(
                    text: const TextSpan(
                      text: "No account? ",

                      style: TextStyle(color: textSecondary),

                      children: [
                        TextSpan(
                          text: "Create one",
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
            ],
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
