#!/usr/bin/env swift
//
//  make-app-icon-layers.swift
//
//  今のアプリのアイコン（AppIcon.appiconset の 1 枚の平面のイラスト）を、Liquid Glass のアイコン（Icon Composer の .icon）の
//  層の素材に切り分け、透過 PNG（1024 × 1024。元の絵と同じ位置・同じ大きさのキャンバス）に書き出す。
//
//  - 背景（水色）は画像にせず、.icon の icon.json の塗り（fill）で表す。塗りの色は実行したときに表示する
//  - piece.png … パズルのピース（赤い面と線）。キャラクターに隠れている部分は、見えている 4 辺を延ばした
//    ひし形（pieceCorners）で推測し、ピースの赤で塗る（キャラクターの下だけに描き足すので、重ねたときの見た目は変わらない）
//  - character.png … キャラクター（白い体・顔・腕・黄色い枠のカード・それらの線）
//
//  切り分け方:
//  1. 画像の縁から、背景の色に近い画素を塗りつぶして背景を決める。残りが前景（ピースとキャラクター）
//  2. 画像の縁から、明るい画素（白・灰色・黄色）以外を塗りつぶす。届かなかった画素がキャラクターの面（線に囲まれた内側）
//  3. キャラクターの面から outlineReach 画素以内の、背景・ピースの赤でない前景の画素（キャラクターの線）をキャラクターに足す
//  4. 前景のうちキャラクターでない画素がピース。ひし形の内側でキャラクターに隠れた画素を赤で塗る
//
//  最後に、塗りの色の上に piece.png・character.png を重ね直し、元の絵との差を表示する（背景の汚れのほかに大きく違う画素があれば止まる）。
//  `--composite <パス>` を付けると、重ね直した画像をそのパスに書き出す（確かめ用。コミットしない）。
//
//  使い方（リポジトリの直下で）: swift scripts/make-app-icon-layers.swift [--composite /tmp/composite.png]
//

import AppKit

let sourcePath = "demomoni-remake-ios/Assets.xcassets/AppIcon.appiconset/demomoni-AppIcon.png"
let outputDirectory = "docs/app-icon/layers"
let size = 1024

/// 画素の色（0〜255）
struct RGB {
    var red: Int
    var green: Int
    var blue: Int

    /// 色の差（RGB の差の絶対値の和）
    func difference(_ other: Self) -> Int {
        abs(red - other.red) + abs(green - other.green) + abs(blue - other.blue)
    }
}

/// 背景の色（元の絵の水色）
let backgroundColor = RGB(red: 172, green: 226, blue: 242)
/// ピースの面の色（元の絵の赤）
let pieceColor = RGB(red: 247, green: 136, blue: 142)
/// 背景・ピースの色とみなす色の差（RGB の差の絶対値の和）
let colorTolerance = 60
/// キャラクターの面から線の外側の縁までの距離（画素）。線の太さは 7 画素ほど
let outlineReach = 9
/// これより小さい前景のかたまりは、背景の上の汚れとして背景に含める（画素の数）
let speckArea = 200
/// ピースのひし形の 4 隅（左・上・右・下。左上が原点）。見えている辺の外側の縁を延ばして交わる点を、元の絵から測った
let pieceCorners: [CGPoint] = [
    CGPoint(x: 83, y: 570),
    CGPoint(x: 522, y: 182),
    CGPoint(x: 973, y: 597),
    CGPoint(x: 505, y: 980)
]

struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    /// 色の変換をせずに読む（元の PNG は色のプロファイルを持たないので、値をそのまま sRGB として扱う）
    init(contentsOfFile path: String) {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("読めない: \(path)")
        }
        guard let sRGBImage = image.copy(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
            fatalError("sRGB として扱えない: \(path)")
        }
        self.init(width: image.width, height: image.height)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        withContext { $0.draw(sRGBImage, in: bounds) }
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

    /// 左上を原点にした画素の番号（CGContext の行は上から並ぶ）
    func rgb(_ index: Int) -> RGB {
        RGB(red: Int(pixels[index * 4]), green: Int(pixels[index * 4 + 1]), blue: Int(pixels[index * 4 + 2]))
    }

    /// 不透明な画素にする
    mutating func set(_ index: Int, _ color: RGB) {
        pixels[index * 4] = UInt8(color.red)
        pixels[index * 4 + 1] = UInt8(color.green)
        pixels[index * 4 + 2] = UInt8(color.blue)
        pixels[index * 4 + 3] = 255
    }

    mutating func writePNG(to path: String) {
        var data: Data?
        withContext { context in
            guard let image = context.makeImage() else {
                return
            }
            data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        }
        guard let data, FileManager.default.createFile(atPath: path, contents: data) else {
            fatalError("書き込めない: \(path)")
        }
    }
}

func neighbors(_ index: Int, diagonal: Bool = false) -> [Int] {
    let x = index % size
    let y = index / size
    let steps = diagonal
        ? [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]
        : [(-1, 0), (1, 0), (0, -1), (0, 1)]
    return steps.compactMap { dx, dy in
        let nx = x + dx
        let ny = y + dy
        return nx >= 0 && nx < size && ny >= 0 && ny < size ? ny * size + nx : nil
    }
}

/// 画像の縁の画素のうち passable なものから、passable な画素を塗りつぶす
func floodFromEdges(_ passable: [Bool]) -> [Bool] {
    var reached = [Bool](repeating: false, count: size * size)
    var stack: [Int] = []
    for index in 0..<(size * size) {
        let x = index % size
        let y = index / size
        if (x == 0 || y == 0 || x == size - 1 || y == size - 1) && passable[index] {
            reached[index] = true
            stack.append(index)
        }
    }
    while let index = stack.popLast() {
        for next in neighbors(index) where passable[next] && !reached[next] {
            reached[next] = true
            stack.append(next)
        }
    }
    return reached
}

