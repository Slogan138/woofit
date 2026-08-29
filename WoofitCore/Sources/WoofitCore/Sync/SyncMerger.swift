import Foundation
import SwiftData

/// payload 를 SwiftData 에 반영하는 병합 로직(F-8).
///
/// `WCSession` 은 테스트하기 어렵지만, 이 타입은 `ModelContext` 만 받는 순수 함수라
/// 전송 없이도 병합 규칙 전부를 테스트할 수 있다. 전송은 `WatchSyncService` 가 맡는다.
public enum SyncMerger {

    // MARK: - 세트 결과 (워치 → 폰)

    /// 멱등. 같은 payload 를 두 번 넣어도 결과가 같다.
    /// 세션·종목·세트가 없으면 만든다 — 세트별 전송이 순서 없이 도착할 수 있어서다.
    @discardableResult
    public static func merge(_ payload: SetResultPayload, into context: ModelContext) throws -> SessionSet {
        let session = try fetchOrCreateSession(payload, in: context)
        let exercise = try fetchOrCreateExercise(payload, in: session, context: context)
        let set = try fetchOrCreateSet(payload, in: exercise, context: context)
        apply(payload, to: set)
        return set
    }

    // MARK: - 세션 종료 스냅샷 (워치 → 폰)

    /// 담긴 세트마다 위 `merge(_:into:)` 를 그대로 호출한다. 미수행 세트(`recordedAt`
    /// 없음)도 포함돼 있어 세션 전체 구조(세트 개수 등)가 복원된다 — 기록값은 덮어쓰지
    /// 않는다(`apply` 참고).
    public static func merge(_ payload: SessionSnapshotPayload, into context: ModelContext) throws {
        let session = try fetchOrCreateSession(payload, in: context)
        for setPayload in payload.sets {
            try merge(setPayload, into: context)
        }
        session.endedAt = payload.endedAt
        session.state = payload.state
    }

    // MARK: - 루틴 (폰 → 워치)

    /// 전체를 교체한다. 루틴은 최신 상태만 있으면 되므로 병합하지 않는다(PRD §8).
    public static func replaceRoutines(with payloads: [RoutinePayload], in context: ModelContext) throws {
        for existing in try context.fetch(FetchDescriptor<Routine>()) {
            context.delete(existing)
        }
        for payload in payloads {
            let routine = Routine(
                id: payload.id,
                name: payload.name,
                category: payload.category,
                weekdayMask: payload.weekdayMask,
                note: payload.note,
                createdAt: payload.createdAt
            )
            routine.updatedAt = payload.updatedAt
            context.insert(routine)

            var exercises: [PlannedExercise] = []
            for exercisePayload in payload.exercises {
                let exercise = PlannedExercise(
                    id: exercisePayload.id,
                    name: exercisePayload.name,
                    order: exercisePayload.order
                )
                exercise.routine = routine
                context.insert(exercise)

                var sets: [PlannedSet] = []
                for setPayload in exercisePayload.sets {
                    let set = PlannedSet(
                        id: setPayload.id,
                        order: setPayload.order,
                        targetWeight: setPayload.targetWeight,
                        targetReps: setPayload.targetReps
                    )
                    set.exercise = exercise
                    context.insert(set)
                    sets.append(set)
                }
                exercise.sets = sets
                exercises.append(exercise)
            }
            routine.exercises = exercises
        }
    }

    // MARK: - 내부

    /// `recordedAt` 이 나중인 값이 이긴다. 이전 값이면 조용히 무시한다(역순 도착 대비).
    /// `recordedAt` 이 없는 payload(스냅샷의 미수행 세트)는 세트 존재만 보장하고 값은
    /// 절대 덮어쓰지 않는다 — 그렇지 않으면 이미 기록된 세트가 스냅샷 병합 순서에 따라
    /// 미수행으로 되돌아갈 수 있다.
    private static func apply(_ payload: SetResultPayload, to set: SessionSet) {
        guard let newRecordedAt = payload.recordedAt else { return }
        if let existing = set.recordedAt, existing > newRecordedAt { return }
        set.result = payload.result
        set.actualWeight = payload.actualWeight
        set.actualReps = payload.actualReps
        set.restSeconds = payload.restSeconds
        set.recordedAt = newRecordedAt
    }

    private static func fetchOrCreateSession(
        _ seed: some SessionSeedProviding,
        in context: ModelContext
    ) throws -> WorkoutSession {
        let id = seed.sessionID
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }

        let session = WorkoutSession(
            id: seed.sessionID,
            routineID: seed.routineID,
            routineName: seed.routineName,
            category: seed.category,
            startedAt: seed.startedAt
        )
        context.insert(session)
        return session
    }

    private static func fetchOrCreateExercise(
        _ payload: SetResultPayload,
        in session: WorkoutSession,
        context: ModelContext
    ) throws -> SessionExercise {
        if let existing = session.sortedExercises.first(where: { $0.id == payload.exerciseID }) {
            return existing
        }
        let exercise = SessionExercise(id: payload.exerciseID, name: payload.exerciseName, order: payload.exerciseOrder)
        exercise.session = session
        session.exercises = (session.exercises ?? []) + [exercise]
        context.insert(exercise)
        return exercise
    }

    private static func fetchOrCreateSet(
        _ payload: SetResultPayload,
        in exercise: SessionExercise,
        context: ModelContext
    ) throws -> SessionSet {
        if let existing = exercise.sortedSets.first(where: { $0.id == payload.setID }) {
            return existing
        }
        let set = SessionSet(id: payload.setID, order: payload.order, targetWeight: payload.targetWeight, targetReps: payload.targetReps)
        set.exercise = exercise
        exercise.sets = (exercise.sets ?? []) + [set]
        context.insert(set)
        return set
    }
}

/// `fetchOrCreateSession` 이 세트 payload·스냅샷 payload 어느 쪽이든 같은 방식으로
/// 받게 하는 최소 인터페이스(`LastRecordLookup.NormalizedNamedExercise` 와 같은 패턴).
private protocol SessionSeedProviding {
    var sessionID: UUID { get }
    var routineID: UUID? { get }
    var routineName: String { get }
    var category: String { get }
    var startedAt: Date { get }
}

extension SetResultPayload: SessionSeedProviding {}
extension SessionSnapshotPayload: SessionSeedProviding {}
