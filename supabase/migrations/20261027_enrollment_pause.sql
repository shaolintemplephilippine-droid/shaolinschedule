-- ================================================================
-- 年卡停卡（100 节 / 200 节年卡 · 每张卡 4 次停卡机会）
--
-- 变更内容：给 enrollment 表增加 suspensions 列，用于保存停卡记录。
--   suspensions = {
--     base:  '2027-01-01',                 -- 原始到期日（生效日 + 有效期）
--     items: [{ start, end, days, note, at }] -- 每次停卡的开始/复课日期与顺延天数
--   }
--
-- 前端口径：
--   当前到期日 = base + 所有「已复课」记录的 days 之和
--   停卡中的记录 end 为空、days 为 0，不计入顺延
--
-- 该脚本可重复执行。
-- ================================================================

-- 1. 新增列（jsonb，默认空对象）
ALTER TABLE public.enrollment
  ADD COLUMN IF NOT EXISTS suspensions jsonb NOT NULL DEFAULT '{}'::jsonb;

-- 2. 说明
COMMENT ON COLUMN public.enrollment.suspensions IS
  '年卡停卡记录：{ base: 原始到期日, items: [{ start, end, days, note, at }] }';

-- 3. 把历史行的空对象规范成完整结构，方便人工查看
UPDATE public.enrollment
   SET suspensions = '{"base": "", "items": []}'::jsonb
 WHERE suspensions IS NULL
    OR suspensions = '{}'::jsonb;

-- 4. 让 PostgREST 立即刷新 schema 缓存，避免刚加列就 upsert 报找不到列
NOTIFY pgrst, 'reload schema';

-- 5. 自检：三列都应返回 true
SELECT
  EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name   = 'enrollment'
       AND column_name  = 'suspensions'
       AND data_type    = 'jsonb'
  ) AS suspensions_column_ok,
  (SELECT count(*) FROM public.enrollment) AS enrollment_rows;
