-- ----------------------------------------------------------------------
-- 開始前通知(Push)：表と列を作る
--   push_subscriptions  : 端末ごとのPush宛先(ホーム画面アイコンで「通知と印を有効にする」を押した端末)
--   push_reminder_sent  : 送信済みの記録(同じお知らせ・同じ段階・同じ予定時刻は二度送らない)
--   announcements.push_remind_minutes_1 / _2 : 開始の何分前に通知するか(null=通知しない)
--     ※既存の reminder_minutes_1/2 は Googleカレンダー用なので別の列にしている
--     ※既存のお知らせは null(通知しない)のまま。登録画面の初期値は 60分前 / 1分前
--
-- RLS:
--   push_subscriptions : 本人の行だけ読める・消せる。追加は register_push_subscription() 経由のみ
--   push_reminder_sent : 画面からは一切触れない(送信関数=service_roleのみ)
--   どちらも全表と同じ RESTRICTIVE 2本(現職 or 管理者 / anon全拒否)を付ける
-- 元に戻す: SQL_PUSH_REMIND_09_ROLLBACK.sql
-- ----------------------------------------------------------------------

create table if not exists public.push_subscriptions (
    id           bigserial primary key,
    user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
    member_email text not null,
    endpoint     text not null unique,
    p256dh       text not null,
    auth_key     text not null,
    user_agent   text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    last_sent_at timestamptz,
    last_error   text,
    constraint push_subscriptions_endpoint_https check (endpoint like 'https://%')
);
create index if not exists push_subscriptions_member_email_idx on public.push_subscriptions (lower(member_email));

create table if not exists public.push_reminder_sent (
    announcement_no bigint not null references public.announcements(no) on delete cascade,
    stage           smallint not null check (stage in (1, 2)),
    fire_at         timestamptz not null,
    sent_at         timestamptz not null default now(),
    primary key (announcement_no, stage, fire_at)
);

alter table public.announcements
    add column if not exists push_remind_minutes_1 integer,
    add column if not exists push_remind_minutes_2 integer;

alter table public.announcements drop constraint if exists announcements_push_remind_minutes_check;
alter table public.announcements add constraint announcements_push_remind_minutes_check check (
        (push_remind_minutes_1 is null or push_remind_minutes_1 in (1, 5, 10, 15, 30, 60, 120, 1440))
    and (push_remind_minutes_2 is null or push_remind_minutes_2 in (1, 5, 10, 15, 30, 60, 120, 1440))
    and (push_remind_minutes_1 is null or push_remind_minutes_2 is null or push_remind_minutes_1 > push_remind_minutes_2)
);

-- 権限：anon には何も渡さない。authenticated は push_subscriptions の読む・消すだけ
revoke all on public.push_subscriptions from anon, authenticated;
revoke all on public.push_reminder_sent from anon, authenticated;
revoke all on sequence public.push_subscriptions_id_seq from anon, authenticated;
grant select, delete on public.push_subscriptions to authenticated;
-- 送信関数(service_role)は送信結果の記録・無効な端末の削除に使う
grant select, insert, update, delete on public.push_subscriptions to service_role;
grant select, insert, update, delete on public.push_reminder_sent to service_role;
grant usage, select on sequence public.push_subscriptions_id_seq to service_role;

alter table public.push_subscriptions enable row level security;
alter table public.push_reminder_sent enable row level security;

drop policy if exists push_subscriptions_select_own on public.push_subscriptions;
create policy push_subscriptions_select_own on public.push_subscriptions
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists push_subscriptions_delete_own on public.push_subscriptions;
create policy push_subscriptions_delete_own on public.push_subscriptions
for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists push_subscriptions_require_member on public.push_subscriptions;
create policy push_subscriptions_require_member on public.push_subscriptions
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists push_subscriptions_deny_anon on public.push_subscriptions;
create policy push_subscriptions_deny_anon on public.push_subscriptions
as restrictive for all to anon
using (false) with check (false);

drop policy if exists push_reminder_sent_require_member on public.push_reminder_sent;
create policy push_reminder_sent_require_member on public.push_reminder_sent
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists push_reminder_sent_deny_anon on public.push_reminder_sent;
create policy push_reminder_sent_deny_anon on public.push_reminder_sent
as restrictive for all to anon
using (false) with check (false);

notify pgrst, 'reload schema';
