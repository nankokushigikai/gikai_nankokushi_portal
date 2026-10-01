-- 日程調整：二重作成防止用の「作成番号」列を追加
-- 作成画面を開くたびに画面側でランダムな作成番号(UUID)を発行し、同じ番号は1件しか登録できないようにする。
-- 既存行は NULL のまま(一意制約は NULL 同士を重複扱いしないため影響なし)。
alter table public.schedule_events
    add column if not exists client_request_id uuid;

create unique index if not exists schedule_events_client_request_id_key
    on public.schedule_events (client_request_id);
