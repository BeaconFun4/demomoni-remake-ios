//
//  NearbyPieceAlertPreference.swift
//  demomoni-remake-ios
//

import Foundation
import Observation

/// 「アプリを閉じていても近くのピースを知らせる」のオン・オフ（せっていタブのスイッチ）。既定はオフ。
/// 端末の `UserDefaults` にキー 1 つで保存する。UI テスト・Unit テストのホストでは端末の値を読まず、書かない（`defaults` が `nil`）
@Observable
final class NearbyPieceAlertPreference {
    /// `UserDefaults` のキー
    nonisolated static let key = "nearbyPieceAlertsEnabled"

    /// オンか
    var isEnabled: Bool {
        didSet {
            defaults?.set(isEnabled, forKey: Self.key)
        }
    }

    /// 端末に値があるか（一度でもスイッチを切り替えたか）。無ければ CLMonitor の条件も足していないので、起動時に片付けなくてよい
    var hasStoredValue: Bool {
        defaults?.object(forKey: Self.key) != nil
    }

    @ObservationIgnored private let defaults: UserDefaults?

    /// - Parameter defaults: 保存先。`nil` ならメモリ上だけで持つ（オフから始まる）
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        isEnabled = defaults?.bool(forKey: Self.key) ?? false
    }
}
