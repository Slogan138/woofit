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

    /// 세션 실행 화면의 현재 세트 판독값 기준 크기(계획 18).
    ///
    /// 폰의 56pt 를 그대로 쓰지 않는다 — 41mm 에서는 무게 한 줄이 화면을 다 먹어
    /// 성공·실패 버튼이 첫 화면 밖으로 밀린다. **반드시 `@ScaledMetric(relativeTo:
    /// .largeTitle)` 로 감싸 쓴다** — 그대로 넣으면 Dynamic Type 이 깨진다(PRD §9).
    static let heroMetricSize: CGFloat = 36

    /// `heroMetricSize` 를 `@ScaledMetric` 으로 환산한 값을 받아 폰트를 만든다.
    /// `.rounded` 인 것은 획이 굵고 자간이 넓어 팔 뻗은 거리에서 숫자 판독이 쉬워서다.
    static func heroMetric(_ scaledSize: CGFloat) -> Font {
        .system(size: scaledSize, weight: .bold, design: .rounded)
    }
}
