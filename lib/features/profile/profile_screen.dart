import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  // 🧠 INSIGHTS STATE
  List<String> insights = [];
  bool isInsightsLoading = true;

  /// 🎨 THEME
  static const bgBlack = Color.fromARGB(255, 0, 0, 0);
  static const surface = Color.fromARGB(255, 0, 0, 0);

  static const gradientStart = Color.fromARGB(255, 0, 0, 0);
  static const gradientEnd = Color(0xFF212121);

  static const divider = Color(0xFF535353);

  static const primary = Color(0xFF1DB954);
  static const accent = Color(0xFF1DB954);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchInsights(); // 👈 added
  }

  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    final data = await supabase
        .from('users')
        .select()
        .eq('id', user!.uid)
        .single();

    setState(() {
      userData = data;
      isLoading = false;
    });
  }

  // ================= INSIGHTS LOGIC =================

  Future<void> fetchInsights() async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      final attendance = await supabase
          .from('attendance')
          .select('present, date')
          .eq('user_id', user!.uid);

      Map<String, int> dayMissCount = {};
      Map<String, int> dayTotalCount = {};

      for (var a in attendance) {
        if (a['present'] == "cancelled") continue;

        final date = DateTime.parse(a['date']);
        final day = _getDayName(date.weekday);

        dayTotalCount[day] = (dayTotalCount[day] ?? 0) + 1;

        if (a['present'] != "present") {
          dayMissCount[day] = (dayMissCount[day] ?? 0) + 1;
        }
      }

      List<String> generatedInsights = [];

      // Worst day
      if (dayMissCount.isNotEmpty) {
        final worstDay = dayMissCount.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );

        generatedInsights.add(
          "You tend to miss more classes on ${worstDay.key}.",
        );
      }

      // Best day
      if (dayTotalCount.isNotEmpty) {
        String bestDay = "";
        double bestRate = 0;

        dayTotalCount.forEach((day, total) {
          final missed = dayMissCount[day] ?? 0;
          final rate = (total - missed) / total;

          if (rate > bestRate) {
            bestRate = rate;
            bestDay = day;
          }
        });

        if (bestDay.isNotEmpty) {
          generatedInsights.add("You attend most classes on $bestDay.");
        }
      }

      // Consistency
      int total = 0;
      int missed = 0;

      dayTotalCount.forEach((day, t) {
        total += t;
        missed += (dayMissCount[day] ?? 0);
      });

      if (total > 0) {
        final percent = ((total - missed) / total) * 100;

        if (percent < 75) {
          generatedInsights.add(
            "Your attendance is inconsistent. You need more regularity.",
          );
        } else {
          generatedInsights.add(
            "Your attendance pattern is fairly consistent.",
          );
        }
      }

      setState(() {
        insights = generatedInsights;
        isInsightsLoading = false;
      });
    } catch (e) {
      setState(() {
        insights = ["Couldn't generate insights"];
        isInsightsLoading = false;
      });
    }
  }

  String _getDayName(int weekday) {
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    return days[weekday - 1];
  }

  // ================= UI HELPERS =================

  void goToEdit() async {
    await context.push('/edit-profile');
    fetchProfile();
  }

  Widget buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: bgBlack,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return Scaffold(
      backgroundColor: bgBlack,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// 👤 PROFILE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [gradientStart, gradientEnd],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: divider),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: primary,
                    child: Text(
                      userData!['name'][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData!['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData!['branch'],
                    style: const TextStyle(color: textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: divider),

                  buildRow("Semester", userData!['semester']),
                  buildRow(
                    "Semester Duration",
                    "${userData!['semester_duration']} months",
                  ),
                  buildRow(
                    "Course Duration",
                    "${userData!['course_duration']} years",
                  ),
                  buildRow("Target", "${userData!['target_percentage']}%"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🧠 INSIGHTS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Insights",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isInsightsLoading)
                    const Center(
                      child: CircularProgressIndicator(color: primary),
                    )
                  else
                    Column(
                      children: insights
                          .map(
                            (insight) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      insight,
                                      style: const TextStyle(
                                        color: textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),

            const Spacer(),

            /// ✏️ EDIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: goToEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Edit Profile",
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
