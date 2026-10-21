//
//  FakeBeaconScanner.swift
//  demomoni-remake-ios
//

import Foundation

/// 擬似検知。探し始めてから `delay` の後に、決めたビーコンを 1 回だけ見つけたことにする。
/// ビーコンを決めなければ、何も見つけない（位置情報を使わずに画面を確かめるとき）。
/// CoreLocation が動かない Simulator の UI テストと、PR のスクリーンショットの撮影で使う
final class FakeBeaconScanner: BeaconScanner {
    let events: AsyncStream<BeaconScanEvent>
    let permission = LocationPermission.authorized

    nonisolated private let continuation: AsyncStream<BeaconScanEvent>.Continuation
    private let beacon: DetectedBeacon?
    private let delay: Duration
    /// 見つけたことにするまで待っている処理（テストで、やめた後に終わるのを待つため internal）
    private(set) var task: Task<Void, Never>?

    init(beacon: DetectedBeacon?, delay: Duration = .seconds(2)) {
        (events, continuation) = AsyncStream.makeStream(of: BeaconScanEvent.self)
        self.beacon = beacon
        self.delay = delay
    }

    deinit {
        continuation.finish()
    }

    func makeSession() -> any LocationSession {
        FakeLocationSession()
    }

    func startRanging(uuids: Set<UUID>) {
        task?.cancel()
        guard let beacon else {
            return
        }
        let delay = delay
        let continuation = continuation
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            continuation.yield(.ranged([beacon]))
        }
    }

    func stopRanging() {
        task?.cancel()
        task = nil
    }
}

/// 擬似検知の session。位置情報を使わないので何もしない
final class FakeLocationSession: LocationSession {
    func invalidate() {}
}
