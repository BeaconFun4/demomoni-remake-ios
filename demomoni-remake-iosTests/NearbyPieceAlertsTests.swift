//
//  NearbyPieceAlertsTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData
import Testing

/// テストから許可と出来事を決められる見張り
private final class StubBeaconRegionMonitor: BeaconRegionMonitor {
    let events: AsyncStream<BeaconRegionEvent>
    var isAlwaysAuthorizedWithFullAccuracy: Bool
    private(set) var conditions: [MonitoredBeacon]?
    private(set) var removeAllCount = 0
    private(set) var sessions: [StubAlwaysSession] = []
    private let continuation: AsyncStream<BeaconRegionEvent>.Continuation

    init(isAlwaysAuthorized: Bool) {
        (events, continuation) = AsyncStream.makeStream(of: BeaconRegionEvent.self)
        isAlwaysAuthorizedWithFullAccuracy = isAlwaysAuthorized
    }

    /// 終えていない session の数
    var activeSessionCount: Int {
        sessions.count { !$0.isInvalidated }
    }

    func makeAlwaysSession() -> any LocationSession {
        let session = StubAlwaysSession()
        sessions.append(session)
        return session
    }

    func setConditions(_ conditions: [MonitoredBeacon]) async {
        self.conditions = conditions
    }

    func removeAllConditions() async {
        conditions = nil
        removeAllCount += 1
    }
}

private final class StubAlwaysSession: LocationSession {
    private(set) var isInvalidated = false

    func invalidate() {
        isInvalidated = true
    }
}

private final class StubPieceNotifier: PieceNotifier {
    var isAllowed: Bool
    private(set) var posted: [PieceNotificationContent] = []

    init(isAllowed: Bool) {
        self.isAllowed = isAllowed
    }

    func areNotificationsAllowed() async -> Bool {
        isAllowed
    }

    func post(_ notification: PieceNotificationContent) async {
        posted.append(notification)
    }
}

