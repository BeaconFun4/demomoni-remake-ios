//
//  FakeBeaconScanner.swift
//  demomoni-remake-ios
//

import Foundation

/// 擬似検知。探し始めてから `delay` の後に、決めたビーコンを 1 回だけ見つけたことにする。
/// ビーコンを決めなければ、何も見つけない（位置情報を使わずに画面を確かめるとき）。
/// CoreLocation が動かない Simulator の UI テストと、PR のスクリーンショットの撮影で使う
final class FakeBeaconScanner: BeaconScanner {
    var onEvent: (@MainActor (BeaconScanEvent) -> Void)?
    let permission = LocationPermission.authorized

    private let beacon: DetectedBeacon?
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(beacon: DetectedBeacon?, delay: Duration = .seconds(2)) {
        self.beacon = beacon
        self.delay = delay
    }

    func requestPermission() {}

    func startRanging(uuids: Set<UUID>) {
        task?.cancel()
        guard let beacon else {
            return
        }
        let delay = delay
        task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            self?.onEvent?(.ranged([beacon]))
        }
    }

    func stopRanging() {
        task?.cancel()
        task = nil
    }
}
