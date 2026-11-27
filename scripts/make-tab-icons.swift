#!/usr/bin/env swift
//
//  make-tab-icons.swift
//
//  タブのアイコン（うさと、タブの意味が分かる小物）を、単色のテンプレート画像（ベクターの PDF）として
//  Assets.xcassets/TabIcon/<名前>.imageset に書き出す。タブバーが、選択中は選択色（ThemeColorPink）、それ以外はラベルと同じ色で塗る。
//
//  - うさの形は歩くうさ（tekuusa）とアプリのアイコンにならう: 上で 2 つにふくらんだ耳（間に縦の線）・ほっぺの張った顔・点の目・「ω」の口
//  - うさは線画（元の絵と同じく線で描く）、小物（？・虫眼鏡・ピース・歯車）は塗りにして、小さくても形が分かるようにする
//  - 手前のものに隠れる線は、手前のものの形から少し離して切る
//  - 図は 100 × 100 の座標（y は下向き）で描き、`size` pt の正方形の PDF にする
//
//  使い方（リポジトリの直下で）:
//    swift scripts/make-tab-icons.swift                      … Assets.xcassets に書き出す
//    swift scripts/make-tab-icons.swift --preview <フォルダ>  … 確かめるための PNG（線画の案・塗りの案）を書き出す（Assets は変えない）
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - 設定

/// PDF の大きさ（pt）。タブバーは画像の大きさのまま出すので、SF Symbols のアイコンと見た目の大きさをそろえる
let size: CGFloat = 30
/// うさの線の太さ（100 × 100 の座標で）
let lineWidth: CGFloat = 6.2
/// 手前のものと、後ろの線の間のすき間
let gap: CGFloat = 2.6
let assets = "demomoni-remake-ios/Assets.xcassets/TabIcon"

/// 描き方の案
enum Style: String, CaseIterable {
    /// うさは線画、小物は塗り（アプリに入れる案）
    case line
    /// うさも塗り（目・口・耳の線を抜く）
    case filled
}

// MARK: - 形を作る道具

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) -> CGPath {
    var transform = CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation)
    return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &transform)
}

func circle(_ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat) -> CGPath {
    ellipse(cx, cy, radius, radius)
}

/// 線を、丸い端の塗りの形にする
func stroked(_ path: CGPath, _ width: CGFloat) -> CGPath {
    path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4)
}

/// 点を結んだ線
func polyline(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    return path
}

func unionAll(_ paths: [CGPath]) -> CGPath {
    guard let first = paths.first else {
        return CGMutablePath()
    }
    return paths.dropFirst().reduce(first) { $0.union($1) }
}

/// 形を `amount` だけ外へふくらませる
func dilated(_ path: CGPath, by amount: CGFloat) -> CGPath {
    amount > 0 ? path.union(stroked(path, amount * 2)) : path
}

extension CGPath {
    func transformed(_ transform: CGAffineTransform) -> CGPath {
        var transform = transform
        return copy(using: &transform) ?? self
    }
}

// MARK: - 層

/// 図の 1 つの層（うさ・小物）。後ろから順に重ねる
struct Layer {
    /// 後ろの層を隠す範囲
    var region: CGPath
    /// 案ごとに塗る形
    var ink: [Style: CGPath]
    /// 塗る形が `region` より外へはみ出す幅（線画の線の半分）。後ろの層はこれとすき間の分だけ離して切る
    var overhang: [Style: CGFloat]
}

/// 線画でも塗りでも同じ形で塗る小物
func solidLayer(_ region: CGPath, ink: CGPath? = nil) -> Layer {
    let ink = ink ?? region
    return Layer(region: region, ink: [.line: ink, .filled: ink], overhang: [.line: 0, .filled: 0])
}

/// 線画の案では輪郭の線と `lines`・`dots`、塗りの案では塗った形から `lines`・`dots` を抜いたものにする（うさ）
func characterLayer(_ region: CGPath, lines: CGPath? = nil, dots: CGPath? = nil) -> Layer {
    var lineInk = stroked(region, lineWidth)
    var holes: [CGPath] = []
    if let lines {
        lineInk = lineInk.union(lines)
        holes.append(lines)
    }
    if let dots {
        lineInk = lineInk.union(dots)
        holes.append(dots)
    }
    let filledInk = holes.isEmpty ? region : region.subtracting(unionAll(holes))
    return Layer(region: region, ink: [.line: lineInk, .filled: filledInk], overhang: [.line: lineWidth / 2, .filled: 0])
}

