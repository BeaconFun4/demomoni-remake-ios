//
//  PiecePhotoImage.swift
//  demomoni-remake-ios
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// ピースの裏側に入れる写真。保存の前に長い辺を縮め、JPEG に書き直す。
/// 写真の向き（EXIF の Orientation）は画素に焼き込み、位置情報・撮影日時・機種などのメタデータは書かない
/// （写真は端末の中だけに保存し、外へは送らないが、写真のデータそのものにも撮った場所を残さない）。
/// どのスレッドからも呼べる（大きな写真は MainActor の外で直す）
nonisolated enum PiecePhotoImage {
    /// 保存する写真の長い辺の上限（ピクセル）
    static let maximumPixelLength = 2048
    /// JPEG の画質
    static let compressionQuality = 0.8

    /// 長い辺を `maximumLength` までに縮めた大きさ。縦横の比は変えず、元より大きくはしない。
    /// 短い辺も 1 px より小さくしない（ピクセルの数なので整数に丸める）
    static func scaledSize(for size: CGSize, maximumLength: Int = maximumPixelLength) -> CGSize {
        let longSide = max(size.width, size.height)
        guard longSide > 0, size.width > 0, size.height > 0 else {
            return .zero
        }
        let factor = min(1, CGFloat(maximumLength) / longSide)
        return CGSize(
            width: max(1, (size.width * factor).rounded()),
            height: max(1, (size.height * factor).rounded())
        )
    }

    /// 写真のデータ（写真ライブラリから選んだ JPEG・HEIC など）を、保存する JPEG に直す。画像として読めなければ `nil`
    static func jpegData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        // サムネイルとして作ると、全体を読み込まずに縮められ、向きも画素に焼き込める（元より大きくはしない）
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelLength,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return jpegData(from: image)
    }

    /// カメラで撮った写真（`UIImagePickerController` の画像）を、保存する JPEG に直す。書き出せなければ `nil`
    static func jpegData(from image: UIImage) -> Data? {
        // いったん向きの情報つきの JPEG にしてから、ライブラリの写真と同じ手順で縮めて向きを焼き込む
        image.jpegData(compressionQuality: 1).flatMap { jpegData(from: $0) }
    }

    /// 画像を JPEG に書き出す（縮めない）。透明なところは白で埋める（JPEG は透明を持てず、そのままだと黒くなる）。メタデータは書かない
    static func jpegData(from image: CGImage) -> Data? {
        guard let opaque = opaqueImage(image) else {
            return nil
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
        CGImageDestinationAddImage(destination, opaque, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    /// 透明なところを白で埋めた画像。透明なところが無ければそのまま
    private static func opaqueImage(_ image: CGImage) -> CGImage? {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return image
        default:
            break
        }
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
