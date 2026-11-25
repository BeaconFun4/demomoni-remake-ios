//
//  NearbyPieceMonitoring.swift
//  demomoni-remake-ios
//

import Foundation

/// CLMonitor で見張る円の条件（`CLMonitor.CircularGeographicCondition` の値）
nonisolated struct MonitoredRegion: Hashable, Sendable {
    /// CLMonitor に足すときの identifier
    let identifier: String
    /// 円の中心
    let center: Coordinate
    /// 円の半径（メートル）
    let radius: Double
}

/// CLMonitor から届く出来事
nonisolated struct RegionEvent: Equatable, Sendable {
    /// 円の内側にいるか
    enum State: Sendable {
        /// 内側に入った（`.satisfied`）
        case inside
        /// 外側に出た（`.unsatisfied`）
        case outside
        /// まだ分からない・見張っていない
        case unknown
    }

    /// 出来事の条件の identifier
    let identifier: String
    let state: State
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
    /// （前の版のビーコンの条件も同じ名前の CLMonitor にあり、条件をそろえるときに外れる）
    static let monitorName = "nearby-pieces"
    /// 1 つのアプリで見張れる条件の数の上限（CoreLocation の地域の監視と同じ 20）
    static let conditionLimit = 20
    /// 選び直す円の半径の下限（メートル）。小さすぎる円は、出たことが分かりにくいため
    static let minimumBoundaryRadius: Double = 200
    /// 通知の `userInfo` のピースの id のキー
    static let pieceIDKey = "pieceID"
    /// 近くのピースの通知の identifier の頭（続けてピースの id）
    static let notificationIdentifierPrefix = "piece-"
    /// 選び直す円の条件の identifier の頭
    static let boundaryIdentifierPrefix = "boundary-"

    /// ピースの場所の円の条件の identifier。ピースの id・緯度・経度・半径を入れる
    /// （CLMonitor の条件はアプリを終えても残るので、同梱データの場所や半径が変わったら別の条件として足し直すため）
    static func identifier(for piece: Piece) -> String {
        "area-\(piece.id)-\(format(piece.latitude))-\(format(piece.longitude))-\(format(PieceArea.radius))"
    }

    /// 選び直す円の条件の identifier。中心と半径を入れる（選び直すたびに別の条件として足し直すため）
    static func boundaryIdentifier(center: Coordinate, radius: Double) -> String {
        "\(boundaryIdentifierPrefix)\(format(center.latitude))-\(format(center.longitude))-\(format(radius))"
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

    /// 見張る条件。まだ獲得していないピースの場所の円（半径は `PieceArea.radius`）が上限に収まれば、すべてを見張る。
    /// 収まらなければ、今いる場所に近いピースを上限より 1 つ少なく選び、残りの 1 つで今いる場所を中心にした「選び直す円」を見張る。
    /// 選び直す円は、選ばなかったピースのうちいちばん近いものの範囲に届かない大きさにし、そこから出たら選び直す（`needsReselection(after:)`）。
    /// 今いる場所が分からなければ、同梱データの順に上限まで選ぶ（アプリを開いて場所が分かったら選び直す）
    static func conditions(
        pieces: [Piece],
        collectedPieceIDs: Set<Int>,
        near location: Coordinate?,
        limit: Int = conditionLimit
    ) -> [MonitoredRegion] {
        let uncollected = pieces.filter { !collectedPieceIDs.contains($0.id) }
        guard uncollected.count > limit else {
            return uncollected.map(region(for:))
        }
        guard let location, limit > 1 else {
            return uncollected.prefix(limit).map(region(for:))
        }
        // 同じ距離なら同梱データの順（sorted は安定）
        let sorted = uncollected
            .map { (piece: $0, distance: location.distance(to: $0.coordinate)) }
            .sorted { $0.distance < $1.distance }
        let monitored = sorted.prefix(limit - 1).map { region(for: $0.piece) }
        let boundaryRadius = max(sorted[limit - 1].distance - PieceArea.radius, minimumBoundaryRadius)
        let boundary = MonitoredRegion(
            identifier: boundaryIdentifier(center: location, radius: boundaryRadius),
            center: location,
            radius: boundaryRadius
        )
        return monitored + [boundary]
    }

    /// 出来事で選び直すか。選び直す円から出たときだけ
    static func needsReselection(after event: RegionEvent) -> Bool {
        event.identifier.hasPrefix(boundaryIdentifierPrefix) && event.state == .outside
    }

    /// 出来事で知らせるピース。範囲に入った・アプリが前面でない・まだ獲得していないピースの円のときだけ。
    /// 同梱データの今の場所と半径の条件でなければ（前の版の条件・選び直す円）知らせない
    static func pieceToNotify(
        for event: RegionEvent,
        catalog: Catalog,
        collectedPieceIDs: Set<Int>,
        isAppActive: Bool
    ) -> Piece? {
        guard event.state == .inside, !isAppActive else {
            return nil
        }
        guard let piece = catalog.pieces.first(where: { identifier(for: $0) == event.identifier }),
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

    /// ピースの場所の円の条件
    private static func region(for piece: Piece) -> MonitoredRegion {
        MonitoredRegion(identifier: identifier(for: piece), center: piece.coordinate, radius: PieceArea.radius)
    }

    /// identifier に入れる数（小数 6 桁。緯度・経度ではおよそ 0.1 m）。端末の地域の設定によらず、小数点は「.」
    private static func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
