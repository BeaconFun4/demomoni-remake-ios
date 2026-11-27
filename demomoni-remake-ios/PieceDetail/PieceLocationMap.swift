//
//  PieceLocationMap.swift
//  demomoni-remake-ios
//

import MapKit
import SwiftUI

/// ピース詳細の、ピースの場所にピンを立てた小さな地図（MapKit）。
/// 詳細のスクロールの邪魔をしないよう地図は動かせず、押すと動かせる大きな地図のシート（`PieceMapSheet`）を開く。
/// 今いる場所は出さない（位置情報の許可を尋ねない）
struct PieceLocationMap: View {
    let piece: Piece

    @State private var showsMap = false

    var body: some View {
        Button {
            showsMap = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Map(
                    initialPosition: .region(PieceMapLocation.region(for: piece, spanMeters: PieceMapLocation.previewSpanMeters)),
                    interactionModes: []
                ) {
                    Marker(piece.name, coordinate: PieceMapLocation.coordinate(for: piece))
                        .tint(.themeColorPink)
                }
                // 地図がドラッグを受けると、詳細の ScrollView がスクロールしなくなる
                .allowsHitTesting(false)

                Label("おおきくみる", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.demomoni(size: 16, relativeTo: .footnote))
                    .foregroundStyle(Color.themeColorGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(12)
            }
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 24))
            // 地図は押せない（allowsHitTesting(false)）ので、押せる形を角丸の四角で決める
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PieceMapLocation.accessibilityLabel(for: piece))
        .accessibilityHint("おおきな地図をひらきます")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showsMap) {
            PieceMapSheet(piece: piece)
        }
    }
}

/// ピースの場所の大きな地図。動かして近くを見られ、「マップでひらく」で Apple のマップに場所を渡す
struct PieceMapSheet: View {
    let piece: Piece

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition

    init(piece: Piece) {
        self.piece = piece
        _position = State(initialValue: .region(PieceMapLocation.region(for: piece, spanMeters: PieceMapLocation.sheetSpanMeters)))
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                Marker(piece.name, coordinate: PieceMapLocation.coordinate(for: piece))
                    .tint(.themeColorPink)
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                Button("マップでひらく", systemImage: "map") {
                    _ = PieceMapLocation.mapItem(for: piece).openInMaps()
                }
                .font(.demomoni(size: 20, relativeTo: .body))
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.themeColorPink)
                .foregroundStyle(Color.themeColorGray)
                .padding()
            }
            .navigationTitle(piece.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("とじる", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        PieceLocationMap(piece: Catalog.bundled.pieces[1])
            .padding()
    }
    .background(Color.themeColorBlue)
}

#Preview("大きな地図") {
    PieceMapSheet(piece: Catalog.bundled.pieces[1])
}
