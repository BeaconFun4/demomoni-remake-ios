//
//  BeaconDetector.swift
//  demomoni-remake-ios
//

import Foundation
import Observation

/// 近くの iBeacon を探し、同梱データのピースに対応するビーコンを見つけたら `detectedPiece` に入れる。
/// さがすタブを表示している間だけ `start()` し、離れたら `stop()` する（バックグラウンドでは探さない）
@Observable
final class BeaconDetector {
    /// 位置情報の許可
    private(set) var permission: LocationPermission
    /// ranging しているか
    private(set) var isScanning = false
    /// 最後に見つけたピース。画面で扱ったら `clearDetectedPiece()` で消す
    private(set) var detectedPiece: Piece?

    @ObservationIgnored private let catalog: Catalog
    @ObservationIgnored private let scanner: any BeaconScanner
    /// `start()` されているか（許可を待っている間も `true`）
    @ObservationIgnored private var wantsScanning = false
    /// 位置情報の session。探していて、許可がまだ・許可済みの間だけ持つ（`updateSession()`）
    @ObservationIgnored private var session: (any LocationSession)?
    /// 外から入れた擬似検知のうち、まだ `detectedPiece` に入れていないもの（`injectDetection(pieceID:)`）
    @ObservationIgnored private var injectedPiece: Piece?
    /// `scanner.events` を受け続ける処理。この検知が無くなったら cancel する
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    /// 出来事を 1 つ扱い終えるたびに呼ぶ（テストで、出来事が届いたのを待つため）
    @ObservationIgnored var onEventHandled: ((BeaconScanEvent) -> Void)?

    init(catalog: Catalog, scanner: any BeaconScanner) {
        self.catalog = catalog
        self.scanner = scanner
        permission = scanner.permission
        // MainActor で受けるので、デリゲートがどのスレッドで呼ばれても handle(_:) は MainActor で動く
        eventTask = Task { [weak self, events = scanner.events] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    isolated deinit {
        eventTask?.cancel()
        session?.invalidate()
    }

    /// 探し始める。許可をまだ尋ねていなければ尋ね、許可されたら探す。
    /// 許可が無い・「正確な位置情報」がオフなら探さない（画面で `permission` を見て案内を出す）
    func start() {
        wantsScanning = true
        deliverInjectedPiece()
        updateSession()
        if permission == .authorized {
            beginRanging()
        }
    }

    /// 探すのをやめる
    func stop() {
        wantsScanning = false
        endRanging()
        updateSession()
    }

    /// 外から「このピースのビーコンを見つけた」を入れる（デバッグモードの擬似検知）。
    /// 探している（`start()` した後で `stop()` していない）間なら、すぐにビーコンを見つけたときと同じく `detectedPiece` に入れる。
    /// 探していなければ持っておき、次に `start()` したときに入れる（さがすタブは表示している間だけ探すため）。
    /// 位置情報の許可が無くても入れる。持っている間にもう一度入れたら、後のほうだけを残す
    /// - Returns: 同梱データにあるピースか。無ければ何もしない
    @discardableResult
    func injectDetection(pieceID: Int) -> Bool {
        guard let piece = catalog.piece(id: pieceID) else {
            return false
        }
        injectedPiece = piece
        if wantsScanning {
            deliverInjectedPiece()
        }
        return true
    }

    /// 見つけたピースを画面で扱ったので消す
    func clearDetectedPiece() {
        detectedPiece = nil
    }

    /// 見つけたビーコンのうち、同梱データにあるビーコンの最初のピース
    nonisolated static func firstPiece(in beacons: [DetectedBeacon], catalog: Catalog) -> Piece? {
        beacons.lazy
            .compactMap { catalog.piece(forBeaconUUID: $0.uuid, major: $0.major, minor: $0.minor) }
            .first
    }

    private func handle(_ event: BeaconScanEvent) {
        switch event {
        case .permissionChanged(let newPermission):
            permission = newPermission
            if newPermission == .authorized {
                if wantsScanning {
                    beginRanging()
                }
            } else {
                endRanging()
            }
            updateSession()
        case .ranged(let beacons):
            if isScanning, let piece = Self.firstPiece(in: beacons, catalog: catalog) {
                detectedPiece = piece
            }
        }
        onEventHandled?(event)
    }

    private func deliverInjectedPiece() {
        guard let piece = injectedPiece else {
            return
        }
        injectedPiece = nil
        detectedPiece = piece
    }

    /// 探していて、許可がまだ・許可済みの間だけ session を持つ。
    /// まだ尋ねていなければ、session を始めたときに許可を尋ねる（さがすタブを最初に表示したとき）。
    /// 許可が無い・「正確な位置情報」がオフのときは持たない（画面で案内する）
    private func updateSession() {
        let needsSession = wantsScanning && (permission == .notDetermined || permission == .authorized)
        if needsSession, session == nil {
            session = scanner.makeSession()
        } else if !needsSession, let session {
            session.invalidate()
            self.session = nil
        }
    }

    private func beginRanging() {
        guard !isScanning else {
            return
        }
        scanner.startRanging(uuids: Set(catalog.beacons.map(\.uuid)))
        isScanning = true
    }

    private func endRanging() {
        guard isScanning else {
            return
        }
        scanner.stopRanging()
        isScanning = false
    }
}

extension BeaconDetector {
    /// アプリで使う検知。起動引数 `-fakeBeaconID <id>` があれば擬似検知、
    /// テスト（`-uiTesting`・Unit テストのホスト）なら何も見つけない擬似検知、それ以外は CoreLocation で探す
    static func live(options: LaunchOptions, catalog: Catalog) -> BeaconDetector {
        if let id = options.fakeBeaconID, let beacon = catalog.beacons.first(where: { $0.beaconId == id }) {
            return BeaconDetector(catalog: catalog, scanner: FakeBeaconScanner(beacon: DetectedBeacon(beacon)))
        }
        guard options.usesLocationServices else {
            return BeaconDetector(catalog: catalog, scanner: FakeBeaconScanner(beacon: nil))
        }
        return BeaconDetector(catalog: catalog, scanner: CoreLocationBeaconScanner())
    }

    /// 擬似検知で動いているか
    var usesFakeScanner: Bool {
        scanner is FakeBeaconScanner
    }
}
