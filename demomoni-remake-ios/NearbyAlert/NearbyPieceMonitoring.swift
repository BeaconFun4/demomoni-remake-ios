//
//  NearbyPieceMonitoring.swift
//  demomoni-remake-ios
//

import Foundation

/// CLMonitor で見張るビーコンの条件（`CLMonitor.BeaconIdentityCondition` の値）
nonisolated struct MonitoredBeacon: Hashable, Sendable {
    /// CLMonitor に足すときの identifier
    let identifier: String
    let uuid: UUID
    /// `nil` なら、この UUID のすべての major
    let major: UInt16?
    /// `nil` なら、この UUID（と major）のすべての minor
    let minor: UInt16?
}

/// CLMonitor から届く出来事
nonisolated struct BeaconRegionEvent: Equatable, Sendable {
    /// 出来事の条件の identifier
    let identifier: String
    /// 範囲に入ったか（`.satisfied`）
    let isInside: Bool
    /// どのビーコンで条件を満たしたか（`refinement`）。分からなければ `nil`
    let beacon: DetectedBeacon?
}

/// 近くのピースを知らせるローカル通知の中身
nonisolated struct PieceNotificationContent: Equatable, Sendable {
    /// 通知の identifier。ピースごとに同じ値にして、同じピースの通知を重ねない
    let identifier: String
    let title: String
    let body: String
    /// 通知の `userInfo` に入れるピースの id（`NearbyPieceMonitoring.pieceIDKey`）
    let pieceID: Int
}

/// 位置情報の許可（`CLAuthorizationStatus` を写した値）。判定を CoreLocation から切り出してテストするために使う
nonisolated enum LocationAuthorization: Sendable {
    case notDetermined
    case restricted
    case denied
    case always
    case whenInUse
    /// 今の SDK に無い値（`@unknown default`）
    case unknown
}

