//
//  RegionMonitor.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// ピースの場所の範囲（円）に入った・出たを見張る仕組み。実機では `CLMonitor`（`CoreLocationRegionMonitor`）、
/// UI テストと Unit テストのホストでは何もしないもの（`InactiveRegionMonitor`）に差し替える
protocol RegionMonitor: AnyObject {
    /// 範囲に入った・出た出来事。受け取るのは 1 か所だけ（`NearbyPieceAlerts`）
    var events: AsyncStream<RegionEvent> { get }
    /// 位置情報が「常に」か（アプリを閉じている間も出来事が届く）
    var isAlwaysAuthorized: Bool { get }
    /// 正確な位置情報がオンか（オフだとピースの場所の範囲を見張れない）
    var hasFullAccuracy: Bool { get }
    /// 最後に分かった今いる場所。まだ分からなければ `nil`（未獲得のピースが多いときに、近いものを選ぶのに使う）
    var lastKnownCoordinate: Coordinate? { get }
    /// 位置情報の「常に許可」を尋ねる。まだ尋ねていない・使用中だけのときだけ尋ね、拒否されている・「常に」なら何もしない
    func requestAlwaysAuthorizationIfNeeded()
    /// 位置情報（常に）の session を始める。持っている間だけ、アプリを閉じていても出来事が届く
    func makeAlwaysSession() -> any LocationSession
    /// 見張る条件をこの一覧にそろえる（無いものは足し、一覧に無いものは外す）。
    /// 位置情報の許可が無い・未決定で `CLMonitor` を開けなければ何もせず `false` を返す
    @discardableResult
    func setConditions(_ conditions: [MonitoredRegion]) async -> Bool
    /// 見張る条件をすべて外す。条件はアプリを終えても残るので、オフにした直後に呼ぶ（起動時には呼ばない。#120）。
    /// 位置情報の許可が無い・未決定で `CLMonitor` を開けなければ何もせず `false` を返す（条件は残る）
    @discardableResult
    func removeAllConditions() async -> Bool
}

/// `CLMonitor` の `CircularGeographicCondition` でピースの場所の範囲を見張る。
/// 同じ名前の `CLMonitor` を 2 つ開かないよう、プロセスで 1 つの共有インスタンス（`shared`）だけを使い、開く処理は `OpenOnce` で 1 回にまとめる（#120）
final class CoreLocationRegionMonitor: RegionMonitor {
    /// プロセスで 1 つだけの見張り。`NearbyPieceAlerts.live` を何度呼んでも、これを使う。
    /// `events` を受けるのは `NearbyPieceAlerts` の 1 か所だけの前提（`live` はアプリの起動で 1 回だけ呼ぶ。2 つが受けると出来事が分かれて届く）
    static let shared = CoreLocationRegionMonitor()

    let events: AsyncStream<RegionEvent>

    /// 許可の状態と最後に分かった場所を読み、「常に許可」を尋ねるために持つ
    private let manager = CLLocationManager()
    /// 最初に条件を扱うときに `CLMonitor` を開く（オンにしたことの無い人には作らない）。
    /// 開いたときに `monitor.events` を受け始めるので、受けるのもプロセスで 1 か所だけになる
    private let opener: OpenOnce<CLMonitor>

    private init() {
        let (events, continuation) = AsyncStream.makeStream(of: RegionEvent.self)
        self.events = events
        opener = OpenOnce {
            // 同じ名前の CLMonitor を開くと、前に足した条件と、起動の理由になった出来事も届く
            let monitor = await CLMonitor(NearbyPieceMonitoring.monitorName)
            let monitorEvents = await monitor.events
            // 共有インスタンスはプロセスが終わるまで残るので、受け続ける処理も止めない
            Task {
                do {
                    for try await event in monitorEvents {
                        continuation.yield(RegionEvent(event))
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

    var lastKnownCoordinate: Coordinate? {
        manager.location.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
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

    func setConditions(_ conditions: [MonitoredRegion]) async -> Bool {
        guard let monitor = await openMonitorIfAuthorized() else {
            return false
        }
        // 前の版のビーコンの条件（identifier が beacon- のもの）も、ここで外れる
        let wanted = Set(conditions.map(\.identifier))
        for identifier in await monitor.identifiers where !wanted.contains(identifier) {
            await monitor.remove(identifier)
        }
        let existing = Set(await monitor.identifiers)
        for condition in conditions where !existing.contains(condition.identifier) {
            await monitor.add(condition.circularGeographicCondition, identifier: condition.identifier)
        }
        return true
    }

    func removeAllConditions() async -> Bool {
        guard let monitor = await openMonitorIfAuthorized() else {
            return false
        }
        for identifier in await monitor.identifiers {
            await monitor.remove(identifier)
        }
        return true
    }

    /// 位置情報が「常に」か「使用中」のときだけ `CLMonitor` を開く（`NearbyPieceMonitoring.canOpenMonitor(_:)`。#120）
    private func openMonitorIfAuthorized() async -> CLMonitor? {
        guard NearbyPieceMonitoring.canOpenMonitor(LocationAuthorization(manager.authorizationStatus)) else {
            return nil
        }
        return await opener.value()
    }
}

extension LocationAuthorization {
    /// CoreLocation の許可の状態から作る
    nonisolated init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedAlways:
            self = .always
        case .authorizedWhenInUse:
            self = .whenInUse
        @unknown default:
            self = .unknown
        }
    }
}

extension MonitoredRegion {
    /// `CLMonitor` に足す条件
    nonisolated var circularGeographicCondition: CLMonitor.CircularGeographicCondition {
        CLMonitor.CircularGeographicCondition(
            center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            radius: radius
        )
    }
}

extension RegionEvent {
    /// `CLMonitor` の出来事から作る
    nonisolated init(_ event: CLMonitor.Event) {
        self.init(identifier: event.identifier, state: State(event.state))
    }
}

extension RegionEvent.State {
    /// `CLMonitor` の条件の状態から作る。入った・出たのどちらでもないもの（まだ分からない・見張っていない）は `unknown`
    nonisolated init(_ state: CLMonitor.Event.State) {
        switch state {
        case .satisfied:
            self = .inside
        case .unsatisfied:
            self = .outside
        case .unknown, .unmonitored:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }
}

/// 何もしない見張り。UI テストと Unit テストのホストで、`CLMonitor`・`CLServiceSession` を作らないために使う
final class InactiveRegionMonitor: RegionMonitor {
    let events = AsyncStream<RegionEvent> { $0.finish() }
    let isAlwaysAuthorized = false
    let hasFullAccuracy = false
    let lastKnownCoordinate: Coordinate? = nil

    func requestAlwaysAuthorizationIfNeeded() {}

    func makeAlwaysSession() -> any LocationSession {
        FakeLocationSession()
    }

    func setConditions(_ conditions: [MonitoredRegion]) async -> Bool {
        false
    }

    func removeAllConditions() async -> Bool {
        false
    }
}
