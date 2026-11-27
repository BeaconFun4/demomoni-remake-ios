//
//  LocationScannerTestDoubles.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation

/// 終えたかを記録する `LocationSession`
final class StubLocationSession: LocationSession {
    private(set) var isInvalidated = false

    func invalidate() {
        isInvalidated = true
    }
}

/// テストから許可の変化と測った位置を送れる `LocationScanner`
final class StubLocationScanner: LocationScanner {
    let events: AsyncStream<LocationScanEvent>
    var permission: LocationPermission
    private let continuation: AsyncStream<LocationScanEvent>.Continuation
    /// 作った session（終えたものも含む）
    private(set) var sessions: [StubLocationSession] = []
    /// 測っているか
    private(set) var isUpdating = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(permission: LocationPermission) {
        (events, continuation) = AsyncStream.makeStream(of: LocationScanEvent.self)
        self.permission = permission
    }

    /// 終えていない session の数
    var activeSessionCount: Int {
        sessions.count { !$0.isInvalidated }
    }

    func makeSession() -> any LocationSession {
        let session = StubLocationSession()
        sessions.append(session)
        return session
    }

    func startUpdating() {
        isUpdating = true
        startCount += 1
    }

    func stopUpdating() {
        isUpdating = false
        stopCount += 1
    }

    func send(_ event: LocationScanEvent) {
        if case .permissionChanged(let newPermission) = event {
            permission = newPermission
        }
        continuation.yield(event)
    }

    /// 出来事を送り、`detector` がそれを扱い終えるまで待つ
    func send(_ event: LocationScanEvent, to detector: PieceDetector) async {
        await detector.handling(event) { send(event) }
    }
}

extension PieceDetector {
    /// `action` の後、この検知が出来事（`event` を決めたらそれと同じもの）を扱い終えるまで待つ（出来事は `AsyncStream` で後から届くため）。
    /// テストが時間切れで cancel されたら、待つのをやめる
    func handling(_ event: LocationScanEvent? = nil, after action: () -> Void) async {
        let (handled, continuation) = AsyncStream.makeStream(of: LocationScanEvent.self)
        onEventHandled = { continuation.yield($0) }
        defer { onEventHandled = nil }
        action()
        for await handledEvent in handled where event == nil || handledEvent == event {
            return
        }
    }
}
