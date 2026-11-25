//
//  PieceDetectorTests.swift
//  demomoni-remake-iosTests
//

import CoreLocation
@testable import demomoni_remake_ios
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PieceDetectorTests {
    private let catalog = Catalog.bundled

    /// 精度のよい、今測った位置
    private func fix(at coordinate: Coordinate, accuracy: Double = 10, age: TimeInterval = 0) -> LocationFix {
        LocationFix(coordinate: coordinate, horizontalAccuracy: accuracy, timestamp: .now.addingTimeInterval(-age))
    }

    /// 函館山の場所（ほかのピースの範囲と重ならない）にいる
    private var atHakodateyama: LocationScanEvent {
        .located(fix(at: catalog.pieces[1].coordinate))
    }

    /// 函館駅の場所（函館朝市の範囲とも重なる）にいる
    private var atHakodateStation: LocationScanEvent {
        .located(fix(at: Coordinate(latitude: 41.7737, longitude: 140.7266)))
    }

    /// どのピースの範囲にも入っていない場所（東京駅）にいる
    private var atTokyo: LocationScanEvent {
        .located(fix(at: Coordinate(latitude: 35.681236, longitude: 139.767125)))
    }

    /// 許可をまだ尋ねていなければ、調べ始めるときに session を始めて尋ね、許可されたら測り始める
    @Test
    func requestsPermissionThenStartsUpdating() async {
        let scanner = StubLocationScanner(permission: .notDetermined)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        #expect(scanner.sessions.isEmpty)

        detector.start()
        #expect(scanner.activeSessionCount == 1)
        #expect(!detector.isScanning)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(detector.permission == .authorized)
        #expect(detector.isScanning)
        #expect(scanner.isUpdating)
        #expect(scanner.sessions.count == 1)
        #expect(scanner.activeSessionCount == 1)
    }

    /// 許可されていれば、すぐに測り始める
    @Test
    func startsUpdatingWhenAuthorized() {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(detector.isScanning)
        #expect(scanner.isUpdating)
        #expect(scanner.activeSessionCount == 1)
    }

    /// 許可が無い・拒否された・「正確な位置情報」がオフのときは測らず、許可の状態を画面に渡す
    @Test(arguments: [LocationPermission.denied, .restricted, .reducedAccuracy])
    func doesNotScanWithoutPermission(permission: LocationPermission) {
        let scanner = StubLocationScanner(permission: permission)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(detector.permission == permission)
        #expect(!detector.isScanning)
        #expect(!scanner.isUpdating)
        #expect(scanner.sessions.isEmpty)
    }

    /// 何度 `start()` しても、許可が何度届いても、測るのと session は 1 回だけ始める
    @Test
    func startsUpdatingOnlyOnce() async {
        let scanner = StubLocationScanner(permission: .notDetermined)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.start()
        await scanner.send(.permissionChanged(.authorized), to: detector)
        await scanner.send(.permissionChanged(.authorized), to: detector)
        detector.start()
        #expect(scanner.startCount == 1)
        #expect(scanner.sessions.count == 1)
    }

    /// 許可を待っている間に `stop()` したら、その後に許可されても測らない
    @Test
    func doesNotScanWhenStoppedWhileWaitingForPermission() async {
        let scanner = StubLocationScanner(permission: .notDetermined)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.stop()
        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.startCount == 0)
        #expect(scanner.sessions.count == 1)
        #expect(scanner.activeSessionCount == 0)
    }

    /// 許可を尋ねている間に拒否されたら、session を終える
    @Test
    func invalidatesSessionWhenPermissionIsDenied() async {
        let scanner = StubLocationScanner(permission: .notDetermined)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(scanner.activeSessionCount == 1)

        await scanner.send(.permissionChanged(.denied), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.sessions.count == 1)
        #expect(scanner.activeSessionCount == 0)
    }

    /// 調べている間に検知が無くなったら、session を終える
    @Test
    func invalidatesSessionOnDeinit() {
        let scanner = StubLocationScanner(permission: .authorized)
        var detector: PieceDetector? = PieceDetector(catalog: catalog, scanner: scanner)
        detector?.start()
        #expect(scanner.activeSessionCount == 1)

        detector = nil
        #expect(scanner.activeSessionCount == 0)
    }

    /// `stop()` したら測るのをやめ、session を終える
    @Test
    func invalidatesSessionOnStop() {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.stop()
        #expect(!scanner.isUpdating)
        #expect(scanner.sessions.count == 1)
        #expect(scanner.activeSessionCount == 0)

        detector.stop()
        #expect(scanner.sessions.count == 1)
    }

    /// `stop()` の後にもう一度 `start()` すると、また範囲に入ったことが分かる（タブを行き来したとき）
    @Test
    func restartsAfterStop() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.stop()
        detector.start()
        #expect(scanner.startCount == 2)
        #expect(scanner.sessions.count == 2)
        #expect(scanner.activeSessionCount == 1)

        await scanner.send(atHakodateyama, to: detector)
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])
    }

    /// 調べている間に「正確な位置情報」をオフにされたら測るのをやめ、オンに戻されたら測り直す
    @Test
    func pausesWhileAccuracyIsReduced() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.permissionChanged(.reducedAccuracy), to: detector)
        #expect(detector.permission == .reducedAccuracy)
        #expect(!detector.isScanning)
        #expect(scanner.activeSessionCount == 0)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(detector.isScanning)
        #expect(scanner.startCount == 2)
        #expect(scanner.activeSessionCount == 1)
    }

    /// 調べている間に許可を取り消されたら、測るのをやめて session を終える
    @Test
    func stopsWhenPermissionIsRevoked() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.permissionChanged(.denied), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.stopCount == 1)
        #expect(scanner.activeSessionCount == 0)
    }

    /// `start()` していなければ、許可されても測らない（さがすタブを表示している間だけ調べる）
    @Test
    func doesNotScanUntilStarted() async {
        let scanner = StubLocationScanner(permission: .notDetermined)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.sessions.isEmpty)
    }

    /// ピースの場所の範囲に入ったら、そのピースを出す
    @Test
    func detectsPieceWithinArea() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(atHakodateyama, to: detector)
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])

        detector.clearDetectedPieces()
        #expect(detector.detectedPieces.isEmpty)
    }

    /// 範囲が重なる場所では、範囲に入ったピースを近い順に出す
    @Test
    func detectsOverlappingPiecesNearestFirst() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(atHakodateStation, to: detector)
        #expect(detector.detectedPieces.map(\.name) == ["函館駅", "函館朝市"])
    }

    /// どのピースの範囲にも入っていなければ出さない。前に入ったピースも消さない（画面で扱う前に次の位置が届いたとき）
    @Test
    func keepsDetectedPiecesOutsideAreas() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(atTokyo, to: detector)
        #expect(detector.detectedPieces.isEmpty)

        await scanner.send(atHakodateyama, to: detector)
        await scanner.send(atTokyo, to: detector)
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])
    }

    /// 精度の悪い位置・古い位置（使い始めた直後に届く前の位置）では、範囲の中でも出さない
    @Test
    func ignoresInaccurateOrStaleFix() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()
        let center = catalog.pieces[1].coordinate

        await scanner.send(.located(fix(at: center, accuracy: 500)), to: detector)
        await scanner.send(.located(fix(at: center, accuracy: -1)), to: detector)
        await scanner.send(.located(fix(at: center, age: 600)), to: detector)
        #expect(detector.detectedPieces.isEmpty)
    }

    /// `stop()` の後に届いた位置は使わない
    @Test
    func ignoresFixAfterStop() async {
        let scanner = StubLocationScanner(permission: .authorized)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        detector.start()
        detector.stop()
        #expect(scanner.stopCount == 1)

        await scanner.send(atHakodateyama, to: detector)
        #expect(detector.detectedPieces.isEmpty)
    }

    /// 擬似検知は、調べ始めてから少し後に、決めた場所にいることにする
    @Test
    func fakeScannerLocatesAfterDelay() async {
        let scanner = FakeLocationScanner(coordinate: catalog.pieces[1].coordinate, delay: .milliseconds(10))
        let detector = PieceDetector(catalog: catalog, scanner: scanner)
        #expect(detector.permission == .authorized)

        await detector.handling(after: detector.start)
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])
    }

    /// 擬似検知も、`stop()` したら位置を伝えない
    @Test
    func fakeScannerDoesNotLocateAfterStop() async {
        let events: AsyncStream<LocationScanEvent>
        do {
            let scanner = FakeLocationScanner(coordinate: catalog.pieces[1].coordinate, delay: .milliseconds(10))
            events = scanner.events
            scanner.startUpdating()
            let task = scanner.task
            scanner.stopUpdating()
            await task?.value
        }

        // 擬似検知が無くなると events が終わるので、それまでに流れた出来事を全部受け取れる
        var received: [LocationScanEvent] = []
        for await event in events {
            received.append(event)
        }
        #expect(received.isEmpty)
    }

    /// `-fakePieceID` があればそのピースの場所の擬似検知、無い・同梱データに無い id なら CoreLocation で調べる
    @Test
    func liveDetectorUsesFakeScannerOnlyForKnownPieceID() {
        #expect(PieceDetector.live(options: LaunchOptions(fakePieceID: 1), catalog: catalog).permission == .authorized)
        #expect(PieceDetector.live(options: LaunchOptions(fakePieceID: 1), catalog: catalog).usesFakeScanner)
        #expect(!PieceDetector.live(options: LaunchOptions(fakePieceID: 99), catalog: catalog).usesFakeScanner)
        #expect(!PieceDetector.live(options: LaunchOptions(), catalog: catalog).usesFakeScanner)
    }

    /// テストでは実際の位置情報を使わず、何も伝えない擬似検知にする
    @Test
    func liveDetectorDoesNotUseLocationServicesWhileTesting() {
        let detector = PieceDetector.live(options: LaunchOptions(usesLocationServices: false), catalog: catalog)
        #expect(detector.usesFakeScanner)

        detector.start()
        #expect(detector.isScanning)
        #expect(detector.detectedPieces.isEmpty)
    }

    /// 場所を決めない擬似検知は、測り始めても何も伝えない
    @Test
    func fakeScannerWithoutCoordinateFindsNothing() {
        let scanner = FakeLocationScanner(coordinate: nil)
        scanner.startUpdating()
        #expect(scanner.task == nil)
    }

    /// CoreLocation の許可の状態を、画面で使う許可の状態に直す
    @Test
    func mapsAuthorizationStatus() {
        #expect(LocationPermission(.notDetermined) == .notDetermined)
        #expect(LocationPermission(.denied) == .denied)
        #expect(LocationPermission(.restricted) == .restricted)
        #expect(LocationPermission(.authorizedWhenInUse) == .authorized)
        #expect(LocationPermission(.authorizedAlways) == .authorized)
        #expect(LocationPermission(.authorizedWhenInUse, accuracy: .fullAccuracy) == .authorized)
        #expect(LocationPermission(.authorizedWhenInUse, accuracy: .reducedAccuracy) == .reducedAccuracy)
        #expect(LocationPermission(.denied, accuracy: .reducedAccuracy) == .denied)
    }
}

