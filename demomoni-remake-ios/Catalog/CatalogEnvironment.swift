//
//  CatalogEnvironment.swift
//  demomoni-remake-ios
//

import SwiftUI

extension Catalog {
    /// アプリに同梱したデータ。最初に使うときにバンドルから 1 回だけ読む。
    /// 同梱データはビルドに入る固定のファイルなので、読めないのはビルドの不具合として止める
    nonisolated static let bundled: Self = {
        do {
            return try load()
        } catch {
            fatalError("同梱データを読めない: \(error)")
        }
    }()
}

extension EnvironmentValues {
    /// 画面で使う同梱データ。プレビューやテストでは差し替えられる
    @Entry var catalog: Catalog = .bundled
}
