import Foundation
import SwiftData

/// 루틴의 요일 배정(F-1). 같은 요일에는 루틴 하나만 배정될 수 있다(A1).
/// 화면에서 배타 처리를 하면 테스트가 안 되므로 여기로 뺀다.
public enum RoutineScheduler {

    /// `routine` 에 `weekdays` 를 배정한다. 겹치는 요일을 쓰던 다른 루틴에서는
    /// 그 요일만 해제한다 — 루틴 전체가 아니라 겹친 비트만 지운다.
    public static func assign(_ weekdays: [Weekday], to routine: Routine, in context: ModelContext) throws {
        let newMask = Weekday.mask(of: weekdays)

        if newMask != 0 {
            let others = try context.fetch(FetchDescriptor<Routine>())
            for other in others where other.id != routine.id && other.weekdayMask & newMask != 0 {
                other.weekdayMask &= ~newMask
                other.touch()
            }
        }

        routine.weekdayMask = newMask
        routine.touch()
    }
}