/// mask の中の、つながった画素のかたまり（上下左右）ごとの画素の番号
func components(of mask: [Bool]) -> [[Int]] {
    var visited = [Bool](repeating: false, count: size * size)
    var result: [[Int]] = []
    for start in 0..<(size * size) where mask[start] && !visited[start] {
        visited[start] = true
        var stack = [start]
        var members: [Int] = []
        while let index = stack.popLast() {
            members.append(index)
            for next in neighbors(index) where mask[next] && !visited[next] {
                visited[next] = true
                stack.append(next)
            }
        }
        result.append(members)
    }
    return result
}

/// 多角形の内側か（偶奇規則）
func contains(_ polygon: [CGPoint], _ point: CGPoint) -> Bool {
    var inside = false
    var previous = polygon[polygon.count - 1]
    for current in polygon {
        if (current.y > point.y) != (previous.y > point.y) {
            let crossX = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
            if point.x < crossX {
                inside.toggle()
            }
        }
        previous = current
    }
    return inside
}

let source = Bitmap(contentsOfFile: sourcePath)
precondition(source.width == size && source.height == size, "元のアイコンが 1024 × 1024 でない")
let count = size * size
let isBackgroundColor = (0..<count).map { source.rgb($0).difference(backgroundColor) < colorTolerance }
let isPieceColor = (0..<count).map { source.rgb($0).difference(pieceColor) < colorTolerance }

// 1. 背景と前景
var isForeground = floodFromEdges(isBackgroundColor).map { !$0 }
var speckPixels = 0
for component in components(of: isForeground) where component.count < speckArea {
    speckPixels += component.count
    for index in component {
        isForeground[index] = false
    }
}

// 2. キャラクターの面（白・灰色・黄色の明るい画素に囲まれた内側）
let isLight = (0..<count).map { index in
    let color = source.rgb(index)
    return (color.red + color.green + color.blue) / 3 >= 215 && !isBackgroundColor[index]
}
var isCharacter = floodFromEdges(isLight.map { !$0 }).map { !$0 }
for component in components(of: isCharacter) where component.count < speckArea {
    for index in component {
        isCharacter[index] = false
    }
}

// 3. キャラクターの線（面から outlineReach 画素以内の、背景・ピースの赤でない前景）
var reach = [Int](repeating: Int.max, count: count)
var queue = (0..<count).filter { isCharacter[$0] }
for index in queue {
    reach[index] = 0
}
var head = 0
while head < queue.count {
    let index = queue[head]
    head += 1
    guard reach[index] < outlineReach else {
        continue
    }
    for next in neighbors(index, diagonal: true) where reach[next] == Int.max {
        reach[next] = reach[index] + 1
        if isForeground[next] && !isPieceColor[next] {
            isCharacter[next] = true
            queue.append(next)
        }
    }
}

// 4. 層の画像
var piece = Bitmap(width: size, height: size)
var character = Bitmap(width: size, height: size)
var filledPixels = 0
for index in 0..<count where isForeground[index] {
    let color = source.rgb(index)
    if isCharacter[index] {
        character.set(index, color)
        let point = CGPoint(x: Double(index % size) + 0.5, y: Double(index / size) + 0.5)
        if contains(pieceCorners, point) {
            piece.set(index, pieceColor)
            filledPixels += 1
        }
    } else {
        piece.set(index, color)
    }
}
try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
piece.writePNG(to: "\(outputDirectory)/piece.png")
character.writePNG(to: "\(outputDirectory)/character.png")
print("wrote: \(outputDirectory)/piece.png（ピース。キャラクターの下に描き足した画素: \(filledPixels)）")
print("wrote: \(outputDirectory)/character.png（キャラクター）")
print(String(
    format: "背景の塗り: #%02X%02X%02X（icon.json の fill は srgb:%.5f,%.5f,%.5f,1.00000）",
    backgroundColor.red,
    backgroundColor.green,
    backgroundColor.blue,
    Double(backgroundColor.red) / 255,
    Double(backgroundColor.green) / 255,
    Double(backgroundColor.blue) / 255
))

// 5. 塗りの上に piece → character の順で重ね直し、元の絵と比べる（層は不透明か透明の 2 値なので、上の層の画素で置き換える）
var composite = Bitmap(width: size, height: size)
var differences: [Int] = []
for index in 0..<count {
    let color: RGB
    if character.pixels[index * 4 + 3] > 0 {
        color = character.rgb(index)
    } else if piece.pixels[index * 4 + 3] > 0 {
        color = piece.rgb(index)
    } else {
        color = backgroundColor
    }
    composite.set(index, color)
    let original = source.rgb(index)
    differences.append(max(abs(color.red - original.red), abs(color.green - original.green), abs(color.blue - original.blue)))
}
let changed = differences.filter { $0 > 0 }.count
let large = differences.filter { $0 > colorTolerance }.count
print("重ね直した絵と元の絵の差: 違う画素 \(changed) / \(count)・差が \(colorTolerance) を超える画素 \(large)（背景の汚れとして消した画素 \(speckPixels)）")
if let index = CommandLine.arguments.firstIndex(of: "--composite"), index + 1 < CommandLine.arguments.count {
    composite.writePNG(to: CommandLine.arguments[index + 1])
    print("wrote: \(CommandLine.arguments[index + 1])（重ね直した絵）")
}
// 大きく違ってよいのは、背景の汚れとして消した画素だけ
if large > speckPixels {
    fputs("重ね直した絵が元の絵と大きく違う\n", stderr)
    exit(1)
}
