//
//  Catalog.swift
//  demomoni-remake-ios
//

import Foundation

/// アプリに同梱したデータ（`Resources/Data/` の `beacons.json`・`pieces.json`・`riddles.json`）
nonisolated struct Catalog: Sendable {
    /// 同梱データを読めなかった理由
    enum LoadError: Error, Equatable {
        /// バンドルに JSON のファイルが無い
        case missingResource(String)
    }

    let beacons: [Beacon]
    let pieces: [Piece]
    let riddles: [Riddle]

    /// バンドルから 3 つの JSON を読む
    static func load(from bundle: Bundle = .main) throws -> Self {
        Self(
            beacons: try decode(BeaconsFile.self, resource: "beacons", in: bundle).beacons,
            pieces: try decode(PiecesFile.self, resource: "pieces", in: bundle).pieces,
            riddles: try decode(RiddlesFile.self, resource: "riddles", in: bundle).riddles
        )
    }

    /// id のピース。無ければ `nil`
    func piece(id: Int) -> Piece? {
        pieces.first { $0.id == id }
    }

    /// iBeacon の UUID・major・minor に対応するピース。
    /// 同梱データに無いビーコン、またはビーコンに対応するピースが無ければ `nil`
    func piece(forBeaconUUID uuid: UUID, major: UInt16, minor: UInt16) -> Piece? {
        guard let beacon = beacons.first(where: { $0.matches(uuid: uuid, major: major, minor: minor) }) else {
            return nil
        }
        return piece(id: beacon.beaconId)
    }

    private static func decode<File: Decodable>(_ type: File.Type, resource: String, in bundle: Bundle) throws -> File {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw LoadError.missingResource("\(resource).json")
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

/// JSON のいちばん外側（`{ "beacons": [...] }` など）
nonisolated private struct BeaconsFile: Decodable {
    let beacons: [Beacon]
}

nonisolated private struct PiecesFile: Decodable {
    let pieces: [Piece]
}

nonisolated private struct RiddlesFile: Decodable {
    let riddles: [Riddle]
}
