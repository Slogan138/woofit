import Foundation
import Testing
@testable import WoofitCore

// MARK: - 세션 기록 묶음 (P6)

/// 테스트가 실행 지역과 무관하게 같은 결과를 내도록 UTC 그레고리력을 고정한다.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
}

private func session(_ name: String, _ startedAt: Date) -> WorkoutSession {
    WorkoutSession(routineName: name, startedAt: startedAt)
}

@Test("세션은 최신 월부터 묶이고 월 안에서도 최신이 먼저다")
func historyGroupsByMonthNewestFirst() {
    let months = SessionHistoryGrouping.byMonth(
        [
            session("금요일 하체", date(2026, 8, 28)),
            session("수요일 등", date(2026, 8, 26)),
            session("월요일 가슴", date(2026, 8, 24)),
            session("월요일 가슴", date(2026, 7, 31))
        ],
        calendar: utc
    )

    #expect(months.map(\.title) == ["2026년 8월", "2026년 7월"])
    #expect(months[0].sessions.map(\.routineName) == ["금요일 하체", "수요일 등", "월요일 가슴"])
    #expect(months[1].sessions.count == 1)
}

/// 정렬은 호출자(`@Query(sort:order:)`) 몫이라는 계약을 고정한다. 안쪽에서 다시 정렬하면
/// 목록이 다시 그려질 때마다 그 비용을 내므로 뺐고, 그 대가가 이 동작이다.
@Test("묶음 순서는 입력 순서를 그대로 따른다")
func historyPreservesInputOrder() {
    let months = SessionHistoryGrouping.byMonth(
        [
            session("7월", date(2026, 7, 31)),
            session("8월 먼저", date(2026, 8, 24)),
            session("8월 나중", date(2026, 8, 28))
        ],
        calendar: utc
    )

    #expect(months.map(\.title) == ["2026년 7월", "2026년 8월"])
    #expect(months[1].sessions.map(\.routineName) == ["8월 먼저", "8월 나중"])
}

@Test("해가 다르면 같은 달이어도 섞이지 않는다")
func historySeparatesSameMonthAcrossYears() {
    let months = SessionHistoryGrouping.byMonth(
        [
            session("올해 8월", date(2026, 8, 3)),
            session("작년 8월", date(2025, 8, 3))
        ],
        calendar: utc
    )

    #expect(months.count == 2)
    #expect(months.map(\.title) == ["2026년 8월", "2025년 8월"])
    #expect(months.map(\.id) == ["2026-08", "2025-08"])
}

@Test("기록이 없으면 묶음도 없다")
func historyGroupingIsEmptyForNoSessions() {
    #expect(SessionHistoryGrouping.byMonth([], calendar: utc).isEmpty)
}
