//
//  NearbyPieceAlertPreference.swift
//  demomoni-remake-ios
//

import Foundation
import Observation

/// 「アプリを閉じていても近くのピースを知らせる」のオン・オフ（せっていタブのスイッチ）。既定はオフ。
/// 端末の `UserDefaults` に保存する。UI テスト・Unit テストのホストでは端末の値を読まず、書かない（`defaults` が `nil`）
@Observable
final class NearbyPieceAlertPreference {
    /// スイッチの値の `UserDefaults` のキー
    nonisolated static let key = "nearbyPieceAlertsEnabled"
    /// `mayHaveConditions` の `UserDefaults` のキー
    nonisolated static let conditionsKey = "nearbyPieceAlertsMayHaveConditions"

    /// オンか
    var isEnabled: Bool {
        didSet {
            defaults?.set(isEnabled, forKey: Self.key)
        }
    }

    /// `CLMonitor` に条件が残っているかもしれないか。条件をそろえたら立て、オフにした直後に外し終えたら下ろす。
    /// 条件はアプリを終えても残るが、片付けのためだけに起動時に `CLMonitor` を開くと落ちる疑いがある（#120）ので、
    /// 外すのはオフにした直後だけにし、下りていればオフにしても開かない
    @ObservationIgnored var mayHaveConditions: Bool {
        didSet {
            defaults?.set(mayHaveConditions, forKey: Self.conditionsKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    /// - Parameter defaults: 保存先。`nil` ならメモリ上だけで持つ（オフ・条件なしから始まる）
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        isEnabled = defaults?.bool(forKey: Self.key) ?? false
        mayHaveConditions = defaults?.bool(forKey: Self.conditionsKey) ?? false
    }
}
