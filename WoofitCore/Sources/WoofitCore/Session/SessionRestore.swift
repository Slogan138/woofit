import Foundation
import SwiftData

/// 진행 중인 세션 복원(F-3). 앱을 강제 종료했다가 다시 열어도 진행 위치를 이어받기 위함이다.
public enum SessionRestore {

    /// 살아 있는 진행 중 세션. 일시정지 중이어도 `stateRaw` 는 여전히 `inProgress` 이므로
    /// 함께 찾힌다.
    ///
    /// **날이 바뀐 세션은 그 자리에서 중단으로 정리하고 후보에서 뺀다**(PRD D14).
    /// 정리하지 않으면 앱을 열 때마다 며칠 전 세션이 되살아나고, 그 상태가 상대 기기로
    /// 릴레이돼 지금 운동 중인 것처럼 보인다.
    ///
    /// **정렬이 필요한 이유** — 진행 중 세션이 둘 이상일 수 있고, 정렬이 없으면 보통
    /// 먼저 저장된(오래된) 쪽이 나온다.
    public static func fetchInProgress(
        in context: ModelContext,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> WorkoutSession? {
        try SessionLifetime.expireStale(in: context, at: date, calendar: calendar)

        let inProgress = SessionState.inProgress.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
