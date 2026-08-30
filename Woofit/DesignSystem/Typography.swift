import SwiftUI

/// 화면 제목 · 종목명 · 수치 · 보조 설명 네 단계로 축소한 타이포 위계(디자인 토큰 계획 ④).
/// SwiftUI Dynamic Type 텍스트 스타일 위에 이름만 얹은 얇은 층이다(CLAUDE.md 원칙 1).
/// 고정 포인트 크기를 쓰지 않아 접근성 설정을 그대로 따른다.
///
/// 이 네 단계에 들어맞지 않는 텍스트(본문 설명, 표준 `.subheadline` 등)는 그대로
/// SwiftUI 기본 스타일을 쓴다 — 모든 텍스트를 네 토큰에 강제로 끼워 맞추지 않는다.
enum Typography {
    /// 화면 전체가 한 메시지에 집중하는 순간의 큰 제목(세션 완료·일시정지 등).
    /// 내비게이션 타이틀과는 별개다.
    static let screenTitle = Font.largeTitle.bold()

    /// 루틴·종목처럼 화면의 주 콘텐츠를 가리키는 이름.
    static let itemName = Font.headline

    /// 무게·횟수·휴식 시간 등 한눈에 읽는 수치 판독값. 숫자에는 호출부에서
    /// `.monospacedDigit()` 를 더한다.
    static let value = Font.title3

    /// 보조 설명 — 부가 정보, 캡션. `.caption`·`.caption2` 가 뒤섞여 있던 걸 하나로 모은다.
    static let secondary = Font.caption

    /// 세션 실행 화면의 현재 세트 판독값 기준 크기(계획 15).
    ///
    /// 다른 토큰과 달리 포인트 값인 것은, 텍스트 스타일 중 가장 큰 `.largeTitle`(34pt)도
    /// 벤치에 폰을 세워둔 거리에서는 작기 때문이다. **반드시 `@ScaledMetric(relativeTo:
    /// .largeTitle)` 로 감싸 쓴다** — 그대로 넣으면 Dynamic Type 이 깨진다(PRD §9).
    static let heroMetricSize: CGFloat = 56

    /// `heroMetricSize` 를 `@ScaledMetric` 으로 환산한 값을 받아 폰트를 만든다.
    /// `.rounded` 인 것은 획이 굵고 자간이 넓어 멀리서 숫자 판독이 쉬워서다.
    static func heroMetric(_ scaledSize: CGFloat) -> Font {
        .system(size: scaledSize, weight: .bold, design: .rounded)
    }
}
