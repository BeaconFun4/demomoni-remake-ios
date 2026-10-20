//
//  DemomoniFontTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing
import UIKit

struct DemomoniFontTests {
    /// 同梱したニコモジ+ がアプリのバンドルに入っている
    @Test
    func fontFileIsBundled() {
        let url = Bundle.main.url(
            forResource: DemomoniFont.resourceName,
            withExtension: DemomoniFont.resourceExtension
        )
        #expect(url != nil)
    }

    /// 登録すると、PostScript 名でフォントが取れる。2 回登録しても失敗にならない
    @Test
    func registeredFontIsAvailableByPostScriptName() {
        #expect(DemomoniFont.register())
        #expect(DemomoniFont.register())
        #expect(UIFont(name: DemomoniFont.postScriptName, size: 17) != nil)
    }

    /// ニコモジ+ の SIL OFL 1.1 の本文と著作権表示が、フォントと一緒に入っている
    @Test
    func licenseTextIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "NicoMojiPlus-OFL", withExtension: "txt"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIL OPEN FONT LICENSE Version 1.1"))
        #expect(text.contains("Copyright(c) 2014 Nicomoji"))
    }
}
