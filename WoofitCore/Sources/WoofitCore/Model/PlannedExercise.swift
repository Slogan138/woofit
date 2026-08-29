import Foundation
import SwiftData

/// 루틴 안의 종목 한 개 (예: 벤치프레스).
@Model
public final class PlannedExercise {
    public var id: UUID = UUID()
    public var name: String = ""
    /// 직전 기록 조회(F-9)용 매칭 키. `name` 과 항상 함께 갱신해야 한다.
    /// 직접 대입하지 말고 `rename(to:)` 를 쓴다.
    public var normalizedName: String = ""
    public var order: Int = 0

    public var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.exercise)
    public var sets: [PlannedSet]? = []

    public init(id: UUID = UUID(), name: String = "", order: Int = 0) {
        self.id = id
        self.name = name
        self.normalizedName = ExerciseName.normalize(name)
        self.order = order
        self.sets = []
    }
}

public extension PlannedExercise {
    var sortedSets: [PlannedSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    /// `name` 과 `normalizedName` 을 함께 바꾼다.
    /// SwiftData 모델에서는 `didSet` 이 기대대로 동작하지 않으므로 갱신 경로를 하나로 모은다.
    func rename(to newName: String) {
        name = ExerciseName.display(newName)
        normalizedName = ExerciseName.normalize(newName)
        routine?.touch()
    }

    @discardableResult
    func appendSet(weight: Double, reps: Int) -> PlannedSet {
        let set = PlannedSet(order: (sets ?? []).count, targetWeight: weight, targetReps: reps)
        set.exercise = self
        sets = (sets ?? []) + [set]
        routine?.touch()
        return set
    }

    /// 같은 값의 세트를 `count` 개 붙인다. 5 × 5 같은 균일 루틴을 한 번에 만든다.
    func appendSets(count: Int, weight: Double, reps: Int) {
        for _ in 0..<max(0, count) {
            appendSet(weight: weight, reps: reps)
        }
    }

    func reindexSets() {
        for (index, set) in sortedSets.enumerated() {
            set.order = index
        }
        routine?.touch()
    }

    /// 세트를 컨텍스트와 관계 배열 양쪽에서 지운다. 배열에서만 빼면 SwiftData
    /// 저장소에는 고아로 남는다. `remove(atOffsets:)` 는 SwiftUI 의존이라 여기서는
    /// 직접 걸러낸다.
    func removeSets(at offsets: IndexSet) {
        let ordered = sortedSets
        for index in offsets {
            modelContext?.delete(ordered[index])
        }
        sets = ordered.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        reindexSets()
    }

    /// 세트 값이 전부 같으면 그 값을 돌려준다. 피라미드 세트면 `nil`.
    var uniformTarget: (weight: Double, reps: Int)? {
        let all = sortedSets
        guard let first = all.first else { return nil }
        let uniform = all.allSatisfy {
            $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps
        }
        return uniform ? (first.targetWeight, first.targetReps) : nil
    }
}
