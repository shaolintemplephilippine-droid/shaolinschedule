-- ================================================================
-- Migration: student_report_tokens
-- Purpose:   Store SHA-256 hashed tokens for per-student report links
-- Security:  RLS enabled; only authenticated admins + service_role
--            can manage tokens. Anon has NO access.
-- ================================================================

-- 1. Create the token table
CREATE TABLE IF NOT EXISTS student_report_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash   TEXT NOT NULL UNIQUE,
  class_name   TEXT NOT NULL,
  student_name TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ,
  is_revoked   BOOLEAN NOT NULL DEFAULT false
);

-- Index for fast hash lookup (Edge Function)
CREATE INDEX IF NOT EXISTS idx_srt_token_hash ON student_report_tokens (token_hash);
-- Index for listing tokens per student
CREATE INDEX IF NOT EXISTS idx_srt_student ON student_report_tokens (class_name, student_name);

-- 2. Enable RLS
ALTER TABLE student_report_tokens ENABLE ROW LEVEL SECURITY;

-- 3. Policies: authenticated admins only. No anon access.
CREATE POLICY "Admins can list tokens"
  ON student_report_tokens FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can create tokens"
  ON student_report_tokens FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update tokens"
  ON student_report_tokens FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Admins can delete tokens"
  ON student_report_tokens FOR DELETE TO authenticated USING (true);
