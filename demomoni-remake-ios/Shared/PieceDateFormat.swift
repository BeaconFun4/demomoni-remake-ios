//
//  PieceDateFormat.swift
//  demomoni-remake-ios
//

import Foundation

/// ピースを獲得した日時の表記（元アプリにならう）
nonisolated enum PieceDateFormat {
    /// 「ピースをゲットしたよ！！」画面の表記（例: 2026/10/21 09:41）
    static func gotDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter(format: "yyyy/MM/dd HH:mm", timeZone: timeZone).string(from: date)
    }

    /// ピース詳細の「にちじ:」の後の表記（例: 10/21 09:41）
    static func detailDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter(format: "MM/dd HH:mm", timeZone: timeZone).string(from: date)
    }

    private static func formatter(format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
