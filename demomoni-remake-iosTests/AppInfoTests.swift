//
//  AppInfoTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct AppInfoTests {
    /// Configs/Project.xcconfig の APP_BUNDLE_IDENTIFIER が Info.plist に反映されていることを確認する。
    /// Bundle ID は App Store Connect のアプリと結びつくので、変えるときはこのテストもあわせて直す
    @Test
    func bundleIdentifierComesFromXcconfig() {
        #expect(Bundle.main.bundleIdentifier == "jp.shilokuma.Demomoni")
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

    /// Configs/Project.xcconfig の INFOPLIST_KEY_CFBundleDisplayName が、記号（「！」）まで欠けずに Info.plist に反映されていることを確認する
    @Test
    func displayNameComesFromXcconfig() {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #expect(name == "でももに！")
    }

    /// 位置情報（使用中の許可）の利用目的が Info.plist に入っていることを確認する。
    /// 無いと CLLocationManager の許可のダイアログが出ず、iBeacon を検知できない
    @Test
    func locationWhenInUseUsageDescriptionIsSet() {
        let description = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
        #expect(description == "近くのビーコンを見つけて、ピースをゲットするために使います")
    }

    /// 位置情報は使用中だけに使う。常に使う許可の利用目的と、バックグラウンドの動作（位置情報の監視）が Info.plist に無いことを確認する
    @Test
    func doesNotRequestBackgroundLocation() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") == nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") == nil)
    }
}
