# サービス名: でももに！
※ SwiftUI リメイク版

## 開発環境

- Xcode 26.6
- iOS 26.0 以上（iPhone / iPad）
- Swift 6（Swift 6 言語モード / Strict Concurrency）
- SwiftUI / Swift Testing / XCTest（UI テスト）
- SwiftLint 0.65.1（Build Tool Plugin。バイナリだけを配布する [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) 経由）

構成は [template-app-ios](https://github.com/shilokuma-inc/template-app-ios) にそろえています。

- 署名情報・Bundle ID・バージョン・Deployment Target は [Configs/Project.xcconfig](Configs/Project.xcconfig) に集約しています（pbxproj には直接書かない）
- Debug 構成は [Configs/Debug.xcconfig](Configs/Debug.xcconfig) で、Bundle ID `jp.shilokuma.Demomoni-debug`・下部に「debug」と書いたアイコン（`AppIcon-Debug`）・ホーム画面の名前「でももに！β」にしています。デバッグモード入りの版を、App Store 版（Release 構成の `jp.shilokuma.Demomoni`）と別のアプリとして配るためです
- スキームは 2 つあります。`demomoni-remake-ios` は App Store 版（Archive は Release）、`demomoni-remake-ios-debug` はデバッグモード入りの版（Run・Archive とも Debug）です
- プロジェクトはフォルダ同期グループ（Xcode 16 以降の形式）で管理しているので、ファイルの追加・削除で pbxproj は変わりません
- SwiftLint のルールは [.swiftlint.yml](.swiftlint.yml) で管理します
- ビルド・テストのコマンドは [CLAUDE.md](CLAUDE.md) の Commands にあります

## アプリの構成

元アプリ（UIKit + Storyboard）の画面・文言・色・画像を、SwiftUI の標準のコンポーネントと Liquid Glass で作り直しています。

| タブ | 画面 |
| --- | --- |
| なぞなぞ | なぞなぞの一覧 → 詳細（問題文・「ヒントをみる」）。答えの場所のピースをゲットしたなぞなぞは、一覧に印が付き、詳細に答えが出ます |
| さがす（初期） | 歩くうさぎと道・チュートリアル。表示している間だけ近くの iBeacon を探し、まだ獲得していないピースを見つけると「ピースをゲットしたよ！！」を出して保存します |
| いちらん | 五稜郭の盤（4 × 8 = 32 マス）に獲得したピースを並べます → ピース詳細 → PencilKit でサインを描いて保存 |
| せってい | 「アプリを閉じていても、近くのピースを知らせる」のスイッチ（既定はオフ）、アプリのバージョンと、ニコモジ+ のライセンス（SIL Open Font License 1.1）の本文。Debug ビルドだけ、ピースを埋める・外す・全部埋める・全部リセットし、ピースを選んで擬似検知（「ゲットした」画面まで）できるデバッグモードがあります |

- 同梱データ（ビーコン・ピース・なぞなぞ）は `demomoni-remake-ios/Resources/Data/` の JSON です
- 獲得状態・日時・サインは SwiftData で端末の中に保存します。位置情報は端末の中だけで使い、外へ送りません
- iBeacon の検知は CoreLocation で、Simulator では動きません（下の「iBeacon の検知と、近くのピースの通知」）。実機での確認は Issue にまとめています

### iBeacon の検知と、近くのピースの通知

#### さがすタブでの検知（全員）

- さがすタブを表示している間だけ、`CLLocationManager` の ranging（`CLBeaconIdentityConstraint`）で同梱のビーコンを探します。ほかのタブに移ると探しません
- 位置情報の「使用中の許可」は、さがすタブを最初に表示したときに `CLServiceSession(authorization: .whenInUse)` で尋ねます。「正確な位置情報」がオフだと ranging できないので、オンにするよう案内します
- 同梱データのビーコン（UUID・major・minor が一致するもの）を 1 回受信したら、まだ獲得していないピースを保存して「ピースをゲットしたよ！！」を出します（距離や連続した検知は見ません）
- CoreLocation のデリゲートの出来事は `AsyncStream` で `BeaconDetector` に流し、MainActor で扱います（`Detection/`）

#### アプリを閉じていても近くのピースを知らせる（オンにした人だけ）

せっていタブの「おしらせ」のスイッチをオンにした人だけ、アプリを閉じていても（スワイプで終了していても）、まだ獲得していないピースのビーコンの近くに来たら「近くにピースがあるよ！」の通知を出します（`NearbyAlert/`）。

- 既定はオフです。オフの人は今までどおり、使用中の許可だけを使い、さがすタブを表示している間だけ探します。通知の許可も尋ねません
- スイッチをオンにしたときだけ、通知の許可と位置情報の「常に許可」を尋ねます。足りない許可（通知・「常に」・正確な位置情報）があれば、スイッチの下に案内と「設定をひらく」を出します。設定アプリから戻ると読み直します
- 見張るのは `CLMonitor` です。許可がそろっている間だけ `CLServiceSession(authorization: .always)` を持ち、まだ獲得していないピースのビーコンを条件にします（`CLMonitor` の条件は 20 個までなので、未獲得が 20 台を超える間は UUID ごとにまとめ、どのビーコンかは出来事の `refinement` で読みます）。オフにすると条件をすべて外します
- 通知を出すのは、まだ獲得していないピースのビーコンの範囲に入り、アプリが前面にないときだけです。同じピースの通知は重ねません（置き換えます）
- 通知は端末の中で出すローカル通知です（Push 通知は使いません）。通知では獲得しません。通知を開くとさがすタブが出るので、そこで獲得します
- `UIBackgroundModes` は使いません。「常に許可」があれば、アプリが終了していても `CLMonitor` の出来事でアプリがバックグラウンドで起こされます

#### 実機での確かめ方

Simulator では ranging・`CLMonitor`・「常に許可」・バックグラウンドでの起動を確かめられないので、判定は Unit テストで確かめ、実機での確認は Issue（`needs-verify` のラベル）にまとめています。

1. 同梱データ（`demomoni-remake-ios/Resources/Data/beacons.json`）の UUID・major・minor のビーコンを用意する（実機の iBeacon か、別の端末のビーコンを出すアプリ）
2. スイッチがオフのまま: さがすタブを開くと使用中の許可を尋ね、ビーコンに近づくとピースをゲットできること。通知の許可を尋ねないこと
3. せっていタブでスイッチをオンにし、通知と「常に許可」を許可する。アプリを終了してから、まだ獲得していないピースのビーコンに近づくと通知が出ること。通知を開くとさがすタブが出て、ゲットできること
4. 獲得済みのピースのビーコン・アプリを前面で使っているとき・スイッチをオフに戻した後は、通知が出ないこと

#### App Store の審査メモ（「常に許可」）

「常に許可」を使うアプリは、審査で理由を聞かれやすいです。App Store Connect の審査メモ（App Review Information の Notes）に、Info.plist の利用目的（`NSLocationAlwaysAndWhenInUseUsageDescription`）と同じ趣旨で、たとえば次のように書きます（審査メモの入力は担当者が行います）。

```text
このアプリは、街に設置した iBeacon の近くでパズルのピースを集めるスタンプラリーです。
位置情報の「常に許可」は、設定画面の「アプリを閉じていても、近くのピースを知らせる」を利用者がオンにしたときだけ求めます（既定はオフ）。
オンにすると、アプリを閉じていても、まだ集めていないピースのビーコンの近くに来たことをローカル通知で知らせます。
位置情報は端末の中だけで使い、外部へ送信・保存しません。オフのときは、アプリの使用中（さがす画面を表示している間）だけ位置情報を使います。
```

### UI テスト・スクリーンショット用の起動引数

| 引数 | 動き |
| --- | --- |
| `-uiTesting` | メモリ上の空のストアで起動し、実際の位置情報を使いません |
| `-fakeBeaconID <id>` | 探し始めて 2 秒後に、その beaconId のビーコンを見つけたことにします（擬似検知） |
| `-collectedPieceIDs <id>,<id>` | `-uiTesting` と一緒に使い、そのピースを獲得済みにして起動します |

### フォント・画像のライセンス

- 文字はニコモジ+（`nicomoji-plus_1.11.ttf`）です。SIL Open Font License 1.1 で、本文と著作権表示を [NicoMojiPlus-OFL.txt](demomoni-remake-ios/Resources/Fonts/NicoMojiPlus-OFL.txt) に置いています
- 元アプリの見出しなどに使っていたうずらフォント（`uzura.ttf`）は、作者の規約で再配布が禁止されているため入れていません（このリポジトリは public です）
- 人物の写った画像（元アプリの `piece14_family`・`notsign_piece`）は入れていません。サインの画面の背景はピースの画像にしています

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
- 確かめるのは iOS の Simulator だけです

### Archive / Upload（App Store Connect への配信）

template-app-ios と同じ構成で、App Store Connect の API Key で認証します（Apple ID は使いません）。

- Upload は Archive → IPA Export → App Store Connect へのアップロードまで行います。`develop` / `release/**` への push（PR のマージ）のたびに、TestFlight にビルドが上がります
- Upload は 2 つのアプリを別の job で上げます。片方が失敗しても、もう片方は止まりません
  - `upload`: App Store 版（スキーム `demomoni-remake-ios` を Release 構成で Archive した `jp.shilokuma.Demomoni`）
  - `upload-debug`: デバッグモード入りの版（スキーム `demomoni-remake-ios-debug` を Debug 構成で Archive した `jp.shilokuma.Demomoni-debug`。アイコンの下部に「debug」、ホーム画面の名前は「でももに！β」）
- デバッグモード入りの版を配るには、担当者が App Store Connect に `jp.shilokuma.Demomoni-debug` のアプリを作ります（名前の候補は「でももに！β」。App Store 全体で使用済みなら別の名前にします）。アプリが無いうちは `upload-debug` がアップロードの前に止まり、入力する値を Job Summary に出します。作った後は再実行します
- ビルド番号は、アップロードのときに App Store Connect の最新ビルドを見て Xcode が自動で増やします。`CURRENT_PROJECT_VERSION` は手で上げません。バージョン（`MARKETING_VERSION`）はリリースのときに [Configs/Project.xcconfig](Configs/Project.xcconfig) で上げます
- Archive / Upload は Actions タブから手動でも実行できます（Run workflow）。作業ブランチを TestFlight で確かめたいときは、Upload を手動で実行してそのブランチを選びます
- 実行中の Upload は、次の push が来ても取り消しません（途中で止めると App Store Connect に中途半端なビルドが残るため）
- App Store Connect にアプリが無いと、Upload はアップロードの前に止まり、「新規アプリ」画面に入力する値（バンドル ID・SKU など）を Job Summary に出します。アプリを作ってから再実行します
- 輸出コンプライアンスは [Configs/Project.xcconfig](Configs/Project.xcconfig) の `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` で申告しています（Info.plist の `ITSAppUsesNonExemptEncryption`）。アップロードしたビルドは暗号化の質問なしで TestFlight に配信できます。
  独自の暗号や標準外のアルゴリズムを入れるときは見直します（`YES` だと App Store Connect で書類が要ることがあり、自動では配信されません）
- 申告は、それを入れた後にビルドしたものにしか効きません。前に上がったビルド（「輸出コンプライアンスの情報がありません（Missing Compliance）」のもの）は使いません。使うなら App Store Connect の TestFlight で手で回答します

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
| `ENABLE_DEBUG_DELIVERY` | `false` にすると、Upload のうちデバッグモード入りの版（`upload-debug`）だけをスキップします。未設定なら実行します |

TestFlight の配信先を用意するには、担当者が変数 `TESTFLIGHT_INTERNAL_TESTERS` を、BeaconFun4 の Organization かこのリポジトリの Settings → Secrets and variables → Actions → **Variables** に登録します。
テスターは App Store Connect のユーザーである必要があります。メールアドレスはリポジトリ・Issue・PR に書きません（このリポジトリは public です）。

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
