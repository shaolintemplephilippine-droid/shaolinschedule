// ================================================================
// Supabase Edge Function: student-report
// Validates a token hash and returns one student's report data.
// ================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---- CORS: only our GitHub Pages origin ----
const ALLOWED_ORIGIN = "https://shaolintemplephilippine-droid.github.io";

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",
  };
}

// ---- Rate limiting (in-memory, per Deno isolate) ----
const rateMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 30; // max requests per window
const RATE_WINDOW_MS = 60_000; // 1 minute

function checkRate(key: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(key);
  if (!entry || now > entry.resetAt) {
    rateMap.set(key, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  if (entry.count >= RATE_LIMIT) return false;
  entry.count++;
  return true;
}

// ---- Generic error (same message for invalid/expired/revoked) ----
const GENERIC_ERROR = "链接无效或已过期，请联系管理员获取新链接。";

function errorResponse(status: number, msg?: string) {
  return new Response(
    JSON.stringify({ error: msg || GENERIC_ERROR }),
    { status, headers: { ...corsHeaders(), "Content-Type": "application/json" } }
  );
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // Rate limit by IP
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (!checkRate("ip:" + ip)) {
    return errorResponse(429, "请求过于频繁，请稍后再试。");
  }

  let body: { hash?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse(400);
  }

  const hash = body.hash;
  if (!hash || typeof hash !== "string" || hash.length !== 64) {
    return errorResponse(400);
  }

  // Rate limit by token hash too
  if (!checkRate("token:" + hash)) {
    return errorResponse(429, "请求过于频繁，请稍后再试。");
  }

  // ---- Validate token ----
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: tokenRow, error: tokenErr } = await supabase
    .from("student_report_tokens")
    .select("*")
    .eq("token_hash", hash)
    .single();

  if (tokenErr || !tokenRow) {
    return errorResponse(403);
  }

  // Check revoked
  if (tokenRow.is_revoked) {
    return errorResponse(403);
  }

  // Check expiry
  if (tokenRow.expires_at && new Date(tokenRow.expires_at) < new Date()) {
    return errorResponse(403);
  }

  const { class_name, student_name } = tokenRow;

  // ---- Fetch enrollment ----
  const { data: enrRow } = await supabase
    .from("enrollment")
    .select("*")
    .eq("class_name", class_name)
    .eq("student_name", student_name)
    .maybeSingle();

  const totalHours = enrRow?.total_hours || 0;
  const validDays = enrRow?.valid_days || 0;
  const startDate = enrRow?.start_date || "";
  const endDate = enrRow?.end_date || "";
  const beforeJune = enrRow?.before_june || 0;
  const isDisciple = enrRow?.is_disciple || false;

  // ---- Fetch attendance records for this student (single query) ----
  const { data: attRows } = await supabase
    .from("attendance_records")
    .select("date, time, teacher, student_names")
    .eq("class_name", class_name);

  // Filter to records containing this student
  const studentRecords: Array<{ date: string; time: string; teacher: string }> = [];
  let fromAttendance = 0;
  const monthly: Record<string, number> = {};

  if (attRows) {
    for (const r of attRows) {
      if (Array.isArray(r.student_names) && r.student_names.includes(student_name)) {
        studentRecords.push({ date: r.date, time: r.time, teacher: r.teacher || "" });
        fromAttendance++;
        const m = r.date.split("-")[1];
        monthly[m] = (monthly[m] || 0) + 1;
      }
    }
  }

  const usedHours = beforeJune + fromAttendance;
  const remainingHours = isDisciple ? null : totalHours - usedHours;

  // Calculate days
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  let daysLeft: number | null = null;
  let validDaysCalc: number | null = null;

  if (startDate && endDate) {
    const s = new Date(startDate + "T00:00:00");
    const e = new Date(endDate + "T00:00:00");
    validDaysCalc = Math.max(0, Math.ceil((e.getTime() - s.getTime()) / 86400000));
    daysLeft = Math.ceil((e.getTime() - now.getTime()) / 86400000);
  }

  // Current month attendance
  const curMonth = now.toISOString().slice(0, 7);
  const curMonthRecords = studentRecords.filter(r => r.date.startsWith(curMonth))
    .sort((a, b) => b.date.localeCompare(a.date) || b.time.localeCompare(a.time));

  // ---- Build response ----
  return new Response(
    JSON.stringify({
      name: student_name,
      className: class_name,
      isDisciple,
      totalHours,
      usedHours,
      remainingHours,
      startDate,
      endDate,
      validDays: validDaysCalc ?? validDays,
      daysLeft,
      currentMonth: curMonth,
      monthlyAttendance: curMonthRecords.map(r => ({
        date: r.date,
        time: r.time,
        teacher: r.teacher,
      })),
    }),
    {
      status: 200,
      headers: {
        ...corsHeaders(),
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    }
  );
});
