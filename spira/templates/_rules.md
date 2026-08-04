# Issue 記述の共通ルール

spira が GitHub Issue に書き込む本文・コメントすべてに適用する。
各テンプレートはこのルールを前提とする。

## 記述量の上限

| 書き込み先 | テンプレート | 上限 |
|:--|:--|--:|
| Issue 本文 | [issue-body.md](./issue-body.md) | 1,500 字 |
| `## 実装計画` | [implementation-plan.md](./implementation-plan.md) | 2,500 字 |
| `## 計画の修正` | [plan-revision.md](./plan-revision.md) | 500 字 |
| `## 設計判断` | [design-decision.md](./design-decision.md) | 800 字／論点 |
| `## 実装内容` | [implementation-result.md](./implementation-result.md) | 1,200 字 |
| `## 設計判断に基づく修正` | [implementation-result.md](./implementation-result.md)（差分版） | 500 字 |
| `## CI 修正 (N回目)` | [implementation-result.md](./implementation-result.md)（差分版） | 500 字 |
| `## QA 結果` / `## CI 失敗 (N回目)` | [qa-result.md](./qa-result.md) | 300 字 |
| `## PR 作成` | — | 200 字 |
| `## CI 修正打ち切り` | — | 300 字 |
| `## 完了報告` | [completion-report.md](./completion-report.md) | 500 字 |
| エスカレーション Issue 本文 | [completion-report.md](./completion-report.md) | 500 字 |

字数は見出しを含む markdown 全体の文字数（`wc -m`）で数える。

## 記述ルール

- **1 項目 1 文**。理由を添える場合も同じ 1 文に収める
- **コードの引用は禁止**。`path/to/file.ts:42` の形式で参照する。diff の貼り付けも禁止
- **同じ内容を複数のセクションに書かない**
- **「なし」「OK」で済む項目は 1 行で終える**。空の表・全行 OK の表は出力しない
- **検討の経緯は書かない**。結論と、結論を支える事実だけを書く
- **前のコメントの再掲は禁止**。参照はコメント URL で行う
- **テンプレートのセクションは増やさない**。書ききれない情報は削る対象であり、追加セクションの理由にはならない

## 投稿手順

字数を自己判断に頼らず、投稿前に必ず機械的に確認する。

```bash
mkdir -p .tmp
cat > .tmp/spira-comment.md <<'EOF'
## 見出し

（本文）
EOF

wc -m .tmp/spira-comment.md          # 上限以内であることを確認する
gh issue comment <ISSUE_URL> --body-file .tmp/spira-comment.md
```

Issue 本文の場合は `gh issue create --body-file .tmp/spira-issue.md` を使う。

上限を超えていた場合は、**投稿せずに本文を削ってから再度確認する**。
削る優先順位は次のとおり。

1. 経緯・背景の説明（結論だけ残す）
2. 自明なトレードオフ・根拠
3. 「なし」「OK」の行（1 行にまとめる）
4. 表の行（重要度の低いものから）
