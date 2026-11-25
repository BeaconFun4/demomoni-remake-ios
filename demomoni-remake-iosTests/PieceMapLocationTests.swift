//
//  PieceMapLocationTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import MapKit
import Testing

/// ピース詳細の地図に出す座標・範囲・読み上げ
@MainActor
struct PieceMapLocationTests {
    /// 函館山（`pieces.json` の id 1）
    private let hakodateyama = Catalog.bundled.pieces[1]

    /// 地図のピンは、`pieces.json` の緯度・経度に立てる
    @Test
    func coordinateComesFromPieceData() {
        let coordinate = PieceMapLocation.coordinate(for: hakodateyama)
        #expect(coordinate.latitude == 41.759167)
        #expect(coordinate.longitude == 140.704444)
    }

    /// 地図の範囲は、ピースの場所を中心にした、南北・東西が決めた幅（メートル）のもの
    @Test(arguments: [PieceMapLocation.previewSpanMeters, PieceMapLocation.sheetSpanMeters])
    func regionIsCenteredOnPiece(spanMeters: CLLocationDistance) {
        let region = PieceMapLocation.region(for: hakodateyama, spanMeters: spanMeters)
        #expect(region.center.latitude == hakodateyama.latitude)
        #expect(region.center.longitude == hakodateyama.longitude)
        // 緯度 1 度はおよそ 111 km
        let expectedLatitudeDelta = spanMeters / 111_000
        #expect(abs(region.span.latitudeDelta - expectedLatitudeDelta) < expectedLatitudeDelta * 0.05)
        // 北緯 42 度あたりでは、経度 1 度は緯度 1 度より短いので、同じ幅でも経度の差は大きい
        #expect(region.span.longitudeDelta > region.span.latitudeDelta)
    }

    /// 大きな地図は、詳細の中の小さな地図より広く見せる
    @Test
    func sheetShowsWiderAreaThanPreview() {
        #expect(PieceMapLocation.sheetSpanMeters > PieceMapLocation.previewSpanMeters)
    }

    /// VoiceOver では「〇〇の地図」と読む
    @Test
    func accessibilityLabelNamesPlace() {
        #expect(PieceMapLocation.accessibilityLabel(for: hakodateyama) == "函館山の地図")
    }

    /// Apple のマップに渡す場所は、ピースの場所の名前と緯度・経度
    @Test
    func mapItemHasPlaceNameAndCoordinate() {
        let item = PieceMapLocation.mapItem(for: hakodateyama)
        #expect(item.name == "函館山")
        #expect(item.location.coordinate.latitude == hakodateyama.latitude)
        #expect(item.location.coordinate.longitude == hakodateyama.longitude)
    }
}
