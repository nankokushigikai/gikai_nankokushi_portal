-- お知らせタイトルマスターテーブル
CREATE TABLE IF NOT EXISTS public.announcement_title_master (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS有効化
ALTER TABLE public.announcement_title_master ENABLE ROW LEVEL SECURITY;

-- 全認証ユーザーが読み取り可能
CREATE POLICY "announcement_title_master_select"
    ON public.announcement_title_master
    FOR SELECT
    TO public
    USING (auth.role() = 'authenticated');

-- 全認証ユーザーが登録可能
CREATE POLICY "announcement_title_master_insert"
    ON public.announcement_title_master
    FOR INSERT
    TO public
    WITH CHECK (auth.role() = 'authenticated');

-- 全認証ユーザーが更新可能
CREATE POLICY "announcement_title_master_update"
    ON public.announcement_title_master
    FOR UPDATE
    TO public
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 全認証ユーザーが削除可能
CREATE POLICY "announcement_title_master_delete"
    ON public.announcement_title_master
    FOR DELETE
    TO public
    USING (auth.role() = 'authenticated');

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER announcement_title_master_updated_at
    BEFORE UPDATE ON public.announcement_title_master
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
