//
//  PieceBoard.swift
//  demomoni-remake-ios
//

import SwiftUI

/// いちらんの盤。五稜郭のモノクロの画像にピースの枠を重ね、獲得したピースを色つきでその番号のマスに置く。
/// ピースを押すと、そのピースを値にした `NavigationLink` でピース詳細を開く
struct PieceBoard: View {
    /// 獲得したピース
    let pieces: [Piece]

    var body: some View {
        ZStack {
            Color.white
            Image(.goryokakuLongMonochrome)
                .resizable()
                .opacity(0.35)
                .accessibilityHidden(true)
            Image(.pieceAllBorder)
                .resizable()
                .opacity(0.5)
                .accessibilityHidden(true)
        }
        .aspectRatio(PieceBoardLayout.aspectRatio, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                ForEach(pieces) { piece in
                    if let number = piece.number,
                       let frame = PieceBoardLayout.pieceImageFrame(number: number, in: proxy.size) {
                        NavigationLink(value: piece) {
                            Image(piece.image)
                                .resizable()
                        }
                        .buttonStyle(.plain)
                        .frame(width: frame.width, height: frame.height)
                        // 画像はマスの縦横 2 倍なので、押せる範囲は中央のマスだけにする（隣のマスと重ねない）
                        .contentShape(Rectangle().inset(by: frame.width / 4))
                        .position(x: frame.midX, y: frame.midY)
                        .accessibilityLabel("ピース No.\(number) \(piece.name)")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ゲットしたピース \(pieces.count) こ")
    }
}

#Preview {
    PieceBoard(pieces: Catalog.bundled.pieces)
        .padding()
}
