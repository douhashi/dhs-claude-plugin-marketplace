# テンプレート: ロードマップ PR

- **書き手**
  - autopilot スキル（キックオフ整理: ロードマップに未記載の Open Issue があるとき。Phase 4）
  - orchestrator エージェント（追加: ループ中に見つかった、システムを壊す不具合を取り込むとき。手順 2-3）
  - orchestrator エージェント（整合修正: チェック状態や完了行の置き場所が現状とずれているとき。手順 6）
- **コミット・PR の共通書式**: `${CLAUDE_PLUGIN_ROOT}/templates/commit-and-pr.md`（`type` の定義もそちらが単一ソース）
- キックオフ整理・追加・整合修正それぞれ、**1 本の PR にまとめる**

## ロードマップの行

既存のロードマップの書式に合わせる。`spira:pick` が読むのは次の形の行である。

```markdown
- [ ] **<ID>** <what>。 → #<Issue 番号>
```

- `<ID>`: 同じ節の既存 ID の付け方に倣い、重複しない次の値にする（例: `B3` の次は `B4`）
- `<what>`: Issue タイトルの説明部（`<type>(<scope>): ` を除いた部分）
- 依存があれば、既存行と同じ位置・書き方で `[dep <ID>]` を付ける
- 既存行の文言は書き換えない。追加 PR は行の挿入だけ、整合修正 PR はチェック状態（`[ ]` / `[~]` / `[x]`）の変更・完了行の完了節への移動（再オープンなら未完了行の先頭へ戻す）・欠けている取り込み行の挿入だけを行う
- 未完了行どうしの並べ替えはしない

## キックオフ整理

### ブランチ・コミット・PR タイトル

| 項目 | 書式 |
|:--|:--|
| ブランチ | `autopilot/roadmap-kickoff` |
| コミットメッセージ / PR タイトル | `docs(roadmap): 未記載の Issue をロードマップに追加する` |

### PR 本文

```markdown
自走開発の対象になる Open Issue のうち、ロードマップに載っていないものを追加する。

| Issue | 追加位置 | 理由 |
|:--|:--|:--|
| #27 | #24 の直後 | 検索の改善で、#24 の設定画面と同じ画面を触る |
| #29 | 未完了行の末尾 | 依存も関連も無く、番号が最後 |
```

- `追加位置` は隣の行の Issue 番号で示す（例: `#25 の直前`・`#24 の直後`、末尾なら `未完了行の末尾`）
- `理由` は位置を決めた根拠を 1 文

## 追加

### ブランチ・コミット・PR タイトル

| 項目 | 書式 |
|:--|:--|
| ブランチ | `autopilot/roadmap-<イテレーション番号>` |
| コミットメッセージ / PR タイトル | `docs(roadmap): #<N> をロードマップに追加する`（複数なら `#<N>, #<M> を…`） |

### PR 本文

```markdown
ループ中に見つかった、システムを壊す不具合を今回の自走開発で直すため、ロードマップに追加する。

| Issue | 追加位置 | 理由 |
|:--|:--|:--|
| #31 | #25 の直前 | ログイン API が 500 を返し、#25 が完了できない |
```

- `追加位置` は隣の行の Issue 番号で示す（例: `#25 の直前`・`#24 の直後`、先頭なら `未完了行の先頭`）
- `理由` は位置を決めた根拠を 1 文。取り込む判断の経緯は書かない
- `Closes` は書かない（Issue はまだ実装されていない）

## 整合修正

### ブランチ・コミット・PR タイトル

| 項目 | 書式 |
|:--|:--|
| ブランチ | `autopilot/roadmap-sync-<イテレーション番号>` |
| コミットメッセージ / PR タイトル | `docs(roadmap): ロードマップの状態を現状に合わせる` |

### PR 本文

```markdown
自走開発の進捗とずれていたロードマップの状態を、現状に合わせる。

| Issue | 修正 | 根拠 |
|:--|:--|:--|
| #22 | `[ ]` → `[x]`、完了節へ移動 | PR #30 のマージでクローズ済み |
| #18 | 完了節へ移動 | `[x]` だが予定節に残っていた |
| #24 | `[ ]` → `[~]` | 自走開発のラインで実装中 |
| #27 | `[~]` → `[ ]` | ラインが失敗し、未着手に戻った |
| #31 | 行を追加（#25 の直前） | 取り込み済みだが、追加 PR #33 が未マージ |
```

- 1 行 1 Issue。`根拠` は Issue・PR・ラインの事実を 1 文
- 統合した古い PR があれば、表の下に `統合した PR: #<番号>` を 1 行足す

## PR の出し方

キックオフ整理・追加・整合修正で共通に使う。`BR` はブランチ名、`TITLE` は PR タイトル、
`ROOT` はリポジトリのルート、`BRANCH` はデフォルトブランチ、`PATH` はルートからのロードマップの相対パス。

```bash
RW="$(dirname ROOT)/$(basename ROOT)-autopilot-roadmap"
git -C ROOT fetch origin --quiet
git -C ROOT worktree add -B BR "$RW" origin/BRANCH
# "$RW/PATH" を編集する（Edit ツール）
git -C "$RW" add PATH
git -C "$RW" commit -m "TITLE"
git -C "$RW" push -u origin HEAD
# "$RW/.tmp/roadmap-pr.md" に PR 本文を書く（Write ツール。上の節に従う）
gh pr create --repo REPO --base BRANCH --head BR --title "TITLE" --body-file "$RW/.tmp/roadmap-pr.md"
gh pr checks <PR 番号> --repo REPO --watch   # チェックが無ければ待たずに次へ
gh pr merge <PR 番号> --repo REPO --squash --delete-branch
git -C ROOT worktree remove --force "$RW"
git -C ROOT branch -D BR
git -C ROOT pull --ff-only --quiet
```

CI 失敗・マージ不可のときは PR を開いたまま残し、worktree とローカルブランチだけ消す。
