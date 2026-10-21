//
//  BeaconDetectorTests.swift
//  demomoni-remake-iosTests
//

import CoreLocation
@testable import demomoni_remake_ios
import Foundation
import Testing

/// テストから許可の変化と ranging の結果を送れる `BeaconScanner`
private final class StubBeaconScanner: BeaconScanner {
    let events: AsyncStream<BeaconScanEvent>
    var permission: LocationPermission
    private let continuation: AsyncStream<BeaconScanEvent>.Continuation
    private(set) var permissionRequests = 0
    private(set) var rangingUUIDs: Set<UUID>?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(permission: LocationPermission) {
        (events, continuation) = AsyncStream.makeStream(of: BeaconScanEvent.self)
        self.permission = permission
    }

    func requestPermission() {
        permissionRequests += 1
    }

    func startRanging(uuids: Set<UUID>) {
        rangingUUIDs = uuids
        startCount += 1
    }

    func stopRanging() {
        rangingUUIDs = nil
        stopCount += 1
    }

    func send(_ event: BeaconScanEvent) {
        if case .permissionChanged(let newPermission) = event {
            permission = newPermission
        }
        continuation.yield(event)
    }

    /// 出来事を送り、`detector` がそれを扱い終えるまで待つ
    func send(_ event: BeaconScanEvent, to detector: BeaconDetector) async {
        await detector.handling(event) { send(event) }
    }
}

extension BeaconDetector {
    /// `action` の後、この検知が出来事（`event` を決めたらそれと同じもの）を扱い終えるまで待つ（出来事は `AsyncStream` で後から届くため）。
    /// テストが時間切れで cancel されたら、待つのをやめる
    func handling(_ event: BeaconScanEvent? = nil, after action: () -> Void) async {
        let (handled, continuation) = AsyncStream.makeStream(of: BeaconScanEvent.self)
        onEventHandled = { continuation.yield($0) }
        defer { onEventHandled = nil }
        action()
        for await handledEvent in handled where event == nil || handledEvent == event {
            return
        }
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct BeaconDetectorTests {
    private let uuid = UUID(uuidString: "E8C65602-6D9C-44EF-9734-B2D3EF1CD961")!
    private let catalog = Catalog.bundled

    /// 元町公園（beaconId 0）のビーコン
    private var motomachi: DetectedBeacon {
        DetectedBeacon(uuid: uuid, major: 0, minor: 5000)
    }

    /// 同梱データに無いビーコン（minor は 5000 + id × 1000 なので 4000 はどの id にも当たらない）
    private var unknown: DetectedBeacon {
        DetectedBeacon(uuid: uuid, major: 0, minor: 4000)
    }

    /// 許可をまだ尋ねていなければ、探し始めるときに尋ね、許可されたら ranging を始める
    @Test
    func requestsPermissionThenStartsRanging() async {
        let scanner = StubBeaconScanner(permission: .notDetermined)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(scanner.permissionRequests == 1)
        #expect(!detector.isScanning)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(detector.permission == .authorized)
        #expect(detector.isScanning)
        #expect(scanner.rangingUUIDs == [uuid])
    }

    /// 許可されていれば、すぐに同梱データの UUID で ranging を始める
    @Test
    func startsRangingWhenAuthorized() {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(scanner.permissionRequests == 0)
        #expect(detector.isScanning)
        #expect(scanner.rangingUUIDs == [uuid])
    }

    /// 許可が無い・拒否されたときは探さず、許可の状態を画面に渡す
    @Test(arguments: [LocationPermission.denied, .restricted, .reducedAccuracy])
    func doesNotScanWithoutPermission(permission: LocationPermission) {
        let scanner = StubBeaconScanner(permission: permission)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        #expect(detector.permission == permission)
        #expect(!detector.isScanning)
        #expect(scanner.rangingUUIDs == nil)
        #expect(scanner.permissionRequests == 0)
    }

    /// 何度 `start()` しても、許可が何度届いても、ranging は 1 回だけ始める
    @Test
    func startsRangingOnlyOnce() async {
        let scanner = StubBeaconScanner(permission: .notDetermined)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.start()
        await scanner.send(.permissionChanged(.authorized), to: detector)
        await scanner.send(.permissionChanged(.authorized), to: detector)
        detector.start()
        #expect(scanner.startCount == 1)
    }

    /// 許可を待っている間に `stop()` したら、その後に許可されても探さない
    @Test
    func doesNotScanWhenStoppedWhileWaitingForPermission() async {
        let scanner = StubBeaconScanner(permission: .notDetermined)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.stop()
        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.startCount == 0)
    }

    /// `stop()` の後にもう一度 `start()` すると、また見つけられる（タブを行き来したとき）
    @Test
    func restartsAfterStop() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.start()
        detector.stop()
        detector.start()
        #expect(scanner.startCount == 2)

        await scanner.send(.ranged([motomachi]), to: detector)
        #expect(detector.detectedPiece?.name == "元町公園")
    }

