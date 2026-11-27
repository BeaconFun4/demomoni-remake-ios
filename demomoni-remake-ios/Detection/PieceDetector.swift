//
//  PieceDetector.swift
//  demomoni-remake-ios
//

import Foundation
import Observation

/// 今いる場所を調べ、同梱データのピースの場所の範囲（`PieceArea`。半径 100 m）に入ったら `detectedPieces` に入れる。
/// さがすタブを表示している間だけ `start()` し、離れたら `stop()` する（バックグラウンドでは調べない）
@Observable
final class PieceDetector {
    /// 位置情報の許可
    private(set) var permission: LocationPermission
    /// 今いる場所を測っているか
    private(set) var isScanning = false
    /// 最後に範囲に入ったピース（近い順。獲得済みのものも入る）。画面で扱ったら `clearDetectedPieces()` で消す
    private(set) var detectedPieces: [Piece] = []

    @ObservationIgnored private let catalog: Catalog
    @ObservationIgnored private let scanner: any LocationScanner
    /// `start()` されているか（許可を待っている間も `true`）
    @ObservationIgnored private var wantsScanning = false
    /// 位置情報の session。調べていて、許可がまだ・許可済みの間だけ持つ（`updateSession()`）
    @ObservationIgnored private var session: (any LocationSession)?
    /// 外から入れた擬似検知のうち、まだ `detectedPieces` に入れていないもの（`injectDetection(pieceID:)`）
    @ObservationIgnored private var injectedPiece: Piece?
    /// `scanner.events` を受け続ける処理。この検知が無くなったら cancel する
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    /// 出来事を 1 つ扱い終えるたびに呼ぶ（テストで、出来事が届いたのを待つため）
    @ObservationIgnored var onEventHandled: ((LocationScanEvent) -> Void)?

    init(catalog: Catalog, scanner: any LocationScanner) {
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

    /// 調べ始める。許可をまだ尋ねていなければ尋ね、許可されたら測り始める。
    /// 許可が無い・「正確な位置情報」がオフなら測らない（画面で `permission` を見て案内を出す）
    func start() {
        wantsScanning = true
        deliverInjectedPiece()
        updateSession()
        if permission == .authorized {
            beginUpdating()
        }
    }

    /// 調べるのをやめる
    func stop() {
        wantsScanning = false
        endUpdating()
        updateSession()
    }

    /// 外から「このピースの場所に来た」を入れる（デバッグモードの擬似検知）。
    /// 調べている（`start()` した後で `stop()` していない）間なら、すぐに範囲に入ったときと同じく `detectedPieces` に入れる。
    /// 調べていなければ持っておき、次に `start()` したときに入れる（さがすタブは表示している間だけ調べるため）。
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

    /// 範囲に入ったピースを画面で扱ったので消す
    func clearDetectedPieces() {
        detectedPieces = []
    }

    private func handle(_ event: LocationScanEvent) {
        switch event {
        case .permissionChanged(let newPermission):
            permission = newPermission
            if newPermission == .authorized {
                if wantsScanning {
                    beginUpdating()
                }
            } else {
                endUpdating()
            }
            updateSession()
        case .located(let fix):
            // どのピースの範囲にも入っていなければ、前に入ったピースを消さない（画面で扱う前に次の位置が届くことがあるため）
            let pieces = PieceArea.pieces(around: fix, in: catalog.pieces, now: .now)
            if isScanning, !pieces.isEmpty {
                detectedPieces = pieces
            }
        }
        onEventHandled?(event)
    }

    private func deliverInjectedPiece() {
        guard let piece = injectedPiece else {
            return
        }
        injectedPiece = nil
        detectedPieces = [piece]
    }

    /// 調べていて、許可がまだ・許可済みの間だけ session を持つ。
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

    private func beginUpdating() {
        guard !isScanning else {
            return
        }
        scanner.startUpdating()
        isScanning = true
    }

    private func endUpdating() {
        guard isScanning else {
            return
        }
        scanner.stopUpdating()
        isScanning = false
    }
}

extension PieceDetector {
    /// アプリで使う検知。起動引数 `-fakePieceID <id>` があれば、そのピースの場所にいることにする擬似検知、
    /// テスト（`-uiTesting`・Unit テストのホスト）なら何も伝えない擬似検知、それ以外は CoreLocation で調べる
    static func live(options: LaunchOptions, catalog: Catalog) -> PieceDetector {
        if let id = options.fakePieceID, let piece = catalog.piece(id: id) {
            return PieceDetector(catalog: catalog, scanner: FakeLocationScanner(coordinate: piece.coordinate))
        }
        guard options.usesLocationServices else {
            return PieceDetector(catalog: catalog, scanner: FakeLocationScanner(coordinate: nil))
        }
        return PieceDetector(catalog: catalog, scanner: CoreLocationScanner())
    }

    /// 擬似検知で動いているか
    var usesFakeScanner: Bool {
        scanner is FakeLocationScanner
    }
}
