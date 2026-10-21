//
//  AppInfoTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct AppInfoTests {
    /// Configs の APP_BUNDLE_IDENTIFIER が Info.plist に反映されていることを確認する。
    /// Release 構成（App Store 版）は Project.xcconfig の値、Debug 構成は Debug.xcconfig の値（TestFlight に別のアプリとして配る）。
    /// Bundle ID は App Store Connect のアプリと結びつくので、変えるときはこのテストもあわせて直す
    @Test
    func bundleIdentifierComesFromXcconfig() {
        #if DEBUG
        #expect(Bundle.main.bundleIdentifier == "jp.shilokuma.Demomoni-debug")
        #else
        #expect(Bundle.main.bundleIdentifier == "jp.shilokuma.Demomoni")
        #endif
    }

    /// Configs/Project.xcconfig の MARKETING_VERSION が、整数を「.」でつないだ形式（1.0 / 1.0.0）で Info.plist に反映されていることを確認する
    @Test
    func marketingVersionIsNumeric() throws {
        let version = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        #expect((1...3).contains(components.count), "MARKETING_VERSION は 3 つまでの整数を「.」でつなぐ: \(version)")
        #expect(components.allSatisfy { Int($0) != nil }, "各要素は整数で指定する: \(version)")
    }

    /// CURRENT_PROJECT_VERSION が正の整数として Info.plist に反映されていることを確認する
    @Test
    func buildNumberIsPositiveInteger() throws {
        let build = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        let number = try #require(Int(build), "CURRENT_PROJECT_VERSION は整数で指定する: \(build)")
        #expect(number > 0)
    }

    /// Configs の INFOPLIST_KEY_CFBundleDisplayName が、記号（「！」）まで欠けずに Info.plist に反映されていることを確認する。
    /// Debug 構成は App Store 版と見分けるため「でももに！β」
    @Test
    func displayNameComesFromXcconfig() {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #if DEBUG
        #expect(name == "でももに！β")
        #else
        #expect(name == "でももに！")
        #endif
    }

    /// Debug 構成のアプリのアイコンは AppIcon-Debug（下部に「debug」と書いたもの）、Release 構成は AppIcon。
    /// アセットカタログのコンパイルで、使うアイコンの名前が Info.plist の CFBundleIcons に入る
    @Test
    func appIconNameDependsOnConfiguration() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #if DEBUG
        #expect(primary["CFBundleIconName"] as? String == "AppIcon-Debug")
        #else
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
        #endif
    }

    /// 位置情報（使用中の許可）の利用目的が Info.plist に入っていることを確認する。
    /// 無いと CLLocationManager の許可のダイアログが出ず、iBeacon を検知できない
    @Test
    func locationWhenInUseUsageDescriptionIsSet() {
        let description = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
        #expect(description == "近くのビーコンを見つけて、ピースをゲットするために使います")
    }

    /// 位置情報（常に許可）の利用目的が Info.plist に入っていて空でないことを確認する。
    /// せっていタブでオンにした人だけが尋ねられる。無いと「常に許可」のダイアログが出ず、アプリを閉じている間に CLMonitor の出来事が届かない
    @Test
    func locationAlwaysUsageDescriptionIsSet() throws {
        let description = try #require(
            Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") as? String
        )
        #expect(!description.isEmpty)
        #expect(description == "アプリを閉じていても、近くにピースがあることを知らせるために使います")
    }

    /// バックグラウンドの動作（UIBackgroundModes）と、iOS 10 以前の常に許可の利用目的は Info.plist に無いことを確認する。
    /// CLMonitor は「常に許可」があれば、アプリが終了していても出来事でバックグラウンドに起こされるので、UIBackgroundModes は要らない
    @Test
    func doesNotDeclareBackgroundModes() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") == nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") == nil)
    }

    /// 輸出コンプライアンスの申告（免除対象外の暗号を使わない）が真偽値の false で Info.plist に入っていることを確認する。
    /// 無いと App Store Connect がビルドごとに暗号化の質問を出し、回答するまで TestFlight に配信されない。
    /// キーが無いときや文字列（"NO"）のときは Bool にならないので、#require で落ちる
    @Test
    func declaresNoNonExemptEncryption() throws {
        let usesEncryption = try #require(
            Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool
        )
        #expect(usesEncryption == false)
    }
}
