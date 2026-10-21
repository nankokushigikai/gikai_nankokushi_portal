-- ----------------------------------------------------------------------
-- C：議員でない認証ユーザー・未ログイン利用者を全表から締め出す
--
-- Googleアカウントがあれば誰でも Supabase 上は authenticated になるため、
-- 既存ポリシー(auth.uid() is not null 等)はそのままに、表ごとに RESTRICTIVE を2本足す:
--   <表>_require_member : authenticated は「現職議員 or 管理者」のときだけ全操作可
--   <表>_deny_anon      : 未ログイン(anon)は全操作不可
-- RESTRICTIVE は既存ポリシーに AND で重なるだけなので、現職議員・管理者の権限は変わらない。
-- (select 関数()) の形にして、1クエリにつき1回だけ判定させる。
--
-- 対象: public スキーマの全38表(2026/10/1 SQL_MEMBER_ONLY_01_DIAG_TABLES の結果より)
-- 元に戻す: SQL_MEMBER_ONLY_03_ROLLBACK.sql
-- ----------------------------------------------------------------------

drop policy if exists activity_records_require_member on public.activity_records;
create policy activity_records_require_member on public.activity_records
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists activity_records_deny_anon on public.activity_records;
create policy activity_records_deny_anon on public.activity_records
as restrictive for all to anon
using (false) with check (false);

drop policy if exists announcement_attendance_responses_require_member on public.announcement_attendance_responses;
create policy announcement_attendance_responses_require_member on public.announcement_attendance_responses
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists announcement_attendance_responses_deny_anon on public.announcement_attendance_responses;
create policy announcement_attendance_responses_deny_anon on public.announcement_attendance_responses
as restrictive for all to anon
using (false) with check (false);

drop policy if exists announcement_calendar_links_require_member on public.announcement_calendar_links;
create policy announcement_calendar_links_require_member on public.announcement_calendar_links
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists announcement_calendar_links_deny_anon on public.announcement_calendar_links;
create policy announcement_calendar_links_deny_anon on public.announcement_calendar_links
as restrictive for all to anon
using (false) with check (false);

drop policy if exists announcement_recipients_require_member on public.announcement_recipients;
create policy announcement_recipients_require_member on public.announcement_recipients
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists announcement_recipients_deny_anon on public.announcement_recipients;
create policy announcement_recipients_deny_anon on public.announcement_recipients
as restrictive for all to anon
using (false) with check (false);

drop policy if exists announcement_title_master_require_member on public.announcement_title_master;
create policy announcement_title_master_require_member on public.announcement_title_master
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists announcement_title_master_deny_anon on public.announcement_title_master;
create policy announcement_title_master_deny_anon on public.announcement_title_master
as restrictive for all to anon
using (false) with check (false);

drop policy if exists announcements_require_member on public.announcements;
create policy announcements_require_member on public.announcements
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists announcements_deny_anon on public.announcements;
create policy announcements_deny_anon on public.announcements
as restrictive for all to anon
using (false) with check (false);

drop policy if exists audit_log_require_member on public.audit_log;
create policy audit_log_require_member on public.audit_log
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists audit_log_deny_anon on public.audit_log;
create policy audit_log_deny_anon on public.audit_log
as restrictive for all to anon
using (false) with check (false);

drop policy if exists committee_activity_posts_require_member on public.committee_activity_posts;
create policy committee_activity_posts_require_member on public.committee_activity_posts
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists committee_activity_posts_deny_anon on public.committee_activity_posts;
create policy committee_activity_posts_deny_anon on public.committee_activity_posts
as restrictive for all to anon
using (false) with check (false);

drop policy if exists committee_activity_recipients_require_member on public.committee_activity_recipients;
create policy committee_activity_recipients_require_member on public.committee_activity_recipients
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists committee_activity_recipients_deny_anon on public.committee_activity_recipients;
create policy committee_activity_recipients_deny_anon on public.committee_activity_recipients
as restrictive for all to anon
using (false) with check (false);

drop policy if exists committee_bills_require_member on public.committee_bills;
create policy committee_bills_require_member on public.committee_bills
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists committee_bills_deny_anon on public.committee_bills;
create policy committee_bills_deny_anon on public.committee_bills
as restrictive for all to anon
using (false) with check (false);

