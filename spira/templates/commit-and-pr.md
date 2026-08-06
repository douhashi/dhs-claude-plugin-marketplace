# テンプレート: コミットメッセージ・PR タイトル・PR 本文

- **書き手**: オーケストレータ（implement / do スキル）
- **共通ルール**: [_rules.md](./_rules.md)

## 書式

コミットメッセージと PR タイトルは、Issue のタイトルと同じ Conventional Commits スタイルで書く。

```
<type>(<scope>): <説明>
```

`type` の一覧と使い分けは
[skills/create-issue/templates/issue-plan.md](../skills/create-issue/templates/issue-plan.md)
の「タイトルの書式」節が単一ソース。

## 実装コミット・PR タイトル

**元 Issue のタイトルをそのまま使う。** create-issue で起票された Issue は
Conventional Commits スタイルになっているため、書き換える必要がない。

```
feat(spira): 論点テーブルに状態列を追加する
```

元 Issue のタイトルがこの書式でない場合（人手で起票された Issue など）だけ、
実装内容から組み立てる。`scope` は変更したディレクトリ・プラグインから決める。

- コミットメッセージと PR タイトルは同じ文字列にする
- Issue 番号はタイトルに含めない。紐付けは PR 本文の `Closes #N` で行う

## CI 修正コミット

```
fix(<scope>): #<元 Issue 番号> の CI 失敗を修正する (N回目)
```

- `type` は `fix` 固定
- `N` は修正ループの回数

## PR 本文

```markdown
Closes #<元 Issue 番号>

## 変更内容

（実装内容の概要を 1-3 文で）
```

- 実装内容の全文再掲は禁止。詳細は Issue の `## 実装内容` コメントと diff にある
- `Closes #N` を必ず 1 行目に置く。マージ時に Issue が自動クローズされる
