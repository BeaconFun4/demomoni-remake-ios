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
/// スイッチをオンにしたことの無い人には、許可を尋ねず、`CLMonitor`・`CLServiceSession` も作らない。
/// 起動時・前面に戻ったときに `CLMonitor` を開くのは、オンで許可がそろっている人だけ。条件を外すのはオフにした直後だけにする
/// （TestFlight の 1.0 (4) で、起動直後に片付けのために開いた `CLMonitor` の初期化で落ちた。#120）
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

    /// スイッチと許可から、見張るかを決め直す。起動したとき（バックグラウンドでの起動を含む）・アプリに戻ったときに呼ぶ。
    /// オフの人・オンでも許可が足りない人には `CLMonitor` を開かない（条件は残す）
    func refresh() async {
        await refresh(removesConditionsWhenDisabled: false)
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
        // オフにしたときは、ここでだけ条件を外す。オン → オフを素早く切り替えても足すのと外すのが入れ違わないよう、refresh() と同じ順番に並べる
        await refresh(removesConditionsWhenDisabled: true)
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

    /// 前の決め直しが終わってから決め直す（条件の足し外しが入れ違わないようにする）
    private func refresh(removesConditionsWhenDisabled: Bool) async {
        let previous = refreshTask
        let task = Task { [weak self] in
            await previous?.value
            await self?.performRefresh(removesConditionsWhenDisabled: removesConditionsWhenDisabled)
        }
        refreshTask = task
        await task.value
    }

    /// - Parameter removesConditionsWhenDisabled: オフのとき、条件が残っているかもしれなければ外すか（オフにした直後だけ `true`）
    private func performRefresh(removesConditionsWhenDisabled: Bool) async {
        guard preference.isEnabled else {
            permissionStatus = nil
            // 片付けのためだけに CLMonitor を開かない（#120）。オフの間は handle(_:) が通知を出さないので、条件が残っても見えない。
            // 外せなかった（位置情報の許可が無く開けなかった）ときは記録を残す
            if removesConditionsWhenDisabled, preference.mayHaveConditions, await monitor.removeAllConditions() {
                preference.mayHaveConditions = false
            }
            stopMonitoring()
            return
        }
        let isLocationAlwaysAuthorized = monitor.isAlwaysAuthorized && monitor.hasFullAccuracy
        // バックグラウンドで起こされたときは、すぐに session を持たないと出来事が届かない（CLServiceSession.h）
        if isLocationAlwaysAuthorized, session == nil {
            session = monitor.makeAlwaysSession()
        }
        let areNotificationsAllowed = await notifier.areNotificationsAllowed()
        permissionStatus = NearbyAlertPermissionStatus(
            isLocationAlways: monitor.isAlwaysAuthorized,
            hasFullAccuracy: monitor.hasFullAccuracy,
            areNotificationsAllowed: areNotificationsAllowed
        )
        let shouldMonitor = NearbyPieceMonitoring.shouldMonitor(
            isEnabled: preference.isEnabled,
            isLocationAlwaysAuthorized: isLocationAlwaysAuthorized,
            areNotificationsAllowed: areNotificationsAllowed
        )
        guard shouldMonitor else {
            // 許可が足りないだけなら条件は残し、CLMonitor を開かない（許可が無ければ出来事は届かない。#120）
            stopMonitoring()
            return
        }
        if session == nil {
            session = monitor.makeAlwaysSession()
        }
        let collected = (try? PieceCollection(context: container.mainContext).collectedPieceIDs()) ?? []
        // 位置情報の許可が無く CLMonitor を開けなかったときは、見張っていることにしない
        isMonitoring = await monitor.setConditions(
            NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: collected)
        )
        if isMonitoring {
            preference.mayHaveConditions = true
        }
    }

    /// session を捨て、見張っていないことにする（`CLMonitor` には触れない）
    private func stopMonitoring() {
        session?.invalidate()
        session = nil
        isMonitoring = false
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
