//
//  BeaconRegionMonitor.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// ビーコンの範囲に入った・出たを見張る仕組み。実機では `CLMonitor`（`CoreLocationBeaconRegionMonitor`）、
/// UI テストと Unit テストのホストでは何もしないもの（`InactiveBeaconRegionMonitor`）に差し替える
protocol BeaconRegionMonitor: AnyObject {
    /// 範囲に入った・出た出来事。受け取るのは 1 か所だけ（`NearbyPieceAlerts`）
    var events: AsyncStream<BeaconRegionEvent> { get }
    /// 位置情報が「常に」か（アプリを閉じている間も出来事が届く）
    var isAlwaysAuthorized: Bool { get }
    /// 正確な位置情報がオンか（オフだと iBeacon を見張れない）
    var hasFullAccuracy: Bool { get }
    /// 位置情報の「常に許可」を尋ねる。まだ尋ねていない・使用中だけのときだけ尋ね、拒否されている・「常に」なら何もしない
    func requestAlwaysAuthorizationIfNeeded()
    /// 位置情報（常に）の session を始める。持っている間だけ、アプリを閉じていても出来事が届く
    func makeAlwaysSession() -> any LocationSession
    /// 見張る条件をこの一覧にそろえる（無いものは足し、一覧に無いものは外す）
    func setConditions(_ conditions: [MonitoredBeacon]) async
    /// 見張る条件をすべて外す。条件はアプリを終えても残るので、オフにしたとき・オフのまま起動したときに呼ぶ
    func removeAllConditions() async
}

/// `CLMonitor` の `BeaconIdentityCondition` でビーコンの範囲を見張る。
/// 同じ名前の `CLMonitor` を 2 つ開かないよう、プロセスで 1 つの共有インスタンス（`shared`）だけを使い、開く処理は `OpenOnce` で 1 回にまとめる（#120）
final class CoreLocationBeaconRegionMonitor: BeaconRegionMonitor {
    /// プロセスで 1 つだけの見張り。`NearbyPieceAlerts.live` を何度呼んでも、これを使う
    static let shared = CoreLocationBeaconRegionMonitor()

    let events: AsyncStream<BeaconRegionEvent>

    /// 許可の状態を読み、「常に許可」を尋ねるために持つ
    private let manager = CLLocationManager()
    /// 最初に条件を扱うときに `CLMonitor` を開く（オンにしたことの無い人には作らない）。
    /// 開いたときに `monitor.events` を受け始めるので、受けるのもプロセスで 1 か所だけになる
    private let opener: OpenOnce<CLMonitor>

    private init() {
        let (events, continuation) = AsyncStream.makeStream(of: BeaconRegionEvent.self)
        self.events = events
        opener = OpenOnce {
            // 同じ名前の CLMonitor を開くと、前に足した条件と、起動の理由になった出来事も届く
            let monitor = await CLMonitor(NearbyPieceMonitoring.monitorName)
            let monitorEvents = await monitor.events
            // 共有インスタンスはプロセスが終わるまで残るので、受け続ける処理も止めない
            Task {
                do {
                    for try await event in monitorEvents {
                        continuation.yield(BeaconRegionEvent(event))
                    }
                } catch {
                    // 出来事が届かなくなっても、通知が出ないだけなので何もしない
                }
            }
            return monitor
        }
    }

    var isAlwaysAuthorized: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    var hasFullAccuracy: Bool {
        manager.accuracyAuthorization == .fullAccuracy
    }

    func requestAlwaysAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            // 使用中から「常に」に上げるダイアログは、iOS が 1 回だけ出す。断られたら設定アプリへ案内する
            manager.requestAlwaysAuthorization()
        case .authorizedAlways, .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func makeAlwaysSession() -> any LocationSession {
        CLServiceSession(authorization: .always)
    }

    func setConditions(_ conditions: [MonitoredBeacon]) async {
        let monitor = await opener.value()
        let wanted = Set(conditions.map(\.identifier))
        for identifier in await monitor.identifiers where !wanted.contains(identifier) {
            await monitor.remove(identifier)
        }
        let existing = Set(await monitor.identifiers)
        for condition in conditions where !existing.contains(condition.identifier) {
            await monitor.add(condition.beaconIdentityCondition, identifier: condition.identifier)
        }
    }

    func removeAllConditions() async {
        let monitor = await opener.value()
        for identifier in await monitor.identifiers {
            await monitor.remove(identifier)
        }
    }
}

extension MonitoredBeacon {
    /// `CLMonitor` に足す条件
    nonisolated var beaconIdentityCondition: CLMonitor.BeaconIdentityCondition {
        if let major, let minor {
            return CLMonitor.BeaconIdentityCondition(uuid: uuid, major: major, minor: minor)
        }
        if let major {
            return CLMonitor.BeaconIdentityCondition(uuid: uuid, major: major)
        }
        return CLMonitor.BeaconIdentityCondition(uuid: uuid)
    }
}

extension BeaconRegionEvent {
    /// `CLMonitor` の出来事から作る。`refinement` が major・minor まで分かるビーコンなら、そのビーコンを入れる
    nonisolated init(_ event: CLMonitor.Event) {
        let refinement = event.refinement as? CLMonitor.BeaconIdentityCondition
        let beacon = refinement.flatMap { condition -> DetectedBeacon? in
            guard let major = condition.major, let minor = condition.minor else {
                return nil
            }
            return DetectedBeacon(uuid: condition.uuid, major: major, minor: minor)
        }
        self.init(identifier: event.identifier, isInside: event.state == .satisfied, beacon: beacon)
    }
}

/// 何もしない見張り。UI テストと Unit テストのホストで、`CLMonitor`・`CLServiceSession` を作らないために使う
final class InactiveBeaconRegionMonitor: BeaconRegionMonitor {
    let events = AsyncStream<BeaconRegionEvent> { $0.finish() }
    let isAlwaysAuthorized = false
    let hasFullAccuracy = false

    func requestAlwaysAuthorizationIfNeeded() {}

    func makeAlwaysSession() -> any LocationSession {
        FakeLocationSession()
    }

    func setConditions(_ conditions: [MonitoredBeacon]) async {}

    func removeAllConditions() async {}
}
