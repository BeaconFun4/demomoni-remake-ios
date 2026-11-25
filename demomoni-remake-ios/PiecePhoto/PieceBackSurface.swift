//
//  PieceBackSurface.swift
//  demomoni-remake-ios
//

import SwiftUI

/// ピースを裏から見た形。縦の軸で回したときの本物の裏と同じく、表のピースの画像（の不透明なところ）を左右反転したもの。
/// 画像のうちピースが入るまんなか（`PieceBackLayout.visibleRect`）が、置き場所の正方形いっぱいになるよう拡大して出す
struct PieceBackSilhouette: View {
    let piece: Piece

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(piece.image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: -PieceBackLayout.zoom, y: PieceBackLayout.zoom)
            }
            .accessibilityHidden(true)
    }
}

/// ピースの裏側の面。白い裏地に写真を敷き、その上に手書きを重ね、すべてをピースを裏から見た形（`PieceBackSilhouette`）で切り抜く。
/// 写真も手書きも形の外には出さない。手書きはサインと同じ 400 × 400 の座標で保存していて、そのうち `PieceBackLayout.visibleRect` を出す
struct PieceBackSurface: View {
    let piece: Piece
    /// 写真の JPEG（`PiecePhotoImage` で縮めたもの）。無ければ白い裏地だけ
    let photo: Data?
    /// 写真の上の手書きの `PKDrawing` のデータ。無ければ写真だけ
    let drawing: Data?

    /// 写真の画像。大きいので MainActor の外で読み、写真が変わったときだけ作り直す
    @State private var photoImage: UIImage?
    /// 手書きの画像。手書きのデータが変わったときだけ作り直す
    @State private var drawingImage: UIImage?

    var body: some View {
        Color.themeColorWhite
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let photoImage {
                    // 写真は形の外接する正方形いっぱいに敷き、はみ出したところは形で切り抜く
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFill()
                } else if photo != nil {
                    ProgressView()
                }
            }
            .overlay {
                if let drawingImage {
                    Image(uiImage: drawingImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            .clipped()
            .mask {
                PieceBackSilhouette(piece: piece)
            }
            // 切り抜いた形の縁が裏地の色に溶けないよう、形に沿って影を付ける
            .compositingGroup()
            .shadow(color: .black.opacity(0.35), radius: 3)
            .task(id: photo) {
                if let photo {
                    photoImage = await Self.decode(photo)
                } else {
                    photoImage = nil
                }
            }
            .task(id: drawing) {
                // 拡大して出すので、細い線がぼやけないよう高い倍率で描く
                drawingImage = drawing.flatMap { SignatureDrawing.image(from: $0, rect: PieceBackLayout.visibleRect, scale: 4) }
            }
    }

    /// 写真を、画面に出せるようにデコードしておいた画像にする（MainActor の外で行う）。壊れていれば `nil`
    @concurrent
    nonisolated private static func decode(_ data: Data) async -> UIImage? {
        UIImage(data: data)?.preparingForDisplay()
    }
}
