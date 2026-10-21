//
//  NearbyPieceAlerts.swift
//  demomoni-remake-ios
//

import Foundation
import Observation
import SwiftData
import UIKit

/// 「アプリを閉じていても近くのピースを知らせる」。スイッチがオンで許可がそろっている間だけ、
/// `CLMonitor` でまだ獲得していないピースのビーコンを見張り、範囲に入ったらローカル通知を出す（獲得は保存しない。さがすタブで行う）。
/// スイッチがオフ（既定）の人には、許可を尋ねず、`CLMonitor`・`CLServiceSession` も作らない
@Observable
final class NearbyPieceAlerts {
    /// スイッチのオン・オフ
    let preference: NearbyPieceAlertPreference
    /// 今、見張っているか
    private(set) var isMonitoring = false
    /// 要る許可の状態。オンの間だけ `refresh()` で読む（オフのときは `nil`）
    private(set) var permissionStatus: NearbyAlertPermissionStatus?

    @ObservationIgnored private let catalog: Catalog
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let monitor: any BeaconRegionMonitor
    @ObservationIgnored private let notifier: any PieceNotifier
    /// アプリが前面か（前面のときは通知を出さない）
    @ObservationIgnored private let isAppActive: () -> Bool
    /// 見張っている間持つ、位置情報（常に）の session
    @ObservationIgnored private var session: (any LocationSession)?
    /// `monitor.events` を受け続ける処理
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    /// 最後に始めた `refresh()`。前のものが終わってから次を行う（条件の足し外しが入れ違わないようにする）
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(
        preference: NearbyPieceAlertPreference,
        catalog: Catalog,
        container: ModelContainer,
        monitor: any BeaconRegionMonitor,
        notifier: any PieceNotifier,
        isAppActive: @escaping () -> Bool
    ) {
        self.preference = preference
        self.catalog = catalog
        self.container = container
        self.monitor = monitor
        self.notifier = notifier
        self.isAppActive = isAppActive
        eventTask = Task { [weak self, events = monitor.events] in
            for await event in events {
                await self?.handle(event)
            }
        }
    }

    isolated deinit {
        eventTask?.cancel()
        refreshTask?.cancel()
        session?.invalidate()
    }

    /// スイッチと許可から、見張るかを決め直す。起動したとき（バックグラウンドでの起動を含む）・スイッチを切り替えたとき・アプリに戻ったときに呼ぶ
    func refresh() async {
        let previous = refreshTask
        let task = Task { [weak self] in
            await previous?.value
            await self?.performRefresh()
        }
        refreshTask = task
        await task.value
    }

    /// スイッチを切り替えたときに呼ぶ。オンにしたときだけ、通知と位置情報の「常に許可」を尋ねてから決め直す
    /// （許可を尋ねるのはここだけ。起動時・さがすタブでは尋ねない）
    func preferenceDidChange() async {
        if preference.isEnabled {
            await notifier.requestAuthorization()
            // 通知の許可を尋ねている間にオフに戻されたら、位置情報は尋ねない
            if preference.isEnabled {
                monitor.requestAlwaysAuthorizationIfNeeded()
            }
        }
        await refresh()
    }

    /// `CLMonitor` の出来事を扱う。まだ獲得していないピースのビーコンの範囲に入り、アプリが前面でなければ通知を出す
    func handle(_ event: BeaconRegionEvent) async {
        guard preference.isEnabled,
              let collected = try? PieceCollection(context: container.mainContext).collectedPieceIDs(),
              let piece = NearbyPieceMonitoring.pieceToNotify(
                  for: event,
                  catalog: catalog,
                  collectedPieceIDs: collected,
                  isAppActive: isAppActive()
              ) else {
            return
        }
        await notifier.post(NearbyPieceMonitoring.notification(for: piece))
    }

    private func performRefresh() async {
        if !preference.isEnabled {
            permissionStatus = nil
        }
        // オンにしたことの無い人には CLMonitor を作らない（条件も足していない）
        guard preference.isEnabled || preference.hasStoredValue || isMonitoring || session != nil else {
            return
        }
        let isLocationAlwaysAuthorized = monitor.isAlwaysAuthorized && monitor.hasFullAccuracy
        // バックグラウンドで起こされたときは、すぐに session を持たないと出来事が届かない（CLServiceSession.h）
        if preference.isEnabled, isLocationAlwaysAuthorized, session == nil {
            session = monitor.makeAlwaysSession()
        }
        let areNotificationsAllowed = preference.isEnabled ? await notifier.areNotificationsAllowed() : false
        if preference.isEnabled {
            permissionStatus = NearbyAlertPermissionStatus(
                isLocationAlways: monitor.isAlwaysAuthorized,
                hasFullAccuracy: monitor.hasFullAccuracy,
                areNotificationsAllowed: areNotificationsAllowed
            )
        }
        let shouldMonitor = NearbyPieceMonitoring.shouldMonitor(
            isEnabled: preference.isEnabled,
            isLocationAlwaysAuthorized: isLocationAlwaysAuthorized,
            areNotificationsAllowed: areNotificationsAllowed
        )
        if shouldMonitor {
            if session == nil {
                session = monitor.makeAlwaysSession()
            }
            let collected = (try? PieceCollection(context: container.mainContext).collectedPieceIDs()) ?? []
            // 位置情報の許可が無く CLMonitor を開けなかったときは、見張っていることにしない
            isMonitoring = await monitor.setConditions(
                NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: collected)
            )
        } else {
            await monitor.removeAllConditions()
            session?.invalidate()
            session = nil
            isMonitoring = false
        }
    }
}

extension NearbyPieceAlerts {
    /// アプリで使うもの。テスト（`-uiTesting`・Unit テストのホスト）では端末の値を読まず、`CLMonitor`・`CLServiceSession`・通知を使わない
    static func live(options: LaunchOptions, catalog: Catalog, container: ModelContainer) -> NearbyPieceAlerts {
        guard options.usesLocationServices else {
            return NearbyPieceAlerts(
                preference: NearbyPieceAlertPreference(defaults: nil),
                catalog: catalog,
                container: container,
                monitor: InactiveBeaconRegionMonitor(),
                notifier: InactivePieceNotifier(),
                isAppActive: { true }
            )
        }
        return NearbyPieceAlerts(
            preference: NearbyPieceAlertPreference(defaults: .standard),
            catalog: catalog,
            container: container,
            monitor: CoreLocationBeaconRegionMonitor.shared,
            notifier: UserNotificationPieceNotifier(),
            isAppActive: { UIApplication.shared.applicationState == .active }
        )
    }
}
