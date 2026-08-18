# お知らせ Googleカレンダー自動登録（方式A-2 ゲスト招待方式）セットアップ手順

お知らせを新規登録すると、メール送信・トップページ表示と同じタイミングで、
**配信対象の議員のGoogleカレンダーに予定が自動で入る**ようにする機能です。

- サーバー側（Supabase Edge Function `announcement-calendar-sync`）が、システム用Googleアカウントのカレンダーに予定を1件作成し、**配信対象者をゲスト（招待者）として追加**します。
- Google が各ゲストの個人カレンダーに予定を反映します。
- `visibility='specific'`（特定議員のみ）のお知らせは、選ばれた議員だけがゲストになるため、**対象外の議員のカレンダーには出ません**（特定配信の機密性を維持）。

---

## ⚠ 最重要の前提

**各議員が「ポータルに登録しているメールアドレス」と「実際に使っているGoogleアカウントのメールアドレス」が一致している必要があります。**

一致していない議員は、招待メールは届いても本人のGoogleカレンダーには自動で紐づきません。
（`member_directory` の各メールが、その人のGoogleカレンダーのアカウントと同じか事前にご確認ください。）

---

## 手順

### 1. システム用Googleアカウントを決める
予定の「入れ物」となるアカウントです。既存のメール送信用アカウント（`GMAIL_FROM_EMAIL`）と同じでも、専用の議会用アカウントでも構いません。
このアカウントの `primary` カレンダー（既定）に予定が作られ、そこから議員がゲスト招待されます。

### 2. Google Calendar API を有効化
Google Cloud Console で、対象プロジェクトの **Google Calendar API** を有効にします。
（お知らせの「個人カレンダー連携」を既に使っていれば有効済みのはずです。）

### 3. `calendar` スコープのリフレッシュトークンを取得
システム用アカウントで、以下スコープのリフレッシュトークンを取得します。

```
https://www.googleapis.com/auth/calendar
```

取得方法の一例（OAuth 2.0 Playground を使う場合）:
1. https://developers.google.com/oauthplayground を開く
2. 右上の歯車 → 「Use your own OAuth credentials」に既存のクライアントID/シークレットを入力
3. 左のスコープ欄に `https://www.googleapis.com/auth/calendar` を入力して Authorize
4. **システム用アカウントでログイン・同意**
5. 「Exchange authorization code for tokens」で **Refresh token** を取得
   - ※ access_type=offline / prompt=consent 相当。Refresh token が空の場合はアカウントのアクセス権を一度解除してからやり直す

### 4. Supabase Secrets を設定
Supabase CLI で以下を設定します（プロジェクトにリンク済みの前提）。

```bash
# 必須：手順3で取得したリフレッシュトークン
supabase secrets set CALENDAR_REFRESH_TOKEN="ここに取得したrefresh_token"

# 任意：メール送信と別のOAuthクライアント/別アカウントを使う場合のみ設定
#（未設定なら GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET を自動で流用します）
supabase secrets set CALENDAR_CLIENT_ID="..."
supabase secrets set CALENDAR_CLIENT_SECRET="..."

# 任意：primary 以外の専用カレンダーに入れたい場合のみ（既定は primary）
supabase secrets set CALENDAR_ID="primary"
```

### 5. 関数をデプロイ

```bash
supabase functions deploy announcement-calendar-sync
```

### 6. 動作確認
1. ポータルの「お知らせ登録」から、自分を配信対象に含めてお知らせを新規登録
2. 対象議員のGoogleカレンダーに予定が入るか確認
3. 登録画面のメッセージが「登録しました。」（カレンダー失敗時は注記付き）になることを確認
4. うまくいかない場合は Supabase の Functions ログでエラー詳細を確認

---

## 補足・設定オプション

- **二重通知について**：既定では Google からも招待メールが届きます（`sendUpdates="all"`）。ポータルからのお知らせメールと二重になります。招待メールを止めたい場合は、`announcement-register.html` の呼び出し `body` に `sendUpdates: "none"` を追加してください（ただし一部の受信設定ではカレンダー反映が弱くなる場合があります）。
- **通知（リマインダー）**：既定で予定の60分前・30分前にポップアップ通知。変更は `announcement-register.html` の `reminderMinutes: [60, 30]` を編集。
- **ゲスト同士の一覧**：非表示（`guestsCanSeeOtherGuests=false`）に設定済み。

## 現時点での対応範囲と今後
- **対応済み**：お知らせ「新規登録」時の自動カレンダー登録。
- **未対応（別途ご依頼で追加可）**：既存お知らせの「編集」「取消」時のカレンダー予定の更新・削除の自動反映。
  Edge Function 側は `action: "upsert"`（更新）/ `action: "delete"`（削除）に既に対応済みで、`announcements.html` の編集・取消処理に呼び出しを追加すれば連動できます。
