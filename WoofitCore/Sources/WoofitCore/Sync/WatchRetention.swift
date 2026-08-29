import Foundation
import SwiftData

/// 워치에 보관할 세션 정리(F-8).
///
/// 워치는 저장 공간이 제한적이라 과거 세션을 무한히 쌓아두지 않는다. 지워도 괜찮은 것은
/// 루틴을 내려보낼 때 직전 기록이 함께 오기 때문이다(F-9) — 오래된 세션 원본이 없어도
/// 다음 세션 시작에는 지장이 없다.
public enum WatchRetention {
    public static let keepCount = 10

    /// 완료·중단된 세션 중 최근 `keepCount` 건만 남기고 지운다.
    /// **진행 중인 세션은 몇 건이든 지우지 않는다** — 운동 도중 기록이 통째로 날아간다.
    public static func prune(in context: ModelContext) throws {
        let sessions = try context.fetch(
            FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
        let finished = sessions.filter { $0.state != .inProgress }
        for session in finished.dropFirst(keepCount) {
            context.delete(session)
        }
    }
}
