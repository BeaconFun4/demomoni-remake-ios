//
//  PieceBoard.swift
//  demomoni-remake-ios
//

import SwiftUI

/// いちらんの盤。五稜郭のモノクロの画像にピースの枠を重ね、獲得したピースを色つきでその番号のマスに置く
struct PieceBoard: View {
    /// 獲得したピース
    let pieces: [Piece]

    var body: some View {
        ZStack {
            Color.white
            Image(.goryokakuLongMonochrome)
                .resizable()
                .opacity(0.35)
            Image(.pieceAllBorder)
                .resizable()
                .opacity(0.5)
        }
        .aspectRatio(PieceBoardLayout.aspectRatio, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                ForEach(pieces) { piece in
                    if let number = piece.number,
                       let frame = PieceBoardLayout.pieceImageFrame(number: number, in: proxy.size) {
                        Image(piece.image)
                            .resizable()
                            .frame(width: frame.width, height: frame.height)
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
