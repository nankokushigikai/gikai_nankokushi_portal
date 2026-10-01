-- ----------------------------------------------------------------------
-- 名簿以外の表に残っていた「*_anon_temp」(anon / 条件 true) ポリシーの削除
--
-- 2026/5/5 commit 01e2006 で setup SQL から作成文を消したが、本番への drop が
-- 行われておらず、未ログインの第三者が閲覧・追加・書換・削除できる状態だった。
--
-- 確認済み事項:
--  - これらの表を使う画面はすべて PortalAuth.init(ログイン必須)経由。
--    ログイン後は authenticated ロールで動くため、anon ポリシーの削除は画面に影響しない。
--  - survey_forms / survey_responses / member_positions_master は現行コードで未使用。
--  - 同じ Supabase プロジェクトを使う他システムは My_Developments 内に無い。
--  - 影響は scripts/backup-portal.ps1 の CSV 書き出し(anonキー使用)のみ。
-- ----------------------------------------------------------------------
drop policy if exists audit_log_insert_anon_temp on public.audit_log;
drop policy if exists audit_log_select_anon_temp on public.audit_log;

drop policy if exists document_ink_notes_select_anon_temp on public.document_ink_notes;
drop policy if exists document_ink_notes_insert_anon_temp on public.document_ink_notes;
drop policy if exists document_ink_notes_update_anon_temp on public.document_ink_notes;
drop policy if exists document_ink_notes_delete_anon_temp on public.document_ink_notes;

drop policy if exists document_notes_select_anon_temp on public.document_notes;
drop policy if exists document_notes_insert_anon_temp on public.document_notes;
drop policy if exists document_notes_update_anon_temp on public.document_notes;
drop policy if exists document_notes_delete_anon_temp on public.document_notes;

drop policy if exists general_question_tracker_select_anon_temp on public.general_question_tracker;
drop policy if exists general_question_tracker_insert_anon_temp on public.general_question_tracker;
drop policy if exists general_question_tracker_update_anon_temp on public.general_question_tracker;
drop policy if exists general_question_tracker_delete_anon_temp on public.general_question_tracker;

drop policy if exists general_question_updates_select_anon_temp on public.general_question_updates;
drop policy if exists general_question_updates_insert_anon_temp on public.general_question_updates;
drop policy if exists general_question_updates_update_anon_temp on public.general_question_updates;
drop policy if exists general_question_updates_delete_anon_temp on public.general_question_updates;

drop policy if exists meeting_settings_select_anon_temp on public.meeting_settings;
drop policy if exists meeting_settings_insert_anon_temp on public.meeting_settings;
drop policy if exists meeting_settings_update_anon_temp on public.meeting_settings;

drop policy if exists member_positions_master_select_anon_temp on public.member_positions_master;
drop policy if exists member_positions_master_insert_anon_temp on public.member_positions_master;
drop policy if exists member_positions_master_update_anon_temp on public.member_positions_master;
drop policy if exists member_positions_master_delete_anon_temp on public.member_positions_master;

drop policy if exists survey_forms_select_anon_temp on public.survey_forms;
drop policy if exists survey_forms_insert_anon_temp on public.survey_forms;
drop policy if exists survey_forms_update_anon_temp on public.survey_forms;
drop policy if exists survey_forms_delete_anon_temp on public.survey_forms;

drop policy if exists survey_responses_select_anon_temp on public.survey_responses;
drop policy if exists survey_responses_insert_anon_temp on public.survey_responses;
drop policy if exists survey_responses_update_anon_temp on public.survey_responses;
drop policy if exists survey_responses_delete_anon_temp on public.survey_responses;
