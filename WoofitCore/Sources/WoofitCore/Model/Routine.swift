import Foundation
import SwiftData

/// 사용자가 미리 작성해두고 계속 고쳐 쓰는 운동 계획 템플릿.
///
/// CloudKit 동기화를 나중에 켤 수 있도록 PRD §7 의 제약을 지킨다.
/// 모든 저장 프로퍼티에 기본값이 있고, 관계는 옵셔널이며, `@Attribute(.unique)` 를 쓰지 않는다.
@Model
public final class Routine {
    public var id: UUID = UUID()
    public var name: String = ""
    /// 주요 타겟 부위. 자유 문자열이되 UI 에서 프리셋을 제안한다(PRD A2).
    public var category: String = ""
    /// 반복 요일 비트마스크. `0` 이면 미지정이고 목록에서 직접 골라 시작한다.
    public var weekdayMask: Int = 0
    public var note: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.routine)
    public var exercises: [PlannedExercise]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        category: String = "",
        weekdayMask: Int = 0,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.weekdayMask = weekdayMask
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.exercises = []
    }
}

public extension Routine {
    /// 관계 배열은 CloudKit 제약 때문에 옵셔널이라, 읽을 때는 항상 이쪽을 쓴다.
    var sortedExercises: [PlannedExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var weekdays: [Weekday] {
        Weekday.from(mask: weekdayMask)
    }

    var isScheduled: Bool { weekdayMask != 0 }

    func isScheduled(on weekday: Weekday) -> Bool {
        weekdayMask & weekday.bit != 0
    }

    var totalSetCount: Int {
        sortedExercises.reduce(0) { $0 + $1.sortedSets.count }
    }

    /// 목록에 보여줄 제목. 비어 있으면 카테고리로 대체한다.
    var resolvedTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return category.isEmpty ? "이름 없는 루틴" : category
    }

    /// 종목을 끝에 붙이고 순서를 매긴다.
    @discardableResult
    func appendExercise(named rawName: String) -> PlannedExercise {
        let exercise = PlannedExercise(
            name: ExerciseName.display(rawName),
            order: (exercises ?? []).count
        )
        exercise.routine = self
        exercises = (exercises ?? []) + [exercise]
        touch()
        return exercise
    }

    /// `order` 를 0부터 빈틈없이 다시 매긴다. 삭제·이동 뒤에 호출한다.
    func reindexExercises() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.order = index
        }
        touch()
    }

    /// 세트가 없는 종목. 그대로 저장하면 마크다운 왕복에서 조용히 사라지므로
    /// 편집기가 저장 전에 경고할 때 쓴다(06-F01 계획 "빈 종목 처리").
    var emptyExercises: [PlannedExercise] {
        sortedExercises.filter { $0.sortedSets.isEmpty }
    }

    /// 종목을 컨텍스트와 관계 배열 양쪽에서 지운다. 배열에서만 빼면 SwiftData
    /// 저장소에는 고아로 남는다 — `ParsedRoutine.apply(to:)` 와 같은 패턴.
    func removeExercise(_ exercise: PlannedExercise) {
        modelContext?.delete(exercise)
        exercises = sortedExercises.filter { $0.id != exercise.id }
        reindexExercises()
    }

    /// 세트 없는 종목을 전부 지운다. 사용자가 빈 종목 경고에서 "종목 빼고 저장"을 골랐을 때 쓴다.
    func removeEmptyExercises() {
        for exercise in emptyExercises {
            removeExercise(exercise)
        }
    }

    func touch(_ date: Date = Date()) {
        updatedAt = date
    }
}
