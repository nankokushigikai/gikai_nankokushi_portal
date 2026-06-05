# Git リモートリポジトリの変更手順

## 概要

VS Code で push 先の GitHub リポジトリを変更したいときの手順です。
Copilot 用アカウントと push 先アカウントが別々でも問題ありません。

---

## 手順

### 1. 現在のリモートURLを確認

```powershell
git remote -v
```

例:
```
origin  https://github.com/yamahiro1960/gikai_nankokushi_portal.git (fetch)
origin  https://github.com/yamahiro1960/gikai_nankokushi_portal.git (push)
```

---

### 2. リモートURLを新しいリポジトリに変更

```powershell
git remote set-url origin https://github.com/【新しいアカウント名】/【リポジトリ名】.git
```

例:
```powershell
git remote set-url origin https://github.com/nankokushigikai/gikai_nankokushi_portal.git
```

変更後に確認:
```powershell
git remote -v
```

---

### 3. 古い認証情報を削除（403エラーが出る場合）

古いアカウントの認証情報が残っていると 403 エラーになります。

#### 保存済み認証情報を確認
```powershell
cmdkey /list | Select-String "github"
```

#### `git:https://github.com` の項目を削除
```powershell
cmdkey /delete:LegacyGeneric:target=git:https://github.com
```

> **注意:** `gh:github.com:yamahiro1960` などの Copilot 用アカウントは削除しないこと。

---

### 4. push を実行

```powershell
git push origin HEAD
```

ブラウザが開くので、**新しいアカウント（nankokushigikai など）でログイン**して認証を許可します。

---

## よくあるトラブル

| 症状 | 原因 | 対処 |
|------|------|------|
| `Permission denied to 【別アカウント名】` | 古い認証情報が残っている | 手順3の認証情報削除を実施 |
| `Repository not found` | push先リポジトリが存在しない | GitHub でリポジトリを先に作成 |
| ブラウザが開かず止まる | 認証プロンプトが別ウィンドウに表示 | タスクバーを確認してブラウザを前面に出す |

---

## アカウントの役割まとめ（本プロジェクト）

| アカウント | 用途 |
|------------|------|
| `yamahiro1960` | GitHub Copilot 用（VS Code サインイン） |
| `nankokushigikai` | コードの保管・push 先リポジトリ |

この2つは独立しており、それぞれ別の用途で同時使用できます。
