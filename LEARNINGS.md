# LEARNINGS — demomoni-remake-ios 固有の知見

このリポジトリだけで通じる知見を書く。全リポジトリ共通の知見は `~/.agents/LEARNINGS.md` に書く。

## UI テスト

- iPad（iOS 26）では `TabView` のタブが画面の上に出て、`app.tabBars` に入らない。タブは `XCUIApplication.tabButton(_:)`（ラベルでも探す）で押す（2026-10-21）
- `PKCanvasView` は `UIScrollView` なので `otherElements` に入らない。`accessibilityElement(children: .ignore)` でまとめた画像も `images` に入らない。どちらも `app.descendants(matching: .any)["ラベル"]` で探す（2026-10-21）
- 起動の直後にボタンを押すと、Mac が混んでいるときに「No matches found」で落ちる。`waitForExistence` で出るまで待ってから押す（2026-10-21）
- 擬似検知（`-fakeBeaconID`）は 2 秒後に見つけるが、Mac が混んでいると表示まで遅れる。UI テストでは 30 秒まで待つ（2026-10-21）

## PencilKit

- `PKCanvasView` は既定でウインドウの `UndoManager` に取り消しを記録するので、画面を閉じても記録が残る。`undoManager` を override して専用のものを返す（`SignatureCanvasView`）（2026-10-21）
- iBeacon の ranging は「正確な位置情報」がオフ（`accuracyAuthorization == .reducedAccuracy`）だとできない。許可の状態として区別する（2026-10-21）

## SwiftData

- `@Attribute(.unique)` は同じ値の insert を upsert として扱い、既存の記録を上書きする。最初の日時を残したいときは、先に探してから insert する（2026-10-20）
