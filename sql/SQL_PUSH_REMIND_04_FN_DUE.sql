-- ----------------------------------------------------------------------
-- 開始前通知(Push)：「今送るべき通知」を判定する関数
--
-- push_reminders_due()     : 今送るべき(お知らせ×段階)を返す。送信済みは除く
--     ・開始時刻 = notice_date + start_time を日本時間として扱う
--     ・予定時刻(開始 - N分)を過ぎて10分以内のものだけ(遅れて登録・編集した分を、大きく遅れて送らない)
--     ・取消(lifecycle_status = 'canceled')は送らない
-- claim_push_reminders()   : 上の分を「送信済み」に記録し、送り先の端末一覧を返す(送信関数だけが呼ぶ)
--     ・送り先 = お知らせの対象者(全員向け=名簿の現職 / 対象者指定=announcement_recipients のうち現職)
--     ・出欠で「欠席」と回答した人には送らない
--     ・送り先の端末が無くても記録はする(同じ分を毎分くり返し判定しないため)
-- 実行できるのは service_role のみ(画面・anon からは呼べない)
-- 前提: SQL_PUSH_REMIND_02_TABLES.sql を実行済みであること
-- ----------------------------------------------------------------------
create or replace function public.push_reminders_due()
returns table (
    announcement_no bigint,
    stage smallint,
    remind_minutes integer,
    fire_at timestamptz,
    title text,
    start_time time
)
language sql
stable
security definer
set search_path = public
as $$
    select a.no, s.stage, s.minutes,
           ((a.notice_date + a.start_time) at time zone 'Asia/Tokyo') - make_interval(mins => s.minutes),
           a.title, a.start_time
      from public.announcements a
     cross join lateral (
            values (1::smallint, a.push_remind_minutes_1), (2::smallint, a.push_remind_minutes_2)
           ) as s(stage, minutes)
     where s.minutes is not null
       and a.notice_date is not null
       and a.start_time is not null
       and coalesce(a.lifecycle_status, 'active') <> 'canceled'
       and ((a.notice_date + a.start_time) at time zone 'Asia/Tokyo') - make_interval(mins => s.minutes) <= now()
       and ((a.notice_date + a.start_time) at time zone 'Asia/Tokyo') - make_interval(mins => s.minutes) > now() - interval '10 minutes'
       and not exists (
            select 1 from public.push_reminder_sent ps
             where ps.announcement_no = a.no
               and ps.stage = s.stage
               and ps.fire_at = ((a.notice_date + a.start_time) at time zone 'Asia/Tokyo') - make_interval(mins => s.minutes)
           );
$$;

create or replace function public.claim_push_reminders()
returns table (
    announcement_no bigint,
    stage smallint,
    remind_minutes integer,
    title text,
    start_time time,
    subscription_id bigint,
    endpoint text,
    p256dh text,
    auth_key text
)
language plpgsql
volatile
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
    return query
    with due as (
        select d.* from public.push_reminders_due() d
    ),
    claimed as (
        insert into public.push_reminder_sent (announcement_no, stage, fire_at)
        select d.announcement_no, d.stage, d.fire_at from due d
        on conflict do nothing
        returning push_reminder_sent.announcement_no, push_reminder_sent.stage, push_reminder_sent.fire_at
    ),
    targets as (
        select c.announcement_no, c.stage, lower(trim(m.email)) as email
          from claimed c
          join public.announcements a on a.no = c.announcement_no
          join public.member_directory m on m.is_current = true and coalesce(trim(m.email), '') <> ''
         where coalesce(a.visibility, 'all') = 'all'
        union
        select c.announcement_no, c.stage, lower(trim(ar.recipient_email))
          from claimed c
          join public.announcements a on a.no = c.announcement_no and a.visibility = 'specific'
          join public.announcement_recipients ar on ar.announcement_no = c.announcement_no
          join public.member_directory m on m.is_current = true and lower(trim(m.email)) = lower(trim(ar.recipient_email))
    )
    select d.announcement_no, d.stage, d.remind_minutes, d.title, d.start_time,
           ps.id, ps.endpoint, ps.p256dh, ps.auth_key
      from targets t
      join due d on d.announcement_no = t.announcement_no and d.stage = t.stage
      join public.push_subscriptions ps on lower(ps.member_email) = t.email
     where not exists (
            select 1 from public.announcement_attendance_responses r
             where r.announcement_no = t.announcement_no
               and lower(trim(r.responder_email)) = t.email
               and r.status = 'absent'
           )
     order by d.announcement_no, d.stage, ps.id;
end;
$$;

revoke all on function public.push_reminders_due() from public, anon, authenticated;
revoke all on function public.claim_push_reminders() from public, anon, authenticated;
grant execute on function public.push_reminders_due() to service_role;
grant execute on function public.claim_push_reminders() to service_role;
