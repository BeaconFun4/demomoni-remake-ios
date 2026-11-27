# LEARNINGS — demomoni-remake-ios 固有の知見

このリポジトリだけで通じる知見を書く。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## UI テスト

- iPad（iOS 26）では `TabView` のタブが画面の上に出て、`app.tabBars` に入らない。タブは `XCUIApplication.tabButton(_:)`（ラベルでも探す）で押す（2026-10-21）
- `PKCanvasView` は `UIScrollView` なので `otherElements` に入らない。`accessibilityElement(children: .ignore)` でまとめた画像も `images` に入らない。どちらも `app.descendants(matching: .any)["ラベル"]` で探す（2026-10-21）
- 起動の直後にボタンを押すと、Mac が混んでいるときに「No matches found」で落ちる。`waitForExistence` で出るまで待ってから押す（2026-10-21）
- 擬似検知（`-fakePieceID`）は 2 秒後に見つけるが、Mac が混んでいると表示まで遅れる。UI テストでは 30 秒まで待つ（2026-10-21）
- `-fakePieceID` はそのピースの場所にいることにするので、範囲が重なるピース（五稜郭公園の中の箱館奉行所、71 m 離れた元町公園と旧函館区公会堂）だと、ゲット画面を閉じて調べ直したときに隣のピースもゲットする。「閉じた後はもう出ない」を確かめる UI テストでは、ほかと重ならない函館山（1）を使う（2026-11-26）
- `-only-testing` で一部の UI テストだけを流す前に、Simulator を `simctl shutdown` → `boot` する。直前のフル検証の `LaunchTests` が横向きのまま残すと、せっていタブの「デバッグモード」の行が画面の外に出て `DebugModeUITests` が落ちる（2026-10-22）
- せっていタブの `List` の行の `Toggle` は、行ではなく中のスイッチ（`app.switches["ラベル"].switches.firstMatch`）を押す（2026-10-22）

## Unit テスト

- 既定の分離が MainActor なので、Swift Testing の `@Test(arguments:)` に渡す型の static プロパティは `nonisolated static let` にする（付けないと、マクロの展開の中から読めずに「main actor-isolated static property cannot be accessed」でテストのビルドが落ちる）（2026-11-02）

## SwiftUI

- せっていタブで行の下に案内を出すと、スイッチの行のカードの下の角が四角くなって切れて見える。案内は Section の footer に置く（2026-10-22）

## PencilKit

- `PKCanvasView` は既定でウインドウの `UndoManager` に取り消しを記録するので、画面を閉じても記録が残る。`undoManager` を override して専用のものを返す（`SignatureCanvasView`）（2026-10-21）

## SwiftData

- `@Attribute(.unique)` は同じ値の insert を upsert として扱い、既存の記録を上書きする。最初の日時を残したいときは、先に探してから insert する（2026-10-20）

## CoreLocation

- 「正確な位置情報」がオフ（`accuracyAuthorization == .reducedAccuracy`）だと、位置が数 km ずれてピースの場所の範囲（80 m〜）を判定できず、`CLMonitor` の地域の条件も使えない。許可の状態として区別する（2026-10-21、2026-11-26 に位置情報の範囲での獲得に合わせて直した）
- `startUpdatingLocation()` の直後は、前に測った古い位置（キャッシュ）が最初に届くことがある。範囲の判定では `timestamp` が 30 秒より古い位置と、`horizontalAccuracy` が負・150 m（半径が 150 m より大きい場所はその半径）より大きい位置を捨てる（`PieceArea`）。`distanceFilter` を付けると、古い位置を捨てた後に止まっていると次の位置が届かないので付けない（2026-11-26）
- 同梱のピースは 32 か所あり、`CLMonitor` の条件の上限（20）を超える。円の条件（`CircularGeographicCondition`）にはビーコンの UUID のようにまとめて `refinement` で見分ける仕組みが無いので、未獲得が 20 か所を超える間は、最後に分かった場所から範囲の縁が近い 19 か所と、そこを中心にした「選び直す円」を見張り、そこから出たら選び直す（`NearbyPieceMonitoring.conditions`）（2026-11-26。前はビーコンを UUID ごとにまとめていた）
- `CLMonitor` の条件はアプリを終えても残る。条件をそろえるとき（`setConditions`）は identifier だけで比べるので、identifier に条件の値（円なら中心の緯度・経度と半径）を入れないと、`pieces.json` の場所や半径を変えたときに古い条件が残り、黙って検知しなくなる（2026-10-22、2026-11-26 に円の条件に合わせて直した）
- `pieces.json` の緯度・経度は、最初に名所を足したときのおおよその値で、32 か所のうち多くが数百 m、トラピスト修道院は 12 km・東大沼キャンプ場は 2.6 km ずれていた（元町公園は元アプリから五稜郭タワーの位置のまま）。場所を足す・直すときは、OpenStreetMap（Nominatim・Overpass）・Wikidata（P625）・国土地理院の住所検索（`msearch.gsi.go.jp/address-search/AddressSearch`）の 2 つ以上で確かめ、Overpass で場所の広さ（`out center bb`）も見て半径を決める。Overpass は混むと 502・504 を返すので、問い合わせを 1 回にまとめ、間を空けてやり直す（2026-11-26）
- `CLMonitor` は actor なので、`events` も外からは `await` で読む（`let` でも）（2026-10-22）
- TestFlight の 1.0 (4)（iOS 27.0）で、起動から約 0.2 秒で `CLMonitor.init(_:)` の中の assertion（`+[CLMonitor _requestMonitorWithConfiguration:locationManager:completion:]`）で落ちた。Exception Reason が無く原因は確定していない（#120）。次の 3 つで防いでいる（2026-10-22）
  - 起動直後に片付けのためだけに `CLMonitor` を開かない（条件を外すのはオフにした直後だけ。「条件が残っているかもしれない」を `UserDefaults` に記録する）
  - 同じ名前の `CLMonitor` を同じプロセスで 2 つ開かない（2 つ目で assert するという報告がある）。`await CLMonitor(...)` の前後で確かめるだけでは、待っている間の呼び出しが 2 つ目を開くので、開く `Task` を持って同じものを待たせる（`OpenOnce`）
  - 位置情報の許可を確かめてから開く（未決定・拒否・制限では開かない）
