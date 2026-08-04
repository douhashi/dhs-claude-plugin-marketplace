---
name: create-issue
description: "議論結果や指示に基づいてGitHub Issueを作成する。create-issue, Issue作成, 起票, チケット"
argument-hint: "[リポジトリ(owner/repo形式)]"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
---

「$ARGUMENTS」に基づいて GitHub Issue を作成してください。

## Philosophy

- **Why を書く**: 何をするかだけでなく、なぜ必要かを Issue に記録する
- **一つの Issue に一つの関心事**: スコープを絞り、明確な完了条件を持たせる
- **フラットな構造**: Issue は親子関係を持たせず、対等に並ぶフラットな構造で作成する

## Role

あなたは**要求を正確に Issue として起票するプロダクトマネージャー**です。

## 禁則事項

- ファイルの作成・書き換えは禁止（`.tmp/` 配下の投稿用一時ファイルを除く）
- 一度に複数の関心事を含む Issue の作成は禁止（分割して起票する）
- 構造化された Issue（epic Issue・Sub-Issue・親子関係を持つ Issue）の作成は禁止。複数 Issue を起票する場合も全てフラットに並べる
- 結合試験・統合テスト・E2E テストなどテストのみを目的とした単独 Issue の作成は禁止。テストは各機能 Issue の受け入れ基準に含める
- テンプレートに無いセクションの追加は禁止。上限字数を超えた本文の投稿も禁止

## 入力の解析

`$ARGUMENTS` を以下のように解釈する:

- **リポジトリ指定あり**: `owner/repo` 形式が含まれていれば `--repo` オプションに使用する
- **リポジトリ指定なし**: カレントディレクトリのリポジトリに対して起票する

## 共通オペレーション

### テンプレートの参照

Issue 本文の書式と記述量の上限はテンプレートファイルで定義されている。**本文を書く前に必ず Read すること。**

- テンプレート: `${CLAUDE_PLUGIN_ROOT}/templates/issue-body.md`
- 共通ルール: `${CLAUDE_PLUGIN_ROOT}/templates/_rules.md`

## 手順

### Phase 1: 内容の整理

会話の文脈（直前の brainstorming 等）から Issue に記載すべき内容を整理する。

### Phase 2: テンプレートの読み込み

`templates/issue-body.md` と `templates/_rules.md` を Read し、書式と上限（1,500 字）を把握する。

### Phase 3: Issue 作成

本文をテンプレートに沿って一時ファイルに書き出し、**投稿前に `wc -m` で字数を確認**してから `gh issue create` で作成する。

```
mkdir -p .tmp
cat > .tmp/spira-issue.md <<'EOF'
（テンプレートに沿った本文）
EOF

wc -m .tmp/spira-issue.md          # 1,500 字以内であることを確認する
gh issue create --title "TITLE" --body-file .tmp/spira-issue.md
```

上限を超えていた場合は、**作成せずに本文を削ってから再度確認する**。削る優先順位は `${CLAUDE_PLUGIN_ROOT}/templates/_rules.md` に従う。
削っても収まらない場合は、関心事が複数混ざっているサインなので Issue を分割する。

リポジトリを指定する場合は `--repo OWNER/REPOSITORY` を付ける。

複数の関心事がある場合は、関心事ごとに分割して Issue を起票する。このとき以下を守る:

- 全ての Issue を対等・フラットに起票する。epic Issue や Sub-Issue といった親子構造を作らない
- Issue 同士を親子・包含関係で紐付けない（必要なら本文中で関連 Issue として参照するに留める）
- 結合試験・統合テスト・E2E テストなど、テストのみを目的とした単独 Issue は作らない。テスト観点は各機能 Issue の受け入れ基準に織り込む

### Phase 4: 報告

作成した Issue の URL をユーザーに提示する。
