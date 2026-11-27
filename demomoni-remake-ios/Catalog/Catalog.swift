//
//  Catalog.swift
//  demomoni-remake-ios
//

import Foundation

/// アプリに同梱したデータ（`Resources/Data/` の `pieces.json`・`riddles.json`）
nonisolated struct Catalog: Sendable {
    /// 同梱データを読めなかった理由
    enum LoadError: Error, Equatable {
        /// バンドルに JSON のファイルが無い
        case missingResource(String)
    }

    let pieces: [Piece]
    let riddles: [Riddle]

    /// バンドルから 2 つの JSON を読む
    static func load(from bundle: Bundle = .main) throws -> Self {
        Self(
            pieces: try decode(PiecesFile.self, resource: "pieces", in: bundle).pieces,
            riddles: try decode(RiddlesFile.self, resource: "riddles", in: bundle).riddles
        )
    }

    /// id のピース。無ければ `nil`
    func piece(id: Int) -> Piece? {
        pieces.first { $0.id == id }
    }

    /// なぞなぞの答えの場所にあるピース。無ければ `nil`
    func piece(for riddle: Riddle) -> Piece? {
        piece(id: riddle.pieceId)
    }

    private static func decode<File: Decodable>(_ type: File.Type, resource: String, in bundle: Bundle) throws -> File {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw LoadError.missingResource("\(resource).json")
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

/// JSON のいちばん外側（`{ "pieces": [...] }` など）
nonisolated private struct PiecesFile: Decodable {
    let pieces: [Piece]
}

nonisolated private struct RiddlesFile: Decodable {
    let riddles: [Riddle]
}
