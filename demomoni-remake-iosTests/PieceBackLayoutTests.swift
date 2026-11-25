//
//  PieceBackLayoutTests.swift
//  demomoni-remake-iosTests
//

import CoreGraphics
@testable import demomoni_remake_ios
import Foundation
import Testing
import UIKit

/// ピースの裏側の大きさと、裏側に出す範囲
@MainActor
struct PieceBackLayoutTests {
    /// 同梱の 32 枚のピースの画像の、画素ごとの不透明度（400 × 400）
    private func alphaMap(of imageName: String) throws -> (width: Int, alpha: [UInt8]) {
        let image = try #require(UIImage(named: imageName)?.cgImage, "\(imageName) のアセット")
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        #expect(isDrawn)
        #expect(width == Int(PieceBackLayout.imageSide) && height == Int(PieceBackLayout.imageSide), "\(imageName) の大きさ")
        return (width, stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] })
    }

    /// どのピースも、不透明なところはすべて裏側に出す範囲（60〜340）の中にある（拡大しても欠けない）。
    /// どのピースでも、まんなかの正方形（140〜260）はすべて不透明（案内の文字が形からはみ出さない）。
    /// 範囲はどちらも左右対称なので、裏から見た（左右反転した）形でも同じ
    @Test
    func everyPieceFitsVisibleRect() throws {
        let visible = PieceBackLayout.visibleRect
        let inner = PieceBackLayout.innerRect
        #expect(visible.midX == PieceBackLayout.imageSide / 2 && inner.midX == PieceBackLayout.imageSide / 2)
        for number in PieceBoardLayout.numbers {
            let name = "piece\(number)"
            let (width, alpha) = try alphaMap(of: name)
            var outside = 0
            var transparentInside = 0
            for (index, value) in alpha.enumerated() {
                let point = CGPoint(x: CGFloat(index % width) + 0.5, y: CGFloat(index / width) + 0.5)
                if value > 8, !visible.contains(point) {
                    outside += 1
                }
                if value < 250, inner.contains(point) {
                    transparentInside += 1
                }
            }
            #expect(outside == 0, "\(name) の範囲の外の画素")
            #expect(transparentInside == 0, "\(name) のまんなかの透明な画素")
        }
    }

    /// 裏側は画面の幅から左右の余白を引いた幅（上限 560）。表は今までと同じ画面の幅の 8 割（上限 400）
    @Test(arguments: [
        (CGFloat(440), CGFloat(408), CGFloat(352)),
        (402, 370, 321.6),
        (375, 343, 300),
        (1024, 560, 400),
        (600, 560, 400)
    ])
    func sides(containerWidth: CGFloat, back: CGFloat, front: CGFloat) {
        let backSide = PieceBackLayout.backSide(containerWidth: containerWidth)
        #expect(backSide == back)
        #expect(abs(PieceBackLayout.frontSide(backSide: backSide) - front) < 0.001)
        #expect(abs(PieceBackLayout.frontSide(backSide: backSide) - min(containerWidth * 0.8, 400)) < 0.001)
    }

    /// 画面の幅が余白より狭くても、裏側の大きさは負にならない
    @Test
    func backSideIsNotNegative() {
        #expect(PieceBackLayout.backSide(containerWidth: 0) == 0)
        #expect(PieceBackLayout.backSide(containerWidth: 20) == 0)
    }

    /// 裏側では画像の全体を 400 ÷ 280 倍にして、範囲をちょうど置き場所いっぱいにする
    @Test
    func zoomFillsVisibleRect() {
        #expect(abs(PieceBackLayout.zoom * PieceBackLayout.visibleRect.width - PieceBackLayout.imageSide) < 0.001)
        #expect(abs(PieceBackLayout.innerFraction - 120.0 / 280.0) < 0.001)
    }
}
