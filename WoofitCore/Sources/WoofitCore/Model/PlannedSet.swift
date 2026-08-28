import Foundation
import SwiftData

/// 계획된 세트 한 줄. 목표 무게와 목표 횟수를 갖는다.
@Model
public final class PlannedSet {
    public var id: UUID = UUID()
    public var order: Int = 0
    /// 킬로그램. 맨몸 운동은 `0`.
    public var targetWeight: Double = 0
    public var targetReps: Int = 0

    public var exercise: PlannedExercise?

    public init(
        id: UUID = UUID(),
        order: Int = 0,
        targetWeight: Double = 0,
        targetReps: Int = 0
    ) {
        self.id = id
        self.order = order
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }
}
