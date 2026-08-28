import Foundation

/// 루틴의 반복 요일. `Routine.weekdayMask` 에 비트마스크로 저장된다.
///
/// 일요일이 `1`, 월요일이 `2`, 화요일이 `4` … 토요일이 `64`.
/// 월·목이면 `2 | 32 = 34`. 배열 대신 정수를 쓰면 CloudKit 제약과
/// 동기화 payload 양쪽에 유리하다(PRD §7).
public enum Weekday: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 0
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public var id: Int { rawValue }

    public var bit: Int { 1 << rawValue }

    /// "일", "월" …
    public var shortName: String {
        ["일", "월", "화", "수", "목", "금", "토"][rawValue]
    }

    /// "일요일", "월요일" …
    public var fullName: String { shortName + "요일" }

    /// `Calendar` 의 weekday 는 일요일이 1이므로 1을 뺀다.
    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday - 1)
    }

    public static func today(_ calendar: Calendar = .current, now: Date = Date()) -> Weekday {
        let value = calendar.component(.weekday, from: now)
        return Weekday(calendarWeekday: value) ?? .sunday
    }

    /// 마스크에 포함된 요일을 일요일부터 순서대로 돌려준다.
    public static func from(mask: Int) -> [Weekday] {
        allCases.filter { mask & $0.bit != 0 }
    }

    public static func mask(of weekdays: some Sequence<Weekday>) -> Int {
        weekdays.reduce(0) { $0 | $1.bit }
    }

    /// "월, 목" 형태. 마크다운 `- 반복:` 항목에 쓴다(PRD §6.3).
    public static func label(mask: Int) -> String {
        from(mask: mask).map(\.shortName).joined(separator: ", ")
    }
}
