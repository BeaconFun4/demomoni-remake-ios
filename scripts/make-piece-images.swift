#!/usr/bin/env swift
//
//  make-piece-images.swift
//
//  goryokaku_long（800 × 1600）を、PieceAllBorder（盤の枠）の形で 4 列 × 8 行の 32 枚のピースに切り出し、
//  Assets.xcassets/Pieces/piece<N>.imageset に書き出す（N = 1〜32。左上から行ごとに数える）。
//
//  - 画像は 400 × 400。中央の 200 × 200 がマスで、外側に出っ張りが入る（PieceBoardLayout・SignatureDrawing と同じ）
//  - ピースの形は、枠の線で区切られた領域を各マスの中心から塗りつぶし、線の画素を近いほうの領域に分けて決める
//    （隣り合うピースの境目が線の中央になり、盤の外周の線はそのマスに入る）
//  - 縁は元の piece1 / piece14 にならって、形の内側を黒くぼかす
//  - 既にある imageset は上書きしない（元アプリから持ってきた piece1・piece14 を残すため）。`--force` で上書きする
//
//  使い方（リポジトリの直下で）: swift scripts/make-piece-images.swift [--force]
//

import AppKit

let assets = "demomoni-remake-ios/Assets.xcassets"
let force = CommandLine.arguments.contains("--force")
let columns = 4
let rows = 8
let cell = 200
let canvas = cell * 2
/// 形の縁からの距離（画素）ごとの明るさ。元の piece1 の左端の画素から読み取った
let edgeShade: [Double] = [0, 0.035, 0.09, 0.22, 0.41, 0.61, 0.79, 0.9, 0.96, 0.98, 1]

struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    init(contentsOfFile path: String) {
        guard let image = NSImage(contentsOfFile: path) else {
            fatalError("読めない: \(path)")
        }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            fatalError("CGImage にできない: \(path)")
        }
        self.init(width: cgImage.width, height: cgImage.height)
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        withContext { $0.draw(cgImage, in: bounds) }
    }

    mutating func withContext(_ body: (CGContext) -> Void) {
        let width = width
        let height = height
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                fatalError("CGContext を作れない")
            }
            body(context)
        }
    }

    /// 左上を原点にした (x, y) の画素の先頭の位置（CGContext の行は上から並ぶ）
    func offset(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }

    mutating func writePNG(to path: String) {
        var data: Data?
        withContext { context in
            guard let cgImage = context.makeImage() else {
                return
            }
            data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        }
        guard let data else {
            fatalError("PNG にできない: \(path)")
        }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}

let photo = Bitmap(contentsOfFile: "\(assets)/Goryokaku/goryokaku_long.imageset/goryokaku_long.png")
let border = Bitmap(contentsOfFile: "\(assets)/Pieces/PieceAllBorder.imageset/PieceAllBorder.png")
let width = border.width
let height = border.height
precondition(width == columns * cell && height == rows * cell, "PieceAllBorder の大きさが 800 × 1600 でない")
precondition(photo.width == width && photo.height == height, "goryokaku_long と PieceAllBorder の大きさが違う")

// 1. 線（不透明度が半分以上）で区切られた領域を、各マスの中心から塗りつぶす。label は 1〜32、線は 0
var label = [Int](repeating: 0, count: width * height)
let isLine = (0..<(width * height)).map { border.pixels[$0 * 4 + 3] >= 128 }
var queue: [Int] = []
for number in 1...(columns * rows) {
    let column = (number - 1) % columns
    let row = (number - 1) / columns
    let seed = (row * cell + cell / 2) * width + column * cell + cell / 2
    precondition(!isLine[seed] && label[seed] == 0, "No.\(number) のマスの中心が線か、別のマスとつながっている")
    label[seed] = number
    var stack = [seed]
    while let index = stack.popLast() {
        queue.append(index)
        let x = index % width
        let y = index / width
        for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
        where nx >= 0 && nx < width && ny >= 0 && ny < height {
            let next = ny * width + nx
            if !isLine[next] && label[next] == 0 {
                label[next] = number
                stack.append(next)
            }
        }
    }
}

