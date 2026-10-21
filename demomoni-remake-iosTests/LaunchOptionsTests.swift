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

    /// `-uiTesting` と Unit テストのホストでは、実際の位置情報を使わない
    @Test
    func disablesLocationServicesWhileTesting() {
        #expect(LaunchOptions(arguments: ["app"]).usesLocationServices)
        #expect(!LaunchOptions(arguments: ["app", "-uiTesting"]).usesLocationServices)
        let unitTestHost = ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]
        #expect(!LaunchOptions(arguments: ["app"], environment: unitTestHost).usesLocationServices)
    }

    /// `-collectedPieceIDs` で獲得済みにするピースをカンマ区切りで指定する。数でないものは読み飛ばす
    @Test
    func readsCollectedPieceIDs() {
        #expect(LaunchOptions(arguments: ["app", "-uiTesting", "-collectedPieceIDs", "0,1"]).collectedPieceIDs == [0, 1])
        #expect(LaunchOptions(arguments: ["app", "-collectedPieceIDs", "1,x"]).collectedPieceIDs == [1])
        #expect(LaunchOptions(arguments: ["app"]).collectedPieceIDs.isEmpty)
    }
}
