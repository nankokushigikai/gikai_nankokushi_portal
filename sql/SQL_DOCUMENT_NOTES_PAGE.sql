-- ----------------------------------------------------------------------
-- document_notes をページ単位保存へ拡張
-- ----------------------------------------------------------------------

alter table public.document_notes
    add column if not exists page_number int;

update public.document_notes
set page_number = 1
where page_number is null;

alter table public.document_notes
    alter column page_number set default 1;

alter table public.document_notes
    alter column page_number set not null;

alter table public.document_notes
    drop constraint if exists document_notes_page_number_chk;

alter table public.document_notes
    add constraint document_notes_page_number_chk
    check (page_number > 0);

-- 旧ユニーク制約（資料単位）を削除して、ページ単位へ変更
alter table public.document_notes
    drop constraint if exists document_notes_member_id_session_id_document_name_key;

alter table public.document_notes
    drop constraint if exists document_notes_member_session_document_page_key;

alter table public.document_notes
    add constraint document_notes_member_session_document_page_key
    unique (member_id, session_id, document_name, page_number);

create index if not exists document_notes_member_doc_page_idx
    on public.document_notes (member_id, session_id, document_name, page_number);
