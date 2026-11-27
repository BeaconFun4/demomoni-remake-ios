//
//  SamplePhoto.swift
//  demomoni-remake-ios
//

import CoreGraphics
import Foundation

/// UI テストと PR のスクリーンショットで、ピースの裏側に入れておく見本の写真（起動引数 `-samplePhotoPieceIDs`）。
/// 写真ライブラリやカメラを使わずに、空・太陽・建物・道を描いた絵を作る（人物や実在の写真は使わない）
nonisolated enum SamplePhoto {
    /// 絵の大きさ（ピクセル。横長の写真と同じ 4 : 3）
    static let width = 1200
    static let height = 900

    /// 見本の写真の JPEG。描けなければ `nil`
    static func jpegData() -> Data? {
        image().flatMap { PiecePhotoImage.jpegData(from: $0) }
    }

    /// 見本の写真の絵
    static func image() -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        let width = CGFloat(width)
        let height = CGFloat(height)
        // CGContext の原点は左下なので、y は下から測る
        fill(context, CGRect(x: 0, y: 0, width: width, height: height), red: 0.62, green: 0.85, blue: 0.97)
        context.setFillColor(CGColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
        context.fillEllipse(in: CGRect(x: width * 0.75, y: height * 0.7, width: 140, height: 140))
        fill(context, CGRect(x: 0, y: 0, width: width, height: height * 0.25), red: 0.55, green: 0.78, blue: 0.45)
        // 建物（左から低い・高い塔・中くらい。絵の幅・高さに対する割合で、地面の上に建てる）
        let buildings = [
            CGRect(x: 0.08, y: 0.25, width: 0.2, height: 0.3),
            CGRect(x: 0.42, y: 0.25, width: 0.12, height: 0.6),
            CGRect(x: 0.62, y: 0.25, width: 0.22, height: 0.38)
        ]
        for building in buildings {
            let rect = CGRect(
                x: width * building.minX,
                y: height * building.minY,
                width: width * building.width,
                height: height * building.height
            )
            fill(context, rect, red: 0.93, green: 0.93, blue: 0.9)
            drawWindows(context, in: rect)
        }
        // 道
        fill(context, CGRect(x: width * 0.3, y: 0, width: width * 0.4, height: height * 0.25), red: 0.6, green: 0.6, blue: 0.6)
        return context.makeImage()
    }

    private static func fill(_ context: CGContext, _ rect: CGRect, red: CGFloat, green: CGFloat, blue: CGFloat) {
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(rect)
    }

    /// 建物の窓を、縦横に並べて描く
    private static func drawWindows(_ context: CGContext, in rect: CGRect) {
        let size: CGFloat = 28
        let gap: CGFloat = 24
        context.setFillColor(CGColor(red: 0.45, green: 0.66, blue: 0.85, alpha: 1))
        var y = rect.minY + gap
        while y + size < rect.maxY - gap {
            var x = rect.minX + gap
            while x + size < rect.maxX - gap {
                context.fill(CGRect(x: x, y: y, width: size, height: size))
                x += size + gap
            }
            y += size + gap
        }
    }
}
