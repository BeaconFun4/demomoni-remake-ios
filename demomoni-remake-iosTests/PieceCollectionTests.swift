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

    /// 獲得していないピースにはサインを保存しない（記録も作らない）
    @Test
    func saveSignatureIgnoresUncollectedPiece() throws {
        #expect(try !collection.saveSignature(Data([1]), pieceID: 0))
        #expect(try !collection.isCollected(pieceID: 0))
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
