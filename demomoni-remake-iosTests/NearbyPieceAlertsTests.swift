//
//  NearbyPieceAlertsTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData
import Testing

/// スイッチ・許可と、CLMonitor の条件・session・通知のつながり
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NearbyPieceAlertsTests {
    private let catalog = Catalog.bundled

    /// ピースのビーコン 1 台の条件の identifier
    private func identifier(pieceID: Int) throws -> String {
        NearbyPieceMonitoring.identifier(for: try #require(catalog.beacons.first { $0.beaconId == pieceID }))
    }

    /// ピースのビーコン 1 台の条件の範囲に入った出来事
    private func insideEvent(pieceID: Int) throws -> BeaconRegionEvent {
        BeaconRegionEvent(identifier: try identifier(pieceID: pieceID), isInside: true, beacon: nil)
    }

    private func makeAlerts(
        isEnabled: Bool,
        mayHaveConditions: Bool = false,
        defaults: UserDefaults? = nil,
        monitor: StubBeaconRegionMonitor,
        notifier: StubPieceNotifier,
        container: ModelContainer,
        isAppActive: Bool = false
    ) -> NearbyPieceAlerts {
        .stub(
            isEnabled: isEnabled,
            mayHaveConditions: mayHaveConditions,
            defaults: defaults,
            monitor: monitor,
            notifier: notifier,
            container: container,
            isAppActive: isAppActive
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
        #expect(monitor.conditions?.map(\.identifier) == [try identifier(pieceID: 3)])
        #expect(alerts.preference.mayHaveConditions)

        await alerts.refresh()
        #expect(monitor.sessions.count == 1)
    }

    /// バックグラウンドで起こされたときに出来事を受け取れるよう、通知の許可を確かめる（`await` する）前に session を持つ
    @Test
    func holdsSessionBeforeCheckingNotificationAuthorization() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let notifier = StubPieceNotifier(isAllowed: true)
        var sessionsWhenChecked: Int?
        notifier.onCheckAuthorization = { sessionsWhenChecked = monitor.activeSessionCount }
        let alerts = makeAuthorizedAlerts(monitor: monitor, notifier: notifier, container: try .demomoni(inMemory: true))

        await alerts.refresh()
        #expect(sessionsWhenChecked == 1)
    }

    /// 獲得が進んだら、決め直したときに条件からそのピースを外す。未獲得が上限を超える間は UUID ごと、収まったら 1 台ずつにする
    @Test
    func updatesConditionsAfterCollecting() async throws {
        let container = try ModelContainer.demomoni(inMemory: true)
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: container)

        await alerts.refresh()
        #expect(monitor.conditions?.count == 1)
        #expect(monitor.conditions?.first?.minor == nil)

        let collected = catalog.pieces.map(\.id).prefix(catalog.pieces.count - NearbyPieceMonitoring.conditionLimit)
        try PieceCollection(context: container.mainContext).collectAll(pieceIDs: collected, at: .now)
        await alerts.refresh()
        #expect(monitor.conditions?.count == NearbyPieceMonitoring.conditionLimit)
        #expect(monitor.conditions?.allSatisfy { $0.minor != nil } == true)
        #expect(monitor.conditions?.contains { $0.identifier == (try? identifier(pieceID: collected[0])) } == false)
    }

    /// CLMonitor を開けなかったら（位置情報の許可が無い・未決定）、見張っていることにしない
    @Test
    func doesNotMonitorWhenMonitorCannotOpen() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        monitor.canOpenMonitor = false
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))

        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.conditions == nil)

        monitor.canOpenMonitor = true
        await alerts.refresh()
        #expect(alerts.isMonitoring)
        #expect(monitor.conditions?.isEmpty == false)
    }

    /// オンでも、位置情報が「常に」でない・通知が許可されていなければ見張らない（session を持たない）。
    /// 条件は外さず、CLMonitor を開かない（#120）
    @Test(arguments: [(false, true), (true, false)])
    func doesNotMonitorWithoutPermission(isAlwaysAuthorized: Bool, areNotificationsAllowed: Bool) async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: isAlwaysAuthorized)
        let alerts = makeAlerts(
            isEnabled: true,
            mayHaveConditions: true,
            monitor: monitor,
            notifier: StubPieceNotifier(isAllowed: areNotificationsAllowed),
            container: try .demomoni(inMemory: true)
        )

        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.conditions == nil)
        #expect(monitor.removeAllCount == 0)
        #expect(monitor.activeSessionCount == 0)
        #expect(alerts.preference.mayHaveConditions)
    }

    /// オンにしたときだけ、通知と位置情報の「常に許可」を尋ね、許可の状態を読む。オフにしたら尋ねず、状態も持たない
    @Test
    func requestsPermissionsOnlyWhenTurnedOn() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: false)
        let notifier = StubPieceNotifier(isAllowed: false)
        let alerts = makeAlerts(isEnabled: false, monitor: monitor, notifier: notifier, container: try .demomoni(inMemory: true))

        alerts.preference.isEnabled = true
        await alerts.preferenceDidChange()
        #expect(notifier.authorizationRequests == 1)
        #expect(monitor.alwaysAuthorizationRequests == 1)
        #expect(alerts.permissionStatus == NearbyAlertPermissionStatus(
            isLocationAlways: false,
            hasFullAccuracy: true,
            areNotificationsAllowed: false
        ))
        #expect(!alerts.isMonitoring)

        alerts.preference.isEnabled = false
        await alerts.preferenceDidChange()
        #expect(notifier.authorizationRequests == 1)
        #expect(monitor.alwaysAuthorizationRequests == 1)
        #expect(alerts.permissionStatus == nil)
    }

    /// 通知の許可を尋ねている間にオフに戻されたら、位置情報の「常に許可」は尋ねない
    @Test
    func doesNotRequestLocationWhenTurnedOffWhileRequestingNotifications() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: false)
        let notifier = StubPieceNotifier(isAllowed: false)
        let alerts = makeAlerts(isEnabled: false, monitor: monitor, notifier: notifier, container: try .demomoni(inMemory: true))
        notifier.onRequestAuthorization = { alerts.preference.isEnabled = false }

        alerts.preference.isEnabled = true
        await alerts.preferenceDidChange()
        #expect(notifier.authorizationRequests == 1)
        #expect(monitor.alwaysAuthorizationRequests == 0)
        #expect(alerts.permissionStatus == nil)
    }

    /// 起動時・アプリに戻ったときの決め直しでは許可を尋ねない。設定アプリで許可されて戻ったら見張り始める
    @Test
    func startsMonitoringAfterPermissionsAreGrantedInSettings() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: false)
        let notifier = StubPieceNotifier(isAllowed: false)
        let alerts = makeAlerts(isEnabled: true, monitor: monitor, notifier: notifier, container: try .demomoni(inMemory: true))
        await alerts.refresh()
        #expect(!alerts.isMonitoring)

        monitor.isAlwaysAuthorized = true
        notifier.isAllowed = true
        await alerts.refresh()
        #expect(alerts.isMonitoring)
        #expect(alerts.permissionStatus?.isSufficient == true)
        #expect(notifier.authorizationRequests == 0)
        #expect(monitor.alwaysAuthorizationRequests == 0)
    }

    /// 「常に」でも正確な位置情報がオフなら見張らない
    @Test
    func doesNotMonitorWithReducedAccuracy() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        monitor.hasFullAccuracy = false
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))

        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.sessions.isEmpty)
        #expect(alerts.permissionStatus?.hasFullAccuracy == false)
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

        await alerts.handle(try insideEvent(pieceID: 2))
        #expect(notifier.posted.map(\.identifier) == ["piece-2"])
        #expect(try PieceCollection(context: container.mainContext).collectedPieceIDs().isEmpty)
    }

    /// 獲得済みのピース・アプリが前面のとき・オフのときは通知を出さない
    @Test
    func doesNotPostNotification() async throws {
        let container = try ModelContainer.demomoni(inMemory: true)
        try PieceCollection(context: container.mainContext).collect(pieceID: 2, at: .now)
        let event = try insideEvent(pieceID: 2)

        let collectedNotifier = StubPieceNotifier(isAllowed: true)
        await makeAuthorizedAlerts(notifier: collectedNotifier, container: container).handle(event)
        #expect(collectedNotifier.posted.isEmpty)

        let otherEvent = try insideEvent(pieceID: 3)
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
        #expect(!alerts.preference.mayHaveConditions)

        alerts.preference.isEnabled = true
        await alerts.refresh()
        #expect(!alerts.isMonitoring)
    }
}
