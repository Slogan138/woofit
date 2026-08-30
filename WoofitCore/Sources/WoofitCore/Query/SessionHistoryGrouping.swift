import Foundation

/// 월 단위로 묶은 세션 기록(P6).
public struct SessionMonth: Identifiable {
    /// `2026-08` 형태. 연·월이 같아야 같은 묶음이다.
    public let id: String
    /// `2026년 8월`
    public let title: String
    /// 최신 세션이 먼저.
    public let sessions: [WorkoutSession]
}

/// 세션 기록 목록의 묶음 규칙(P6). 화면에서 조립하면 테스트가 안 되므로 여기로 뺀다 —
/// `RoutineOrdering` 과 같은 이유다.
public enum SessionHistoryGrouping {
    /// 최신 월이 먼저, 월 안에서도 최신 세션이 먼저다.
    ///
    /// 묶음 기준에 **연도를 함께 넣는다.** 월만 쓰면 작년 8월과 올해 8월이 한 묶음이 되는데,
    /// 세션이 몇 년치 쌓인 뒤에야 드러나는 종류의 오류라 조용히 지나간다.
    public static func byMonth(
        _ sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> [SessionMonth] {
        var order: [String] = []
        var buckets: [String: [WorkoutSession]] = [:]

        for session in sessions.sorted(by: { $0.startedAt > $1.startedAt }) {
            let parts = calendar.dateComponents([.year, .month], from: session.startedAt)
            guard let year = parts.year, let month = parts.month else { continue }
            let key = String(format: "%04d-%02d", year, month)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(session)
        }

        return order.map { key in
            let sessions = buckets[key] ?? []
            let parts = calendar.dateComponents([.year, .month], from: sessions[0].startedAt)
            return SessionMonth(
                id: key,
                title: "\(parts.year ?? 0)년 \(parts.month ?? 0)월",
                sessions: sessions
            )
        }
    }
}