drop policy if exists committee_materials_require_member on public.committee_materials;
create policy committee_materials_require_member on public.committee_materials
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists committee_materials_deny_anon on public.committee_materials;
create policy committee_materials_deny_anon on public.committee_materials
as restrictive for all to anon
using (false) with check (false);

drop policy if exists document_ink_notes_require_member on public.document_ink_notes;
create policy document_ink_notes_require_member on public.document_ink_notes
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists document_ink_notes_deny_anon on public.document_ink_notes;
create policy document_ink_notes_deny_anon on public.document_ink_notes
as restrictive for all to anon
using (false) with check (false);

drop policy if exists document_notes_require_member on public.document_notes;
create policy document_notes_require_member on public.document_notes
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists document_notes_deny_anon on public.document_notes;
create policy document_notes_deny_anon on public.document_notes
as restrictive for all to anon
using (false) with check (false);

drop policy if exists document_tags_require_member on public.document_tags;
create policy document_tags_require_member on public.document_tags
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists document_tags_deny_anon on public.document_tags;
create policy document_tags_deny_anon on public.document_tags
as restrictive for all to anon
using (false) with check (false);

drop policy if exists document_text_lookup_require_member on public.document_text_lookup;
create policy document_text_lookup_require_member on public.document_text_lookup
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists document_text_lookup_deny_anon on public.document_text_lookup;
create policy document_text_lookup_deny_anon on public.document_text_lookup
as restrictive for all to anon
using (false) with check (false);

drop policy if exists general_question_material_require_member on public.general_question_material;
create policy general_question_material_require_member on public.general_question_material
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists general_question_material_deny_anon on public.general_question_material;
create policy general_question_material_deny_anon on public.general_question_material
as restrictive for all to anon
using (false) with check (false);

drop policy if exists general_question_tracker_require_member on public.general_question_tracker;
create policy general_question_tracker_require_member on public.general_question_tracker
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists general_question_tracker_deny_anon on public.general_question_tracker;
create policy general_question_tracker_deny_anon on public.general_question_tracker
as restrictive for all to anon
using (false) with check (false);

drop policy if exists general_question_updates_require_member on public.general_question_updates;
create policy general_question_updates_require_member on public.general_question_updates
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists general_question_updates_deny_anon on public.general_question_updates;
create policy general_question_updates_deny_anon on public.general_question_updates
as restrictive for all to anon
using (false) with check (false);

drop policy if exists kaiha_master_require_member on public.kaiha_master;
create policy kaiha_master_require_member on public.kaiha_master
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists kaiha_master_deny_anon on public.kaiha_master;
create policy kaiha_master_deny_anon on public.kaiha_master
as restrictive for all to anon
using (false) with check (false);

drop policy if exists mail_notice_recipients_require_member on public.mail_notice_recipients;
create policy mail_notice_recipients_require_member on public.mail_notice_recipients
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists mail_notice_recipients_deny_anon on public.mail_notice_recipients;
create policy mail_notice_recipients_deny_anon on public.mail_notice_recipients
as restrictive for all to anon
using (false) with check (false);

drop policy if exists mail_notice_settings_backup_require_member on public.mail_notice_settings_backup;
create policy mail_notice_settings_backup_require_member on public.mail_notice_settings_backup
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists mail_notice_settings_backup_deny_anon on public.mail_notice_settings_backup;
create policy mail_notice_settings_backup_deny_anon on public.mail_notice_settings_backup
as restrictive for all to anon
using (false) with check (false);

drop policy if exists mail_notice_templates_require_member on public.mail_notice_templates;
create policy mail_notice_templates_require_member on public.mail_notice_templates
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists mail_notice_templates_deny_anon on public.mail_notice_templates;
create policy mail_notice_templates_deny_anon on public.mail_notice_templates
as restrictive for all to anon
using (false) with check (false);

drop policy if exists mail_notices_require_member on public.mail_notices;
create policy mail_notices_require_member on public.mail_notices
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists mail_notices_deny_anon on public.mail_notices;
create policy mail_notices_deny_anon on public.mail_notices
as restrictive for all to anon
using (false) with check (false);

drop policy if exists meeting_settings_require_member on public.meeting_settings;
create policy meeting_settings_require_member on public.meeting_settings
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists meeting_settings_deny_anon on public.meeting_settings;
create policy meeting_settings_deny_anon on public.meeting_settings
as restrictive for all to anon
using (false) with check (false);

