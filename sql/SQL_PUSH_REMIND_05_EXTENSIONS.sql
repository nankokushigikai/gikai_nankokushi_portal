-- ----------------------------------------------------------------------
-- 開始前通知(Push)：毎分の確認に使う拡張機能を有効にする
--   pg_cron : 毎分 push_reminder_tick() を動かす
--   pg_net  : 通知すべき分があるときだけ、送信関数(Edge Function)を呼ぶ
-- 2026-10-21 の診断(SQL_PUSH_REMIND_01)で、どちらも「使えるが未有効」を確認済み。
-- ※ダッシュボードの Database → Extensions で有効にしても同じ。
-- ----------------------------------------------------------------------
create extension if not exists pg_cron;
create extension if not exists pg_net;
