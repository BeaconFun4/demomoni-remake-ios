//
//  DemomoniFont.swift
//  demomoni-remake-ios
//

import CoreText
import SwiftUI

/// 同梱しているニコモジ+（SIL Open Font License 1.1）の登録。
/// Info.plist の `UIAppFonts` を使わず、起動時にプロセスへ登録する
enum DemomoniFont {
    /// ニコモジ+ の PostScript 名。`Font.custom(_:size:relativeTo:)` に渡す
    static let postScriptName = "NicoMoji+"

    /// 同梱しているフォントのファイル（`Resources/Fonts/`）
    static let resourceName = "nicomoji-plus_1.11"
    static let resourceExtension = "ttf"

    /// バンドルにあるニコモジ+ を、このプロセスに登録する。
    /// すでに登録されているときも登録済みとして `true` を返す（2 回呼んでもよい）
    /// - Returns: フォントが使える状態になったか
    @discardableResult
    static func register(in bundle: Bundle = .main) -> Bool {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            return false
        }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            return true
        }
        guard let error = error?.takeRetainedValue() else {
            return false
        }
        return CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue
    }
}

extension Font {
    /// ニコモジ+ の `Font`。`textStyle` の Dynamic Type の倍率に合わせて `size` から拡大・縮小する
    /// - Parameters:
    ///   - size: 標準の文字の大きさのときの大きさ（元アプリの storyboard のポイント数）
    ///   - textStyle: 拡大・縮小の倍率を合わせる文字のスタイル
    static func demomoni(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(DemomoniFont.postScriptName, size: size, relativeTo: textStyle)
    }
}
