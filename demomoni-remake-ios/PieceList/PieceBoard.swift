//
//  PieceBoard.swift
//  demomoni-remake-ios
//

import SwiftUI

/// いちらんの盤。五稜郭のモノクロの画像にピースの枠を重ね、獲得したピースを色つきでその番号のマスに置く。
/// ピースを押すと、そのピースを値にした `NavigationLink` でピース詳細を開く。
/// Debug 構成だけ、空きマスを押すとそのピースを埋める（デモ用。App Store 版には入れない）
struct PieceBoard: View {
    /// 獲得したピース
    let pieces: [Piece]
    /// ピースの id ごとのサインのデータ。サインのあるピースはサインを重ねて出す
    var signatures: [Int: Data] = [:]
    #if DEBUG
    /// 獲得していないピース（Debug 構成だけ）。そのマスを押すと `fill` を呼ぶ
    var emptyPieces: [Piece] = []
    /// 空きマスを押したときに、そのピースを埋める
    var fill: (Piece) -> Void = { _ in }
    #endif

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
                #if DEBUG
                ForEach(emptyPieces) { piece in
                    if let number = piece.number,
                       let frame = PieceBoardLayout.pieceImageFrame(number: number, in: proxy.size) {
                        // 何も描かず、押せる範囲は獲得したピースと同じく中央のマスだけにする
                        Button {
                            fill(piece)
                        } label: {
                            // 透明な塗りは押せないので、押せる形を中身に付ける
                            Rectangle()
                                .fill(.clear)
                                .frame(width: frame.width / 2, height: frame.height / 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: frame.midX, y: frame.midY)
                        .accessibilityLabel("ピース No.\(number) \(piece.name) を埋める")
                    }
                }
                #endif
                ForEach(pieces) { piece in
                    if let number = piece.number,
                       let frame = PieceBoardLayout.pieceImageFrame(number: number, in: proxy.size) {
                        NavigationLink(value: piece) {
                            PieceWithSignature(piece: piece, signature: signatures[piece.id])
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
