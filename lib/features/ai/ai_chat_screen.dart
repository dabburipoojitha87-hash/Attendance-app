import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController controller = TextEditingController();

  final supabase = Supabase.instance.client;

  List<Map<String, String>> messages = [];

  Map<String, double> subjectAttendance = {};

  @override
  void initState() {
    super.initState();
    fetchAttendanceSummary();
  }

  // ================= FETCH DATA =================

  Future<void> fetchAttendanceSummary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final subjects = await supabase
        .from('subjects')
        .select('id, name')
        .eq('user_id', user.uid);

    final attendance = await supabase
        .from('attendance')
        .select('subject_id, present')
        .eq('user_id', user.uid);

    Map<String, int> presentMap = {};
    Map<String, int> totalMap = {};

    for (var a in attendance) {
      final id = a['subject_id'];

      totalMap[id] = (totalMap[id] ?? 0) + 1;

      if (a['present'] == 'present') {
        presentMap[id] = (presentMap[id] ?? 0) + 1;
      }
    }

    Map<String, double> result = {};

    for (var s in subjects) {
      final id = s['id'];
      final name = s['name'];

      final present = presentMap[id] ?? 0;
      final total = totalMap[id] ?? 0;

      double percent = total == 0 ? 0 : (present / total) * 100;

      result[name] = percent;
    }

    setState(() {
      subjectAttendance = result;
    });
  }

  // ================= AI LOGIC =================

  String generateResponse(String question) {
    if (subjectAttendance.isEmpty) {
      return "No attendance data available.";
    }

    // find lowest subject
    String lowSubject = "";
    double lowPercent = 100;

    subjectAttendance.forEach((name, percent) {
      if (percent < lowPercent) {
        lowPercent = percent;
        lowSubject = name;
      }
    });

    if (question.toLowerCase().contains("bunk")) {
      if (lowPercent < 75) {
        return "❌ Don't bunk. $lowSubject is below 75% ($lowPercent%)";
      } else if (lowPercent < 80) {
        return "⚠️ Be careful. $lowSubject is close to 75%";
      } else {
        return "✅ Safe to bunk. All subjects are above 80%";
      }
    }

    if (question.toLowerCase().contains("which subject")) {
      return "⚠️ Focus on $lowSubject ($lowPercent%)";
    }

    return "📊 Your lowest subject is $lowSubject at $lowPercent%";
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final reply = generateResponse(text);

    setState(() {
      messages.add({"user": text});
      messages.add({"bot": reply});
    });

    controller.clear();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Assistant"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];

                final isUser = msg.containsKey("user");

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isUser ? msg["user"]! : msg["bot"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // INPUT
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
