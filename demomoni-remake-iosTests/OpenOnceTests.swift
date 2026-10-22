//
//  OpenOnceTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

/// 開く処理を呼んだ回数を数える
private actor OpenCounter {
    private(set) var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}

@Suite(.timeLimit(.minutes(1)))
struct OpenOnceTests {
    @Test func opensOnceWhenCalledWhileOpening() async {
        let counter = OpenCounter()
        let (started, startedContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let (requests, requestContinuation) = AsyncStream.makeStream(of: Void.self)
        let opener = OpenOnce(
            onRequest: { requestContinuation.yield() },
            {
                let number = await counter.increment()
                startedContinuation.yield()
                // テストが開けてよいと言うまで、開いている途中のままにする
                for await _ in gate {
                    break
                }
                return number
            }
        )
        let callers = 5

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<callers {
                group.addTask { await opener.value() }
            }
            // すべての呼び出しが届き、開く処理が始まってから開け終える
            var received = 0
            for await _ in requests {
                received += 1
                if received == callers {
                    break
                }
            }
            for await _ in started {
                break
            }
            // 閉じて開けるので、壊れて 2 回目の開く処理が始まっても止まらず、回数の確認で失敗する
            gateContinuation.finish()

            var results: [Int] = []
            for await result in group {
                results.append(result)
            }
            #expect(results == Array(repeating: 1, count: callers))
        }
        #expect(await counter.count == 1)
    }

    @Test func doesNotOpenAgainAfterOpened() async {
        let counter = OpenCounter()
        let opener = OpenOnce { await counter.increment() }

        let first = await opener.value()
        let second = await opener.value()

        #expect(first == 1)
        #expect(second == 1)
        #expect(await counter.count == 1)
    }
}