// 2. 線の画素を、いちばん近い領域に分ける（領域から外へ 1 画素ずつ広げる）
var head = 0
while head < queue.count {
    let index = queue[head]
    head += 1
    let x = index % width
    let y = index / width
    for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
    where nx >= 0 && nx < width && ny >= 0 && ny < height {
        let next = ny * width + nx
        if label[next] == 0 {
            label[next] = label[index]
            queue.append(next)
        }
    }
}

/// 形の内側の画素の、形の縁までの距離（2 回の走査による近似のユークリッド距離）
func distanceToEdge(inside: [Bool], size: Int) -> [Double] {
    let far = Double(size * 2)
    var distance = inside.map { $0 ? far : 0 }
    let diagonal = 2.0.squareRoot()
    func relax(_ x: Int, _ y: Int, _ dx: Int, _ dy: Int, _ cost: Double) {
        let nx = x + dx
        let ny = y + dy
        // 画像の外は形の外として扱う
        let neighbor = (nx >= 0 && nx < size && ny >= 0 && ny < size) ? distance[ny * size + nx] : 0
        distance[y * size + x] = min(distance[y * size + x], neighbor + cost)
    }
    for y in 0..<size {
        for x in 0..<size where inside[y * size + x] {
            relax(x, y, -1, 0, 1)
            relax(x, y, 0, -1, 1)
            relax(x, y, -1, -1, diagonal)
            relax(x, y, 1, -1, diagonal)
        }
    }
    for y in (0..<size).reversed() {
        for x in (0..<size).reversed() where inside[y * size + x] {
            relax(x, y, 1, 0, 1)
            relax(x, y, 0, 1, 1)
            relax(x, y, 1, 1, diagonal)
            relax(x, y, -1, 1, diagonal)
        }
    }
    // 縁に接する画素の中心は、縁から 0.5 画素の位置にある
    return distance.map { max($0 - 0.5, 0) }
}

func shade(_ distance: Double) -> Double {
    let position = min(distance, Double(edgeShade.count - 1))
    let lower = Int(position)
    let upper = min(lower + 1, edgeShade.count - 1)
    let fraction = position - Double(lower)
    return edgeShade[lower] * (1 - fraction) + edgeShade[upper] * fraction
}

let contents = """
{
  "images" : [
    {
      "filename" : "piece%d.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

// 3. マスごとに 400 × 400 の画像を作る（マスの左上が画像の (100, 100)）
for number in 1...(columns * rows) {
    let directory = "\(assets)/Pieces/piece\(number).imageset"
    if FileManager.default.fileExists(atPath: directory) && !force {
        print("skip: piece\(number)（既にある）")
        continue
    }
    let originX = (number - 1) % columns * cell - cell / 2
    let originY = (number - 1) / columns * cell - cell / 2
    var inside = [Bool](repeating: false, count: canvas * canvas)
    for y in 0..<canvas {
        for x in 0..<canvas {
            let boardX = originX + x
            let boardY = originY + y
            if boardX >= 0 && boardX < width && boardY >= 0 && boardY < height {
                inside[y * canvas + x] = label[boardY * width + boardX] == number
            }
        }
    }
    let distance = distanceToEdge(inside: inside, size: canvas)
    var piece = Bitmap(width: canvas, height: canvas)
    for y in 0..<canvas {
        for x in 0..<canvas where inside[y * canvas + x] {
            let source = photo.offset(originX + x, originY + y)
            let target = piece.offset(x, y)
            let factor = shade(distance[y * canvas + x])
            for channel in 0..<3 {
                piece.pixels[target + channel] = UInt8((Double(photo.pixels[source + channel]) * factor).rounded())
            }
            piece.pixels[target + 3] = 255
        }
    }
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    piece.writePNG(to: "\(directory)/piece\(number).png")
    try String(format: contents, number).write(toFile: "\(directory)/Contents.json", atomically: true, encoding: .utf8)
    print("wrote: piece\(number)")
}
