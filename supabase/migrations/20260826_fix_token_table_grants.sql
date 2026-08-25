-- ================================================================
-- Patch: fix student_report_tokens table-level grants
-- Root cause: table owned by postgres; authenticated and service_role
--             had RLS policies but no table-level GRANT for CRUD.
-- Fix: grant SELECT/INSERT/UPDATE/DELETE to authenticated + service_role.
-- anon receives NO grants — cannot access the table at all.
-- ================================================================

-- 1. Grant CRUD to authenticated (admin browser session)
GRANT SELECT, INSERT, UPDATE, DELETE ON student_report_tokens TO authenticated;

-- 2. Grant CRUD to service_role (Edge Function uses service_role key)
GRANT SELECT, INSERT, UPDATE, DELETE ON student_report_tokens TO service_role;

-- 3. Explicitly revoke any lingering CRUD from anon (safety)
REVOKE SELECT, INSERT, UPDATE, DELETE ON student_report_tokens FROM anon;
