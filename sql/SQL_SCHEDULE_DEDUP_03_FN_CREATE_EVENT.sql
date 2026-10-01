-- 日程調整：作成処理を1回のトランザクションにまとめる関数
-- ・本体／日程候補／対象者を一括登録。途中で失敗したら全部取り消される(本体だけ残らない)。
-- ・同じ作成番号(p_request_id)で2回呼ばれたら、新規作成せず既存の id を返す(duplicate = true)。
-- ・SECURITY INVOKER(既定)なので、呼び出したユーザーの RLS がそのまま効く。権限昇格はしない。
-- ・作成者メールは引数で受け取らず、ログイン中のトークンから取る(なりすまし防止)。
-- 前提: SQL_SCHEDULE_DEDUP_02_ADD_REQUEST_ID.sql 適用済み
create or replace function public.create_schedule_event(
    p_request_id        uuid,
    p_title             text,
    p_description       text,
    p_deadline          date,
    p_visibility        text,
    p_auto_close        boolean,
    p_require_unanimous boolean,
    p_created_by_name   text,
    p_slots             jsonb,
    p_recipient_emails  text[]
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_email text := nullif(auth.jwt() ->> 'email', '');
    v_title text := nullif(btrim(coalesce(p_title, '')), '');
    v_id    bigint;
begin
    if v_email is null then
        raise exception 'ログイン情報を確認できません';
    end if;
    if p_request_id is null then
        raise exception '作成番号がありません';
    end if;
    if v_title is null then
        raise exception 'タイトルを入力してください';
    end if;
    if p_visibility not in ('all', 'specific') then
        raise exception '公開範囲の指定が不正です';
    end if;
    if p_slots is null or jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) = 0 then
        raise exception '日程候補を1つ以上入力してください';
    end if;
    if p_visibility = 'specific' and coalesce(array_length(p_recipient_emails, 1), 0) = 0 then
        raise exception '対象メンバーを選択してください';
    end if;

    -- 同じ作成番号が既に登録済みなら何もしない(同時実行時は一意制約で後発が待たされ、ここで弾かれる)
    insert into public.schedule_events
        (title, description, deadline, visibility, auto_close, require_unanimous,
         created_by_email, created_by_name, is_closed, client_request_id)
    values
        (v_title, nullif(btrim(coalesce(p_description, '')), ''), p_deadline, p_visibility,
         coalesce(p_auto_close, false), coalesce(p_require_unanimous, false),
         v_email, coalesce(nullif(btrim(coalesce(p_created_by_name, '')), ''), v_email), false, p_request_id)
    on conflict (client_request_id) do nothing
    returning id into v_id;

    if v_id is null then
        select e.id into v_id
          from public.schedule_events e
         where e.client_request_id = p_request_id
           and e.created_by_email = v_email;
        if v_id is null then
            raise exception '作成番号が重複しています。画面を開き直してください';
        end if;
        return jsonb_build_object('id', v_id, 'duplicate', true);
    end if;

    insert into public.schedule_slots (event_id, slot_date, slot_start, slot_end, sort_order)
    select v_id, x.slot_date, x.slot_start, x.slot_end, coalesce(x.sort_order, 0)
      from jsonb_to_recordset(p_slots) as x(slot_date date, slot_start time, slot_end time, sort_order int);

    if p_visibility = 'specific' then
        insert into public.schedule_recipients (event_id, member_email)
        select distinct v_id, m
          from unnest(p_recipient_emails) as m
         where nullif(btrim(m), '') is not null;
    end if;

    return jsonb_build_object('id', v_id, 'duplicate', false);
end;
$$;

revoke all on function public.create_schedule_event(uuid, text, text, date, text, boolean, boolean, text, jsonb, text[]) from public, anon;
grant execute on function public.create_schedule_event(uuid, text, text, date, text, boolean, boolean, text, jsonb, text[]) to authenticated;
