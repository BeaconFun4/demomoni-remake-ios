//
//  PiecePhotoSquare.swift
//  demomoni-remake-ios
//

import SwiftUI

/// ピースの裏側の写真。写真のまんなかを正方形に切り抜いて出し、手書きがあれば重ねる。
/// 手書きは正方形の枠を 400 × 400 とした座標で保存している（`SignatureDrawing`）ので、枠の大きさが変わっても位置がずれない
struct PiecePhotoSquare: View {
    /// 写真の JPEG（`PiecePhotoImage` で縮めたもの）
    let photo: Data
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
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFill()
                } else {
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
            .task(id: photo) {
                photoImage = await Self.decode(photo)
            }
            .task(id: drawing) {
                drawingImage = drawing.flatMap { SignatureDrawing.image(from: $0) }
            }
    }

    /// 写真を、画面に出せるようにデコードしておいた画像にする（MainActor の外で行う）。壊れていれば `nil`
    @concurrent
    nonisolated private static func decode(_ data: Data) async -> UIImage? {
        UIImage(data: data)?.preparingForDisplay()
    }
}
