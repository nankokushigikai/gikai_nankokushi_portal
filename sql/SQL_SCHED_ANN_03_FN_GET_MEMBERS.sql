-- ----------------------------------------------------------------------
-- 日程調整の決定から作ったお知らせの「対象者一覧」を返す関数
--
-- ・返すもの: 日程調整の対象者 と 決定日程への回答(circle / triangle / cross / null=未回答)
--     日程調整が visibility = 'specific' → schedule_recipients の人
--     それ以外                            → 名簿の現職(member_directory.is_current = true)
-- ・呼び出せるのは get_announcement_attendance_members と同じ: 管理者 / そのお知らせの対象者本人(現職)
--     お知らせが visibility = 'all'      → 現職なら対象者
--     お知らせが visibility = 'specific' → announcement_recipients に本人のメールがある場合のみ
-- ・対象外の人・日程調整と紐づかないお知らせ・未決定の日程調整は0件を返す
-- ・表のRLSは広げず、この関数だけが一覧を返す
-- 前提: SQL_SCHED_ANN_02_ADD_COLUMN.sql を先に実行済みであること
-- ----------------------------------------------------------------------
create or replace function public.get_schedule_announcement_members(p_announcement_no bigint)
returns table (
    member_email text,
    member_name text,
    response text,
    responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
    v_email text := lower(trim(coalesce(auth.jwt()->>'email', '')));
    v_ann_visibility text;
    v_event_id bigint;
    v_event_visibility text;
    v_slot_id bigint;
begin
    if auth.uid() is null or v_email = '' then
        return;
    end if;

    select a.visibility, a.schedule_event_id
      into v_ann_visibility, v_event_id
      from public.announcements a
     where a.no = p_announcement_no;

    if not found or v_event_id is null then
        return;
    end if;

    if not public.is_portal_admin() then
        if not public.is_current_portal_member() then
            return;
        end if;
        if v_ann_visibility = 'specific' then
            if not exists (
                select 1
                from public.announcement_recipients ar
                where ar.announcement_no = p_announcement_no
                  and lower(trim(ar.recipient_email)) = v_email
            ) then
                return;
            end if;
        elsif v_ann_visibility is distinct from 'all' then
            return;
        end if;
    end if;

    select e.visibility, e.decided_slot_id
      into v_event_visibility, v_slot_id
      from public.schedule_events e
     where e.id = v_event_id;

    if not found or v_slot_id is null then
        return;
    end if;

    if v_event_visibility = 'specific' then
        return query
        select t.email,
               coalesce(m.full_name, r.member_name, t.email),
               r.response,
               r.updated_at
          from (
                select distinct lower(trim(sr.member_email)) as email
                  from public.schedule_recipients sr
                 where sr.event_id = v_event_id
                   and coalesce(trim(sr.member_email), '') <> ''
               ) t
          left join lateral (
                select md.full_name
                  from public.member_directory md
                 where lower(trim(md.email)) = t.email
                 order by md.is_current desc
                 limit 1
               ) m on true
          left join lateral (
                select x.member_name, x.response, x.updated_at
                  from public.schedule_responses x
                 where x.slot_id = v_slot_id
                   and lower(trim(x.member_email)) = t.email
                 order by x.updated_at desc
                 limit 1
               ) r on true
         order by t.email;
    else
        return query
        select t.email,
               coalesce(t.full_name, r.member_name, t.email),
               r.response,
               r.updated_at
          from (
                select distinct on (lower(trim(md.email)))
                       lower(trim(md.email)) as email,
                       md.full_name
                  from public.member_directory md
                 where md.is_current = true
                   and coalesce(trim(md.email), '') <> ''
                 order by lower(trim(md.email))
               ) t
          left join lateral (
                select x.member_name, x.response, x.updated_at
                  from public.schedule_responses x
                 where x.slot_id = v_slot_id
                   and lower(trim(x.member_email)) = t.email
                 order by x.updated_at desc
                 limit 1
               ) r on true
         order by t.email;
    end if;
end;
$$;

revoke all on function public.get_schedule_announcement_members(bigint) from public;
revoke all on function public.get_schedule_announcement_members(bigint) from anon;
grant execute on function public.get_schedule_announcement_members(bigint) to authenticated;
grant execute on function public.get_schedule_announcement_members(bigint) to service_role;
