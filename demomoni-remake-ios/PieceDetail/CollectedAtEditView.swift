//
//  CollectedAtEditView.swift
//  demomoni-remake-ios
//

#if DEBUG
import SwiftUI

/// Debug 版だけ。ピース詳細の「日時を変える」で、獲得した日時を選ぶシート。
/// 「保存」で選んだ日時を保存して閉じ、「キャンセル」で何もせずに閉じる
struct CollectedAtEditView: View {
    /// 選んだ日時を保存する。獲得していなくて保存しなかったら `false`
    let save: (Date) throws -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    /// 保存できなかったときに出す文言
    @State private var errorMessage: String?

    /// - Parameter collectedAt: 今の獲得した日時。最初に選んでおく
    init(collectedAt: Date, save: @escaping (Date) throws -> Bool) {
        self.save = save
        _date = State(initialValue: collectedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("獲得した日時", selection: $date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("日時を変える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAndDismiss()
                    }
                }
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// 選んだ日時を保存して閉じる。保存できなければ知らせて、シートは残す
    private func saveAndDismiss() {
        do {
            if try save(date) {
                dismiss()
            } else {
                errorMessage = "このピースはまだゲットしていません"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CollectedAtEditView(collectedAt: .now) { _ in true }
}
#endif
