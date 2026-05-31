-- メールお知らせの旧データ(cleanup)
-- 目的: meeting_settings に残っている旧キーを、バックアップ後に削除する
-- 実行タイミング: 新テーブル移行後、画面動作確認が終わった後

begin;

-- 1) 退避テーブル（初回のみ作成）
create table if not exists public.mail_notice_settings_backup (
    backup_id bigserial primary key,
    setting_key text not null,
    setting_payload jsonb not null,
    backed_up_at timestamptz not null default now(),
    backed_up_by uuid,
    unique (setting_key)
);

-- 2) 旧キーをバックアップ（同じキーは二重保存しない）
insert into public.mail_notice_settings_backup (
    setting_key,
    setting_payload,
    backed_up_by
)
select
    ms.setting_key,
    ms.setting_payload,
    auth.uid()
from public.meeting_settings ms
where ms.setting_key in (
    'mail_notice_records_v1',
    'mail_notice_greeting_samples_v1',
    'mail_notice_sender_samples_v1'
)
on conflict (setting_key) do nothing;

-- 3) 旧キーを削除
delete from public.meeting_settings
where setting_key in (
    'mail_notice_records_v1',
    'mail_notice_greeting_samples_v1',
    'mail_notice_sender_samples_v1'
);

commit;

-- 実行後チェック
-- select setting_key from public.meeting_settings
-- where setting_key in ('mail_notice_records_v1','mail_notice_greeting_samples_v1','mail_notice_sender_samples_v1');
--
-- select setting_key, backed_up_at from public.mail_notice_settings_backup
-- order by backed_up_at desc;