/// スイッチ・許可と、CLMonitor の条件・session・通知のつながり
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NearbyPieceAlertsTests {
    private let catalog = Catalog.bundled

    private func makeAlerts(
        isEnabled: Bool,
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
        return NearbyPieceAlerts(
            preference: preference,
            catalog: catalog,
            container: container,
            monitor: monitor,
            notifier: notifier,
            isAppActive: { isAppActive }
        )
    }

    /// 許可がそろった見張りと通知で作る
    private func makeAuthorizedAlerts(
        isEnabled: Bool = true,
        monitor: StubBeaconRegionMonitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true),
        notifier: StubPieceNotifier = StubPieceNotifier(isAllowed: true),
        container: ModelContainer,
        isAppActive: Bool = false
    ) -> NearbyPieceAlerts {
        makeAlerts(isEnabled: isEnabled, monitor: monitor, notifier: notifier, container: container, isAppActive: isAppActive)
    }

    /// オンで許可がそろっていれば、常にの session を持ち、まだ獲得していないピースのビーコンを見張る
    @Test
    func monitorsWhenEnabledAndAuthorized() async throws {
        let container = try ModelContainer.demomoni(inMemory: true)
        let otherPieceIDs = catalog.pieces.map(\.id).filter { $0 != 3 }
        try PieceCollection(context: container.mainContext).collectAll(pieceIDs: otherPieceIDs, at: .now)
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: container)

        await alerts.refresh()
        #expect(alerts.isMonitoring)
        #expect(monitor.activeSessionCount == 1)
        #expect(monitor.conditions?.map(\.identifier) == ["beacon-3"])

        await alerts.refresh()
        #expect(monitor.sessions.count == 1)
    }

    /// オンでも、位置情報が「常に」でない・通知が許可されていなければ見張らない（条件を外し、session を持たない）
    @Test(arguments: [(false, true), (true, false)])
    func doesNotMonitorWithoutPermission(isAlwaysAuthorized: Bool, areNotificationsAllowed: Bool) async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: isAlwaysAuthorized)
        let alerts = makeAlerts(
            isEnabled: true,
            monitor: monitor,
            notifier: StubPieceNotifier(isAllowed: areNotificationsAllowed),
            container: try .demomoni(inMemory: true)
        )

        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.conditions == nil)
        #expect(monitor.removeAllCount == 1)
        #expect(monitor.activeSessionCount == 0)
    }

    /// オフにしたら、条件をすべて外して session を終える
    @Test
    func stopsMonitoringWhenDisabled() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))
        await alerts.refresh()
        #expect(alerts.isMonitoring)

        alerts.preference.isEnabled = false
        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.conditions == nil)
        #expect(monitor.activeSessionCount == 0)
    }

    /// 前にオンにしたことがあれば、オフのまま起動したときも条件を外す（CLMonitor の条件はアプリを終えても残る）
    @Test
    func removesConditionsWhenLaunchedDisabled() async throws {
        let defaults = try #require(UserDefaults(suiteName: "NearbyPieceAlertsTests-\(UUID().uuidString)"))
        defaults.set(false, forKey: NearbyPieceAlertPreference.key)
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAlerts(
            isEnabled: false,
            defaults: defaults,
            monitor: monitor,
            notifier: StubPieceNotifier(isAllowed: true),
            container: try .demomoni(inMemory: true)
        )

        await alerts.refresh()
        #expect(monitor.removeAllCount == 1)
        #expect(monitor.sessions.isEmpty)
    }

    /// オンにしたことが無ければ、CLMonitor に触れない（スイッチがオフの人の挙動を変えない）
    @Test
    func doesNothingWhenNeverEnabled() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(isEnabled: false, monitor: monitor, container: try .demomoni(inMemory: true))

        await alerts.refresh()
        #expect(monitor.removeAllCount == 0)
        #expect(monitor.conditions == nil)
        #expect(monitor.sessions.isEmpty)
    }

    /// まだ獲得していないピースのビーコンの範囲に入ったら通知を出す。獲得は保存しない
    @Test
    func postsNotificationForUncollectedPiece() async throws {
        let container = try ModelContainer.demomoni(inMemory: true)
        let notifier = StubPieceNotifier(isAllowed: true)
        let alerts = makeAuthorizedAlerts(notifier: notifier, container: container)

        await alerts.handle(BeaconRegionEvent(identifier: "beacon-2", isInside: true, beacon: nil))
        #expect(notifier.posted.map(\.identifier) == ["piece-2"])
        #expect(try PieceCollection(context: container.mainContext).collectedPieceIDs().isEmpty)
    }

    /// 獲得済みのピース・アプリが前面のとき・オフのときは通知を出さない
    @Test
    func doesNotPostNotification() async throws {
        let container = try ModelContainer.demomoni(inMemory: true)
        try PieceCollection(context: container.mainContext).collect(pieceID: 2, at: .now)
        let event = BeaconRegionEvent(identifier: "beacon-2", isInside: true, beacon: nil)

        let collectedNotifier = StubPieceNotifier(isAllowed: true)
        await makeAuthorizedAlerts(notifier: collectedNotifier, container: container).handle(event)
        #expect(collectedNotifier.posted.isEmpty)

        let otherEvent = BeaconRegionEvent(identifier: "beacon-3", isInside: true, beacon: nil)
        let activeNotifier = StubPieceNotifier(isAllowed: true)
        await makeAuthorizedAlerts(notifier: activeNotifier, container: container, isAppActive: true).handle(otherEvent)
        #expect(activeNotifier.posted.isEmpty)

        let disabledNotifier = StubPieceNotifier(isAllowed: true)
        await makeAuthorizedAlerts(isEnabled: false, notifier: disabledNotifier, container: container).handle(otherEvent)
        #expect(disabledNotifier.posted.isEmpty)
    }

    /// テスト（`-uiTesting`・Unit テストのホスト）では、端末の値を読まず CLMonitor・通知を使わない
    @Test
    func liveAlertsDoNotUseLocationServicesWhileTesting() async throws {
        let alerts = NearbyPieceAlerts.live(
            options: LaunchOptions(usesLocationServices: false),
            catalog: catalog,
            container: try .demomoni(inMemory: true)
        )
        #expect(!alerts.preference.isEnabled)
        #expect(!alerts.preference.hasStoredValue)

        alerts.preference.isEnabled = true
        await alerts.refresh()
        #expect(!alerts.isMonitoring)
    }
}
