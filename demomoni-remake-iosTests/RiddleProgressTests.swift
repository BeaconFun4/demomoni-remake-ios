//
//  RiddleProgressTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct RiddleProgressTests {
    private let tower = Riddle(
        id: 0, pieceId: 2, title: "函館ののっぽ", content: "", hint: "五◯郭タワー", answer: "五稜郭タワー", area: "goryokaku"
    )

    /// 答えの場所のピースを獲得していれば解いたことにする。ほかのピースだけでは解いたことにしない
    @Test
    func solvedOnlyWhenAnswerPieceIsCollected() {
        #expect(RiddleProgress.isSolved(tower, collectedPieceIDs: [2]))
        #expect(RiddleProgress.isSolved(tower, collectedPieceIDs: [0, 1, 2]))
        #expect(!RiddleProgress.isSolved(tower, collectedPieceIDs: [0, 1]))
        #expect(!RiddleProgress.isSolved(tower, collectedPieceIDs: []))
    }

    /// 答えの文言と読み上げ
    @Test
    func answerTexts() {
        #expect(RiddleProgress.answerText(for: tower) == "こたえ：五稜郭タワー")
        #expect(RiddleProgress.answerAccessibilityLabel(for: tower) == "こたえ、五稜郭タワー")
    }

    /// 同梱データでは、ピースを 1 つ獲得すると、そのピースのなぞなぞ 1 問だけを解いたことになる
    @Test
    func collectingOnePieceSolvesExactlyOneBundledRiddle() {
        for piece in Catalog.bundled.pieces {
            let solved = Catalog.bundled.riddles.filter { RiddleProgress.isSolved($0, collectedPieceIDs: [piece.id]) }
            #expect(solved.map(\.answer) == [piece.name], "\(piece.name)")
        }
    }
}
