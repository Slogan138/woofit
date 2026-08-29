import Foundation
import Testing
@testable import WoofitCore

@Test("오늘 배정된 루틴이 맨 앞에 온다")
func todaysRoutineComesFirst() {
    let monday = Routine(name: "월요일 가슴", weekdayMask: Weekday.mask(of: [.monday]))
    let tuesday = Routine(name: "화요일 등", weekdayMask: Weekday.mask(of: [.tuesday]))

    let ordered = RoutineOrdering.forList([monday, tuesday], today: .tuesday)

    #expect(ordered.map(\.name) == ["화요일 등", "월요일 가슴"])
}

@Test("오늘 루틴이 없으면 요일 순으로 정렬된다")
func sortsByWeekdayWhenNothingScheduledToday() {
    let friday = Routine(name: "금요일", weekdayMask: Weekday.mask(of: [.friday]))
    let monday = Routine(name: "월요일", weekdayMask: Weekday.mask(of: [.monday]))
    let wednesday = Routine(name: "수요일", weekdayMask: Weekday.mask(of: [.wednesday]))

    let ordered = RoutineOrdering.forList([friday, monday, wednesday], today: .sunday)

    #expect(ordered.map(\.name) == ["월요일", "수요일", "금요일"])
}

@Test("미지정 루틴이 맨 뒤로 간다")
func unscheduledRoutineGoesLast() {
    let unscheduled = Routine(name: "미지정")
    let monday = Routine(name: "월요일", weekdayMask: Weekday.mask(of: [.monday]))

    let ordered = RoutineOrdering.forList([unscheduled, monday], today: .sunday)

    #expect(ordered.map(\.name) == ["월요일", "미지정"])
}

@Test("여러 요일에 배정된 루틴은 가장 이른 요일 기준으로 정렬된다")
func multiWeekdayRoutineSortsByEarliestWeekday() {
    // 화·금 배정 루틴은 화요일 기준으로, 수요일 단독 루틴보다 앞에 온다.
    let tuesdayAndFriday = Routine(name: "화·금", weekdayMask: Weekday.mask(of: [.tuesday, .friday]))
    let wednesday = Routine(name: "수요일", weekdayMask: Weekday.mask(of: [.wednesday]))

    let ordered = RoutineOrdering.forList([wednesday, tuesdayAndFriday], today: .sunday)

    #expect(ordered.map(\.name) == ["화·금", "수요일"])
}