    /// 探している間に「正確な位置情報」をオフにされたら探すのをやめ、オンに戻されたら探し直す
    @Test
    func pausesWhileAccuracyIsReduced() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.permissionChanged(.reducedAccuracy), to: detector)
        #expect(detector.permission == .reducedAccuracy)
        #expect(!detector.isScanning)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(detector.isScanning)
        #expect(scanner.startCount == 2)
    }

    /// 探している間に許可を取り消されたら、探すのをやめる
    @Test
    func stopsWhenPermissionIsRevoked() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.permissionChanged(.denied), to: detector)
        #expect(!detector.isScanning)
        #expect(scanner.stopCount == 1)
    }

    /// `start()` していなければ、許可されても探さない（さがすタブを表示している間だけ探す）
    @Test
    func doesNotScanUntilStarted() async {
        let scanner = StubBeaconScanner(permission: .notDetermined)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        await scanner.send(.permissionChanged(.authorized), to: detector)
        #expect(!detector.isScanning)
    }

    /// 同梱データのビーコンを見つけたら、対応するピースを出す
    @Test
    func detectsPieceForKnownBeacon() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.ranged([unknown, motomachi]), to: detector)
        #expect(detector.detectedPiece?.name == "元町公園")

        detector.clearDetectedPiece()
        #expect(detector.detectedPiece == nil)
    }

    /// 同梱データに無いビーコン・空の結果では、ピースを出さない
    @Test
    func ignoresUnknownBeacons() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        detector.start()

        await scanner.send(.ranged([unknown]), to: detector)
        await scanner.send(.ranged([]), to: detector)
        #expect(detector.detectedPiece == nil)
    }

    /// `stop()` の後に届いた ranging の結果は使わない
    @Test
    func ignoresRangingAfterStop() async {
        let scanner = StubBeaconScanner(permission: .authorized)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        detector.start()
        detector.stop()
        #expect(scanner.stopCount == 1)

        await scanner.send(.ranged([motomachi]), to: detector)
        #expect(detector.detectedPiece == nil)
    }

    /// 見つけたビーコンのうち、同梱データにある最初のビーコンのピースを選ぶ
    @Test
    func firstPieceSkipsUnknownBeacons() {
        let hakodateyama = DetectedBeacon(uuid: uuid, major: 0, minor: 6000)
        #expect(BeaconDetector.firstPiece(in: [unknown, hakodateyama, motomachi], catalog: catalog)?.name == "函館山")
        #expect(BeaconDetector.firstPiece(in: [unknown], catalog: catalog) == nil)
    }

    /// 擬似検知は、探し始めてから少し後に決めたビーコンを見つけたことにする
    @Test
    func fakeScannerDetectsBeaconAfterDelay() async {
        let scanner = FakeBeaconScanner(beacon: motomachi, delay: .milliseconds(10))
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)
        #expect(detector.permission == .authorized)

        await detector.handling(after: detector.start)
        #expect(detector.detectedPiece?.name == "元町公園")
    }

    /// 擬似検知も、`stop()` したら見つけたことにしない
    @Test
    func fakeScannerDoesNotDetectAfterStop() async {
        let events: AsyncStream<BeaconScanEvent>
        do {
            let scanner = FakeBeaconScanner(beacon: motomachi, delay: .milliseconds(10))
            events = scanner.events
            scanner.startRanging(uuids: [])
            let task = scanner.task
            scanner.stopRanging()
            await task?.value
        }

        // 擬似検知が無くなると events が終わるので、それまでに流れた出来事を全部受け取れる
        var received: [BeaconScanEvent] = []
        for await event in events {
            received.append(event)
        }
        #expect(received.isEmpty)
    }

    /// `-fakeBeaconID` があれば擬似検知、無い・同梱データに無い id なら CoreLocation で探す
    @Test
    func liveDetectorUsesFakeScannerOnlyForKnownBeaconID() {
        #expect(BeaconDetector.live(options: LaunchOptions(fakeBeaconID: 1), catalog: catalog).permission == .authorized)
        #expect(BeaconDetector.live(options: LaunchOptions(fakeBeaconID: 1), catalog: catalog).usesFakeScanner)
        #expect(!BeaconDetector.live(options: LaunchOptions(fakeBeaconID: 99), catalog: catalog).usesFakeScanner)
        #expect(!BeaconDetector.live(options: LaunchOptions(), catalog: catalog).usesFakeScanner)
    }

    /// テストでは実際の位置情報を使わず、何も見つけない擬似検知にする
    @Test
    func liveDetectorDoesNotUseLocationServicesWhileTesting() {
        let detector = BeaconDetector.live(options: LaunchOptions(usesLocationServices: false), catalog: catalog)
        #expect(detector.usesFakeScanner)

        detector.start()
        #expect(detector.isScanning)
        #expect(detector.detectedPiece == nil)
    }

    /// ビーコンを決めない擬似検知は、探し始めても何も見つけない
    @Test
    func fakeScannerWithoutBeaconFindsNothing() {
        let scanner = FakeBeaconScanner(beacon: nil)
        scanner.startRanging(uuids: [])
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
struct BeaconDetectorInjectionTests {
    private let catalog = Catalog.bundled

    /// 探している間に入れると、すぐにビーコンを見つけたときと同じく `detectedPiece` に入る
    @Test
    func injectionWhileScanningIsDeliveredImmediately() {
        let detector = BeaconDetector(catalog: catalog, scanner: StubBeaconScanner(permission: .authorized))
        detector.start()

        #expect(detector.injectDetection(pieceID: 2))
        #expect(detector.detectedPiece?.name == "五稜郭タワー")
    }

    /// 探していないときに入れると持っておき、次に探し始めたときに入れる（さがすタブに切り替わったとき）
    @Test
    func injectionBeforeStartIsDeliveredOnStart() {
        let detector = BeaconDetector(catalog: catalog, scanner: StubBeaconScanner(permission: .authorized))

        #expect(detector.injectDetection(pieceID: 1))
        #expect(detector.detectedPiece == nil)

        detector.start()
        #expect(detector.detectedPiece?.name == "函館山")
    }

    /// `stop()` した後に入れても、次の `start()` で入る。一度入れたものは、また探し始めても入れ直さない
    @Test
    func injectionIsDeliveredOnlyOnce() {
        let detector = BeaconDetector(catalog: catalog, scanner: StubBeaconScanner(permission: .authorized))
        detector.start()
        detector.stop()

        detector.injectDetection(pieceID: 0)
        detector.start()
        #expect(detector.detectedPiece?.name == "元町公園")

        detector.clearDetectedPiece()
        detector.stop()
        detector.start()
        #expect(detector.detectedPiece == nil)
    }

    /// 位置情報の許可が無くても入れる（擬似検知なので、ranging は始めない）
    @Test(arguments: [LocationPermission.notDetermined, .denied, .restricted, .reducedAccuracy])
    func injectionIgnoresPermission(permission: LocationPermission) {
        let scanner = StubBeaconScanner(permission: permission)
        let detector = BeaconDetector(catalog: catalog, scanner: scanner)

        detector.injectDetection(pieceID: 0)
        detector.start()
        #expect(detector.detectedPiece?.name == "元町公園")
        #expect(scanner.startCount == 0)
    }

    /// 持っている間にもう一度入れたら、後のほうだけを入れる
    @Test
    func laterInjectionReplacesPendingOne() {
        let detector = BeaconDetector(catalog: catalog, scanner: StubBeaconScanner(permission: .authorized))

        detector.injectDetection(pieceID: 0)
        detector.injectDetection(pieceID: 1)
        detector.start()
        #expect(detector.detectedPiece?.name == "函館山")
    }

    /// 同梱データに無いピースは入れない
    @Test
    func unknownPieceIsIgnored() {
        let detector = BeaconDetector(catalog: catalog, scanner: StubBeaconScanner(permission: .authorized))
        detector.start()

        #expect(!detector.injectDetection(pieceID: 99))
        #expect(detector.detectedPiece == nil)
    }
}
