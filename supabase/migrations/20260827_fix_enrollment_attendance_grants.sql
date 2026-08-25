-- ================================================================
-- Patch: grant CRUD on enrollment + attendance_records to service_role
-- Root cause: tables owned by postgres; service_role had no table-level
--             GRANT for SELECT. Edge Function (service_role) could not
--             query enrollment or attendance_records.
-- Also fixes: existing student_report_tokens with 30-day expiry should
--             be set to permanent (expires_at = null).
-- ================================================================

-- 1. Grant CRUD to service_role on enrollment
GRANT SELECT, INSERT, UPDATE, DELETE ON enrollment TO service_role;

-- 2. Grant CRUD to service_role on attendance_records
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance_records TO service_role;

-- 3. Set all existing tokens to permanent (remove 30-day expiry)
UPDATE student_report_tokens SET expires_at = NULL WHERE expires_at IS NOT NULL;
