import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;

  // ================= SEND MESSAGE =================

  void sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      isLoading = true;
    });

    controller.clear();

    try {
      final result = await callAI(text);

      setState(() {
        messages.add({
          "role": "bot",
          "text": result["reply"] ?? "No reply",
          "suggestions": result["suggestions"] ?? [],
        });
      });
    } catch (e) {
      setState(() {
        messages.add({
          "role": "bot",
          "text": "Something went wrong",
          "suggestions": [],
        });
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ================= CALL AI =================

  Future<Map<String, dynamic>> callAI(String question) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {"reply": "Login required", "suggestions": []};
    }

    try {
      final attendance = await supabase
          .from('attendance')
          .select('subject_id, present, date')
          .eq('user_id', user.uid);

      final subjects = await supabase
          .from('subjects')
          .select('id, name')
          .eq('user_id', user.uid);

      print("ATTENDANCE: $attendance");
      print("SUBJECTS: $subjects");

      final res = await supabase.functions.invoke(
        'ai-chat',
        body: {
          "question": question,
          "attendanceData": {"attendance": attendance, "subjects": subjects},
          "userId": user.uid,
        },
      );

      print("RAW FUNCTION RESPONSE: ${res.data}");

      print("FULL RESPONSE: ${res.data}");

      if (res.data == null) {
        return {"reply": "No response from AI", "suggestions": []};
      }

      // ✅ FIX: Proper casting
      final data = res.data as Map<String, dynamic>;

      print("FINAL REPLY: ${data["reply"]}");

      return {
        "reply": data["reply"] ?? "No reply",
        "suggestions": data["suggestions"] ?? [],
      };
    } catch (e) {
      print("ERROR IN FLUTTER: $e");
      return {"reply": "Error: $e", "suggestions": []};
    }
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
                final isUser = msg["role"] == "user";

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.blue.shade100
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg["text"] ?? "Empty response"),
                      ),

                      // Suggestions
                      if (!isUser && msg["suggestions"] != null)
                        Wrap(
                          spacing: 6,
                          children: (msg["suggestions"] as List)
                              .map(
                                (s) => Chip(
                                  label: Text(s.toString()),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Ask about attendance...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
