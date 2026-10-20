//
//  LaunchOptionsTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct LaunchOptionsTests {
    /// 起動引数が無ければ、端末のストアを使う
    @Test
    func defaultsToPersistentStore() {
        #expect(LaunchOptions(arguments: ["demomoni-remake-ios"]) == LaunchOptions())
        #expect(!LaunchOptions(arguments: []).usesInMemoryStore)
    }

    /// `-uiTesting` を渡すと、メモリ上のストアを使う
    @Test
    func uiTestingUsesInMemoryStore() {
        #expect(LaunchOptions(arguments: ["demomoni-remake-ios", "-uiTesting"]).usesInMemoryStore)
    }
}
