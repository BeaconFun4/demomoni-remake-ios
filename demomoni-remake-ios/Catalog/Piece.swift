//
//  Piece.swift
//  demomoni-remake-ios
//

import Foundation

/// 集めるピースの 1 つ（`pieces.json` の 1 件）。
/// 元の JSON の `hasGot`・`date` は固定値なので読まない（獲得したかどうかと日時は端末に保存する）
nonisolated struct Piece: Decodable, Hashable, Identifiable, Sendable {
    /// ピースの id。同じ値の `Beacon.beaconId` のビーコンで獲得する
    let id: Int
    /// 場所の名前（例: 元町公園）
    let name: String
    /// 場所の緯度
    let latitude: Double
    /// 場所の経度
    let longitude: Double
    /// 場所のエリア（例: 元町・函館山）
    let area: String
    /// ピースの画像のアセット名（例: piece14）
    let image: String

    /// ピースの番号。画像の名前の末尾の数字（`piece14` → 14）で、いちらんの 32 マスのどこに置くかを表す。
    /// 画像の名前に数字が無ければ `nil`
    var number: Int? {
        Int(String(image.reversed().prefix { $0.isNumber }.reversed()))
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, area, image
    }

    init(id: Int, name: String, latitude: Double, longitude: Double, area: String, image: String) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.area = area
        self.image = image
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try Self.decodeCoordinate(from: container, forKey: .latitude)
        longitude = try Self.decodeCoordinate(from: container, forKey: .longitude)
        area = try container.decode(String.self, forKey: .area)
        image = try container.decode(String.self, forKey: .image)
    }

    /// 元の JSON では緯度・経度が文字列（"41.794689"）なので、`Double` に直して読む
    private static func decodeCoordinate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Double {
        let text = try container.decode(String.self, forKey: key)
        guard let value = Double(text) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "緯度・経度を数値として読めない: \(text)"
            )
        }
        return value
    }
}
