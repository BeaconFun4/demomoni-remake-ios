//
//  PieceCollection.swift
//  demomoni-remake-ios
//

import Foundation
import SwiftData

/// ピースの獲得状態とサインを、SwiftData の `ModelContext` に読み書きする
struct PieceCollection {
    let context: ModelContext

    /// ピースを獲得したことを保存する。
    /// すでに獲得済みなら何もしない（最初に獲得した日時を残す）
    /// - Returns: 今回はじめて獲得したか
    @discardableResult
    func collect(pieceID: Int, at date: Date) throws -> Bool {
        guard try record(pieceID: pieceID) == nil else {
            return false
        }
        context.insert(CollectedPiece(pieceID: pieceID, collectedAt: date))
        try context.save()
        return true
    }

    /// ピースを獲得済みか
    func isCollected(pieceID: Int) throws -> Bool {
        try record(pieceID: pieceID) != nil
    }

    /// 獲得済みのピースの id
    func collectedPieceIDs() throws -> Set<Int> {
        Set(try context.fetch(FetchDescriptor<CollectedPiece>()).map(\.pieceID))
    }

    /// ピースの獲得の記録。獲得していなければ `nil`
    func record(pieceID: Int) throws -> CollectedPiece? {
        var descriptor = FetchDescriptor<CollectedPiece>(predicate: #Predicate { $0.pieceID == pieceID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 獲得済みのピースにサインを保存する（前のサインは置き換える）
    /// - Returns: 保存できたか。獲得していないピースには保存しない
    @discardableResult
    func saveSignature(_ signature: Data, pieceID: Int) throws -> Bool {
        guard let record = try record(pieceID: pieceID) else {
            return false
        }
        record.signature = signature
        try context.save()
        return true
    }
}

extension ModelContainer {
    /// アプリで使う `ModelContainer`
    /// - Parameter inMemory: 端末に保存せずメモリ上だけで持つか（UI テスト・Unit テスト・プレビュー用）
    static func demomoni(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: CollectedPiece.self, configurations: configuration)
    }
}
