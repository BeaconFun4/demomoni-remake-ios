//
//  GIFAnimation.swift
//  demomoni-remake-ios
//

import Foundation
import ImageIO

/// GIF のフレームと、各フレームを出す秒数。ImageIO で読む
nonisolated struct GIFAnimation: @unchecked Sendable {
    /// GIF に秒数が書かれていないか、短すぎるときに使う 1 フレームの秒数（ブラウザと同じ扱い）
    static let defaultFrameDuration: TimeInterval = 0.1

    /// フレームの画像（`CGImage` は変更できないので、別のスレッドへ渡してもよい）
    let frames: [CGImage]
    /// 各フレームを出す秒数
    let durations: [TimeInterval]

    /// 1 周の秒数
    var totalDuration: TimeInterval {
        durations.reduce(0, +)
    }

    /// GIF のデータからフレームを読む。フレームが 1 枚も読めなければ `nil`
    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        var frames: [CGImage] = []
        var durations: [TimeInterval] = []
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            frames.append(image)
            durations.append(Self.frameDuration(of: source, at: index))
        }
        guard !frames.isEmpty else {
            return nil
        }
        self.frames = frames
        self.durations = durations
    }

    /// 再生を始めてから `elapsed` 秒たったときに出すフレームの番号（繰り返し再生する）
    func frameIndex(at elapsed: TimeInterval) -> Int {
        Self.frameIndex(at: elapsed, durations: durations)
    }

    /// 各フレームの秒数が `durations` のとき、`elapsed` 秒たったときに出すフレームの番号（繰り返し再生する）
    static func frameIndex(at elapsed: TimeInterval, durations: [TimeInterval]) -> Int {
        let total = durations.reduce(0, +)
        guard total > 0, elapsed > 0 else {
            return 0
        }
        var remaining = elapsed.truncatingRemainder(dividingBy: total)
        for (index, duration) in durations.enumerated() {
            if remaining < duration {
                return index
            }
            remaining -= duration
        }
        return durations.count - 1
    }

    private static func frameDuration(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0
        return delay < 0.02 ? defaultFrameDuration : delay
    }
}
