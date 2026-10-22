//
//  OpenOnce.swift
//  demomoni-remake-ios
//

/// 開く処理を 1 回だけ行い、その結果を返し続ける。開いている途中に呼ばれたときも、2 回目は開かずに同じ処理（`Task`）の結果を待つ。
/// `CLMonitor` を同じ名前で 2 つ開くと CoreLocation の中で assert するという報告があり、
/// TestFlight の 1.0 (4) で起動直後に `CLMonitor.init(_:)` の中で落ちた（#120）ため、開く処理をプロセスで 1 つにするのに使う。
/// `await` で開くのを待っている間は、別の呼び出しが同じ確認（まだ開いていない）を通れる（再入）ので、`await` の前後で確かめるだけでは 2 つ目を開いてしまう。
/// 原因は確定していないので、「2 つ開かない」は防御として入れている
actor OpenOnce<Value: Sendable> {
    private let open: @Sendable () async -> Value
    /// 呼ばれたときに呼ぶ（テストで、呼び出しが届いたのを待つため）
    private let onRequest: @Sendable () -> Void
    /// 最初の呼び出しで始めた開く処理。以後の呼び出しはこれを待つ
    private var opening: Task<Value, Never>?

    init(onRequest: @escaping @Sendable () -> Void = {}, _ open: @escaping @Sendable () async -> Value) {
        self.open = open
        self.onRequest = onRequest
    }

    /// 開いたものを返す。まだ開いていなければ開き、開いている途中ならそれを待つ
    func value() async -> Value {
        onRequest()
        if let opening {
            return await opening.value
        }
        // 確かめてから Task を持つまでに await を挟まないので、actor の中で 2 つ目の Task は作られない。
        // 呼び出し元が cancel されても、開く処理は止めない（ほかの呼び出しが同じ結果を待っている）
        let task = Task { await open() }
        opening = task
        return await task.value
    }
}