- `CLMonitor`・`CLServiceSession` は UI テスト・Unit テストのホストで `Inactive…` に差し替えているので、CI・Simulator では上のクラッシュを再現も確認もできない。判定は差し替えで Unit テストし、直ったかは TestFlight のクラッシュレポートで見る（2026-10-22）

## アイコン・画像のスクリプト

- 今のアイコンの PNG（`demomoni-AppIcon.png`）は色のプロファイルを持たない。`NSBitmapImageRep.colorAt(x:y:)` を `usingColorSpace(.sRGB)` で読むと色が変換されて値がずれる（背景の水色 `#ACE2F2` が `#B8E7F4` に読める）。画素の値を測るときは、`CGImageSource` で読んだ `CGImage` を `copy(colorSpace: sRGB)` して sRGB の `CGContext` に描き、バイトを直接読む（`scripts/make-app-icon-layers.swift`）（2026-10-22）
- `AppIcon.icon` を `demomoni-remake-ios/` の下に置くと、`APP_ICON_NAME = AppIcon` のまま actool が拾い、Release 構成のビルドで `AppIcon60x60@2x.png`・`AppIcon76x76@2x~ipad.png` を書き出す（pbxproj・xcconfig は変えていない）。同じ名前の `AppIcon.appiconset` は消した（2026-10-22）
- `ictool <.icon> --export-image …` は書き出すたびに標準出力へ `{` と `}` の 2 行を出す。エラーではない（終了コードで見る）（2026-10-22）
- `icon.json` の背景の塗りは `"fill" : { "solid" : "srgb:<r>,<g>,<b>,1.00000" }`（0〜1 の小数 5 桁）。`scripts/make-app-icon-layers.swift` が元の絵の水色をこの形で表示する（2026-10-22）
- タブの画像（`.tabItem` の `Image`）は、画像の大きさ（pt）で出る。30 pt 四方の PDF（図を四方いっぱいに描く）で、iPhone の下のタブバーの SF Symbols とほぼ同じ大きさになった。iPad（iOS 26・縦向き）の上のタブバーはラベルだけを出し、アイコンを出さない（`scripts/make-tab-icons.swift`）（2026-11-26）
- `CGContext` で書いた PDF には作成日時・更新日時（`D:` の 14 桁）と `/ID` が入り、同じ図でも書き出すたびに中身が変わる。相互参照表の位置がずれないよう、同じ長さの固定の値に置き換えると、図を変えない限り差分が出ない（`scripts/make-tab-icons.swift`）（2026-11-26）

## ピースの裏側の写真

- `CollectedPiece` に任意の値（`photo`・`photoDrawing`）を足すだけなら、`VersionedSchema` を書かなくても SwiftData の軽量の移行で前の版のストアを開ける。確かめるテストは、テストのターゲットに前の版の `@Model final class CollectedPiece` を `enum` の中に入れて書く（エンティティの名前は入れ子でもクラスの名前だけになるので、同じストアの記録として読める。`CollectedPieceMigrationTests`）（2026-11-26）
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` なので、`nonisolated async` の関数は呼んだ側の actor（View なら MainActor）で動く。写真を縮めるなどの重い処理を MainActor の外で行うには `@concurrent` を付ける（2026-11-26）
- iOS 26 の Simulator では `UIImagePickerController.isSourceTypeAvailable(.camera)` が `true` になり、「しゃしんをとる」が出る。UI テストで「カメラの無い端末」を前提にしない（2026-11-26）
