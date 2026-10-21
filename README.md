# サービス名: でももに！
※ SwiftUI リメイク版

## 開発環境

- Xcode 26.6
- iOS 17.4 以上（iPhone / iPad）・macOS 14.3 以上
- Swift 6（Swift 6 言語モード / Strict Concurrency）
- SwiftUI / Swift Testing / XCTest（UI テスト）
- SwiftLint 0.65.1（Build Tool Plugin。バイナリだけを配布する [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) 経由）

構成は [template-app-ios](https://github.com/shilokuma-inc/template-app-ios) にそろえています。

- 署名情報・Bundle ID・バージョン・Deployment Target は [Configs/Project.xcconfig](Configs/Project.xcconfig) に集約しています（pbxproj には直接書かない）
- プロジェクトはフォルダ同期グループ（Xcode 16 以降の形式）で管理しているので、ファイルの追加・削除で pbxproj は変わりません
- SwiftLint のルールは [.swiftlint.yml](.swiftlint.yml) で管理します
- ビルド・テストのコマンドは [CLAUDE.md](CLAUDE.md) の Commands にあります

## CI

GitHub Actions で、Build（[.github/workflows/build.yml](.github/workflows/build.yml)）が SwiftLint（`--strict`）・ビルド・テストを、
Archive / Upload（[.github/workflows/archive.yml](.github/workflows/archive.yml)・[.github/workflows/upload.yml](.github/workflows/upload.yml)）が App Store Connect への配信を実行します。

| きっかけ | Build（ビルド + テスト + SwiftLint） | Archive（IPA Export） | Upload（App Store Connect） |
|---|:-:|:-:|:-:|
| `main` への push | ✅（UI テストも） | ✅ | |
| `develop` / `release/**` への push | ✅（UI テストも） | | ✅ |
| その他の作業ブランチへの push | ✅（Unit テストのみ） | | |
| Pull Request の作成時（opened / reopened / ready_for_review） | ✅（UI テストも） | | |
| `epic/**` 宛ての Pull Request（ralph-loop の子 PR） | （push の Unit テストで確かめる） | | |
| `epic/**` から `develop` などへの Pull Request（ralph-loop の最終 PR） | ✅（更新のたびに UI テストも） | | |
| Fork からの Pull Request | ✅（UI テストも） | | |

- ドキュメントだけの変更（`**/*.md`、`docs/**`）では Build を実行しません（Archive / Upload は実行します）
- Xcode のバージョンは [.github/workflows/_build.yml](.github/workflows/_build.yml) と [.github/workflows/_archive.yml](.github/workflows/_archive.yml) の `xcode-version` で固定しています。開発環境を更新するときは合わせて変えます
- 確かめるのは iOS の Simulator だけです。macOS のビルドは手元で確かめます

### Archive / Upload（App Store Connect への配信）

template-app-ios と同じ構成で、App Store Connect の API Key で認証します（Apple ID は使いません）。

- Upload は Archive → IPA Export → App Store Connect へのアップロードまで行います。`develop` / `release/**` への push（PR のマージ）のたびに、TestFlight にビルドが上がります
- ビルド番号は、アップロードのときに App Store Connect の最新ビルドを見て Xcode が自動で増やします。`CURRENT_PROJECT_VERSION` は手で上げません。バージョン（`MARKETING_VERSION`）はリリースのときに [Configs/Project.xcconfig](Configs/Project.xcconfig) で上げます
- Archive / Upload は Actions タブから手動でも実行できます（Run workflow）。作業ブランチを TestFlight で確かめたいときは、Upload を手動で実行してそのブランチを選びます
- 実行中の Upload は、次の push が来ても取り消しません（途中で止めると App Store Connect に中途半端なビルドが残るため）
- App Store Connect にアプリが無いと、Upload はアップロードの前に止まり、「新規アプリ」画面に入力する値（バンドル ID・SKU など）を Job Summary に出します。アプリを作ってから再実行します

Secrets は BeaconFun4 の Organization に登録してあります（Settings → Secrets and variables → Actions）。

| Secret | 内容 |
|---|---|
| `EXPORT_OPTIONS` | `ExportOptions.plist` の内容（[docs/ExportOptions.sample.plist](docs/ExportOptions.sample.plist) の `teamID` を書き換えたもの） |
| `APPLE_API_KEY_BASE64` | App Store Connect の API Key（`.p8`）を base64 にした文字列。API Key は App Manager 以上の権限で発行します |
| `APPLE_API_KEY_ID` | API Key の Key ID |
| `APPLE_API_ISSUER_ID` | API Key の Issuer ID |

| 変数 | 内容 |
|---|---|
| `TESTFLIGHT_INTERNAL_TESTERS` | TestFlight の内部テスターにするメールアドレス（カンマ区切り）。Upload が内部テストグループ「Internal Testers」を作って追加し、以降のビルドは処理が終わりしだい配信されます。空なら何もしません |
| `ENABLE_DELIVERY` | `false` にすると Upload をスキップします。未設定なら実行します |

App Store の掲載情報（スクリーンショット・説明文・ヘッダー）のワークフローはまだありません（#64）。

### 卍Github運用について✒卍

##### 卍リポジトリ卍
- 各プラットフォームごとにリポジトリを作る
- リポジトリごとにカンバンを作る

##### 卍Issue卍
- Issueとは
    - 追加する機能を書く(余裕があれば完成予想図なモックがあると嬉しい)
    - スプリントバックログからIssueを書き写す
    - 他、機能の修正提案、挙動が変なんじゃないか、などを話し合うところ
- タイトル命名規則 ([FIX]とか)
    - タイトルを見て要件が分かるようにする
    - そのIssueが何についてのIssueなのか記載する
    - Issueの要件定義
        - (ハロワの場合)
        - テキストラベルをおく
        - テキストラベルの中身を定義する
    - ラベル
        - 緊急
        - なるはや
        - いつでも

##### 卍カンバン卍
[参考資料](https://tmytokai.github.io/open-ed/activity/wbs/)
- スプリントバックログに対応するカンバンを作る
- ToDo、Doing、Review、Done の4カラムで運用する
- 誰がやっているのかはわかるようにしておく (Issueと対応させて、Assigneeを設定する)

##### 卍ブランチ卍
#### git flowとgithub flowについて
[Git flowとGithub flowについて](https://qiita.com/mint__/items/bfc58589b5b1e0a1856a)
- git flowで決定
    - 開発ブランチはdevelopにする (defaultブランチにする)
    - develop, main, fix, feature
    - develop: 開発用
    - main: スプリントごとのリリース用
    - fix: バグ修正
    - feature: 機能追加

<font color='red'>**日本語ブランチは許されません！**</font>

- 基本はキャメルケース、多少ブレても良い 以下例
    - feature/*** (機能追加ブランチ)
    - fix/*** (修正ブランチ)

- スプリントごとにマスターにプッシュにするのも良き


##### 卍プルリク卍
- 命名規則
    - prefix
        - 【FEAT】
        - 【FIX】
    - タイトルで伝わるように
    - 日本語でもおｋ

- メッセージ
    - どんな変更なのか簡単に説明が書いてあると良い
    - どんなところをレビューして欲しいかもあるとレビューしやすい

- 粒度
    - 莫大な変更を含むプルリクを出さない。
    - なるべく細かくやる。
    - 余計なことしない。（ついでに他のとこ直すとかしない）
    - 目安は1ファイル分の変更くらいだと見やすい (読み手の存在を意識しながら)

- ラベルの付け方
    - カンバンと一緒

#### 卍レビューの方法卍
- 流し見しがち
    - わかんなくても、ちゃんと見てコメントしてほしい。
    - 積極的に参加してほしい。
    - 自分以外二人のレビューでマージ可能
    - 良識の範囲内でレビューを催促したほうが進みが良い。

#### 卍コミットについて卍
- 粒度
    - プルリクよりも小さい単位。
    - こまめにコミットするよう心がける。

- コミットメッセージ
    - 変更内容がわかるように書く。
    - 日本語でおｋ！！
