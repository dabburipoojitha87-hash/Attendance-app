import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BunkCalculatorScreen extends StatefulWidget {
  const BunkCalculatorScreen({super.key});

  @override
  State<BunkCalculatorScreen> createState() => _BunkCalculatorScreenState();
}

class _BunkCalculatorScreenState extends State<BunkCalculatorScreen> {
  final supabase = Supabase.instance.client;

  // ================= THEME =================

  static const bgBlack = Color.fromARGB(255, 0, 0, 0);
  static const cardStart = Color.fromARGB(255, 0, 0, 0);
  static const cardEnd = Color.fromARGB(255, 0, 0, 0);
  static const borderColor = Color.fromARGB(255, 0, 0, 0);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB3B3B3);
  static const success = Color(0xFF1DB954);
  static const warning = Color.fromARGB(255, 255, 158, 1);
  static const errorColor = Color(0xFFE57373);

  // ================= STATE =================

  bool isLoading = true;

  /// All theory subjects (id + name)
  List<Map<String, dynamic>> theorySubjects = [];

  /// Aggregated stats per subject: { subjectId: {present, total} }
  Map<String, Map<String, int>> subjectStats = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ================= FETCH =================

  Future<void> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      /// 1. Fetch all theory subjects for this user
      final subjects = await supabase
          .from('subjects')
          .select('id, name, type')
          .eq('user_id', user.uid)
          .eq('type', 'Theory');

      /// 2. Fetch ALL-TIME attendance for theory subjects
      final attendance = await supabase
          .from('attendance')
          .select('subject_id, present')
          .eq('user_id', user.uid)
          .eq('type', 'Theory');

      /// 3. Aggregate present / total per subject
      final Map<String, Map<String, int>> stats = {};

      for (final a in attendance) {
        final sid = a['subject_id']?.toString();
        if (sid == null) continue;

        stats.putIfAbsent(sid, () => {'present': 0, 'total': 0});

        final status = a['present'];
        if (status != 'cancelled') {
          stats[sid]!['total'] = stats[sid]!['total']! + 1;
          if (status == 'present') {
            stats[sid]!['present'] = stats[sid]!['present']! + 1;
          }
        }
      }

      setState(() {
        theorySubjects = List<Map<String, dynamic>>.from(subjects);
        subjectStats = stats;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("BunkCalculator fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  // ================= CALCULATIONS =================

  /// Returns overall attendance % after simulating [classes] bunked or attended
  double _simulateOverall(int classes, String scenario) {
    int totalPresent = 0;
    int totalClasses = 0;

    for (final subject in theorySubjects) {
      final sid = subject['id'].toString();
      final stats = subjectStats[sid] ?? {'present': 0, 'total': 0};

      totalPresent += stats['present']!;
      totalClasses += stats['total']!;
    }

    if (scenario == 'bunk') {
      totalClasses += classes;
      // present stays same
    } else {
      totalClasses += classes;
      totalPresent += classes;
    }

    if (totalClasses == 0) return 0;
    return (totalPresent / totalClasses) * 100;
  }

  /// Returns per-subject attendance % after simulation
  double _simulateSubject(String subjectId, int classes, String scenario) {
    final stats = subjectStats[subjectId] ?? {'present': 0, 'total': 0};
    int present = stats['present']!;
    int total = stats['total']!;

    if (scenario == 'bunk') {
      total += classes;
    } else {
      total += classes;
      present += classes;
    }

    if (total == 0) return 0;
    return (present / total) * 100;
  }

  /// How many classes can still be bunked before dropping below [target]%
  int _canStillBunk(String subjectId, int target) {
    final stats = subjectStats[subjectId] ?? {'present': 0, 'total': 0};
    final present = stats['present']!;
    final total = stats['total']!;

    // present / (total + x) >= target/100  →  x <= (present*100 - target*total) / target
    if (target == 0) return 9999;
    final value = (present * 100 - target * total) / target;
    if (value < 0) return 0;
    return value.floor();
  }

  /// How many classes must be attended to reach [target]%
  int _mustAttend(String subjectId, int target) {
    final stats = subjectStats[subjectId] ?? {'present': 0, 'total': 0};
    final present = stats['present']!;
    final total = stats['total']!;

    // (present + x) / (total + x) >= target/100
    // x >= (target*total - 100*present) / (100 - target)
    if (target >= 100) return 9999;
    final value = (target * total - 100 * present) / (100 - target);
    if (value <= 0) return 0;
    return value.ceil();
  }

  double _currentOverall() {
    int p = 0, t = 0;
    for (final subject in theorySubjects) {
      final sid = subject['id'].toString();
      final stats = subjectStats[sid] ?? {'present': 0, 'total': 0};
      p += stats['present']!;
      t += stats['total']!;
    }
    if (t == 0) return 0;
    return (p / t) * 100;
  }

  double _currentSubjectPct(String subjectId) {
    final stats = subjectStats[subjectId] ?? {'present': 0, 'total': 0};
    final t = stats['total']!;
    if (t == 0) return 0;
    return (stats['present']! / t) * 100;
  }

  // ================= UI =================

  Color _pctColor(double pct) {
    if (pct >= 75) return success;
    if (pct >= 60) return warning;
    return errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      appBar: AppBar(
        backgroundColor: bgBlack,
        title: const Text(
          "Bunk Calculator",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textSecondary),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: success))
          : theorySubjects.isEmpty
          ? const Center(
              child: Text(
                "No theory subjects found.",
                style: TextStyle(color: textSecondary),
              ),
            )
          : RefreshIndicator(
              color: success,
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Overall card ──
                  _overallCard(),

                  const SizedBox(height: 20),

                  const Text(
                    "Subject-wise",
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Per-subject cards ──
                  ...theorySubjects.map((subject) {
                    final sid = subject['id'].toString();
                    return _subjectCard(sid, subject['name']);
                  }),

                  const SizedBox(height: 20),

                  // ── Simulator button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: success,
                        foregroundColor: bgBlack,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.calculate_rounded),
                      label: const Text(
                        "Open Attendance Simulator",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () => _showAttendanceSimulator(context),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _overallCard() {
    final overall = _currentOverall();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [cardStart, cardEnd]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overall >= 75 ? success : errorColor,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Attendance",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  "${overall.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: _pctColor(overall),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            overall >= 75
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: _pctColor(overall),
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(String subjectId, String name) {
    final pct = _currentSubjectPct(subjectId);
    final canBunk = _canStillBunk(subjectId, 75);
    final mustAttend = _mustAttend(subjectId, 75);
    final stats = subjectStats[subjectId] ?? {'present': 0, 'total': 0};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [cardStart, cardEnd]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pct < 75 ? errorColor : borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                "${pct.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: _pctColor(pct),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            "${stats['present']} / ${stats['total']} classes attended",
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: borderColor,
              valueColor: AlwaysStoppedAnimation(_pctColor(pct)),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              if (pct >= 75) ...[
                _infoChip(
                  Icons.event_busy_rounded,
                  "Can bunk: $canBunk",
                  success,
                ),
              ] else ...[
                _infoChip(
                  Icons.event_available_rounded,
                  "Must attend: $mustAttend",
                  errorColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SIMULATOR BOTTOM SHEET =================

  void _showAttendanceSimulator(BuildContext context) {
    int classes = 1;
    String scenario = "bunk";
    String scope = "overall"; // "overall" or a subjectId
    int target = 75;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardStart,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Compute result live
            double result;
            if (scope == "overall") {
              result = _simulateOverall(classes, scenario);
            } else {
              result = _simulateSubject(scope, classes, scenario);
            }

            final double currentPct = scope == "overall"
                ? _currentOverall()
                : _currentSubjectPct(scope);

            final bool willPass = result >= target;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Attendance Simulator",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Scope selector ──
                    const Text(
                      "Scope",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text("Overall"),
                            selected: scope == "overall",
                            selectedColor: success.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: scope == "overall"
                                  ? success
                                  : textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) =>
                                setModalState(() => scope = "overall"),
                          ),
                          const SizedBox(width: 8),
                          ...theorySubjects.map((s) {
                            final sid = s['id'].toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(s['name']),
                                selected: scope == sid,
                                selectedColor: success.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: scope == sid ? success : textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) =>
                                    setModalState(() => scope = sid),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Scenario selector ──
                    const Text(
                      "Scenario",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => scenario = "bunk"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: scenario == "bunk"
                                    ? errorColor.withOpacity(0.15)
                                    : cardEnd,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: scenario == "bunk"
                                      ? errorColor
                                      : borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy_rounded,
                                    color: scenario == "bunk"
                                        ? errorColor
                                        : textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Bunk",
                                    style: TextStyle(
                                      color: scenario == "bunk"
                                          ? errorColor
                                          : textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setModalState(() => scenario = "attend"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: scenario == "attend"
                                    ? success.withOpacity(0.15)
                                    : cardEnd,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: scenario == "attend"
                                      ? success
                                      : borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    color: scenario == "attend"
                                        ? success
                                        : textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Attend",
                                    style: TextStyle(
                                      color: scenario == "attend"
                                          ? success
                                          : textSecondary,
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

                    const SizedBox(height: 20),

                    // ── Classes slider ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Classes",
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        Text(
                          "$classes",
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    Slider(
                      value: classes.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: success,
                      inactiveColor: borderColor,
                      label: classes.toString(),
                      onChanged: (val) {
                        setModalState(() => classes = val.toInt());
                      },
                    ),

                    // ── Target slider ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Target %",
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        Text(
                          "$target%",
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    Slider(
                      value: target.toDouble(),
                      min: 50,
                      max: 100,
                      divisions: 10,
                      activeColor: warning,
                      inactiveColor: borderColor,
                      label: "$target%",
                      onChanged: (val) {
                        setModalState(() => target = val.toInt());
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Live result card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: willPass
                            ? success.withOpacity(0.1)
                            : errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: willPass
                              ? success.withOpacity(0.4)
                              : errorColor.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                willPass
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: willPass ? success : errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                willPass
                                    ? "Safe to ${scenario == 'bunk' ? 'bunk' : 'attend'}!"
                                    : "Risky!",
                                style: TextStyle(
                                  color: willPass ? success : errorColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _resultRow(
                            "Current",
                            "${currentPct.toStringAsFixed(1)}%",
                            textSecondary,
                          ),
                          const SizedBox(height: 4),
                          _resultRow(
                            "After ${scenario == 'bunk' ? 'bunking' : 'attending'} $classes class${classes == 1 ? '' : 'es'}",
                            "${result.toStringAsFixed(1)}%",
                            _pctColor(result),
                          ),
                          const SizedBox(height: 4),
                          _resultRow("Target", "$target%", warning),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
