//
//  PieceBackSide.swift
//  demomoni-remake-ios
//

import SwiftUI

/// ピースの裏側。ピースを裏から見た形（表の形を左右反転したもの）の中に、写真があれば写真（と、その上の手書き）を、
/// 無ければ白い裏地と、写真を入れる案内を出す
struct PieceBackSide: View {
    let piece: Piece
    /// 写真の JPEG。無ければ案内を出す
    let photo: Data?
    /// 写真の上の手書き
    let drawing: Data?

    var body: some View {
        PieceBackSurface(piece: piece, photo: photo, drawing: drawing)
            .overlay {
                if photo == nil {
                    placeholder
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PiecePhotoText.backLabel(hasPhoto: photo != nil, hasDrawing: drawing != nil))
    }

    /// 写真を入れる案内。凸凹のどの形でもはみ出さないよう、どのピースでも内側になる正方形（`PieceBackLayout.innerRect`）の中に出す
    private var placeholder: some View {
        GeometryReader { proxy in
            let side = proxy.size.width * PieceBackLayout.innerFraction
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.themeColorPink)
                Text(PiecePhotoText.placeholder)
                    .font(.demomoni(size: 20, relativeTo: .title3))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
