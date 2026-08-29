import Foundation

/// 루틴 목록 정렬 규칙(F-2). 화면에서 조건을 조립하면 테스트가 안 되므로 여기로 뺀다.
public enum RoutineOrdering {
    /// 오늘 배정된 루틴 먼저, 그다음 요일 순(가장 이른 요일 기준), 마지막에 미지정.
    /// 같은 그룹 안에서는 입력 순서를 유지한다(`sorted` 는 안정 정렬).
    public static func forList(_ routines: [Routine], today: Weekday) -> [Routine] {
        routines.sorted { priority($0, today: today) < priority($1, today: today) }
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