/// 層を重ねて、塗る形を 1 つにする。後ろの層は、手前の層の範囲（とはみ出し・すき間）を切り抜く
func compose(_ layers: [Layer], style: Style) -> CGPath {
    var result: CGPath?
    for (index, layer) in layers.enumerated() {
        guard var ink = layer.ink[style] else {
            continue
        }
        let front = layers[(index + 1)...].map { dilated($0.region, by: ($0.overhang[style] ?? 0) + gap) }
        if !front.isEmpty {
            ink = ink.subtracting(unionAll(front))
        }
        result = result.map { $0.union(ink) } ?? ink
    }
    return result ?? CGMutablePath()
}

// MARK: - うさ

/// うさの顔（耳を含む）。原点が顔の中心、顔の幅はおよそ 62
struct Usa {
    /// 置く位置・大きさ・傾き
    var center: CGPoint
    var scale: CGFloat
    var rotation: CGFloat = 0

    var transform: CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotation).scaledBy(x: scale, y: scale)
    }

    /// 顔の中の点を、図の座標に直す
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y).applying(transform)
    }

    var rightEye: CGPoint {
        point(9.5, -3.5)
    }

    var layer: Layer {
        // 顔は横に広く、ほっぺが張る。耳は 2 つの楕円を重ね、上のくぼみが耳の境目になる
        let face = ellipse(0, 0, 31, 22.5)
        let leftEar = ellipse(-9.5, -33, 13.5, 19, rotation: -0.06)
        let rightEar = ellipse(9.5, -33, 13.5, 19, rotation: 0.06)
        let head = unionAll([face, leftEar, rightEar])
        // 耳の間の線（くぼみから耳の半ばまで）
        let earLine = stroked(polyline([CGPoint(x: 0, y: -44), CGPoint(x: 0, y: -30)]), lineWidth * 0.8)
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: -5.5, y: 2.2))
        mouth.addQuadCurve(to: CGPoint(x: 0, y: 2.6), control: CGPoint(x: -2.8, y: 6.6))
        mouth.addQuadCurve(to: CGPoint(x: 5.5, y: 2.2), control: CGPoint(x: 2.8, y: 6.6))
        let eyes = unionAll([
            ellipse(-9.5, -3.5, 3.9, 3.4),
            ellipse(9.5, -3.5, 3.9, 3.4)
        ])
        let lines = earLine.union(stroked(mouth, lineWidth * 0.62))
        return characterLayer(
            head.transformed(transform),
            lines: lines.transformed(transform),
            dots: eyes.transformed(transform)
        )
    }
}

// MARK: - 小物

/// 「？」
func questionMark(x: CGFloat, y: CGFloat, height: CGFloat) -> CGPath {
    let unit = height / 40
    let path = CGMutablePath()
    let radius = 9.5 * unit
    let center = CGPoint(x: x, y: y + radius)
    path.addArc(center: center, radius: radius, startAngle: .pi * 1.02, endAngle: .pi * 2.28, clockwise: false)
    path.addQuadCurve(to: CGPoint(x: x, y: y + 27 * unit), control: CGPoint(x: x, y: y + 21 * unit))
    path.addLine(to: CGPoint(x: x, y: y + 29 * unit))
    return stroked(path, 7.4 * unit).union(circle(x, y + 37.5 * unit, 4.6 * unit))
}

