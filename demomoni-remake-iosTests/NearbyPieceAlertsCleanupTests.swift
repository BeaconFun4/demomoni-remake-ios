//
//  NearbyPieceAlertsCleanupTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData
import Testing

/// CLMonitor の条件を外す時機と、「条件が残っているかもしれない」の記録。
/// 起動時・前面に戻ったときは片付けのためだけに CLMonitor を開かず、オフにした直後にだけ外す（#120）
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NearbyPieceAlertsCleanupTests {
    private func makeAlerts(
        isEnabled: Bool,
        defaults: UserDefaults? = nil,
        monitor: StubBeaconRegionMonitor,
        notifier: StubPieceNotifier,
        container: ModelContainer
    ) -> NearbyPieceAlerts {
        .stub(isEnabled: isEnabled, defaults: defaults, monitor: monitor, notifier: notifier, container: container)
    }

    /// 許可がそろった見張りと通知で作る
    private func makeAuthorizedAlerts(
        isEnabled: Bool = true,
        monitor: StubBeaconRegionMonitor,
        container: ModelContainer
    ) -> NearbyPieceAlerts {
        makeAlerts(isEnabled: isEnabled, monitor: monitor, notifier: StubPieceNotifier(isAllowed: true), container: container)
    }

    /// オフにした直後は、条件をすべて外して session を終え、記録を下ろす
    @Test
    func stopsMonitoringWhenTurnedOff() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))
        await alerts.refresh()
        #expect(alerts.isMonitoring)
        #expect(alerts.preference.mayHaveConditions)

        alerts.preference.isEnabled = false
        await alerts.preferenceDidChange()
        #expect(!alerts.isMonitoring)
        #expect(monitor.conditions == nil)
        #expect(monitor.removeAllCount == 1)
        #expect(monitor.activeSessionCount == 0)
        #expect(!alerts.preference.mayHaveConditions)
    }

    /// 起動時・前面に戻ったときの決め直しでは、オフでも条件を外さない（片付けのためだけに CLMonitor を開かない。#120）。session は終える
    @Test
    func doesNotRemoveConditionsOnRefreshWhenDisabled() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))
        await alerts.refresh()
        #expect(alerts.isMonitoring)

        alerts.preference.isEnabled = false
        await alerts.refresh()
        #expect(!alerts.isMonitoring)
        #expect(monitor.removeAllCount == 0)
        #expect(monitor.activeSessionCount == 0)
        #expect(alerts.preference.mayHaveConditions)
    }

    /// オフのまま起動したら、記録があっても無くても（スイッチを切り替えたことがあっても）CLMonitor を開かない
    @Test(arguments: [(true, true), (true, false), (false, false)])
    func doesNotOpenMonitorWhenLaunchedDisabled(hasStoredSwitch: Bool, mayHaveConditions: Bool) async throws {
        let suiteName = "NearbyPieceAlertsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        if hasStoredSwitch {
            defaults.set(false, forKey: NearbyPieceAlertPreference.key)
        }
        defaults.set(mayHaveConditions, forKey: NearbyPieceAlertPreference.conditionsKey)
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAlerts(
            isEnabled: false,
            defaults: defaults,
            monitor: monitor,
            notifier: StubPieceNotifier(isAllowed: true),
            container: try .demomoni(inMemory: true)
        )

        await alerts.refresh()
        #expect(monitor.removeAllCount == 0)
        #expect(monitor.conditions == nil)
        #expect(monitor.sessions.isEmpty)
        #expect(NearbyPieceAlertPreference(defaults: defaults).mayHaveConditions == mayHaveConditions)
    }

    /// 条件をそろえたら記録を端末に保存し、オフにした直後に外し終えたら下ろす
    @Test
    func storesConditionsRecord() async throws {
        let suiteName = "NearbyPieceAlertsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let alerts = makeAlerts(
            isEnabled: true,
            defaults: defaults,
            monitor: StubBeaconRegionMonitor(isAlwaysAuthorized: true),
            notifier: StubPieceNotifier(isAllowed: true),
            container: try .demomoni(inMemory: true)
        )

        await alerts.refresh()
        #expect(NearbyPieceAlertPreference(defaults: defaults).mayHaveConditions)

        alerts.preference.isEnabled = false
        await alerts.preferenceDidChange()
        #expect(!NearbyPieceAlertPreference(defaults: defaults).mayHaveConditions)
    }

    /// 記録が下りていれば（条件を足したことが無い・外し終えた）、オフにしても CLMonitor を開かない
    @Test
    func doesNotOpenMonitorWhenTurnedOffWithoutConditions() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: false)
        let alerts = makeAlerts(
            isEnabled: true,
            monitor: monitor,
            notifier: StubPieceNotifier(isAllowed: true),
            container: try .demomoni(inMemory: true)
        )
        await alerts.refresh()

        alerts.preference.isEnabled = false
        await alerts.preferenceDidChange()
        #expect(monitor.removeAllCount == 0)
        #expect(!alerts.preference.mayHaveConditions)
    }

    /// オフにした直後でも、CLMonitor を開けなければ（位置情報の許可が無い・未決定）条件は外せないので、記録を残す。session は終える
    @Test
    func keepsRecordWhenMonitorCannotOpenOnTurningOff() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(monitor: monitor, container: try .demomoni(inMemory: true))
        await alerts.refresh()
        #expect(alerts.isMonitoring)

        monitor.canOpenMonitor = false
        alerts.preference.isEnabled = false
        await alerts.preferenceDidChange()
        #expect(!alerts.isMonitoring)
        #expect(monitor.removeAllCount == 0)
        #expect(monitor.activeSessionCount == 0)
        #expect(alerts.preference.mayHaveConditions)
    }

    /// オン → オフを続けて切り替えても、条件をそろえ終えてから外す（足すのと外すのが入れ違わない）
    @Test
    func processesTurningOnAndOffInOrder() async throws {
        let monitor = StubBeaconRegionMonitor(isAlwaysAuthorized: true)
        let alerts = makeAuthorizedAlerts(isEnabled: false, monitor: monitor, container: try .demomoni(inMemory: true))
        let (settingStarted, settingStartedContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        monitor.onSetConditions = {
            settingStartedContinuation.yield()
            // テストがオフに切り替えるまで、条件をそろえている途中のままにする
            for await _ in gate {
                break
            }
        }

        alerts.preference.isEnabled = true
        let turningOn = Task { await alerts.preferenceDidChange() }
        for await _ in settingStarted {
            break
        }
        alerts.preference.isEnabled = false
        let (offRequested, offRequestedContinuation) = AsyncStream.makeStream(of: Void.self)
        let turningOff = Task {
            offRequestedContinuation.yield()
            await alerts.preferenceDidChange()
        }
        // オフの決め直しが並んでから（Task が最初に止まるまで MainActor を離さない）、そろえ終える
        for await _ in offRequested {
            break
        }
        gateContinuation.finish()
        await turningOn.value
        await turningOff.value

        #expect(monitor.removeAllCount == 1)
        #expect(monitor.conditions == nil)
        #expect(!alerts.isMonitoring)
        #expect(monitor.activeSessionCount == 0)
        #expect(!alerts.preference.mayHaveConditions)
    }
}
