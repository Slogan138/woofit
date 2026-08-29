import SwiftUI
import Testing
@testable import WoofitCore

@Test("성공과 실패는 서로 다른 색을 갖는다")
func successAndFailureHaveDistinctColors() {
    #expect(SetResult.success.tintColor != SetResult.failure.tintColor)
}

@Test("같은 결과는 항상 같은 색을 반환한다")
func sameResultAlwaysReturnsSameColor() {
    for result in SetResult.allCases {
        #expect(result.tintColor == result.tintColor)
    }
}

@Test("미수행과 건너뜀은 기호로 구분되므로 같은 보조색을 공유해도 된다")
func pendingAndSkippedShareSecondaryColor() {
    #expect(SetResult.pending.tintColor == SetResult.skipped.tintColor)
    #expect(SetResult.pending.markdownSymbol != SetResult.skipped.markdownSymbol)
}
