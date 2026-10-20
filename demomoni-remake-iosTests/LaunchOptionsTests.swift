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

    /// `-fakeBeaconID <id>` で擬似検知するビーコンを指定する
    @Test
    func readsFakeBeaconID() {
        #expect(LaunchOptions(arguments: ["app", "-uiTesting", "-fakeBeaconID", "1"]).fakeBeaconID == 1)
        #expect(LaunchOptions(arguments: ["app", "-uiTesting"]).fakeBeaconID == nil)
    }

    /// `-fakeBeaconID` の値が無い・数でないときは、擬似検知しない
    @Test
    func ignoresInvalidFakeBeaconID() {
        #expect(LaunchOptions(arguments: ["app", "-fakeBeaconID"]).fakeBeaconID == nil)
        #expect(LaunchOptions(arguments: ["app", "-fakeBeaconID", "one"]).fakeBeaconID == nil)
    }
}
