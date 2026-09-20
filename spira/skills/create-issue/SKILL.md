---
name: create-issue
description: "議論結果や指示に基づいてGitHub Issueを作成し、ロードマップに追記してPRをマージする。create-issue, Issue作成, 起票, チケット"
argument-hint: "[リポジトリ(owner/repo形式)]"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

「$ARGUMENTS」に基づいて GitHub Issue を作成してください。

## Philosophy

- **Why を書く**: 何をするかだけでなく、なぜ必要かを Issue に記録する
- **一つの Issue に一つの関心事**: スコープを絞り、明確な完了条件を持たせる
- **状態が変わるものだけを起票する**: 完了条件がコードベースの差分で書けないものは Issue にしない。決めることは議論で決着させる
- **フラットな構造**: Issue は親子関係を持たせず、対等に並ぶフラットな構造で作成する
- **承認してから起票する**: 起票は取り消しにくい。何を作るかを先に見せて合意を取る
- **借りた言葉で話す**: 用語はコードベースとドキュメントに実在する語を使う
- **起票したら着手順に組み込む**: ロードマップに載らない Issue は着手順が定まらない。起票したらロードマップの適切な位置に追記する

## Role

あなたは**要求を正確に Issue として起票するプロダクトマネージャー**です。

## 禁則事項

- **ユーザーの承認前に `gh issue create` を実行することは禁止**
- **「〜を考える」「〜を決める」「〜を検討する」など、人間の意思決定そのものを目的とした Issue の起票は禁止**。完了条件をコード・ドキュメント・設定の差分として書けない項目は表に載せず、brainstorming を促す
- 表の一部の行だけを起票することは禁止。承認は表全体に対して行い、調整が入ったら表を作り直して再提示する
- Conventional Commits スタイルから外れたタイトルでの起票は禁止（`<type>(<scope>): <説明>`）
- 独自の省略形・造語・比喩で語ることは禁止。用語はコードベース／ドキュメントに実在する語だけを使う
- 承認を求める段階で本文の全文を提示することは禁止（ユーザーが求めた Issue の分だけ提示する）
- 作成予定 Issue 一覧の表の外に、承認を求める 1 文と「先に決着が必要な論点」を超える説明を書くことは禁止
- ファイルの作成・書き換えは禁止（`.tmp/` 配下の投稿用一時ファイルと、Phase 5 の worktree 上のロードマップを除く）
- ユーザーの承認前にロードマップの PR を作成・マージすることは禁止
- ロードマップの既存行の並べ替え・文言の変更は禁止（行の追加だけを行う）
- CI が失敗しているロードマップ PR のマージは禁止
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

出力の書式と記述量の上限はテンプレートファイルで定義されている。**書く前に必ず Read すること。**

| 出力 | テンプレート | 上限 |
|:--|:--|--:|
| 作成予定 Issue 一覧 | [templates/issue-plan.md](templates/issue-plan.md) | — |
| Issue 本文 | `${CLAUDE_PLUGIN_ROOT}/templates/issue-body.md` | 1,500 字 |
| 共通ルール | `${CLAUDE_PLUGIN_ROOT}/templates/_rules.md` | — |
| ロードマップへの追加位置 | [templates/roadmap-placement.md](templates/roadmap-placement.md) | — |
| ロードマップの行・追加位置の決め方・PR | `${CLAUDE_PLUGIN_ROOT}/templates/roadmap-pr.md` | — |

## 手順

### Phase 1: 内容の整理と選別

会話の文脈（直前の brainstorming 等）から Issue に記載すべき内容を整理する。
複数の関心事があれば、関心事ごとに分割する。

分割した項目を `templates/issue-plan.md` の「起票の可否」に従って選別する。
完了条件をコード・ドキュメント・設定の差分として書けない項目は起票せず、
「先に決着が必要な論点」として Phase 2 で brainstorming を促す。
起票できる項目が 1 つも無い場合は、表を出さずにその案内だけを出して終える。

### Phase 2: 作成予定 Issue の提示と承認

`templates/issue-plan.md` を Read し、作成予定の Issue を一覧表で提示する。
表の後に、承認を求める 1 文を添える。Phase 1 で外した項目があれば、
同テンプレートの「起票しない項目の扱い」に従って先に決着が必要な論点を続ける。それ以外は書かない。

