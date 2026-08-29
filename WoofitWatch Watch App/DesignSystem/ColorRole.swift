import SwiftUI

/// 화면마다 즉흥적으로 골라 쓰던 색에 역할 이름을 붙인다. 새 팔레트가 아니라
/// SwiftUI 시맨틱 색 위에 이름만 얹은 얇은 층이다(CLAUDE.md 원칙 1).
///
/// 폰 타겟의 `ColorRole` 과 이름은 같지만, buildable folder 는 타겟별로 소스를
/// 관리하므로 값을 공유하려면 WoofitCore 로 옮겨야 한다 — 지금은 값이 같아 그럴
/// 필요가 없다(디자인 토큰 계획 6번, 워치는 다른 값이 필요할 수 있다는 전제).
enum ColorRole {
    /// 휴식 타이머 표시.
    static let rest = Color.orange
}
