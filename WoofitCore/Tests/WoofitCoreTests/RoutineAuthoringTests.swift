import Foundation
import SwiftData
import Testing
@testable import WoofitCore

// MARK: - 요일 배타 배정 (A1)

@MainActor
@Test("요일을 배정하면 같은 요일을 쓰던 다른 루틴에서 해제된다")
func assigningWeekdayUnassignsOtherRoutine() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let existing = Routine(name: "월요일 가슴", weekdayMask: Weekday.mask(of: [.monday]))
    context.insert(existing)
    let incoming = Routine(name: "월요일 등")
    context.insert(incoming)

    try RoutineScheduler.assign([.monday], to: incoming, in: context)

    #expect(incoming.isScheduled(on: .monday))
    #expect(existing.isScheduled(on: .monday) == false)
}

@MainActor
@Test("겹치지 않는 요일을 쓰던 루틴은 영향받지 않는다")
func assigningWeekdayLeavesUnrelatedRoutineAlone() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let tuesday = Routine(name: "화요일", weekdayMask: Weekday.mask(of: [.tuesday]))
    context.insert(tuesday)
    let monday = Routine(name: "월요일")
    context.insert(monday)

    try RoutineScheduler.assign([.monday], to: monday, in: context)

    #expect(tuesday.isScheduled(on: .tuesday))
}

@MainActor
@Test("여러 요일을 한 루틴에 배정할 수 있다")
func assignsMultipleWeekdays() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "월·목")
    context.insert(routine)

    try RoutineScheduler.assign([.monday, .thursday], to: routine, in: context)

    #expect(routine.weekdayMask == 18)
}

@MainActor
@Test("요일을 비우면 미지정 루틴이 된다")
func assigningEmptyWeekdaysUnschedules() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "월요일", weekdayMask: Weekday.mask(of: [.monday]))
    context.insert(routine)

    try RoutineScheduler.assign([], to: routine, in: context)

    #expect(routine.weekdayMask == 0)
    #expect(routine.isScheduled == false)
}

// MARK: - 종목명 자동완성

@MainActor
@Test("자동완성 후보가 빈도 순으로, 빈도가 같으면 최근 순으로 나온다")
func suggestionsOrderByFrequencyThenRecency() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let old = Routine(name: "옛 루틴", createdAt: Date().addingTimeInterval(-100))
    old.updatedAt = Date().addingTimeInterval(-100)
    context.insert(old)
    old.appendExercise(named: "스쿼트")
    old.appendExercise(named: "벤치프레스")

    let recent = Routine(name: "최근 루틴")
    recent.updatedAt = Date()
    context.insert(recent)
    recent.appendExercise(named: "벤치프레스")

    let candidates = try ExerciseNameSuggester.suggest(in: context)

    #expect(candidates.first?.normalizedName == ExerciseName.normalize("벤치프레스"))
    #expect(candidates.map(\.normalizedName).contains(ExerciseName.normalize("스쿼트")))
}

@MainActor
@Test("자동완성이 공백 표기 차이를 하나로 묶는다")
func suggestionsMergeWhitespaceVariants() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "루틴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스")
    routine.appendExercise(named: "벤치 프레스")

    let candidates = try ExerciseNameSuggester.suggest(in: context)

    let matches = candidates.filter { $0.normalizedName == ExerciseName.normalize("벤치프레스") }
    #expect(matches.count == 1)
}

// MARK: - 루틴 복제

@Test("루틴을 복제하면 종목·세트가 전부 복사된다")
func duplicateCopiesExercisesAndSets() {
    let routine = Routine(name: "월요일 가슴", category: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 3, weight: 80, reps: 5)
    routine.appendExercise(named: "플라이").appendSets(count: 2, weight: 20, reps: 15)

    let copy = routine.duplicate()

    #expect(copy.sortedExercises.map(\.name) == ["벤치프레스", "플라이"])
    #expect(copy.sortedExercises[0].sortedSets.count == 3)
    #expect(copy.sortedExercises[1].sortedSets.count == 2)
    #expect(copy.category == "가슴")
}

@Test("복제본은 요일 배정을 물려받지 않는다")
func duplicateDoesNotInheritWeekdays() {
    let routine = Routine(name: "월요일 가슴", weekdayMask: Weekday.mask(of: [.monday]))

    let copy = routine.duplicate()

    #expect(copy.weekdayMask == 0)
    #expect(routine.weekdayMask == Weekday.mask(of: [.monday]))
}

@Test("복제본을 고쳐도 원본은 바뀌지 않는다")
func duplicateIsIndependentFromOriginal() {
    let routine = Routine(name: "월요일 가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSet(weight: 80, reps: 5)

    let copy = routine.duplicate()
    copy.sortedExercises[0].sortedSets[0].targetWeight = 100

    #expect(bench.sortedSets[0].targetWeight == 80)
}

// MARK: - 종목 삭제와 재정렬

@Test("종목 삭제 후 order 가 빈틈없이 재정렬된다")
func removingExerciseReindexesOrder() {
    let routine = Routine(name: "가슴")
    routine.appendExercise(named: "벤치프레스")
    let fly = routine.appendExercise(named: "플라이")
    routine.appendExercise(named: "딥스")

    routine.exercises = routine.sortedExercises.filter { $0.id != fly.id }
    routine.reindexExercises()

    #expect(routine.sortedExercises.map(\.order) == [0, 1])
    #expect(routine.sortedExercises.map(\.name) == ["벤치프레스", "딥스"])
}

// MARK: - 세트 복제

@Test("세트 복제로 5세트를 한 번에 만든다")
func appendSetsCreatesUniformSets() {
    let routine = Routine(name: "가슴")
    let squat = routine.appendExercise(named: "스쿼트")

    squat.appendSets(count: 5, weight: 100, reps: 5)

    #expect(squat.sortedSets.count == 5)
    #expect(squat.uniformTarget?.weight == 100)
    #expect(squat.uniformTarget?.reps == 5)
}
