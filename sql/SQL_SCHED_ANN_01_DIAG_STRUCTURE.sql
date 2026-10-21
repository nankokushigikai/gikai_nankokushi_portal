-- ----------------------------------------------------------------------
-- 【診断・読み取りのみ】日程調整→お知らせの対象者一覧：本番の構造を確認する
-- setup SQL と本番が一致しないことがあるため、関数を作る前に現物を確認する。
--   column   : 関数・画面で使う列が本番にあるか(announcements.schedule_event_id は未作成なら出ない)
--   function : 権限判定に使う関数があるか
--   trigger  : announcements に付いているトリガー(列追加の影響確認)
-- ----------------------------------------------------------------------
select 'column' as kind,
       c.table_name || '.' || c.column_name as name,
       c.data_type as detail
from information_schema.columns c
where c.table_schema = 'public'
  and (
       (c.table_name = 'announcements'       and c.column_name in ('no', 'title', 'notice_date', 'visibility', 'schedule_event_id'))
    or (c.table_name = 'schedule_events'     and c.column_name in ('id', 'title', 'visibility', 'decided_slot_id', 'is_closed'))
    or (c.table_name = 'schedule_slots'      and c.column_name in ('id', 'event_id', 'slot_date', 'slot_start', 'slot_end'))
    or (c.table_name = 'schedule_responses'  and c.column_name in ('event_id', 'slot_id', 'member_email', 'member_name', 'response', 'updated_at'))
    or (c.table_name = 'schedule_recipients' and c.column_name in ('event_id', 'member_email'))
    or (c.table_name = 'member_directory'    and c.column_name in ('email', 'full_name', 'is_current'))
  )
union all
select 'function', p.proname, pg_get_function_identity_arguments(p.oid)
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('is_current_portal_member', 'is_portal_admin', 'get_announcement_attendance_members', 'get_schedule_announcement_members')
union all
select 'trigger', t.tgname, pg_get_triggerdef(t.oid)
from pg_trigger t
where t.tgrelid = 'public.announcements'::regclass
  and not t.tgisinternal
order by 1, 2;
