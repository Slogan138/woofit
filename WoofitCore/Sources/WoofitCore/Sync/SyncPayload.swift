import Foundation

/// 폰 → 워치. 루틴 한 개의 스냅샷(F-8). `updateApplicationContext` 로 통째로 덮어쓴다.
///
/// 종목마다 직전 기록을 함께 싣는다(F-9) — 워치는 과거 세션을 최근 10건만 들고 있어서
/// 세션 실행 화면에 직전 기록을 띄우려면 이 payload 가 유일한 경로다.
public struct RoutinePayload: Codable, Hashable, Sendable {

    public struct SetPayload: Codable, Hashable, Sendable {
        public var id: UUID
        public var order: Int
        public var targetWeight: Double
        public var targetReps: Int

        public init(id: UUID, order: Int, targetWeight: Double, targetReps: Int) {
            self.id = id
            self.order = order
            self.targetWeight = targetWeight
            self.targetReps = targetReps
        }
    }

    public struct ExercisePayload: Codable, Hashable, Sendable {
        public var id: UUID
        public var name: String
        public var order: Int
        public var sets: [SetPayload]
        public var lastRecord: LastRecord?

        public init(id: UUID, name: String, order: Int, sets: [SetPayload], lastRecord: LastRecord?) {
            self.id = id
            self.name = name
            self.order = order
            self.sets = sets
            self.lastRecord = lastRecord
        }
    }

    public var id: UUID
    public var name: String
    public var category: String
    public var weekdayMask: Int
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date
    public var exercises: [ExercisePayload]

