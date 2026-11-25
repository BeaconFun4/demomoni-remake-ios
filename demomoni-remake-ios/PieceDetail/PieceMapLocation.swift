//
//  PieceMapLocation.swift
//  demomoni-remake-ios
//

import CoreLocation
import MapKit

/// ピースの場所の地図に出す座標・範囲・読み上げ。地図の View（`PieceLocationMap`）から切り出してテストする
nonisolated enum PieceMapLocation {
    /// ピース詳細の中の小さな地図で見せる範囲（メートル。南北・東西の幅）。名所のまわりの道が分かるくらい
    static let previewSpanMeters: CLLocationDistance = 600
    /// 大きな地図を開いたときに最初に見せる範囲（メートル。南北・東西の幅）。近くの名所や駅が入るくらい
    static let sheetSpanMeters: CLLocationDistance = 1_500

    /// ピースの場所（`pieces.json` の緯度・経度）
    static func coordinate(for piece: Piece) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: piece.latitude, longitude: piece.longitude)
    }

    /// ピースの場所を中心にした、南北・東西が `spanMeters` の範囲
    static func region(for piece: Piece, spanMeters: CLLocationDistance) -> MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate(for: piece), latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
    }

    /// VoiceOver で読む地図の名前（例: 元町公園の地図）
    static func accessibilityLabel(for piece: Piece) -> String {
        "\(piece.name)の地図"
    }
}

extension PieceMapLocation {
    /// Apple のマップに渡す場所。名前はピースの場所の名前
    static func mapItem(for piece: Piece) -> MKMapItem {
        let location = CLLocation(latitude: piece.latitude, longitude: piece.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = piece.name
        return item
    }
}
