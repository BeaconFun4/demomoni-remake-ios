#!/usr/bin/env swift
//
//  make-debug-app-icon.swift
//
//  Debug 構成のアプリのアイコン（AppIcon-Debug）を、アイコンの元の絵（docs/app-icon/demomoni-AppIcon.png）の下部に「debug」と書いて作る。
//  Debug 構成のビルドを jp.shilokuma.Demomoni-debug として TestFlight に配るときに、App Store 版と見分けるため。
//
//  - App Store 版のアイコン（AppIcon.icon。Liquid Glass）と違い、平面の 1 枚の画像のまま
//  - 元の絵の下に、線の色に近い濃いグレーの帯を敷き、白い太字で「debug」と書く
//  - App Store Connect は透明な画素のあるアイコンを受け付けないので、不透明な PNG にする
//
//  使い方（リポジトリの直下で）: swift scripts/make-debug-app-icon.swift
//

import AppKit

let assets = "demomoni-remake-ios/Assets.xcassets"
let sourcePath = "docs/app-icon/demomoni-AppIcon.png"
let directory = "\(assets)/AppIcon-Debug.appiconset"
let fileName = "demomoni-AppIcon-Debug.png"
let size = 1024
/// 帯の高さ（アイコンの高さに対する割合）
let bandRatio = 0.22
/// 帯の色（元のアイコンの線の色に近い濃いグレー）と不透明度
let bandColor = NSColor(srgbRed: 0.29, green: 0.29, blue: 0.29, alpha: 0.88)

guard let source = NSImage(contentsOfFile: sourcePath) else {
    fatalError("読めない: \(sourcePath)")
}
var proposed = CGRect(x: 0, y: 0, width: size, height: size)
guard let sourceImage = source.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
    fatalError("CGImage にできない: \(sourcePath)")
}
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("CGContext を作れない")
}

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
context.draw(sourceImage, in: bounds)

// CoreGraphics の原点は左下なので、帯は y = 0 から
let band = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size) * bandRatio)
context.setFillColor(bandColor.cgColor)
context.fill(band)

let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: band.height * 0.68, weight: .heavy),
    .foregroundColor: NSColor.white,
    .kern: 4
]
let text = NSAttributedString(string: "debug", attributes: attributes)
let textSize = text.size()
text.draw(at: CGPoint(x: band.midX - textSize.width / 2, y: band.midY - textSize.height / 2))
NSGraphicsContext.restoreGraphicsState()

guard let image = context.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("PNG にできない")
}
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
guard FileManager.default.createFile(atPath: "\(directory)/\(fileName)", contents: data) else {
    fatalError("書き込めない: \(directory)/\(fileName)")
}
let contents = """
{
  "images" : [
    {
      "filename" : "\(fileName)",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try contents.write(toFile: "\(directory)/Contents.json", atomically: true, encoding: .utf8)
print("wrote: \(directory)/\(fileName)")
