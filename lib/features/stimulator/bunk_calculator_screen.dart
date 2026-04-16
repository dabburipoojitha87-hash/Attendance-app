import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BunkCalculatorScreen extends StatefulWidget {
  const BunkCalculatorScreen({super.key});

  @override
  State<BunkCalculatorScreen> createState() => _BunkCalculatorScreenState();
}

class _BunkCalculatorScreenState extends State<BunkCalculatorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bunk Calculator")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showAttendanceSimulator(context);
          },
          child: const Text("Open Attendance Simulator"),
        ),
      ),
    );
  }

  void showAttendanceSimulator(BuildContext context) {
    int classes = 0;
    String scenario = "bunk";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Attendance Simulator",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  /// Classes slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text("Classes:"), Text("$classes")],
                  ),

                  Slider(
                    value: classes.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: classes.toString(),
                    onChanged: (val) {
                      setModalState(() => classes = val.toInt());
                    },
                  ),

                  /// Scenario selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Bunk"),
                        selected: scenario == "bunk",
                        onSelected: (_) {
                          setModalState(() => scenario = "bunk");
                        },
                      ),

                      const SizedBox(width: 12),

                      ChoiceChip(
                        label: const Text("Attend"),
                        selected: scenario == "attend",
                        onSelected: (_) {
                          setModalState(() => scenario = "attend");
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// Calculate button
                  ElevatedButton(
                    onPressed: () async {
                      double newAttendance = await calculateSimulatedAttendance(
                        classes,
                        scenario,
                      );

                      showDialog(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          title: const Text("Result"),
                          content: Text(
                            "Your new overall attendance would be ${newAttendance.toStringAsFixed(2)}%",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text("Calculate"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Simulated calculation
  Future<double> calculateSimulatedAttendance(
    int classes,
    String scenario,
  ) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    int totalClasses = 0;
    int attendedClasses = 0;

    /// TODO:
    /// Replace this with Supabase fetch
    /// Right now this is placeholder logic

    if (scenario == "bunk") {
      totalClasses += classes;
    } else {
      totalClasses += classes;
      attendedClasses += classes;
    }

    if (totalClasses == 0) return 0;

    return (attendedClasses / totalClasses) * 100;
  }
}
