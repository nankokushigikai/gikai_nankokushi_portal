-- ----------------------------------------------------------------------
-- 開始前通知(Push)：送信関数を呼ぶときの「合言葉」を Vault に保管する
--
-- 使い方:
--   1. 下の <<PUSH_CRON_SECRET>> を、手元の .重要/push_reminder.env の PUSH_CRON_SECRET の値に
--      SQL Editor 上で置き換えて実行する(このファイル自体は書き換えて保存しない・Gitに入れない)
--   2. 同じ値を Edge Function の secrets(PUSH_CRON_SECRET)にも設定する
-- 合言葉が一致しない呼び出しは、送信関数が拒否する(外から呼ばれても通知は送られない)。
-- 結果: 保管した名前が1行出れば成功(値そのものは表示しない)
-- ----------------------------------------------------------------------
do $$
declare
    v_secret text := '<<PUSH_CRON_SECRET>>';
    v_id uuid;
begin
    if v_secret like '<<%' or length(v_secret) < 32 then
        raise exception '合言葉が置き換えられていません';
    end if;
    select id into v_id from vault.secrets where name = 'push_reminder_cron_secret';
    if v_id is null then
        perform vault.create_secret(v_secret, 'push_reminder_cron_secret', '開始前通知の送信関数を呼ぶ合言葉');
    else
        perform vault.update_secret(v_id, v_secret);
    end if;
end;
$$;

select name, created_at, updated_at from vault.secrets where name = 'push_reminder_cron_secret';
