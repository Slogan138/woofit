import Foundation
import SwiftData

/// 직전 기록 조회(F-9, PRD §7).
///
/// ```
/// 입력  normalizedName
/// 필터  stateRaw ∈ { completed, abandoned }        진행 중 세션 제외
/// 정렬  startedAt 내림차순
/// 선택  해당 종목을 포함한 첫 세션의 SessionExercise
/// ```
///
/// 폰은 전체 세션을 들고 있으므로 직접 조회한다.
/// 워치는 세션을 최근 10건만 유지하므로, 루틴을 내려보낼 때 결과를 함께 실어 보낸다(F-8).
public enum LastRecordLookup {

    /// 종목 하나의 직전 기록. 첫 수행이면 `nil`.
    public static func fetch(
        normalizedName: String,
        in context: ModelContext,
        excluding excludedSessionID: UUID? = nil
    ) throws -> LastRecord? {
        guard !normalizedName.isEmpty else { return nil }

        let inProgress = SessionState.inProgress.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw != inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        // 종목 포함 여부는 관계를 타고 들어가야 해서 술어로 걸기 어렵다.
        // 세션 수가 많아도 최근 것부터 보다가 첫 일치에서 끊으므로 실사용에서 문제되지 않는다.
        descriptor.fetchLimit = 200

        let sessions = try context.fetch(descriptor)
        for session in sessions {
            if let excludedSessionID, session.id == excludedSessionID { continue }
            guard let exercise = session.sortedExercises.first(
                where: { $0.normalizedName == normalizedName }
            ) else { continue }

            let entries = exercise.sortedSets
                .filter { $0.result.isRecorded }
                .map {
                    LastRecord.Entry(
                        weight: $0.performedWeight,
                        targetReps: $0.targetReps,
                        performedReps: $0.performedReps,
                        result: $0.result
                    )
                }
            guard !entries.isEmpty else { continue }

            return LastRecord(
                normalizedName: normalizedName,
                displayName: exercise.name,
                performedAt: session.startedAt,
                entries: entries
            )
        }
        return nil
    }

    /// 루틴 전체의 직전 기록을 한 번에 모은다.
    /// 루틴 편집기 표시와 워치 전송 payload 구성에 쓴다.
    public static func fetchAll(
        for routine: Routine,
        in context: ModelContext
    ) throws -> [String: LastRecord] {
        try fetchAll(for: routine.sortedExercises, in: context)
    }

    /// 세션(스냅샷) 전체의 직전 기록을 한 번에 모은다.
    /// 세션 실행 화면 진입 시 종목마다 개별 조회하지 않도록 쓴다(F-3).
    public static func fetchAll(
        for session: WorkoutSession,
        in context: ModelContext
    ) throws -> [String: LastRecord] {
        try fetchAll(for: session.sortedExercises, in: context)
    }

    private static func fetchAll(
        for exercises: [some NormalizedNamedExercise],
        in context: ModelContext
    ) throws -> [String: LastRecord] {
        var result: [String: LastRecord] = [:]
        for exercise in exercises {
            let key = exercise.normalizedName
            guard result[key] == nil else { continue }
            if let record = try fetch(normalizedName: key, in: context) {
                result[key] = record
            }
        }
        return result
    }
}

/// `fetchAll` 이 루틴 종목·세션 종목 어느 쪽이든 같은 방식으로 받게 하는 최소 인터페이스.
private protocol NormalizedNamedExercise {
    var normalizedName: String { get }
}

extension PlannedExercise: NormalizedNamedExercise {}
extension SessionExercise: NormalizedNamedExercise {}
