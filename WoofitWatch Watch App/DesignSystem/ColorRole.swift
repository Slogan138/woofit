import SwiftUI

/// 화면마다 즉흥적으로 골라 쓰던 색에 역할 이름을 붙인다. 새 팔레트가 아니라
/// SwiftUI 시맨틱 색 위에 이름만 얹은 얇은 층이다(CLAUDE.md 원칙 1).
///
/// 폰 타겟의 `ColorRole` 과 이름은 같지만 **값 집합이 이미 다르다** — 폰만
/// `cardSurface`(OLED 검정 위에 카드를 얹으면 대비만 떨어진다)와
/// `progress` 그라디언트(워치에는 그릴 면적이 없다)를 갖는다. 그래도 타입을 `WoofitCore`
/// 로 합치지 않는다: 두 타겟이 실제로 공유해야 하는 건 브랜드 색 하나뿐이고, 그건 에셋
/// 카탈로그 두 벌의 값을 맞추는 것으로 끝난다(계획 18).
enum ColorRole {
    /// 강조 — 성공 버튼·현재 세트 표시 등 주요 동작. 폰과 같은 인디고
    /// `AccentColor` 를 가리킨다. 워치에서는 단색으로만 쓴다.
    static let accent = Color.accentColor

    /// 휴식 타이머 표시.
    static let rest = Color.orange
}
