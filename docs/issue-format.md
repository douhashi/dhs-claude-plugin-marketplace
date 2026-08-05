# Issue 本文・コメントのフォーマット

spira が GitHub Issue に書き込む本文・コメントは、書式と記述量が制約される。その仕組みを定義する。

## 原則

- Issue は読み手（implementer・レビュアー）が短時間で把握できる量に収める
- 書式と上限の定義はテンプレートファイルが単一ソースであり、スキル・エージェントの本文には書かない
- 差分で足りるコメントは差分だけを書く
- 上限は投稿前に機械的に検証する

## テンプレート

`spira/templates/` 配下の markdown ファイルが書式と上限を定義する。

| ファイル | 定義対象 | 上限 |
|:--|:--|--:|
| `_rules.md` | 共通ルール・上限一覧・投稿手順 | — |
| `issue-body.md` | Issue 本文 | 1,500 字 |
| `implementation-plan.md` | `## 実装計画` | 2,500 字 |
| `plan-revision.md` | `## 計画の修正` | 500 字 |
| `design-decision.md` | `## 設計判断` | 800 字／論点 |
| `implementation-result.md` | `## 実装内容` | 1,200 字 |
| `implementation-result.md`（差分版） | `## 設計判断に基づく修正` / `## CI 修正 (N回目)` | 500 字 |
| `qa-result.md` | `## QA 結果` / `## CI 失敗 (N回目)` | 300 字 |
| `completion-report.md` | `## PR 作成` / `## 完了報告` / `## CI 修正打ち切り` / エスカレーション Issue 本文 | 200 / 500 / 300 / 500 字 |

上限一覧の正本は `spira/templates/_rules.md`。本表は概要であり、値を変える場合は
`_rules.md` と該当テンプレートの両方を更新する。

## 起票前の承認

Issue の起票は取り消しにくいため、create-issue スキルは本文を書く前に
**作成予定 Issue の一覧表**を提示して承認を得る。書式は
`spira/skills/create-issue/templates/issue-plan.md`（`#` / タイトル / 目的 / 完了条件、最大 7 行）。

Issue のタイトルは Conventional Commits スタイル（`<type>(<scope>): <説明>`）で書く。
`type` と使い分けの定義も `issue-plan.md` が単一ソースであり、スキル本文には書かない。

- 承認前に `gh issue create` を実行しない
- 承認段階で本文の全文は提示しない。ユーザーが求めた Issue の分だけ `issue-body.md` に沿って提示する
- 承認は表全体に対して行う。承認されたら全行を起票し、行を選んで一部だけ起票しない
- 粒度・分割・統合などの調整が入ったら、表を作り直して再提示し、改めて承認を得る

## 参照方法

`${CLAUDE_PLUGIN_ROOT}` は skill と agent の本文いずれでも、出現箇所を問わず展開される
（[plugins-reference](https://code.claude.com/docs/ja/plugins-reference.md) の環境変数の節）。
スキル・エージェントは次の形でテンプレートを指し、Claude に Read させる。

```markdown
`${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md` を Read し、その雛形どおりに記述する
```

SKILL.md で `@path` によるインポートは使えない（`@` は CLAUDE.md の機能）。
プラグイン内の共有ファイルは上記の `${CLAUDE_PLUGIN_ROOT}` で、スキル固有の補助ファイルは
相対 markdown リンクで参照する。

## 誰がテンプレートを読むか

| 書き込み先 | 書き手 | テンプレートを読む主体 |
|:--|:--|:--|
| `## 実装計画` / `## 計画の修正` | planner | エージェント自身 |
| `## 設計判断` | po | エージェント自身 |
| `## 実装内容` / `## 設計判断に基づく修正` / `## CI 修正 (N回目)` | implementer / setup | エージェント自身 |
| `## QA 結果` / `## CI 失敗 (N回目)` | qa | エージェント自身 |
| Issue 本文 | create-issue スキル | スキル自身 |
| `## PR 作成` / `## 完了報告` / `## CI 修正打ち切り` / エスカレーション Issue 本文 | implement / do スキル | スキル自身 |

オーケストレータがエージェントに渡すのは**見出しだけ**でよい。テンプレートの解決はエージェントが行う。

## 上限の担保

字数の自己申告は当てにならないため、投稿前に `wc -m` で確認する。

```bash
mkdir -p .tmp
cat > .tmp/spira-comment.md <<'EOF'
（本文）
EOF

wc -m .tmp/spira-comment.md          # 上限以内であることを確認する
gh issue comment <ISSUE_URL> --body-file .tmp/spira-comment.md
```

`--body-file` を使うのは、投稿前に `wc -m` を挟むためである。
上限を超えた本文は投稿しない。`_rules.md` の優先順位に従って削り、再度確認する。

## 差分で記録するコメント

以下は差分のみを記録し、参照元コメントの内容を再掲しない。

| コメント | 内容 | 参照元 |
|:--|:--|:--|
| `## 計画の修正` | 論点 / 決定 / 計画への反映 の表 | `## 実装計画` |
| `## 設計判断に基づく修正` | 修正したファイルと修正内容の表 | `## 実装内容` |
| `## CI 修正 (N回目)` | 修正したファイルと修正内容の表 | `## 実装内容` |
| `## 完了報告` | PR URL・マージ結果・変更ファイル数 | `## 実装内容` と PR の diff |
