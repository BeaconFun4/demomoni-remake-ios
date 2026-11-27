//
//  FakeLocationScanner.swift
//  demomoni-remake-ios
//

import Foundation

/// 擬似検知。測り始めてから `delay` の後に、決めた場所にいることを 1 回だけ伝える（精度のよい、その時に測った位置として）。
/// 場所を決めなければ、何も伝えない（位置情報を使わずに画面を確かめるとき）。
/// CoreLocation が動かない Simulator の UI テストと、PR のスクリーンショットの撮影で使う
final class FakeLocationScanner: LocationScanner {
    /// 擬似検知で伝える位置の精度（メートル）
    nonisolated static let horizontalAccuracy: Double = 5

    let events: AsyncStream<LocationScanEvent>
    let permission = LocationPermission.authorized

    nonisolated private let continuation: AsyncStream<LocationScanEvent>.Continuation
    private let coordinate: Coordinate?
    private let delay: Duration
    /// 伝えるまで待っている処理（テストで、やめた後に終わるのを待つため internal）
    private(set) var task: Task<Void, Never>?

    init(coordinate: Coordinate?, delay: Duration = .seconds(2)) {
        (events, continuation) = AsyncStream.makeStream(of: LocationScanEvent.self)
        self.coordinate = coordinate
        self.delay = delay
    }

    deinit {
        continuation.finish()
    }

    func makeSession() -> any LocationSession {
        FakeLocationSession()
    }

    func startUpdating() {
        task?.cancel()
        guard let coordinate else {
            return
        }
        let delay = delay
        let continuation = continuation
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            continuation.yield(.located(LocationFix(
                coordinate: coordinate,
                horizontalAccuracy: Self.horizontalAccuracy,
                timestamp: .now
            )))
        }
    }

    func stopUpdating() {
        task?.cancel()
        task = nil
    }
}

/// 擬似検知の session。位置情報を使わないので何もしない
final class FakeLocationSession: LocationSession {
    func invalidate() {}
}
