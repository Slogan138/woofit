import Foundation

/// 루틴 목록 정렬 규칙(F-2). 화면에서 조건을 조립하면 테스트가 안 되므로 여기로 뺀다.
public enum RoutineOrdering {
    /// 오늘 배정된 루틴 먼저, 그다음 요일 순(가장 이른 요일 기준), 마지막에 미지정.
    /// 같은 그룹 안에서는 입력 순서를 유지한다. `sorted` 의 안정성은 표준에서 보장하지
    /// 않으므로, 원래 인덱스를 동점 처리 기준으로 명시해 결정적으로 만든다.
    public static func forList(_ routines: [Routine], today: Weekday) -> [Routine] {
        routines.enumerated()
            .sorted { lhs, rhs in
                let a = priority(lhs.element, today: today)
                let b = priority(rhs.element, today: today)
                return a == b ? lhs.offset < rhs.offset : a < b
            }
            .map(\.element)
    }

    private static func priority(_ routine: Routine, today: Weekday) -> (Int, Int) {
        if routine.isScheduled(on: today) {
            return (0, 0)
        }
        if let earliest = routine.weekdays.first {
            return (1, earliest.rawValue)
        }
        return (2, 0)
    }
}
