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
        #expect(Bundle.main.bundleIdentifier == "ml.mrs1669.demomoni-remake-ios")
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
}