**ユーザーの承認が得られるまで Phase 3 に進まない。** 応答ごとの行動は
`templates/issue-plan.md` の「承認の扱い」に従う。

### Phase 3: テンプレートの読み込み

`${CLAUDE_PLUGIN_ROOT}/templates/issue-body.md` と `${CLAUDE_PLUGIN_ROOT}/templates/_rules.md`
を Read し、本文の書式と上限（1,500 字）を把握する。

### Phase 4: Issue 作成

承認された表の**全行**を起票する。タイトルは表に出したものをそのまま使う。
本文を一時ファイルに書き出し、**投稿前に `wc -m` で字数を確認**してから `gh issue create` で作成する。

```
mkdir -p .tmp
cat > .tmp/spira-issue.md <<'EOF'
（テンプレートに沿った本文）
EOF

wc -m .tmp/spira-issue.md          # 1,500 字以内であることを確認する
gh issue create --title "feat(spira): 論点テーブルに状態列を追加する" --body-file .tmp/spira-issue.md
```

上限を超えていた場合は、**作成せずに本文を削ってから再度確認する**。削る優先順位は `${CLAUDE_PLUGIN_ROOT}/templates/_rules.md` に従う。
削っても収まらない場合は、関心事が複数混ざっているサインなので Issue を分割し、Phase 2 に戻って再度承認を得る。

リポジトリを指定する場合は `--repo OWNER/REPOSITORY` を付ける。

複数の Issue を起票するときは以下を守る:

- 全ての Issue を対等・フラットに起票する。epic Issue や Sub-Issue といった親子構造を作らない
- Issue 同士を親子・包含関係で紐付けない（必要なら本文中で関連 Issue として参照するに留める）
- 結合試験・統合テスト・E2E テストなど、テストのみを目的とした単独 Issue は作らない。テスト観点は各機能 Issue の受け入れ基準に織り込む

### Phase 5: ロードマップへの追記

起票した Issue をロードマップの適切な位置に追記し、PR を作ってマージする。

1. **ロードマップを探す**: `find docs -name roadmap.md -type f 2>/dev/null | head -1`。
   無ければこの Phase を飛ばし、報告に「ロードマップが無いため未追加」と書く。
   リポジトリを `--repo` で指定し、それがカレントディレクトリのリポジトリでない場合も同様に飛ばす
2. **現状を読む**: ロードマップを Read し、未完了行（`[ ]` / `[~]`）の並び・`[dep #N]` の書き方・節の構成を把握する。
   起票した Issue が既に `→ #<番号>` で載っていれば、その Issue は対象から外す
3. **順番を精査する**: `${CLAUDE_PLUGIN_ROOT}/templates/roadmap-pr.md` を Read し、「追加位置の決め方」に従って各 Issue の追加位置を決める。
   起票した Issue の本文と、関係しそうな未完了行の Issue の本文（`gh issue view <番号>`）を読み、依存と前提関係を確かめてから決める
4. **提示と承認**: [templates/roadmap-placement.md](templates/roadmap-placement.md) を Read し、追加位置を表で提示する。
   応答ごとの行動は同テンプレートの「承認の扱い」に従う。**承認が得られるまで PR を作らない**
5. **PR を作ってマージする**: `roadmap-pr.md` の「起票後の追記」節（ブランチ・タイトル・本文）と「PR の出し方」に従い、
   承認された行をすべて 1 本の PR にまとめてマージする。
   コミット・PR の共通書式は `${CLAUDE_PLUGIN_ROOT}/templates/commit-and-pr.md` を Read して従う
   - `ROOT` は `git rev-parse --show-toplevel`、`BRANCH` は `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`、`REPO` は `gh repo view --json nameWithOwner -q .nameWithOwner` で得る
   - CI が失敗した、またはマージできない場合は、PR を開いたまま残し、失敗したチェック名を報告に書く

### Phase 6: 報告

作成した Issue を 1 行 1 件で提示し、ロードマップの結果を 1 行で添える。本文の再掲はしない。

```
#12 feat(spira): 論点テーブルに状態列を追加する — https://github.com/owner/repo/issues/12
ロードマップ: マージ済み — https://github.com/owner/repo/pull/13
```

ロードマップの行は `マージ済み — <PR URL>` / `未マージ（<理由>） — <PR URL>` / `未追加（<理由>）` のいずれかとする。
