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

- ファイルの作成・書き換えは禁止
- 一度に複数の関心事を含む Issue の作成は禁止（分割して起票する）
- 構造化された Issue（epic Issue・Sub-Issue・親子関係を持つ Issue）の作成は禁止。複数 Issue を起票する場合も全てフラットに並べる
- 結合試験・統合テスト・E2E テストなどテストのみを目的とした単独 Issue の作成は禁止。テストは各機能 Issue の受け入れ基準に含める

## 入力の解析

`$ARGUMENTS` を以下のように解釈する:

- **リポジトリ指定あり**: `owner/repo` 形式が含まれていれば `--repo` オプションに使用する
- **リポジトリ指定なし**: カレントディレクトリのリポジトリに対して起票する

## 手順

### Phase 1: 内容の整理

会話の文脈（直前の brainstorming 等）から Issue に記載すべき内容を整理する。

### Phase 2: Issue 作成

`gh issue create` で Issue を作成する。

```
gh issue create --title "TITLE" --body "$(cat <<'EOF'
Issue 本文
EOF
)"
```

リポジトリを指定する場合は `--repo OWNER/REPOSITORY` を付ける。

Issue 本文は以下のテンプレートに従う:

```markdown
## 背景

（なぜこの要求が必要なのか。現状の課題や動機を記述する）

## 要求

（実現すべきことを箇条書きで明確に記述する。「何を」にフォーカスし、「どう実装するか」は含めない）

- [ ] 要求1
- [ ] 要求2
- [ ] 要求3

## 受け入れ基準

（この要求が満たされたとみなす条件を具体的に記述する）

- [ ] 基準1
- [ ] 基準2

## 制約・前提

（制約事項や前提条件を記述する。なければ省略可）
```

複数の関心事がある場合は、関心事ごとに分割して Issue を起票する。このとき以下を守る:

- 全ての Issue を対等・フラットに起票する。epic Issue や Sub-Issue といった親子構造を作らない
- Issue 同士を親子・包含関係で紐付けない（必要なら本文中で関連 Issue として参照するに留める）
- 結合試験・統合テスト・E2E テストなど、テストのみを目的とした単独 Issue は作らない。テスト観点は各機能 Issue の受け入れ基準に織り込む

### Phase 3: 報告

作成した Issue の URL をユーザーに提示する。
