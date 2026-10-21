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
        try saveOrRollback()
        return true
    }

    /// まだ獲得していないピースをまとめて獲得済みにする（獲得済みのピースは日時・サインを残す）。
    /// 1 回だけ保存するので、保存に失敗したら 1 件も獲得しない
    /// - Returns: 今回はじめて獲得した件数
    @discardableResult
    func collectAll(pieceIDs: some Sequence<Int>, at date: Date) throws -> Int {
        let missing = Set(pieceIDs).subtracting(try collectedPieceIDs())
        guard !missing.isEmpty else {
            return 0
        }
        for pieceID in missing.sorted() {
            context.insert(CollectedPiece(pieceID: pieceID, collectedAt: date))
        }
        try saveOrRollback()
        return missing.count
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

    /// 獲得済みのピースにサインを保存する（前のサインは置き換える）。`nil` ならサインを消す
    /// - Returns: 保存できたか。獲得していないピースには保存しない
    @discardableResult
    func saveSignature(_ signature: Data?, pieceID: Int) throws -> Bool {
        guard let record = try record(pieceID: pieceID) else {
            return false
        }
        record.signature = signature
        try saveOrRollback()
        return true
    }

    /// ピースの獲得の記録（最初に獲得した日時・サイン）を消し、獲得していない状態に戻す
    /// - Returns: 消したか。獲得していなければ何もしない
    @discardableResult
    func remove(pieceID: Int) throws -> Bool {
        guard let record = try record(pieceID: pieceID) else {
            return false
        }
        context.delete(record)
        try saveOrRollback()
        return true
    }

    /// すべてのピースの獲得の記録を消す。保存に失敗したら 1 件も消さない
    /// - Returns: 消した件数
    @discardableResult
    func removeAll() throws -> Int {
        let records = try context.fetch(FetchDescriptor<CollectedPiece>())
        guard !records.isEmpty else {
            return 0
        }
        for record in records {
            context.delete(record)
        }
        try saveOrRollback()
        return records.count
    }

    /// 保存する。失敗したら保存前の変更を捨てる（獲得していないのに獲得済みに見えないようにする）
    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
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
