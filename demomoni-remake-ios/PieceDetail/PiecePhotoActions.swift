//
//  PiecePhotoActions.swift
//  demomoni-remake-ios
//

import PhotosUI
import SwiftData
import SwiftUI

/// ピースの裏側の操作。写真が無ければ「しゃしんをとる」（カメラのある端末だけ）・「しゃしんをえらぶ」、
/// あれば「かきこむ！」・「しゃしんをかえる」・「しゃしんをけす」（確かめてから消す）。
/// 写真は保存の前に縮め、位置情報などのメタデータを消す（`PiecePhotoImage`）。端末の外へは送らない
struct PiecePhotoActions: View {
    let pieceID: Int
    /// 今の写真。無ければ写真を入れる操作だけを出す
    let photo: Data?
    /// 今の手書き。あれば、写真を替える前に確かめる（替えると消えるため）
    let drawing: Data?

    @Environment(\.modelContext) private var modelContext
    /// 写真ライブラリを出しているか（`PhotosPicker` は許可が要らない）
    @State private var showsLibrary = false
    /// ライブラリで選んだ写真
    @State private var pickedItem: PhotosPickerItem?
    /// カメラを出しているか
    @State private var showsCamera = false
    /// 手書きの画面を出しているか
    @State private var showsDrawing = false
    /// 写真を消す前に確かめているか
    @State private var confirmsRemoval = false
    /// 手書きがあるときに、確かめてから保存する新しい写真
    @State private var pendingPhoto: Data?
    /// 写真を読み込んで縮めている途中か
    @State private var isProcessing = false
    /// 読み込み・保存に失敗したときに出す見出し
    @State private var errorTitle: String?

    var body: some View {
        VStack(spacing: 12) {
            if photo != nil {
                Button("かきこむ！") {
                    showsDrawing = true
                }
                .font(.demomoni(size: 26, relativeTo: .title2))
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.themeColorPink)
                .foregroundStyle(Color.themeColorGray)

                HStack(spacing: 12) {
                    Menu {
                        cameraButton
                        libraryButton
                    } label: {
                        Label("しゃしんをかえる", systemImage: "photo.on.rectangle.angled")
                    }
                    Button("しゃしんをけす", systemImage: "trash", role: .destructive) {
                        confirmsRemoval = true
                    }
                }
                .font(.demomoni(size: 18, relativeTo: .body))
                .buttonStyle(.glass)
                .foregroundStyle(Color.themeColorGray)
            } else {
                HStack(spacing: 12) {
                    cameraButton
                    libraryButton
                }
                .font(.demomoni(size: 20, relativeTo: .title3))
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.themeColorPink)
                .foregroundStyle(Color.themeColorGray)
            }
        }
        .disabled(isProcessing)
        .overlay {
            if isProcessing {
                ProgressView()
            }
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else {
                return
            }
            pickedItem = nil
            Task {
                await importPhoto(from: item)
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                Task {
                    await importPhoto(from: image)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsDrawing) {
            if let photo {
                PhotoDrawingView(pieceID: pieceID, photo: photo, drawing: drawing)
            }
        }
        .alert("しゃしんをけす？", isPresented: $confirmsRemoval) {
            Button("けす", role: .destructive) {
                write { try $0.removePhoto(pieceID: pieceID) }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("かきこみもいっしょにきえるよ")
        }
        .alert("しゃしんをかえる？", isPresented: isConfirmingReplacement, presenting: pendingPhoto) { newPhoto in
            Button("かえる", role: .destructive) {
                save(newPhoto)
            }
            Button("やめる", role: .cancel) {}
        } message: { _ in
            Text("いまのかきこみはきえるよ")
        }
        .alert(errorTitle ?? "", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        }
    }

    /// カメラのある端末だけに出す
    @ViewBuilder private var cameraButton: some View {
        if CameraPicker.isAvailable {
            Button("しゃしんをとる", systemImage: "camera") {
                showsCamera = true
            }
        }
    }

    private var libraryButton: some View {
        Button("しゃしんをえらぶ", systemImage: "photo.on.rectangle") {
            showsLibrary = true
        }
    }

    private var isConfirmingReplacement: Binding<Bool> {
        Binding {
            pendingPhoto != nil
        } set: { isPresented in
            if !isPresented {
                pendingPhoto = nil
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding {
            errorTitle != nil
        } set: { isPresented in
            if !isPresented {
                errorTitle = nil
            }
        }
    }

    /// ライブラリで選んだ写真を読み込み、縮めて受け取る
    private func importPhoto(from item: PhotosPickerItem) async {
        // 読み込んでいる間に表へ戻されて、この View が画面から外れても保存できるよう、保存先を先に持っておく
        let collection = PieceCollection(context: modelContext)
        isProcessing = true
        defer { isProcessing = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = await Self.jpegData(from: data) else {
            errorTitle = "しゃしんをよみこめませんでした"
            return
        }
        receive(jpeg, into: collection)
    }

    /// カメラで撮った写真を縮めて受け取る
    private func importPhoto(from image: UIImage) async {
        let collection = PieceCollection(context: modelContext)
        isProcessing = true
        defer { isProcessing = false }
        guard let jpeg = await Self.jpegData(from: image) else {
            errorTitle = "しゃしんをよみこめませんでした"
            return
        }
        receive(jpeg, into: collection)
    }

    /// 新しい写真を受け取る。手書きがあれば消えるので確かめてから、無ければすぐに保存する
    private func receive(_ jpeg: Data, into collection: PieceCollection) {
        if drawing != nil {
            pendingPhoto = jpeg
        } else {
            write(into: collection) { try $0.savePhoto(jpeg, pieceID: pieceID) }
        }
    }

    private func save(_ jpeg: Data) {
        write { try $0.savePhoto(jpeg, pieceID: pieceID) }
    }

    /// 写真を書き換える。保存できなければ知らせる
    /// - Parameter collection: 保存先。`nil` ならこの View の `modelContext`
    private func write(into collection: PieceCollection? = nil, _ change: (PieceCollection) throws -> Bool) {
        let saved = (try? change(collection ?? PieceCollection(context: modelContext))) ?? false
        if !saved {
            errorTitle = "しゃしんをほぞんできませんでした"
        }
    }

    /// 写真のデータを縮めた JPEG にする（大きな写真もあるので MainActor の外で行う）
    @concurrent
    nonisolated private static func jpegData(from data: Data) async -> Data? {
        PiecePhotoImage.jpegData(from: data)
    }

    /// カメラの写真を縮めた JPEG にする（MainActor の外で行う）
    @concurrent
    nonisolated private static func jpegData(from image: UIImage) async -> Data? {
        PiecePhotoImage.jpegData(from: image)
    }
}
