import Foundation
import SwiftData

/// 실제로 수행한 운동 한 회차.
///
/// 시작 시점의 루틴을 **복사해서** 담는다(PRD §7 스냅샷).
/// 참조만 하면 다음 주에 무게를 올리려고 루틴을 고쳤을 때 지난달 기록까지 같이 바뀐다.
@Model
public final class WorkoutSession {
    public var id: UUID = UUID()
    /// 어느 루틴에서 시작했는지 표시하기 위한 값. 조회에는 쓰지 않는다.
    public var routineID: UUID?
    public var routineName: String = ""
    public var category: String = ""
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var stateRaw: String = SessionState.inProgress.rawValue
    /// 일시정지 시작 시각. 일시정지 중일 때만 값이 있다. 세션 복원에 쓴다(F-3).
    public var pausedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    public var exercises: [SessionExercise]? = []

    public init(
        id: UUID = UUID(),
        routineID: UUID? = nil,
        routineName: String = "",
        category: String = "",
        startedAt: Date = Date()
    ) {
        self.id = id
        self.routineID = routineID
        self.routineName = routineName
        self.category = category
        self.startedAt = startedAt
        self.stateRaw = SessionState.inProgress.rawValue
        self.exercises = []
    }
}

// MARK: - 스냅샷 생성

public extension WorkoutSession {
    /// 루틴 내용을 통째로 복사해 새 세션을 만든다.
    static func start(from routine: Routine, at date: Date = Date()) -> WorkoutSession {
        let session = WorkoutSession(
            routineID: routine.id,
            routineName: routine.resolvedTitle,
            category: routine.category,
            startedAt: date
        )

        var copiedExercises: [SessionExercise] = []
        for planned in routine.sortedExercises {
            let exercise = SessionExercise(name: planned.name, order: planned.order)
            exercise.session = session

            var copiedSets: [SessionSet] = []
            for plannedSet in planned.sortedSets {
                let set = SessionSet(
                    order: plannedSet.order,
                    targetWeight: plannedSet.targetWeight,
                    targetReps: plannedSet.targetReps
                )
                set.exercise = exercise
                copiedSets.append(set)
            }
            exercise.sets = copiedSets
            copiedExercises.append(exercise)
        }
        session.exercises = copiedExercises
        return session
    }
}

// MARK: - 상태와 진행

public extension WorkoutSession {
    var state: SessionState {
        get { SessionState(rawValue: stateRaw) ?? .inProgress }
        set { stateRaw = newValue.rawValue }
    }

    var sortedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var allSets: [SessionSet] {
        sortedExercises.flatMap(\.sortedSets)
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var totalSetCount: Int { allSets.count }

    var recordedSetCount: Int { allSets.count { $0.result.isRecorded } }

    var successSetCount: Int { allSets.count { $0.result == .success } }

    /// 아직 결과가 없는 세트가 하나라도 있으면 `false`.
    var isFullyRecorded: Bool { allSets.allSatisfy { $0.result.isRecorded } }

    /// 다음에 수행해야 할 세트. 앞에서부터 첫 `pending` 을 찾는다.
    var nextPendingSet: SessionSet? {
        allSets.first { $0.result == .pending }
    }

    /// 현재 진행 중인 종목. 남은 세트가 있는 첫 종목이다.
    var currentExercise: SessionExercise? {
        sortedExercises.first { !$0.isComplete }
    }

    /// 지정한 종목 다음으로 수행할 종목(F-4).
    func exercise(after exercise: SessionExercise) -> SessionExercise? {
        let all = sortedExercises
        guard let index = all.firstIndex(where: { $0.id == exercise.id }) else { return nil }
        return all[(index + 1)...].first
    }

    /// 측정 중인 휴식이 있으면 돌려준다. 세션 복원 시 이 값으로 타이머를 되살린다.
    var restingSet: SessionSet? {
        allSets.first { $0.restStartedAt != nil }
    }

    var isPaused: Bool { pausedAt != nil }

    /// 일시정지한다. 진행 중이 아니거나 이미 일시정지 중이면 아무 일도 하지 않는다.
    func pause(at date: Date = Date()) {
        guard state == .inProgress, pausedAt == nil else { return }
        pausedAt = date
    }

    /// 재개한다.
    func resume() {
        pausedAt = nil
    }

    /// 측정하지 않은 세트를 뺀 평균 휴식 시간.
    var averageRestSeconds: Double? {
        let values = allSets.compactMap(\.restSeconds)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// 세션을 끝낸다. 남은 `pending` 세트가 있으면 중단으로 기록한다.
    func finish(at date: Date = Date()) {
        restingSet?.stopRest(at: date)
        pausedAt = nil
        endedAt = date
        state = isFullyRecorded ? .completed : .abandoned
    }

    /// 사용자가 명시적으로 그만둔 경우.
    func abandon(at date: Date = Date()) {
        restingSet?.stopRest(at: date)
        pausedAt = nil
        endedAt = date
        state = .abandoned
    }
}
