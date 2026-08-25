-- ================================================================
-- Patch: fix token architecture — remove double-hashing flaw
-- Root cause: token_hash stored SHA-256(rawToken), but URL contained
--             rawToken. Page hashed rawToken again → SHA-256(rawToken)
--             was sent but SHA-256(SHA-256(rawToken)) was compared.
-- Fix: rename column token_hash → token_value, store raw token directly,
--      Edge Function compares directly without hashing.
--      All existing tokens are revoked (they were broken anyway).
-- ================================================================

-- 1. Rename column: token_hash → token_value
ALTER TABLE student_report_tokens RENAME COLUMN token_hash TO token_value;

-- 2. Revoke all existing tokens (they used the broken double-hash scheme)
UPDATE student_report_tokens SET is_revoked = true WHERE is_revoked = false;
