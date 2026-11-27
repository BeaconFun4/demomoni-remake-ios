//
//  Piece.swift
//  demomoni-remake-ios
//

import Foundation

/// 集めるピースの 1 つ（`pieces.json` の 1 件）。場所（緯度・経度）の範囲に入るとゲットできる（`PieceArea`）。
/// 元の JSON の `hasGot`・`date` は固定値なので読まない（獲得したかどうかと日時は端末に保存する）
nonisolated struct Piece: Decodable, Hashable, Identifiable, Sendable {
    /// ピースの id。獲得状態（`CollectedPiece.pieceID`）となぞなぞ（`Riddle.pieceId`）がこの値でピースを指す
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
    /// ゲットできる範囲（場所の緯度・経度を中心にした円）の半径（メートル）。場所の広さに合わせて決める。
    /// `pieces.json` に無ければ `defaultRadius`
    let radius: Double

    /// 範囲の半径の既定値（メートル）。建物 1 つほどの場所の大きさ
    static let defaultRadius: Double = 100

    /// 場所の緯度・経度
    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    /// ピースの番号。画像の名前の末尾の数字（`piece14` → 14）で、いちらんの 32 マスのどこに置くかを表す。
    /// 画像の名前に数字が無ければ `nil`
    var number: Int? {
        Int(String(image.reversed().prefix { $0.isNumber }.reversed()))
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, area, image, radius
    }

    init(
        id: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        area: String,
        image: String,
        radius: Double = defaultRadius
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.area = area
        self.image = image
        self.radius = radius
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try Self.decodeCoordinate(from: container, forKey: .latitude)
        longitude = try Self.decodeCoordinate(from: container, forKey: .longitude)
        area = try container.decode(String.self, forKey: .area)
        image = try container.decode(String.self, forKey: .image)
        radius = try container.decodeIfPresent(Double.self, forKey: .radius) ?? Self.defaultRadius
        guard radius > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .radius, in: container, debugDescription: "範囲の半径が 0 以下: \(radius)")
        }
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
