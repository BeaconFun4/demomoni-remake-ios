//
//  CollectedPieceMigrationTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import SwiftData
import Testing

/// 写真（`photo`・`photoDrawing`）を足す前の版の `CollectedPiece`。前の版のアプリが端末に残したストアの形
enum CollectedPieceBeforePhoto {
    @Model
    final class CollectedPiece {
        @Attribute(.unique)
        var pieceID: Int
        var collectedAt: Date
        @Attribute(.externalStorage)
        var signature: Data?

        init(pieceID: Int, collectedAt: Date, signature: Data?) {
            self.pieceID = pieceID
            self.collectedAt = collectedAt
            self.signature = signature
        }
    }
}

/// 写真を足した `CollectedPiece` で、前の版のストアを開けるか（任意の値を足しただけなので、SwiftData の軽量の移行で済む）
@MainActor
struct CollectedPieceMigrationTests {
    private let collectedAt = Date(timeIntervalSince1970: 1_792_000_000)

    /// 前の版の記録（日時・サイン）はそのまま読め、写真と手書きは `nil`。開いた後は写真を保存できる
    @Test
    func opensStoreSavedBeforePhoto() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CollectedPieceMigrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try saveStoreBeforePhoto(at: url)

        let container = try ModelContainer(for: CollectedPiece.self, configurations: ModelConfiguration(url: url))
        let collection = PieceCollection(context: container.mainContext)
        let record = try #require(try collection.record(pieceID: 3))
        #expect(record.collectedAt == collectedAt)
        #expect(record.signature == Data([1, 2, 3]))
        #expect(record.photo == nil)
        #expect(record.photoDrawing == nil)

        #expect(try collection.savePhoto(Data([4]), pieceID: 3))
        #expect(try collection.record(pieceID: 3)?.photo == Data([4]))
    }

    /// 前の版の形でストアを作って閉じる（関数を抜けるときに `ModelContainer` を手放す）
    private func saveStoreBeforePhoto(at url: URL) throws {
        let container = try ModelContainer(
            for: CollectedPieceBeforePhoto.CollectedPiece.self,
            configurations: ModelConfiguration(url: url)
        )
        container.mainContext.insert(
            CollectedPieceBeforePhoto.CollectedPiece(pieceID: 3, collectedAt: collectedAt, signature: Data([1, 2, 3]))
        )
        try container.mainContext.save()
    }
}
