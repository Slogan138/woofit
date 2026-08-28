import Foundation
import SwiftData

/// 세션 안의 종목. 시작 시점의 `PlannedExercise` 를 복사한 것이다.
@Model
public final class SessionExercise {
    public var id: UUID = UUID()
    public var name: String = ""
    /// 직전 기록 조회(F-9)용 매칭 키.
    public var normalizedName: String = ""
    public var order: Int = 0

    public var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SessionSet.exercise)
    public var sets: [SessionSet]? = []

    public init(id: UUID = UUID(), name: String = "", order: Int = 0) {
        self.id = id
        self.name = name
        self.normalizedName = ExerciseName.normalize(name)
        self.order = order
        self.sets = []
    }
}

public extension SessionExercise {
    var sortedSets: [SessionSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    /// 모든 세트가 처리됐는가. 성공·실패·건너뜀을 가리지 않는다(F-4).
    var isComplete: Bool {
        let all = sortedSets
        return !all.isEmpty && all.allSatisfy { $0.result.isRecorded }
    }

    var nextPendingSet: SessionSet? {
        sortedSets.first { $0.result == .pending }
    }

    var successCount: Int { sortedSets.count { $0.result == .success } }

    /// 세트 값이 전부 같으면 그 값을 돌려준다. 마크다운 `목표` 열에 쓴다.
    var uniformTarget: (weight: Double, reps: Int)? {
        let all = sortedSets
        guard let first = all.first else { return nil }
        let uniform = all.allSatisfy {
            $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps
        }
        return uniform ? (first.targetWeight, first.targetReps) : nil
    }

    var averageRestSeconds: Double? {
        let values = sortedSets.compactMap(\.restSeconds)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
