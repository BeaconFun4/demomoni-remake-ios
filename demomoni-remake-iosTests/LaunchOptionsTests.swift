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

    /// `-fakePieceID <id>` で、擬似検知でいることにするピースの場所を指定する
    @Test
    func readsFakePieceID() {
        #expect(LaunchOptions(arguments: ["app", "-uiTesting", "-fakePieceID", "1"]).fakePieceID == 1)
        #expect(LaunchOptions(arguments: ["app", "-uiTesting"]).fakePieceID == nil)
    }

    /// `-fakePieceID` の値が無い・数でないときは、擬似検知しない
    @Test
    func ignoresInvalidFakePieceID() {
        #expect(LaunchOptions(arguments: ["app", "-fakePieceID"]).fakePieceID == nil)
        #expect(LaunchOptions(arguments: ["app", "-fakePieceID", "one"]).fakePieceID == nil)
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

    /// `-samplePhotoPieceIDs` で裏側に見本の写真を入れるピースをカンマ区切りで指定する。数でないものは読み飛ばす
    @Test
    func readsSamplePhotoPieceIDs() {
        let options = LaunchOptions(arguments: ["app", "-uiTesting", "-collectedPieceIDs", "0,1", "-samplePhotoPieceIDs", "1,x"])
        #expect(options.samplePhotoPieceIDs == [1])
        #expect(options.collectedPieceIDs == [0, 1])
        #expect(LaunchOptions(arguments: ["app"]).samplePhotoPieceIDs.isEmpty)
        #expect(LaunchOptions(arguments: ["app", "-samplePhotoPieceIDs"]).samplePhotoPieceIDs.isEmpty)
    }
}
