# アーキテクチャセット: モバイル

同梱の内容は叩き台であり、最新かどうかは architect スキルの実行時に調査で確かめる。

## 対象と対象外

- 対象: Android / iOS で動くモバイルアプリ
- 対象外: ブラウザで使う Web アプリケーション（`web.md`）、ストア配布（署名・審査・TestFlight）
- 責務: Android は APK を GitHub Release に置くまで、iOS は CI でビルドが通るまで

## 最終検証日

2026-09-20

## 構成パターン

| パターン | 使う場面 |
|:--|:--|
| Flutter 単体 | 既定 |
| Flutter + API のクライアント | 同じ案件の API セットを呼ぶ |
| Flutter でモバイルとデスクトップ | 同じ案件にデスクトップアプリがある |

## 選定の観点

| 要件 | 優先するもの |
|:--|:--|
| 特別な要件が無いなら | Flutter |
| 同じ案件にデスクトップアプリがあるなら | デスクトップも Flutter に寄せ、コードを共有する |
| オフライン動作が必要なら | データを端末に持ち、同期は API セットで扱う |
| オフライン動作が不要なら | データは API セットに持たせ、アプリはクライアントにする |
| 想定規模が小さく利用者が限られるなら | Android の APK 配布だけで始める |
| AI エージェントに実装させるなら | 1 つのコードで Android と iOS を作れる Flutter を優先する |

## 推奨スタック例

| 役割 | 推奨 | 理由 |
|:--|:--|:--|
| アプリの枠組み | Flutter | 1 つのコードで Android と iOS を作れる |
| 言語 | Dart | Flutter の言語 |
| Android の配布 | APK を GitHub Release に置く | ストアを通さずに配布できる |
| iOS の確認 | 署名なしのビルドを CI で通す | ストア配布をせずにビルドが壊れていないことを確かめられる |
| CI | GitHub Actions | Android と iOS のビルドを行える |

## 代替の検索語

- Flutter build apk
- Flutter build ios no codesign
- Flutter GitHub Actions
- React Native vs Flutter
- Tauri mobile support
