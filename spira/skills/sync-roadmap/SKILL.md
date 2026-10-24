---
name: sync-roadmap
description: "ロードマップを Issue の現状に合わせる。チェック状態・完了行の置き場所のずれを直し、ロードマップに未記載の Open Issue を載せるかどうか・どこに載せるかをユーザーと決めて、それぞれ PR→マージする。sync-roadmap, ロードマップ更新, ロードマップ整理, ロードマップの整合, 着手順"
argument-hint: ""
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

現在のリポジトリのロードマップを、Issue の現状に合わせてください。

## Philosophy

- **ロードマップは着手順の単一ソース**: `spira:pick` はロードマップの並びで Issue を選ぶ。現状とずれたロードマップや、載っていない Issue では着手順が定まらない
- **まとめて整える**: 起票のたびに追記せず、このスキルでまとめて現状に合わせる
- **機械的なずれは直し、並びは人が決める**: Issue の状態だけで決まるずれは規則どおりに直す。何を載せ、どこに置くかはユーザーが決める
- **借りた言葉で話す**: 用語はコードベースとドキュメントに実在する語を使う

## Role

あなたは**ロードマップを Issue の現状に合わせる進行管理担当**です。

## 禁則事項

- ユーザーが載せると決めていない Issue をロードマップに追加することは禁止
- 未記載 Issue を載せる PR を、一覧を出す前、またはユーザーの返答を待たずに作成・マージすることは禁止
- `roadmap-pr.md` の「整合の規則」に無いチェック状態の変更・行の移動は禁止
- 未完了行どうしの並べ替え・既存行の文言の書き換えは禁止
- Issue 側（本文・ラベル・状態）の変更は禁止
- CI が失敗しているロードマップ PR のマージは禁止
- ロードマップ以外のファイルの作成・書き換えは禁止（`.tmp/` 配下の PR 本文を除く）

## 入力の解析

引数は取らない。以下の変数を確定させる。

```
ROOT=$(git rev-parse --show-toplevel)
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
```

## 共通オペレーション

### テンプレートの参照

出力の書式はテンプレートファイルで定義されている。**書く前に必ず Read すること。**

| 出力 | テンプレート |
|:--|:--|
| ロードマップの行・整合の規則・追加位置の決め方・PR | `${CLAUDE_PLUGIN_ROOT}/templates/roadmap-pr.md` |
| 未記載 Issue の一覧 | [templates/roadmap-triage.md](templates/roadmap-triage.md) |
| コミット・PR の共通書式 | `${CLAUDE_PLUGIN_ROOT}/templates/commit-and-pr.md` |

## 手順

### Phase 1: 現状の確認

1. `find ROOT/docs -name roadmap.md -type f 2>/dev/null | head -1` でロードマップを探す。
   無ければ「ロードマップが無いため、着手順は Issue 番号の若い順になる」と伝えて終了する
2. ロードマップを Read し、未完了行（`[ ]` / `[~]`）の並び・`[dep #N]` の書き方・節の構成・完了節の有無を把握する
3. `${CLAUDE_PLUGIN_ROOT}/templates/roadmap-pr.md` を Read する
4. Issue を取得する

   ```
   gh issue list --repo REPO --state all --limit 1000 --json number,title,state,stateReason,labels
   ```

### Phase 2: 整合

1. `→ #<番号>` を持つ各行を、Issue の `state` / `stateReason` と突き合わせ、`roadmap-pr.md` の「整合の規則」に照らしてずれを洗い出す
2. ずれが 0 件なら PR は作らず、Phase 3 へ進む
3. ずれがあれば、同ファイルの「整合修正」節（sync-roadmap のブランチ）と「PR の出し方」に従い、すべてのずれを 1 本の PR にまとめてマージする。
   ずれは Issue の状態だけで決まるため、承認を求めずに直す
   - CI 失敗・マージ不可のときは、PR を開いたまま残し、失敗したチェック名を Phase 4 の報告に書いて先に進む
4. 以降の手順は、ロードマップを Read し直し、整合後のロードマップを基にする

### Phase 3: 未記載 Issue の整理

1. **洗い出す**: Open Issue（`escalated` ラベル付きを除く）のうち、ロードマップに `→ #<番号>` の行が無いもの。0 件なら Phase 4 へ進む
2. **位置の案を作る**: 各 Issue の本文を `gh issue view <番号> --repo REPO` で読み、`roadmap-pr.md` の「追加位置の決め方」に従って案を作る。
   関係しそうな未完了行の Issue も、行の文言だけで判断できなければ本文を読んで確かめる
3. **一覧を出して一緒に決める**: [templates/roadmap-triage.md](templates/roadmap-triage.md) を Read し、未記載の Issue を一覧で提示する。
   どれを載せるか・どこに載せるかは**ユーザーが決める**。応答ごとの行動は同テンプレートの「進め方」に従う
4. **PR を作ってマージする**: `載せる` と決まった Issue を、`roadmap-pr.md` の「整理」節と「PR の出し方」に従って 1 本の PR にまとめる
   - `載せる` が 0 件なら PR は作らない
   - CI 失敗・マージ不可のときは、PR を開いたまま残し、失敗したチェック名を Phase 4 の報告に書く

### Phase 4: 報告

整合と整理の結果を 1 行ずつ提示する。`載せない` と決まった Issue があれば、その番号と理由を続ける。

```
整合: マージ済み（2 件） — https://github.com/owner/repo/pull/35
整理: マージ済み（2 件追加） — https://github.com/owner/repo/pull/36
載せない: #30（議論が要る）、#12（着手の単位でない）
```

各行は `マージ済み（<件数>） — <PR URL>` / `未マージ（<理由>） — <PR URL>` / `変更なし` のいずれかとする。
