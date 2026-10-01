-- 日程調整：二重作成された重複分 id 11・14 を削除（2026/10/1 ユーザー承認済み）
--   11 = 「DX推進委員の進捗状況」の重複（残すのは 10）
--   14 = 「コメダ」の重複（残すのは 13）
-- 安全策:
--   ・id／作成者／タイトルが想定と一致しなければ何も消さずに中止する
--   ・回答が1件でもあれば中止する（診断時点では両方とも回答0件）
--   ・本番の外部キー(カスケード)設定に頼らず、回答→対象者→日程候補→本体の順に明示的に削除する
--   ・DOブロック全体が1トランザクションなので、途中で失敗したら全部取り消される
do $$
declare
    v_ids    bigint[] := array[11, 14];
    v_match  int;
    v_resp   int;
begin
    select count(*) into v_match
      from public.schedule_events
     where (id = 11 and created_by_email = 'zhenghezhaiteng638@gmail.com' and title = 'DX推進委員の進捗状況')
        or (id = 14 and created_by_email = 'decodani0107@gmail.com'       and title = 'コメダ');
    if v_match <> 2 then
        raise exception '対象の行が想定と一致しません(一致 % 件)。中止しました', v_match;
    end if;

    select count(*) into v_resp
      from public.schedule_responses r
     where r.event_id = any(v_ids)
        or r.slot_id in (select s.id from public.schedule_slots s where s.event_id = any(v_ids));
    if v_resp > 0 then
        raise exception '回答が % 件あります。中止しました', v_resp;
    end if;

    delete from public.schedule_recipients where event_id = any(v_ids);
    delete from public.schedule_slots      where event_id = any(v_ids);
    delete from public.schedule_events     where id = any(v_ids);

    raise notice '削除完了: id 11, 14';
end;
$$;
