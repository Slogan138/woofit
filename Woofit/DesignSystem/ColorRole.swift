import SwiftUI

/// 화면마다 즉흥적으로 골라 쓰던 색에 역할 이름을 붙인다. 새 팔레트가 아니라
/// SwiftUI 시맨틱 색 위에 이름만 얹은 얇은 층이다(CLAUDE.md 원칙 1).
///
/// 세트 결과(성공·실패·건너뜀)의 색은 여기가 아니라 `SetResult.tintColor` 가 정의한다 —
/// 화면이 아니라 모델이 결과의 시각 표현에 대한 단일 출처여야 한다(디자인 토큰 계획 ①).
enum ColorRole {
    /// 강조 — 시작·편집·복제·내보내기 등 주요 동작. 되돌리기(`.secondary`)와
    /// 뜻이 겹치지 않도록 이 역할에만 쓴다(디자인 토큰 계획 ②).
    static let accent = Color.accentColor

    /// 휴식 타이머 표시. 루틴 복제 스와이프와 같은 주황을 썼던 문제(디자인 토큰
    /// 계획 ③)를 없애기 위해 이 역할에만 쓴다.
    static let rest = Color.orange
}
