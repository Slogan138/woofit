import Foundation

/// 마크다운 가져오기 결과. SwiftData 가 아닌 값 타입이라 `ModelContext` 없이 미리보기에 쓸 수 있다(F-7).
///
/// 파싱과 반영을 분리하는 설계의 핵심이다. `RoutineMarkdownImporter.parse` 가 이 값을 만들고,
/// 사용자가 미리보기에서 확인한 뒤에야 `ParsedRoutine.apply(to:)` 가 SwiftData 에 쓴다.
public struct ParsedRoutine: Sendable, Equatable {
    public var title: String
    public var category: String
    /// `- 반복:` 항목이나 제목에서 추론한 값. 없으면 `0`(미지정).
    public var weekdayMask: Int
    public var exercises: [ParsedExercise]

    public init(title: String, category: String, weekdayMask: Int, exercises: [ParsedExercise]) {
        self.title = title
        self.category = category
        self.weekdayMask = weekdayMask
        self.exercises = exercises
    }
}

public struct ParsedExercise: Sendable, Equatable {
    public var name: String
    public var sets: [ParsedSet]

    public init(name: String, sets: [ParsedSet]) {
        self.name = name
        self.sets = sets
    }
}

public struct ParsedSet: Sendable, Equatable {
    public var targetWeight: Double
    public var targetReps: Int

    public init(targetWeight: Double, targetReps: Int) {
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }
}
