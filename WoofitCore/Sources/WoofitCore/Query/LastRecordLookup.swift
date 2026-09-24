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

    /// **세션을 한 번만 읽는다.** 종목마다 `fetch(normalizedName:)` 을 부르면 그때마다
    /// 최근 세션을 전부 훑으며 종목·세트를 메모리로 끌어올린다. 종목이 여섯이면 그것이
    /// 여섯 번이고, 아직 한 번도 안 한 종목은 매번 끝까지 훑는다.
    ///
    /// 실기기에서 워치가 10초 워치독에 걸려 강제 종료됐다(`0x8BADF00D`). 앱이 앞으로
    /// 나올 때 이 조회가 메인 스레드에서 돌기 때문이다 — "세션 수가 많아도 첫 일치에서
    /// 끊으므로 문제되지 않는다"고 적어둔 판단이 틀렸다.
    private static func fetchAll(
        for exercises: [some NormalizedNamedExercise],
        in context: ModelContext
    ) throws -> [String: LastRecord] {
        var wanted = Set(exercises.map(\.normalizedName))
        wanted.remove("")
        guard !wanted.isEmpty else { return [:] }

        var result: [String: LastRecord] = [:]
        for session in try recentSessions(in: context) {
            for exercise in session.sortedExercises where wanted.contains(exercise.normalizedName) {
                guard let record = record(for: exercise, in: session) else { continue }
                result[exercise.normalizedName] = record
                wanted.remove(exercise.normalizedName)
            }
            // 찾을 것이 남지 않으면 더 훑지 않는다.
            if wanted.isEmpty { break }
        }
        return result
    }

    /// 끝난 세션을 최근 순으로. 진행 중인 세션은 아직 직전 기록이 아니다.
    private static func recentSessions(in context: ModelContext) throws -> [WorkoutSession] {
        let inProgress = SessionState.inProgress.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw != inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    /// 기록된 세트가 하나도 없으면 직전 기록이 아니다 — 시작만 하고 중단한 세션이 그렇다.
    private static func record(for exercise: SessionExercise, in session: WorkoutSession) -> LastRecord? {
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
        guard !entries.isEmpty else { return nil }
        return LastRecord(
            normalizedName: exercise.normalizedName,
            displayName: exercise.name,
            performedAt: session.startedAt,
            entries: entries
        )
    }
}

/// `fetchAll` 이 루틴 종목·세션 종목 어느 쪽이든 같은 방식으로 받게 하는 최소 인터페이스.
private protocol NormalizedNamedExercise {
    var normalizedName: String { get }
}

extension PlannedExercise: NormalizedNamedExercise {}
extension SessionExercise: NormalizedNamedExercise {}
