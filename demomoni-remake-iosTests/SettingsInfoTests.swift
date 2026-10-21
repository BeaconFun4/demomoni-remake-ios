//
//  SettingsInfoTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct SettingsInfoTests {
    /// バージョンとビルド番号は「1.0（3）」の形で出す
    @Test
    func versionTextJoinsVersionAndBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "34"]
        #expect(SettingsInfo.versionText(infoDictionary: info) == "1.2.0（34）")
    }

    /// ビルド番号が無ければバージョンだけ、バージョンが無ければ「-」
    @Test
    func versionTextWithoutBuildOrVersion() {
        #expect(SettingsInfo.versionText(infoDictionary: ["CFBundleShortVersionString": "1.0"]) == "1.0")
        #expect(SettingsInfo.versionText(infoDictionary: ["CFBundleVersion": "3"]) == "-")
        #expect(SettingsInfo.versionText(infoDictionary: nil) == "-")
    }

    /// アプリの Info.plist のバージョンが出る
    @Test
    func versionTextOfMainBundle() throws {
        let version = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(SettingsInfo.versionText(infoDictionary: Bundle.main.infoDictionary).hasPrefix(version))
    }

    /// ニコモジ+ のライセンスの本文がバンドルに入っていて、SIL OFL 1.1 と著作権表示を含む
    @Test
    func fontLicenseTextIsBundled() throws {
        let text = try #require(SettingsInfo.fontLicenseText())
        #expect(text.contains("SIL OPEN FONT LICENSE Version 1.1"))
        #expect(text.contains("Copyright"))
    }
}
