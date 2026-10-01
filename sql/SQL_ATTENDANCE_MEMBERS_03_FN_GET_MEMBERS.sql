-- ----------------------------------------------------------------------
-- お知らせの「対象者一覧」を、そのお知らせの対象者全員が見られるようにする関数
--
-- ・表のRLSは広げず、この関数だけが一覧を返す(コメント欄などは返さない)
-- ・呼び出せるのは: 管理者 / そのお知らせの対象者本人(現職利用者)のみ
--     visibility = 'all'      → 現職利用者なら対象者
--     visibility = 'specific' → announcement_recipients に本人のメールがある場合のみ
-- ・対象外の人が呼んだ場合は0件を返す
-- 前提: SQL_ATTENDANCE_MEMBERS_02_FN_IS_CURRENT_MEMBER.sql を先に実行済みであること
-- ----------------------------------------------------------------------
create or replace function public.get_announcement_attendance_members(p_announcement_no bigint)
returns table (
    member_email text,
    member_name text,
    attendance_status text,
    attendance_responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
    v_email text := lower(trim(coalesce(auth.jwt()->>'email', '')));
    v_visibility text;
    v_required boolean;
begin
    if auth.uid() is null or v_email = '' then
        return;
    end if;

    select a.visibility, a.attendance_required
      into v_visibility, v_required
      from public.announcements a
     where a.no = p_announcement_no;

    if not found or not coalesce(v_required, false) then
        return;
    end if;

    if not public.is_portal_admin() then
        if not public.is_current_portal_member() then
            return;
        end if;
        if v_visibility = 'specific' then
            if not exists (
                select 1
                from public.announcement_recipients ar
                where ar.announcement_no = p_announcement_no
                  and lower(trim(ar.recipient_email)) = v_email
            ) then
                return;
            end if;
        elsif v_visibility is distinct from 'all' then
            return;
        end if;
    end if;

    if v_visibility = 'specific' then
        return query
        select distinct on (lower(trim(ar.recipient_email)))
               lower(trim(ar.recipient_email)),
               ar.recipient_name,
               r.status,
               r.responded_at
          from public.announcement_recipients ar
          left join public.announcement_attendance_responses r
            on r.announcement_no = ar.announcement_no
           and lower(trim(r.responder_email)) = lower(trim(ar.recipient_email))
         where ar.announcement_no = p_announcement_no
           and coalesce(trim(ar.recipient_email), '') <> ''
         order by lower(trim(ar.recipient_email)), r.responded_at desc nulls last, ar.assigned_at desc;
    else
        return query
        select distinct on (lower(trim(m.email)))
               lower(trim(m.email)),
               m.full_name,
               r.status,
               r.responded_at
          from public.member_directory m
          left join public.announcement_attendance_responses r
            on r.announcement_no = p_announcement_no
           and lower(trim(r.responder_email)) = lower(trim(m.email))
         where m.is_current = true
           and coalesce(trim(m.email), '') <> ''
         order by lower(trim(m.email)), r.responded_at desc nulls last;
    end if;
end;
$$;

revoke all on function public.get_announcement_attendance_members(bigint) from public;
revoke all on function public.get_announcement_attendance_members(bigint) from anon;
grant execute on function public.get_announcement_attendance_members(bigint) to authenticated;
grant execute on function public.get_announcement_attendance_members(bigint) to service_role;
