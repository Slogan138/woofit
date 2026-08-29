import SwiftUI

/// 워치용 타이포 위계(디자인 토큰 계획 ④, ⑥). 화면이 좁아 폰과 다른 값을 쓴다 —
/// 이름(routine·종목)이 화면에서 사실상 제목 역할을 겸하므로 별도 `screenTitle` 은
/// 두지 않는다. SwiftUI Dynamic Type 위에 이름만 얹은 얇은 층이다(CLAUDE.md 원칙 1).
enum Typography {
    /// 루틴·종목 이름. 워치 화면에서는 이 이름이 곧 화면의 초점이다.
    static let itemName = Font.headline

    /// 무게·횟수·휴식 시간 등 한눈에 읽는 수치 판독값. 숫자에는 호출부에서
    /// `.monospacedDigit()` 를 더한다.
    static let value = Font.title3

    /// 보조 설명. `.caption`·`.caption2` 가 뒤섞여 있던 걸 워치에서 더 널리 쓰이던
    /// `.caption2` 하나로 모은다.
    static let secondary = Font.caption2
}
