-- ----------------------------------------------------------------------
-- 開始前通知(Push)：毎分動かす確認関数
-- ・DBの中だけで「今送るべき通知」があるかを確認し、
--   **ある時だけ** 送信関数(Edge Function: push-reminder-send)を呼ぶ。無ければ何もしない。
-- ・呼び出しには Vault の合言葉(push_reminder_cron_secret)を付ける
-- ・pg_cron(postgres)からだけ使う。画面・anon・authenticated からは呼べない
-- 前提: 02・04・05・06 を実行済みであること
-- ----------------------------------------------------------------------
create or replace function public.push_reminder_tick()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
    v_secret text;
begin
    if not exists (select 1 from public.push_reminders_due()) then
        return 'no data';
    end if;

    select decrypted_secret into v_secret
      from vault.decrypted_secrets
     where name = 'push_reminder_cron_secret';
    if v_secret is null then
        return 'secret missing';
    end if;

    perform net.http_post(
        url := 'https://gnnfzimhfizbfhvwuzbf.supabase.co/functions/v1/push-reminder-send',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-cron-secret', v_secret),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
    );
    return 'called';
end;
$$;

revoke all on function public.push_reminder_tick() from public, anon, authenticated;
