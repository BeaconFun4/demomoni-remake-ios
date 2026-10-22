# LEARNINGS — demomoni-remake-ios 固有の知見

このリポジトリだけで通じる知見を書く。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## UI テスト

- iPad（iOS 26）では `TabView` のタブが画面の上に出て、`app.tabBars` に入らない。タブは `XCUIApplication.tabButton(_:)`（ラベルでも探す）で押す（2026-10-21）
- `PKCanvasView` は `UIScrollView` なので `otherElements` に入らない。`accessibilityElement(children: .ignore)` でまとめた画像も `images` に入らない。どちらも `app.descendants(matching: .any)["ラベル"]` で探す（2026-10-21）
- 起動の直後にボタンを押すと、Mac が混んでいるときに「No matches found」で落ちる。`waitForExistence` で出るまで待ってから押す（2026-10-21）
- 擬似検知（`-fakeBeaconID`）は 2 秒後に見つけるが、Mac が混んでいると表示まで遅れる。UI テストでは 30 秒まで待つ（2026-10-21）
- `-only-testing` で一部の UI テストだけを流す前に、Simulator を `simctl shutdown` → `boot` する。直前のフル検証の `LaunchTests` が横向きのまま残すと、せっていタブの「デバッグモード」の行が画面の外に出て `DebugModeUITests` が落ちる（2026-10-22）
- せっていタブの `List` の行の `Toggle` は、行ではなく中のスイッチ（`app.switches["ラベル"].switches.firstMatch`）を押す（2026-10-22）

## SwiftUI

- せっていタブで行の下に案内を出すと、スイッチの行のカードの下の角が四角くなって切れて見える。案内は Section の footer に置く（2026-10-22）

## PencilKit

- `PKCanvasView` は既定でウインドウの `UndoManager` に取り消しを記録するので、画面を閉じても記録が残る。`undoManager` を override して専用のものを返す（`SignatureCanvasView`）（2026-10-21）
- iBeacon の ranging は「正確な位置情報」がオフ（`accuracyAuthorization == .reducedAccuracy`）だとできない。許可の状態として区別する（2026-10-21）

## SwiftData

- `@Attribute(.unique)` は同じ値の insert を upsert として扱い、既存の記録を上書きする。最初の日時を残したいときは、先に探してから insert する（2026-10-20）

## iBeacon / CoreLocation

- 同梱のビーコンは 32 台あり、`CLMonitor` の条件の上限（20）を超える。未獲得が 20 台を超える間は UUID ごとの条件にまとめ、どのビーコンかは出来事の `refinement` で読む（`NearbyPieceMonitoring.conditions`）（2026-10-22）
- `CLMonitor` の条件はアプリを終えても残る。identifier にビーコンの UUID・major・minor を入れないと、`beacons.json` の値を変えたときに古い条件が残り、黙って検知しなくなる（2026-10-22）
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
