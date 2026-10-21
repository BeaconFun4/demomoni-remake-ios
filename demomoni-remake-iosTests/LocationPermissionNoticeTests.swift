//
//  LocationPermissionNoticeTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct LocationPermissionNoticeTests {
    /// 探せる・まだ尋ねていないときは案内を出さない
    @Test(arguments: [LocationPermission.notDetermined, .authorized])
    func noNoticeWhenScanningIsPossible(permission: LocationPermission) {
        #expect(LocationPermissionNotice.message(for: permission) == nil)
    }

    /// 許可が無いときは位置情報の許可を、正確な位置情報がオフのときはそれをオンにするよう案内する
    @Test
    func noticeMessages() {
        #expect(LocationPermissionNotice.message(for: .denied) == "ピースをさがすには、位置情報の利用を許可してね")
        #expect(LocationPermissionNotice.message(for: .restricted) == "ピースをさがすには、位置情報の利用を許可してね")
        #expect(LocationPermissionNotice.message(for: .reducedAccuracy) == "ピースをさがすには、「正確な位置情報」をオンにしてね")
    }
}