/// 外から入れる擬似検知（デバッグモード用の `injectDetection(pieceID:)`）
@MainActor
struct PieceDetectorInjectionTests {
    private let catalog = Catalog.bundled

    /// 調べている間に入れると、すぐに範囲に入ったときと同じく `detectedPieces` に入る
    @Test
    func injectionWhileScanningIsDeliveredImmediately() {
        let detector = PieceDetector(catalog: catalog, scanner: StubLocationScanner(permission: .authorized))
        detector.start()

        #expect(detector.injectDetection(pieceID: 2))
        #expect(detector.detectedPieces.map(\.name) == ["五稜郭タワー"])
    }

    /// 調べていないときに入れると持っておき、次に調べ始めたときに入れる（さがすタブに切り替わったとき）
    @Test
    func injectionBeforeStartIsDeliveredOnStart() {
        let detector = PieceDetector(catalog: catalog, scanner: StubLocationScanner(permission: .authorized))

        #expect(detector.injectDetection(pieceID: 1))
        #expect(detector.detectedPieces.isEmpty)

        detector.start()
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])
    }

    /// `stop()` した後に入れても、次の `start()` で入る。一度入れたものは、また調べ始めても入れ直さない
    @Test
    func injectionIsDeliveredOnlyOnce() {
        let detector = PieceDetector(catalog: catalog, scanner: StubLocationScanner(permission: .authorized))
        detector.start()
        detector.stop()

        detector.injectDetection(pieceID: 0)
        detector.start()
        #expect(detector.detectedPieces.map(\.name) == ["元町公園"])

        detector.clearDetectedPieces()
        detector.stop()
        detector.start()
        #expect(detector.detectedPieces.isEmpty)
    }

    /// 位置情報の許可が無くても入れる（擬似検知なので、測り始めない）
    @Test(arguments: [LocationPermission.notDetermined, .denied, .restricted, .reducedAccuracy])
    func injectionIgnoresPermission(permission: LocationPermission) {
        let scanner = StubLocationScanner(permission: permission)
        let detector = PieceDetector(catalog: catalog, scanner: scanner)

        detector.injectDetection(pieceID: 0)
        detector.start()
        #expect(detector.detectedPieces.map(\.name) == ["元町公園"])
        #expect(scanner.startCount == 0)
    }

    /// 持っている間にもう一度入れたら、後のほうだけを入れる
    @Test
    func laterInjectionReplacesPendingOne() {
        let detector = PieceDetector(catalog: catalog, scanner: StubLocationScanner(permission: .authorized))

        detector.injectDetection(pieceID: 0)
        detector.injectDetection(pieceID: 1)
        detector.start()
        #expect(detector.detectedPieces.map(\.name) == ["函館山"])
    }

    /// 同梱データに無いピースは入れない
    @Test
    func unknownPieceIsIgnored() {
        let detector = PieceDetector(catalog: catalog, scanner: StubLocationScanner(permission: .authorized))
        detector.start()

        #expect(!detector.injectDetection(pieceID: 99))
        #expect(detector.detectedPieces.isEmpty)
    }
}
