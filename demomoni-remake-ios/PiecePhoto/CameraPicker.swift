//
//  CameraPicker.swift
//  demomoni-remake-ios
//

import SwiftUI
import UIKit

/// カメラで写真を撮る（`UIImagePickerController`）。撮ったら `onPick` に渡して閉じ、やめたら何もせずに閉じる。
/// カメラの無い端末（Simulator など）では出さない（`isAvailable`）
struct CameraPicker: UIViewControllerRepresentable {
    /// 撮った写真を受け取る
    let onPick: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    /// この端末でカメラを使えるか
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