    public init(
        id: UUID,
        name: String,
        category: String,
        weekdayMask: Int,
        note: String,
        createdAt: Date,
        updatedAt: Date,
        exercises: [ExercisePayload]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.weekdayMask = weekdayMask
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

public extension RoutinePayload {
    /// 루틴과 미리 조회해둔 직전 기록으로 전송용 payload 를 만든다.
    /// 직전 기록은 `LastRecordLookup.fetchAll(for:in:)` 로 한 번에 모아 넘긴다.
    static func make(from routine: Routine, lastRecords: [String: LastRecord]) -> RoutinePayload {
        RoutinePayload(
            id: routine.id,
            name: routine.name,
            category: routine.category,
            weekdayMask: routine.weekdayMask,
            note: routine.note,
            createdAt: routine.createdAt,
            updatedAt: routine.updatedAt,
            exercises: routine.sortedExercises.map { exercise in
                ExercisePayload(
                    id: exercise.id,
                    name: exercise.name,
                    order: exercise.order,
                    sets: exercise.sortedSets.map {
                        SetPayload(id: $0.id, order: $0.order, targetWeight: $0.targetWeight, targetReps: $0.targetReps)
                    },
                    lastRecord: lastRecords[exercise.normalizedName]
                )
            }
        )
    }
}

/// 워치 → 폰. 세트 하나의 기록 결과(F-8). `transferUserInfo` 로 큐잉 전송된다.
///
/// 세션·종목이 폰에 아직 없을 수 있다 — 폰이 꺼져 있던 동안 워치에서 세션을 시작해
/// 끝냈다면 폰은 이 payload 로 처음 그 존재를 알게 된다. 그래서 새로 만드는 데
/// 필요한 값을 전부 싣는다.
public struct SetResultPayload: Codable, Hashable, Sendable {
    public var sessionID: UUID
    public var routineID: UUID?
    public var routineName: String
    public var category: String
    public var startedAt: Date

    public var exerciseID: UUID
    public var exerciseName: String
    public var exerciseOrder: Int

    public var setID: UUID
    public var order: Int
    public var targetWeight: Double
    public var targetReps: Int

    public var result: SetResult
    public var actualWeight: Double?
    public var actualReps: Int?
    public var restSeconds: Double?
    /// 병합 우선순위 기준(PRD §8). 나중 값이 이긴다. 아직 수행하지 않은 세트는 `nil` —
    /// 이 값이 없는 payload 는 기존 기록을 절대 덮어쓰지 않는다(`SyncMerger.apply`).
    public var recordedAt: Date?

    public init(
        sessionID: UUID,
        routineID: UUID?,
        routineName: String,
        category: String,
        startedAt: Date,
        exerciseID: UUID,
        exerciseName: String,
        exerciseOrder: Int,
        setID: UUID,
        order: Int,
        targetWeight: Double,
        targetReps: Int,
        result: SetResult,
        actualWeight: Double?,
        actualReps: Int?,
        restSeconds: Double?,
        recordedAt: Date?
    ) {
        self.sessionID = sessionID
        self.routineID = routineID
        self.routineName = routineName
        self.category = category
        self.startedAt = startedAt
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.exerciseOrder = exerciseOrder
        self.setID = setID
        self.order = order
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.result = result
        self.actualWeight = actualWeight
        self.actualReps = actualReps
        self.restSeconds = restSeconds
        self.recordedAt = recordedAt
    }
}

public extension SetResultPayload {
    /// 세트 하나를 전송용 payload 로 바꾼다. 아직 기록되지 않은 세트(`recordedAt` 없음)는
    /// 세트별 전송에서 보낼 이유가 없으므로 `nil`. 세션 전체를 복원해야 하는 스냅샷은
    /// `makeSnapshotEntry(for:)` 를 쓴다.
    static func make(for set: SessionSet) -> SetResultPayload? {
        guard set.recordedAt != nil else { return nil }
        return makeSnapshotEntry(for: set)
    }

    /// 스냅샷용. 미수행 세트(`result == .pending`, `recordedAt == nil`)도 그대로 담아
    /// 세션 전체 구조(개수·목표값)를 복원할 수 있게 한다.
    static func makeSnapshotEntry(for set: SessionSet) -> SetResultPayload? {
        guard let exercise = set.exercise, let session = exercise.session else { return nil }
        return SetResultPayload(
            sessionID: session.id,
            routineID: session.routineID,
            routineName: session.routineName,
            category: session.category,
            startedAt: session.startedAt,
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            exerciseOrder: exercise.order,
            setID: set.id,
            order: set.order,
            targetWeight: set.targetWeight,
            targetReps: set.targetReps,
            result: set.result,
            actualWeight: set.actualWeight,
            actualReps: set.actualReps,
            restSeconds: set.restSeconds,
            recordedAt: set.recordedAt
        )
    }
}

/// 워치 → 폰. 세션 종료 시점의 전체 스냅샷(F-8).
///
/// 세트별 전송이 하나라도 새면 여기서 복구된다 — 최종 정합성 보루다. 그래서 미수행
/// 세트까지 포함해 세션 전체 구조를 복원해야 한다(`makeSnapshotEntry(for:)`). 세트별
/// 전송의 `make(for:)` 와 달리 `recordedAt` 이 없는 세트도 걸러내지 않는다.
public struct SessionSnapshotPayload: Codable, Hashable, Sendable {
    public var sessionID: UUID
    public var routineID: UUID?
    public var routineName: String
    public var category: String
    public var startedAt: Date
    public var endedAt: Date?
    public var state: SessionState
    public var sets: [SetResultPayload]

    public init(
        sessionID: UUID,
        routineID: UUID?,
        routineName: String,
        category: String,
        startedAt: Date,
        endedAt: Date?,
        state: SessionState,
        sets: [SetResultPayload]
    ) {
        self.sessionID = sessionID
        self.routineID = routineID
        self.routineName = routineName
        self.category = category
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
        self.sets = sets
    }
}

public extension SessionSnapshotPayload {
    static func make(for session: WorkoutSession) -> SessionSnapshotPayload {
        SessionSnapshotPayload(
            sessionID: session.id,
            routineID: session.routineID,
            routineName: session.routineName,
            category: session.category,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            state: session.state,
            sets: session.allSets.compactMap(SetResultPayload.makeSnapshotEntry(for:))
        )
    }
}
