//
//  PiecePhotoImageTests.swift
//  demomoni-remake-iosTests
//

import CoreGraphics
@testable import demomoni_remake_ios
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

/// 裏側に入れる写真を、保存の前に縮めてメタデータを消す
struct PiecePhotoImageTests {
    /// 長い辺を 2048 px までに縮め、縦横の比は変えない。元より大きくはせず、短い辺も 1 px は残す
    @Test(arguments: [
        (CGSize(width: 4032, height: 3024), CGSize(width: 2048, height: 1536)),
        (CGSize(width: 3024, height: 4032), CGSize(width: 1536, height: 2048)),
        (CGSize(width: 2048, height: 2048), CGSize(width: 2048, height: 2048)),
        (CGSize(width: 1000, height: 500), CGSize(width: 1000, height: 500)),
        (CGSize(width: 10_000, height: 1), CGSize(width: 2048, height: 1)),
        (CGSize(width: 0, height: 100), CGSize.zero)
    ])
    func scalesLongSideDown(size: CGSize, expected: CGSize) {
        #expect(PiecePhotoImage.scaledSize(for: size) == expected)
    }

    /// 大きな写真は長い辺を 2048 px に縮めた JPEG にし、位置情報・撮影日時などのメタデータを残さない
    @Test
    func shrinksPhotoAndRemovesMetadata() throws {
        let original = try makeJPEG(width: 3000, height: 1500, properties: [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 41.7945,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 140.7539,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:11:26 10:00:00"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "iPhone"]
        ])
        #expect(try properties(of: original)[kCGImagePropertyGPSDictionary] != nil)

        let data = try #require(PiecePhotoImage.jpegData(from: original))
        let saved = try properties(of: data)
        #expect(saved[kCGImagePropertyPixelWidth] as? Int == 2048)
        #expect(saved[kCGImagePropertyPixelHeight] as? Int == 1024)
        #expect(saved[kCGImagePropertyGPSDictionary] == nil)
        #expect((saved[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect((saved[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFModel] == nil)
        #expect(try typeIdentifier(of: data) == UTType.jpeg.identifier)
    }

    /// 横に倒して撮った写真（EXIF の向きが「右に 90 度」）は、向きを画素に焼き込んで縦長にする
    @Test
    func appliesOrientation() throws {
        let original = try makeJPEG(width: 400, height: 200, properties: [kCGImagePropertyOrientation: 6])
        let saved = try properties(of: try #require(PiecePhotoImage.jpegData(from: original)))
        #expect(saved[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(saved[kCGImagePropertyPixelHeight] as? Int == 400)
        #expect((saved[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    /// カメラで撮った画像も、向きを焼き込んだ JPEG にする
    @Test
    func convertsCameraImage() throws {
        let image = UIImage(cgImage: try makeImage(width: 400, height: 200), scale: 1, orientation: .right)
        let saved = try properties(of: try #require(PiecePhotoImage.jpegData(from: image)))
        #expect(saved[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(saved[kCGImagePropertyPixelHeight] as? Int == 400)
    }

    /// 透明なところ（スクリーンショットの PNG など）は白で埋める
    @Test
    func fillsTransparencyWithWhite() throws {
        let png = try makePNGWithTransparency(width: 10, height: 10)
        let data = try #require(PiecePhotoImage.jpegData(from: png))
        let pixel = try firstPixel(of: data)
        #expect(pixel.allSatisfy { $0 > 240 }, "左上の画素: \(pixel)")
    }

    /// 画像でないデータは保存しない
    @Test
    func rejectsNonImageData() {
        #expect(PiecePhotoImage.jpegData(from: Data("not an image".utf8)) == nil)
        #expect(PiecePhotoImage.jpegData(from: Data()) == nil)
    }

    /// UI テストの見本の写真（`-samplePhotoPieceIDs`）は描いた絵で、保存するときと同じ JPEG（4 : 3・長い辺は 2048 px 以下）
    @Test
    func samplePhotoIsSavableJPEG() throws {
        let data = try #require(SamplePhoto.jpegData())
        let saved = try properties(of: data)
        #expect(saved[kCGImagePropertyPixelWidth] as? Int == SamplePhoto.width)
        #expect(saved[kCGImagePropertyPixelHeight] as? Int == SamplePhoto.height)
        #expect(max(SamplePhoto.width, SamplePhoto.height) <= PiecePhotoImage.maximumPixelLength)
        #expect(try typeIdentifier(of: data) == UTType.jpeg.identifier)
    }

    // MARK: - テスト用の画像

    /// 左半分が青・右半分が緑の不透明な画像
    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return try #require(context.makeImage())
    }

    private func makeJPEG(width: Int, height: Int, properties: [CFString: Any]) throws -> Data {
        try encode(try makeImage(width: width, height: height), type: .jpeg, properties: properties)
    }

    /// すべて透明な PNG
    private func makePNGWithTransparency(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return try encode(try #require(context.makeImage()), type: .png, properties: [:])
    }

    private func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func typeIdentifier(of data: Data) throws -> String? {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceGetType(source) as String?
    }

    /// 左上の画素の RGB
    private func firstPixel(of data: Data) throws -> [UInt8] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixel = [UInt8](repeating: 0, count: 4)
        let isDrawn = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                return false
            }
            // 左上の 1 画素だけを 1 × 1 に描く（CGContext の原点は左下）
            context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
            return true
        }
        #expect(isDrawn)
        return Array(pixel.prefix(3))
    }
}
