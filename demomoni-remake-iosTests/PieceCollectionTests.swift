//
//  PieceCollectionTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData
import Testing

@MainActor
struct PieceCollectionTests {
    private let container: ModelContainer
    private let collection: PieceCollection

    private let firstDate = Date(timeIntervalSince1970: 1_792_000_000)
    private let laterDate = Date(timeIntervalSince1970: 1_792_086_400)

    init() throws {
        container = try .demomoni(inMemory: true)
        collection = PieceCollection(context: container.mainContext)
    }

    /// 空のストアでは、どのピースも獲得していない
    @Test
    func startsEmpty() throws {
        #expect(try collection.collectedPieceIDs().isEmpty)
        #expect(try !collection.isCollected(pieceID: 0))
    }

    /// 獲得すると、獲得済みになり日時が残る
    @Test
    func collectStoresPieceAndDate() throws {
        #expect(try collection.collect(pieceID: 0, at: firstDate))
        #expect(try collection.isCollected(pieceID: 0))
        #expect(try collection.record(pieceID: 0)?.collectedAt == firstDate)
        #expect(try collection.record(pieceID: 0)?.signature == nil)
        #expect(try !collection.isCollected(pieceID: 1))
    }

    /// 同じピースを 2 回獲得しても 1 件のまま、最初の日時を残す
    @Test
    func collectingTwiceKeepsFirstRecord() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        #expect(try !collection.collect(pieceID: 0, at: laterDate))

        let records = try container.mainContext.fetch(FetchDescriptor<CollectedPiece>())
        #expect(records.count == 1)
        #expect(records.first?.collectedAt == firstDate)
    }

    /// 獲得済みのピースの id をまとめて返す
    @Test
    func collectedPieceIDsListsAll() throws {
        try collection.collect(pieceID: 1, at: firstDate)
        try collection.collect(pieceID: 0, at: laterDate)
        #expect(try collection.collectedPieceIDs() == [0, 1])
    }

    /// 獲得済みのピースにサインを保存でき、2 回目は置き換える。獲得の日時は変わらない
    @Test
    func saveSignatureReplacesPreviousSignature() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        #expect(try collection.saveSignature(Data([1, 2, 3]), pieceID: 0))
        #expect(try collection.saveSignature(Data([4, 5]), pieceID: 0))

        let record = try #require(try collection.record(pieceID: 0))
        #expect(record.signature == Data([4, 5]))
        #expect(record.collectedAt == firstDate)
    }

    /// `nil` を保存するとサインを消す（線を全部消して「これでかんせい！」を押したとき）
    @Test
    func saveNilSignatureRemovesSignature() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.saveSignature(Data([1]), pieceID: 0)
        #expect(try collection.saveSignature(nil, pieceID: 0))
        #expect(try collection.record(pieceID: 0)?.signature == nil)
        #expect(try collection.isCollected(pieceID: 0))
    }

    /// 獲得していないピースにはサインを保存しない（記録も作らない）
    @Test
    func saveSignatureIgnoresUncollectedPiece() throws {
        #expect(try !collection.saveSignature(Data([1]), pieceID: 0))
        #expect(try !collection.isCollected(pieceID: 0))
    }

    /// まとめて獲得すると、まだ獲得していないピースだけを足し、獲得済みのピースの日時・サインは残す
    @Test
    func collectAllAddsOnlyMissingPieces() throws {
        try collection.collect(pieceID: 1, at: firstDate)
        try collection.saveSignature(Data([7]), pieceID: 1)

        #expect(try collection.collectAll(pieceIDs: [0, 1, 2], at: laterDate) == 2)
        #expect(try collection.collectedPieceIDs() == [0, 1, 2])
        #expect(try collection.record(pieceID: 0)?.collectedAt == laterDate)
        #expect(try collection.record(pieceID: 1)?.collectedAt == firstDate)
        #expect(try collection.record(pieceID: 1)?.signature == Data([7]))
        #expect(try container.mainContext.fetch(FetchDescriptor<CollectedPiece>()).count == 3)
    }

    /// すべて獲得済み・同じ id が重なっていても、記録は 1 ピース 1 件のまま
    @Test
    func collectAllIgnoresCollectedAndDuplicatedIDs() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        #expect(try collection.collectAll(pieceIDs: [0, 0], at: laterDate) == 0)
        #expect(try collection.collectAll(pieceIDs: [3, 3], at: laterDate) == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<CollectedPiece>()).count == 2)
    }

    /// ピースを外すと獲得していない状態に戻り、ほかのピースは残る
    @Test
    func removeDeletesOnlyThatPiece() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.saveSignature(Data([1]), pieceID: 0)
        try collection.collect(pieceID: 1, at: firstDate)

        #expect(try collection.remove(pieceID: 0))
        #expect(try !collection.isCollected(pieceID: 0))
        #expect(try collection.record(pieceID: 0) == nil)
        #expect(try collection.collectedPieceIDs() == [1])
    }

    /// 獲得していないピースを外しても何もしない
    @Test
    func removeIgnoresUncollectedPiece() throws {
        try collection.collect(pieceID: 1, at: firstDate)
        #expect(try !collection.remove(pieceID: 0))
        #expect(try collection.collectedPieceIDs() == [1])
    }

    /// 外したピースをもう一度獲得すると、新しい日時でサインの無い記録になる
    @Test
    func collectAfterRemoveStartsNewRecord() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.saveSignature(Data([1]), pieceID: 0)
        try collection.remove(pieceID: 0)

        #expect(try collection.collect(pieceID: 0, at: laterDate))
        let record = try #require(try collection.record(pieceID: 0))
        #expect(record.collectedAt == laterDate)
        #expect(record.signature == nil)
    }

    /// 全部消すと、どのピースも獲得していない状態に戻り、消した件数を返す
    @Test
    func removeAllDeletesEveryRecord() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.collect(pieceID: 1, at: laterDate)
        try collection.saveSignature(Data([1]), pieceID: 1)

        #expect(try collection.removeAll() == 2)
        #expect(try collection.collectedPieceIDs().isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<CollectedPiece>()).isEmpty)
    }

    /// 獲得していなければ、全部消しても 0 件
    @Test
    func removeAllOnEmptyStoreDoesNothing() throws {
        #expect(try collection.removeAll() == 0)
    }

    /// 外した・全部消した結果は、同じストアの別の `ModelContext` からも見える
    @Test
    func removalIsVisibleFromAnotherContext() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.collect(pieceID: 1, at: firstDate)
        let other = PieceCollection(context: ModelContext(container))

        try collection.remove(pieceID: 0)
        #expect(try other.collectedPieceIDs() == [1])

        try collection.removeAll()
        #expect(try other.collectedPieceIDs().isEmpty)
    }

    /// 保存した内容は、同じストアの別の `ModelContext` からも読める
    @Test
    func savedRecordIsVisibleFromAnotherContext() throws {
        try collection.collect(pieceID: 0, at: firstDate)
        try collection.saveSignature(Data([9]), pieceID: 0)

        let other = PieceCollection(context: ModelContext(container))
        #expect(try other.record(pieceID: 0)?.signature == Data([9]))
    }
}
