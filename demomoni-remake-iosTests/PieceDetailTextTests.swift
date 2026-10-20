//
//  PieceDetailTextTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct PieceDetailTextTests {
    private let motomachi = Piece(id: 0, name: "元町公園", latitude: 0, longitude: 0, area: "元町・函館山", image: "piece14")

    /// 見出しは「ピース No.<番号>」
    @Test
    func title() {
        #expect(PieceDetailText.title(for: motomachi) == "ピース No.14")
        let noNumber = Piece(id: 9, name: "", latitude: 0, longitude: 0, area: "", image: "piece")
        #expect(PieceDetailText.title(for: noNumber) == "ピース")
    }

    /// 「にちじ:MM/dd HH:mm」。獲得の記録が無ければ日時を出さない
    @Test
    func date() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 2026-10-21 00:41 UTC（日本時間 09:41）
        let date = Date(timeIntervalSince1970: 1_792_543_260)
        #expect(PieceDetailText.date(date, timeZone: tokyo) == "にちじ:10/21 09:41")
        #expect(PieceDetailText.date(nil, timeZone: tokyo) == "にちじ:")
    }

    /// エリアと場所の名前（元アプリの「エリア:元町・函館山」「ばしょ:元町公園」）
    @Test
    func areaAndPlace() {
        #expect(PieceDetailText.area(for: motomachi) == "エリア:元町・函館山")
        #expect(PieceDetailText.place(for: motomachi) == "ばしょ:元町公園")
    }
}