/// 虫眼鏡（輪と柄）。輪の内側は後ろのうさを隠し、大きく見えた目（`eye` の大きさの倍率）を出す。
/// 線画の案では目を塗り、塗りの案ではレンズの中を塗って目を抜く（うさの顔と同じ描き方）
func magnifier(center: CGPoint, radius: CGFloat, eye: CGFloat) -> Layer {
    let ringWidth: CGFloat = 6
    let ring = stroked(circle(center.x, center.y, radius), ringWidth)
    let direction = CGPoint(x: cos(CGFloat.pi / 4), y: sin(CGFloat.pi / 4))
    let start = CGPoint(x: center.x + direction.x * (radius + 2), y: center.y + direction.y * (radius + 2))
    let end = CGPoint(x: center.x + direction.x * (radius + 20), y: center.y + direction.y * (radius + 20))
    let handle = stroked(polyline([start, end]), 10)
    let magnifiedEye = ellipse(center.x, center.y, 3.9 * eye, 3.4 * eye)
    let region = circle(center.x, center.y, radius + ringWidth / 2).union(handle)
    return Layer(
        region: region,
        ink: [
            .line: unionAll([ring, handle, magnifiedEye]),
            .filled: region.subtracting(magnifiedEye)
        ],
        overhang: [.line: 0, .filled: 0]
    )
}

/// パズルのピース（上と右に出っ張り）
func puzzlePiece(x: CGFloat, y: CGFloat, side: CGFloat) -> CGPath {
    let body = CGPath(roundedRect: CGRect(x: x, y: y, width: side, height: side), cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)
    let knob = side * 0.2
    let top = circle(x + side / 2, y - knob * 0.55, knob)
    let right = circle(x + side + knob * 0.55, y + side / 2, knob)
    return unionAll([body, top, right])
}

/// 歯車（真ん中に穴）
func gear(center: CGPoint, radius: CGFloat, teeth: Int = 8) -> CGPath {
    let inner = radius * 0.76
    let half = CGFloat.pi / CGFloat(teeth)
    let outline = CGMutablePath()
    for index in 0..<teeth {
        let angle = CGFloat(index) * half * 2 - .pi / 2
        let points: [(CGFloat, CGFloat)] = [
            (angle - half * 0.78, inner),
            (angle - half * 0.42, radius),
            (angle + half * 0.42, radius),
            (angle + half * 0.78, inner)
        ]
        for (pointAngle, length) in points {
            let point = CGPoint(x: center.x + cos(pointAngle) * length, y: center.y + sin(pointAngle) * length)
            if outline.isEmpty {
                outline.move(to: point)
            } else {
                outline.addLine(to: point)
            }
        }
    }
    outline.closeSubpath()
    // 角を少し丸める
    let rounded = outline.union(stroked(outline, 2.4))
    return rounded.subtracting(circle(center.x, center.y, radius * 0.34))
}

// MARK: - アイコン

struct TabIcon {
    /// アセットの名前
    let name: String
    let layers: [Layer]
}

let icons: [TabIcon] = {
    // なぞなぞ: 首をかしげて考えているうさと「？」
    let thinking = Usa(center: CGPoint(x: 39, y: 63), scale: 0.86, rotation: -0.2)
    let riddle = TabIcon(name: "TabRiddle", layers: [
        thinking.layer,
        solidLayer(questionMark(x: 80, y: 6, height: 42))
    ])

    // さがす: 虫眼鏡を右の目に当てて、のぞいているうさ（レンズの中で目が大きく見える）
    let looking = Usa(center: CGPoint(x: 37, y: 57), scale: 0.84)
    let search = TabIcon(name: "TabSearch", layers: [
        looking.layer,
        // レンズは右の目から少し外へずらし、左の目を隠さない
        magnifier(center: CGPoint(x: looking.rightEye.x + 5, y: looking.rightEye.y + 1), radius: 12, eye: 1.6)
    ])

    // いちらん: パズルのピースを胸の前に持っているうさ
    let holding = Usa(center: CGPoint(x: 45, y: 45), scale: 0.8)
    let pieceList = TabIcon(name: "TabPieceList", layers: [
        holding.layer,
        solidLayer(puzzlePiece(x: 30, y: 62, side: 30))
    ])

    // せってい: 歯車の後ろから顔を出すうさ
    let settingUp = Usa(center: CGPoint(x: 38, y: 52), scale: 0.84)
    let settings = TabIcon(name: "TabSettings", layers: [
        settingUp.layer,
        solidLayer(gear(center: CGPoint(x: 72, y: 72), radius: 22))
    ])

    return [riddle, search, pieceList, settings]
}()

