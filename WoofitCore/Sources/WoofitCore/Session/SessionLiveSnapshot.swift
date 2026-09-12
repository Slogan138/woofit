import Foundation

/// 잠금화면·다이내믹 아일랜드에 띄우는 진행 현황(F-16).
///
/// **위젯 확장은 별도 프로세스라 앱의 객체를 볼 수 없다.** 화면에 그릴 값만 담아
/// 넘긴다 — 여기 없는 값은 잠금화면에 뜨지 않는다는 뜻이고, 그래서 이 타입이 곧
/// 위젯 화면의 명세다.
public struct SessionLiveSnapshot: Codable, Hashable, Sendable {

    public var routineName: String
    public var exerciseName: String
    public var targetWeight: Double
    public var targetReps: Int

    /// 이 종목에서 지금 몇 번째 세트인가(1부터).
    public var setIndex: Int
    /// 이 종목의 전체 세트 수.
    public var setCount: Int

    public var recordedSetCount: Int
    public var totalSetCount: Int

    /// 휴식 측정 중이면 시작 시각. 위젯은 이 값으로 `Text(timerInterval:)` 을 만들어
    /// **갱신 없이** 시간을 흘려보낸다(F-5, PRD §9 배터리).
    public var restStartedAt: Date?

    public init(
        routineName: String,
        exerciseName: String,
        targetWeight: Double,
        targetReps: Int,
        setIndex: Int,
        setCount: Int,
        recordedSetCount: Int,
        totalSetCount: Int,
        restStartedAt: Date?
    ) {
        self.routineName = routineName
        self.exerciseName = exerciseName
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.setIndex = setIndex
        self.setCount = setCount
        self.recordedSetCount = recordedSetCount
        self.totalSetCount = totalSetCount
        self.restStartedAt = restStartedAt
    }
}

public extension SessionLiveSnapshot {

    /// 진행 중인 세션의 현재 모습. 기록할 세트가 남아 있지 않으면 `nil` —
    /// **보여줄 것이 없다는 뜻이고, 그때 Live Activity 는 끝나야 한다.**
    static func make(for session: WorkoutSession) -> SessionLiveSnapshot? {
        guard session.state == .inProgress, let set = session.nextPendingSet else { return nil }
        let sets = set.exercise?.sortedSets ?? []
        return SessionLiveSnapshot(
            routineName: session.routineName,
            exerciseName: set.exercise?.name ?? "",
            targetWeight: set.targetWeight,
            targetReps: set.targetReps,
            setIndex: (sets.firstIndex { $0.id == set.id } ?? 0) + 1,
            setCount: sets.count,
            recordedSetCount: session.recordedSetCount,
            totalSetCount: session.totalSetCount,
            // 지금 쉬는 중인지는 세션 전체에서 본다. 방금 끝낸 세트의 휴식이므로
            // 초점이 옮겨간 다음 세트와는 다른 세트에 붙어 있다(F-5).
            restStartedAt: session.restingSet?.restStartedAt
        )
    }
}
