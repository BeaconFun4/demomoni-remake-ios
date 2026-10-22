//
//  NearbyAlertTestDoubles.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData

/// テストから許可と出来事を決められる見張り
final class StubBeaconRegionMonitor: BeaconRegionMonitor {
    let events: AsyncStream<BeaconRegionEvent>
    var isAlwaysAuthorized: Bool
    var hasFullAccuracy = true
    /// CLMonitor を開けるか（位置情報の許可が無い・未決定なら開けない）
    var canOpenMonitor = true
    private(set) var alwaysAuthorizationRequests = 0
    private(set) var conditions: [MonitoredBeacon]?
    private(set) var removeAllCount = 0
    private(set) var sessions: [StubAlwaysSession] = []
    private let continuation: AsyncStream<BeaconRegionEvent>.Continuation

    init(isAlwaysAuthorized: Bool) {
        (events, continuation) = AsyncStream.makeStream(of: BeaconRegionEvent.self)
        self.isAlwaysAuthorized = isAlwaysAuthorized
    }

    /// 終えていない session の数
    var activeSessionCount: Int {
        sessions.count { !$0.isInvalidated }
    }

    func requestAlwaysAuthorizationIfNeeded() {
        alwaysAuthorizationRequests += 1
    }

    func makeAlwaysSession() -> any LocationSession {
        let session = StubAlwaysSession()
        sessions.append(session)
        return session
    }

    /// 条件をそろえ始めたときに呼ぶ（そろえ終える前に利用者がしたことを入れるため）
    var onSetConditions: (() async -> Void)?

    func setConditions(_ conditions: [MonitoredBeacon]) async -> Bool {
        guard canOpenMonitor else {
            return false
        }
        await onSetConditions?()
        self.conditions = conditions
        return true
    }

    func removeAllConditions() async -> Bool {
        guard canOpenMonitor else {
            return false
        }
        conditions = nil
        removeAllCount += 1
        return true
    }
}

final class StubAlwaysSession: LocationSession {
    private(set) var isInvalidated = false

    func invalidate() {
        isInvalidated = true
    }
}

final class StubPieceNotifier: PieceNotifier {
    var isAllowed: Bool
    private(set) var posted: [PieceNotificationContent] = []
    /// 通知の許可を確かめたときに呼ぶ（確かめる前に何が済んでいるかを見るため）
    var onCheckAuthorization: (() -> Void)?
    /// 通知の許可を尋ねたときに呼ぶ（尋ねている間に利用者がしたことを入れるため）
    var onRequestAuthorization: (() -> Void)?
    private(set) var authorizationRequests = 0

    init(isAllowed: Bool) {
        self.isAllowed = isAllowed
    }

    func areNotificationsAllowed() async -> Bool {
        onCheckAuthorization?()
        return isAllowed
    }

    func requestAuthorization() async {
        authorizationRequests += 1
        onRequestAuthorization?()
    }

    func post(_ notification: PieceNotificationContent) async {
        posted.append(notification)
    }
}

extension NearbyPieceAlerts {
    /// テスト用の差し替えで作る
    static func stub(
        isEnabled: Bool,
        mayHaveConditions: Bool = false,
        defaults: UserDefaults? = nil,
        monitor: StubBeaconRegionMonitor,
        notifier: StubPieceNotifier,
        container: ModelContainer,
        isAppActive: Bool = false
    ) -> NearbyPieceAlerts {
        let preference = NearbyPieceAlertPreference(defaults: defaults)
        if isEnabled {
            preference.isEnabled = true
        }
        if mayHaveConditions {
            preference.mayHaveConditions = true
        }
        return NearbyPieceAlerts(
            preference: preference,
            catalog: .bundled,
            container: container,
            monitor: monitor,
            notifier: notifier,
            isAppActive: { isAppActive }
        )
    }
}