/// 「アプリを閉じていても近くのピースを知らせる」の判定。CoreLocation・UserNotifications から切り出してテストする
nonisolated enum NearbyPieceMonitoring {
    /// CLMonitor の名前。起動するたびに同じ名前で作り直すと、前に足した条件と出来事を受け取れる
    static let monitorName = "nearby-pieces"
    /// 1 つのアプリで見張れる条件の数の上限（CoreLocation の地域の監視と同じ 20）
    static let conditionLimit = 20
    /// 通知の `userInfo` のピースの id のキー
    static let pieceIDKey = "pieceID"
    /// 近くのピースの通知の identifier の頭（続けてピースの id）
    static let notificationIdentifierPrefix = "piece-"

    /// ビーコン 1 台の条件の identifier。UUID・major・minor を入れる
    /// （CLMonitor の条件はアプリを終えても残るので、同梱データの値が変わったら別の条件として足し直すため）
    static func identifier(for beacon: Beacon) -> String {
        "beacon-\(beacon.uuid.uuidString)-\(beacon.major)-\(beacon.minor)"
    }

    /// UUID のすべてのビーコンの条件の identifier
    static func identifier(uuid: UUID) -> String {
        "beacon-uuid-\(uuid.uuidString)"
    }

    /// ビーコン 1 台の条件の identifier から、そのビーコンを読む。ビーコン 1 台の条件でなければ `nil`
    static func beacon(fromIdentifier identifier: String) -> DetectedBeacon? {
        guard identifier.hasPrefix("beacon-"), !identifier.hasPrefix("beacon-uuid-") else {
            return nil
        }
        // UUID も「-」を含むので、後ろの 2 つを major・minor として読む
        let parts = identifier.dropFirst("beacon-".count).split(separator: "-")
        guard parts.count >= 3,
              let minor = UInt16(parts[parts.count - 1]),
              let major = UInt16(parts[parts.count - 2]),
              let uuid = UUID(uuidString: parts.dropLast(2).joined(separator: "-")) else {
            return nil
        }
        return DetectedBeacon(uuid: uuid, major: major, minor: minor)
    }

    /// 監視するか。スイッチがオンで、位置情報が「常に」・正確な位置情報がオン・通知が許可されているときだけ
    static func shouldMonitor(isEnabled: Bool, isLocationAlwaysAuthorized: Bool, areNotificationsAllowed: Bool) -> Bool {
        isEnabled && isLocationAlwaysAuthorized && areNotificationsAllowed
    }

    /// `CLMonitor` を開いてよいか。位置情報が「常に」か「使用中」のときだけ。
    /// 許可が無い・未決定のときに開くと CoreLocation の中で assert する疑いがあり、TestFlight の 1.0 (4) で起動直後に `CLMonitor.init(_:)` の中で落ちた（#120）。
    /// 許可が無ければ出来事も届かないので、開かなくても失うものは無い。分からない値（今後足される状態）も、安全な側に倒して開かない
    static func canOpenMonitor(_ authorization: LocationAuthorization) -> Bool {
        switch authorization {
        case .always, .whenInUse:
            true
        case .notDetermined, .restricted, .denied, .unknown:
            false
        }
    }

    /// 見張る条件。まだ獲得していないピースのビーコンが上限に収まれば 1 台ずつ、
    /// 収まらなければ UUID ごとにまとめる（どのビーコンかは出来事の `refinement` で分かる）
    static func conditions(beacons: [Beacon], collectedPieceIDs: Set<Int>, limit: Int = conditionLimit) -> [MonitoredBeacon] {
        let uncollected = beacons.filter { !collectedPieceIDs.contains($0.beaconId) }
        if uncollected.count <= limit {
            return uncollected.map {
                MonitoredBeacon(identifier: identifier(for: $0), uuid: $0.uuid, major: $0.major, minor: $0.minor)
            }
        }
        var uuids: [UUID] = []
        for beacon in uncollected where !uuids.contains(beacon.uuid) {
            uuids.append(beacon.uuid)
        }
        return uuids.prefix(limit).map {
            MonitoredBeacon(identifier: identifier(uuid: $0), uuid: $0, major: nil, minor: nil)
        }
    }

    /// 出来事で知らせるピース。範囲に入った・アプリが前面でない・まだ獲得していないピースのビーコンのときだけ。
    /// どのビーコンか分からない（UUID ごとの条件で `refinement` が無い）ときは知らせない（獲得済みのピースで知らせないため）
    static func pieceToNotify(
        for event: BeaconRegionEvent,
        catalog: Catalog,
        collectedPieceIDs: Set<Int>,
        isAppActive: Bool
    ) -> Piece? {
        guard event.isInside, !isAppActive else {
            return nil
        }
        guard let beacon = event.beacon ?? beacon(fromIdentifier: event.identifier),
              let piece = catalog.piece(forBeaconUUID: beacon.uuid, major: beacon.major, minor: beacon.minor),
              !collectedPieceIDs.contains(piece.id) else {
            return nil
        }
        return piece
    }

    /// 近くのピースの通知（`notification(for:)`）の identifier と `userInfo` から、ピースの id を読む。近くのピースの通知でなければ `nil`
    static func pieceID(fromNotificationIdentifier identifier: String, userInfo: [AnyHashable: Any]) -> Int? {
        guard identifier.hasPrefix(notificationIdentifierPrefix) else {
            return nil
        }
        return userInfo[pieceIDKey] as? Int ?? Int(identifier.dropFirst(notificationIdentifierPrefix.count))
    }

    /// ピースを知らせる通知の中身
    static func notification(for piece: Piece) -> PieceNotificationContent {
        PieceNotificationContent(
            identifier: "\(notificationIdentifierPrefix)\(piece.id)",
            title: "近くにピースがあるよ！",
            body: "さがすタブをひらいて、ピースをゲットしよう",
            pieceID: piece.id
        )
    }
}
