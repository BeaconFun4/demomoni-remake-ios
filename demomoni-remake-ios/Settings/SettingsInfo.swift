//
//  SettingsInfo.swift
//  demomoni-remake-ios
//

import Foundation

/// せっていタブに出す情報（アプリのバージョン・フォントのライセンス）を、バンドルから読む
nonisolated enum SettingsInfo {
    /// ニコモジ+ のライセンス（SIL Open Font License 1.1）の本文と著作権表示のファイル（`Resources/Fonts/`）
    static let fontLicenseResourceName = "NicoMojiPlus-OFL"
    static let fontLicenseResourceExtension = "txt"

    /// バージョンの表示。`CFBundleShortVersionString` と `CFBundleVersion` を「1.0（3）」の形にする。
    /// ビルド番号が無ければバージョンだけ、バージョンが無ければ「-」
    static func versionText(infoDictionary: [String: Any]?) -> String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?):
            return "\(version)（\(build)）"
        case let (version?, nil):
            return version
        default:
            return "-"
        }
    }

    /// ニコモジ+ のライセンスの本文。バンドルに無ければ `nil`
    static func fontLicenseText(in bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: fontLicenseResourceName, withExtension: fontLicenseResourceExtension) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
