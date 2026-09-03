-- ================================================================
-- Migration: weekly_summaries
-- Purpose:   Store weekly class summaries shown in student report links
-- ================================================================

CREATE TABLE IF NOT EXISTS weekly_summaries (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name   TEXT NOT NULL,
  week_start   DATE NOT NULL,
  author       TEXT NOT NULL,
  content_items TEXT[] NOT NULL DEFAULT '{}',
  summary_text TEXT NOT NULL DEFAULT '',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(class_name, week_start)
);

CREATE INDEX IF NOT EXISTS idx_weekly_class_start ON weekly_summaries (class_name, week_start);

ALTER TABLE weekly_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can list weekly summaries"
  ON weekly_summaries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can create weekly summaries"
  ON weekly_summaries FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update weekly summaries"
  ON weekly_summaries FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admins can delete weekly summaries"
  ON weekly_summaries FOR DELETE TO authenticated USING (true);
-- Explicit grants are required even when RLS policies exist; policies alone do not give table-level permission.
GRANT ALL ON TABLE weekly_summaries TO authenticated, service_role;