drop policy if exists member_directory_require_member on public.member_directory;
create policy member_directory_require_member on public.member_directory
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists member_directory_deny_anon on public.member_directory;
create policy member_directory_deny_anon on public.member_directory
as restrictive for all to anon
using (false) with check (false);

drop policy if exists member_positions_master_require_member on public.member_positions_master;
create policy member_positions_master_require_member on public.member_positions_master
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists member_positions_master_deny_anon on public.member_positions_master;
create policy member_positions_master_deny_anon on public.member_positions_master
as restrictive for all to anon
using (false) with check (false);

drop policy if exists members_require_member on public.members;
create policy members_require_member on public.members
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists members_deny_anon on public.members;
create policy members_deny_anon on public.members
as restrictive for all to anon
using (false) with check (false);

drop policy if exists nankoku_ordinance_links_require_member on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_require_member on public.nankoku_ordinance_links
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists nankoku_ordinance_links_deny_anon on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_deny_anon on public.nankoku_ordinance_links
as restrictive for all to anon
using (false) with check (false);

drop policy if exists profiles_require_member on public.profiles;
create policy profiles_require_member on public.profiles
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists profiles_deny_anon on public.profiles;
create policy profiles_deny_anon on public.profiles
as restrictive for all to anon
using (false) with check (false);

drop policy if exists schedule_events_require_member on public.schedule_events;
create policy schedule_events_require_member on public.schedule_events
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists schedule_events_deny_anon on public.schedule_events;
create policy schedule_events_deny_anon on public.schedule_events
as restrictive for all to anon
using (false) with check (false);

drop policy if exists schedule_recipients_require_member on public.schedule_recipients;
create policy schedule_recipients_require_member on public.schedule_recipients
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists schedule_recipients_deny_anon on public.schedule_recipients;
create policy schedule_recipients_deny_anon on public.schedule_recipients
as restrictive for all to anon
using (false) with check (false);

drop policy if exists schedule_responses_require_member on public.schedule_responses;
create policy schedule_responses_require_member on public.schedule_responses
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists schedule_responses_deny_anon on public.schedule_responses;
create policy schedule_responses_deny_anon on public.schedule_responses
as restrictive for all to anon
using (false) with check (false);

drop policy if exists schedule_slots_require_member on public.schedule_slots;
create policy schedule_slots_require_member on public.schedule_slots
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists schedule_slots_deny_anon on public.schedule_slots;
create policy schedule_slots_deny_anon on public.schedule_slots
as restrictive for all to anon
using (false) with check (false);

drop policy if exists subsidies_require_member on public.subsidies;
create policy subsidies_require_member on public.subsidies
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists subsidies_deny_anon on public.subsidies;
create policy subsidies_deny_anon on public.subsidies
as restrictive for all to anon
using (false) with check (false);

drop policy if exists survey_catalog_require_member on public.survey_catalog;
create policy survey_catalog_require_member on public.survey_catalog
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists survey_catalog_deny_anon on public.survey_catalog;
create policy survey_catalog_deny_anon on public.survey_catalog
as restrictive for all to anon
using (false) with check (false);

drop policy if exists survey_forms_require_member on public.survey_forms;
create policy survey_forms_require_member on public.survey_forms
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists survey_forms_deny_anon on public.survey_forms;
create policy survey_forms_deny_anon on public.survey_forms
as restrictive for all to anon
using (false) with check (false);

drop policy if exists survey_responses_require_member on public.survey_responses;
create policy survey_responses_require_member on public.survey_responses
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists survey_responses_deny_anon on public.survey_responses;
create policy survey_responses_deny_anon on public.survey_responses
as restrictive for all to anon
using (false) with check (false);

drop policy if exists system_requests_require_member on public.system_requests;
create policy system_requests_require_member on public.system_requests
as restrictive for all to authenticated
using ((select public.is_current_portal_member()) or (select public.is_portal_admin()))
with check ((select public.is_current_portal_member()) or (select public.is_portal_admin()));
drop policy if exists system_requests_deny_anon on public.system_requests;
create policy system_requests_deny_anon on public.system_requests
as restrictive for all to anon
using (false) with check (false);
