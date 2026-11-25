//
//  PieceBackSide.swift
//  demomoni-remake-ios
//

import SwiftUI

/// ピースの裏側。写真があれば写真（と、その上の手書き）を正方形のカードにして出し、無ければ写真を入れるよう案内する
struct PieceBackSide: View {
    /// 写真の JPEG。無ければ案内を出す
    let photo: Data?
    /// 写真の上の手書き
    let drawing: Data?

    var body: some View {
        Group {
            if let photo {
                PiecePhotoSquare(photo: photo, drawing: drawing)
            } else {
                placeholder
            }
        }
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PiecePhotoText.backLabel(hasPhoto: photo != nil, hasDrawing: drawing != nil))
    }

    private var placeholder: some View {
        Color.themeColorWhite
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.themeColorPink)
                    Text(PiecePhotoText.placeholder)
                        .font(.demomoni(size: 22, relativeTo: .title3))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                .padding()
            }
    }
}
