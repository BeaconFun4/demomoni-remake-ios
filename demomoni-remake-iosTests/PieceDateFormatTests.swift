//
//  PieceDateFormatTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct PieceDateFormatTests {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    /// 2026-10-21 00:41:00 UTC（日本時間 09:41）
    private let date = Date(timeIntervalSince1970: 1_792_543_260)

    /// 「ゲットした」画面は yyyy/MM/dd HH:mm（24 時間制・ゼロ埋め）
    @Test
    func gotDate() {
        #expect(PieceDateFormat.gotDate(date, timeZone: tokyo) == "2026/10/21 09:41")
    }

    /// ピース詳細は MM/dd HH:mm
    @Test
    func detailDate() {
        #expect(PieceDateFormat.detailDate(date, timeZone: tokyo) == "10/21 09:41")
    }

    /// 午後も 24 時間制で書く。日付はタイムゾーンで変わる
    @Test
    func usesTwentyFourHourClockInTimeZone() {
        let evening = date.addingTimeInterval(12 * 60 * 60)
        #expect(PieceDateFormat.gotDate(evening, timeZone: tokyo) == "2026/10/21 21:41")
        #expect(PieceDateFormat.gotDate(date, timeZone: TimeZone(identifier: "UTC")!) == "2026/10/21 00:41")
        #expect(PieceDateFormat.gotDate(date.addingTimeInterval(-60 * 60), timeZone: TimeZone(identifier: "UTC")!)
            == "2026/10/20 23:41")
    }
}
