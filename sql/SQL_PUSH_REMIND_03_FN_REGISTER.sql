-- ----------------------------------------------------------------------
-- 開始前通知(Push)：端末の登録・解除をする関数
-- ・register_push_subscription : ログイン中の現職(または管理者)の端末を登録する
--     同じ端末(endpoint)が別の人で登録済みなら、今ログインしている人に付け替える
--     (端末を共用・持ち替えた場合に、前の人あての通知が届き続けないようにするため)
-- ・unregister_push_subscription : 自分の端末の登録を消す
-- ・メールはJWTから取るので、画面から他人のメールでは登録できない
-- 前提: SQL_PUSH_REMIND_02_TABLES.sql を実行済みであること
-- ----------------------------------------------------------------------
create or replace function public.register_push_subscription(
    p_endpoint text,
    p_p256dh text,
    p_auth text,
    p_user_agent text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_email text := lower(trim(coalesce(auth.jwt()->>'email', '')));
begin
    if v_uid is null or v_email = '' then
        raise exception 'ログインが必要です';
    end if;
    if not (public.is_current_portal_member() or public.is_portal_admin()) then
        raise exception '登録できるのは現職議員・管理者のみです';
    end if;
    if p_endpoint is null or p_endpoint !~ '^https://' or length(p_endpoint) > 1000
       or coalesce(p_p256dh, '') = '' or length(p_p256dh) > 200
       or coalesce(p_auth, '') = '' or length(p_auth) > 100 then
        raise exception '端末情報が不正です';
    end if;

    insert into public.push_subscriptions (user_id, member_email, endpoint, p256dh, auth_key, user_agent)
    values (v_uid, v_email, p_endpoint, p_p256dh, p_auth, left(p_user_agent, 300))
    on conflict (endpoint) do update
       set user_id      = excluded.user_id,
           member_email = excluded.member_email,
           p256dh       = excluded.p256dh,
           auth_key     = excluded.auth_key,
           user_agent   = excluded.user_agent,
           updated_at   = now(),
           last_error   = null;
end;
$$;

create or replace function public.unregister_push_subscription(p_endpoint text)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        return;
    end if;
    delete from public.push_subscriptions
     where endpoint = p_endpoint
       and user_id = auth.uid();
end;
$$;

revoke all on function public.register_push_subscription(text, text, text, text) from public, anon;
revoke all on function public.unregister_push_subscription(text) from public, anon;
grant execute on function public.register_push_subscription(text, text, text, text) to authenticated;
grant execute on function public.unregister_push_subscription(text) to authenticated;