// MARK: - 書き出し

/// 100 × 100（y は下向き）の図を、PDF の座標（y は上向き）の `side` pt に直す
func canvasTransform(side: CGFloat) -> CGAffineTransform {
    CGAffineTransform(a: side / 100, b: 0, c: 0, d: -side / 100, tx: 0, ty: side)
}

func writePDF(_ path: CGPath, to url: URL) {
    var mediaBox = CGRect(x: 0, y: 0, width: size, height: size)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        fatalError("PDF を作れない: \(url.path)")
    }
    context.beginPDFPage(nil)
    context.addPath(path.transformed(canvasTransform(side: size)))
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillPath(using: .evenOdd)
    context.endPDFPage()
    context.closePDF()
    makeReproducible(url)
}

/// PDF に入る作成日時・更新日時・ID を、同じ長さの固定の値にする（図が変わらなければ、書き出し直しても差分が出ないように）。
/// 長さを変えると相互参照表の位置がずれるので、桁の数を保つ
func makeReproducible(_ url: URL) {
    guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .isoLatin1) else {
        fatalError("PDF を読めない: \(url.path)")
    }
    let replacements = [
        (#"D:\d{14}"#, "D:20260101000000"),
        (#"<[0-9a-f]{32}>"#, "<" + String(repeating: "0", count: 32) + ">")
    ]
    let fixedText = replacements.reduce(text) { text, replacement in
        text.replacingOccurrences(of: replacement.0, with: replacement.1, options: .regularExpression)
    }
    guard let fixedData = fixedText.data(using: .isoLatin1) else {
        fatalError("PDF を書けない: \(url.path)")
    }
    try? fixedData.write(to: url)
}

func writePNG(width: Int, height: Int, to url: URL, draw: (CGContext) -> Void) {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("画像を作れない")
    }
    draw(context)
    guard let image = context.makeImage() else {
        fatalError("画像を作れない")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG にできない")
    }
    try? data.write(to: url)
}

let imageContents = """
{
  "images" : [
    {
      "filename" : "%@.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}

"""

let folderContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--preview"), arguments.indices.contains(index + 1) {
    // 確かめるための PNG: 案ごとに、4 つのアイコンを選択色・灰色で、大きく（各 300 px）と、タブバーの大きさ（3x）で並べる
    let folder = URL(fileURLWithPath: arguments[index + 1])
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let pink = CGColor(srgbRed: 0.969, green: 0.533, blue: 0.557, alpha: 1)
    let gray = CGColor(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1)
    for style in Style.allCases {
        let paths = icons.map { compose($0.layers, style: style) }
        let big: CGFloat = 300
        let small = size * 3
        let height = big + small * 2 + 60
        let url = folder.appendingPathComponent("tab-icons-\(style.rawValue).png")
        writePNG(width: Int(big * 4), height: Int(height), to: url) { context in
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: big * 4, height: height))
            for (column, path) in paths.enumerated() {
                let x = CGFloat(column) * big
                context.saveGState()
                context.translateBy(x: x, y: small * 2 + 60)
                context.addPath(path.transformed(canvasTransform(side: big)))
                context.setFillColor(pink)
                context.fillPath(using: .evenOdd)
                context.restoreGState()
                for (row, color) in [pink, gray].enumerated() {
                    context.saveGState()
                    context.translateBy(x: x + (big - small) / 2, y: CGFloat(1 - row) * (small + 20) + 20)
                    context.addPath(path.transformed(canvasTransform(side: small)))
                    context.setFillColor(color)
                    context.fillPath(using: .evenOdd)
                    context.restoreGState()
                }
            }
        }
    }
    print("書き出した: \(folder.path)")
} else {
    let folder = URL(fileURLWithPath: assets)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try folderContents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    for icon in icons {
        let imageset = folder.appendingPathComponent("\(icon.name).imageset")
        try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
        writePDF(compose(icon.layers, style: .line), to: imageset.appendingPathComponent("\(icon.name).pdf"))
        try String(format: imageContents, icon.name).write(
            to: imageset.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )
        print("書き出した: \(imageset.path)")
    }
}
