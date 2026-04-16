import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok");
  }

  try {
    console.log("FUNCTION VERSION 2 RUNNING");
    const { question, attendanceData, userId } = await req.json();

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");

if (!GROQ_API_KEY) {
  throw new Error("Missing GROQ_API_KEY");
}
    function analyzeAttendance(attendance: any[], subjects: any[]) {
      const map: any = {};

      attendance.forEach((a) => {
        const id = a.subject_id;

        if (!map[id]) {
          map[id] = { total: 0, present: 0 };
        }

        if (a.present !== "cancelled") {
          map[id].total++;
          if (a.present === "present") {
            map[id].present++;
          }
        }
      });

      return subjects.map((sub) => {
        const stat = map[sub.id] || { total: 0, present: 0 };
        const percent =
          stat.total === 0 ? 0 : (stat.present / stat.total) * 100;

        return {
  name: sub.name,
  percentage: Number(percent.toFixed(1)),
  total: stat.total,
  present: stat.present,
  missed: stat.total - stat.present,
};
      });
    }

    const analysis = analyzeAttendance(
      attendanceData.attendance,
      attendanceData.subjects
    );

    // ✅ FORCE JSON OUTPUT
    const response = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "openai/gpt-oss-120b",
          messages: [
            {
              role: "system",
              content: `
You are a smart attendance assistant inside a student app.

Return ONLY valid JSON in this format:
{
  "reply": "string",
  "suggestions": ["string", "string", "string"]
}

STRICT RULES:
- Keep reply short (1-2 lines, max 3)
- Be clear, slightly conversational, not robotic
- Suggestions must be 2-3 helpful follow-up questions
- Always base answers ONLY on given student data
- If data is missing, say you don't have enough info

CORE BEHAVIOR:

1. Attendance Summary
- If user asks overall or subject attendance → show percentage clearly
- Mention subject names when relevant

2. Warning Logic
- If any subject < 75% → warn clearly
- If < 65% → mark as "danger zone"
- If >= 75% → say safe but avoid overconfidence

3. Bunk / Safety Questions
- If user asks "can I bunk" or similar:
  - If any subject < 75% → say NOT safe
  - If all >= 75% → say limited bunk possible but be cautious

4. Improvement Guidance
- If attendance is low → suggest attending consecutive classes
- Give simple actionable advice, not vague motivation

5. Insights (light)
- If multiple subjects are low → mention overall risk
- If most are fine → reassure briefly

6. Tone
- Helpful, slightly human
- No long explanations
- No emojis
- No extra text outside JSON

Student data:
${JSON.stringify(analysis)}
              `,
            },
            {
              role: "user",
              content: question,
            },
          ],
        }),
      }
    );

    const data = await response.json();
    const aiText = data.choices?.[0]?.message?.content;

    if (!aiText) {
      return new Response(
        JSON.stringify({ reply: "No AI response", suggestions: [] }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ✅ SAFE JSON PARSE
    let parsed;

    try {
      parsed = JSON.parse(aiText);
    } catch {
      // fallback if AI misbehaves
      parsed = {
        reply: aiText,
        suggestions: [],
      };
    }

    return new Response(
      JSON.stringify({
        reply: parsed.reply ?? "No reply",
        suggestions: parsed.suggestions ?? [],
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ reply: "Server error", suggestions: [] }),
      { headers: { "Content-Type": "application/json" } }
    );
  }
});