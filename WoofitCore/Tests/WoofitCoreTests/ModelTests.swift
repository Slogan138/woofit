import Foundation
import SwiftData
import Testing
@testable import WoofitCore

// MARK: - 종목명 정규화 (A6)

@Test("공백 표기가 달라도 같은 종목으로 묶인다")
func normalizesWhitespaceAway() {
    #expect(ExerciseName.normalize("벤치프레스") == ExerciseName.normalize("벤치 프레스"))
    #expect(ExerciseName.normalize("  랫 풀 다운 ") == ExerciseName.normalize("랫풀다운"))
    #expect(ExerciseName.normalize("Bench Press") == ExerciseName.normalize("benchpress"))
}

@Test("표시용 이름은 사용자가 적은 표기를 유지한다")
func keepsDisplaySpelling() {
    #expect(ExerciseName.display("  벤치 프레스 ") == "벤치 프레스")
}

// MARK: - 요일 비트마스크 (§7)

@Test("월·목 마스크는 18이다")
func weekdayMaskMatchesSpec() {
    let mask = Weekday.mask(of: [.monday, .thursday])
    #expect(mask == 18)
    #expect(Weekday.from(mask: mask) == [.monday, .thursday])
    #expect(Weekday.label(mask: mask) == "월, 목")
}

@Test("마스크 0은 미지정이다")
func emptyMaskMeansUnscheduled() {
    let routine = Routine(name: "임시")
    #expect(routine.isScheduled == false)
    #expect(routine.weekdays.isEmpty)
}

// MARK: - 스냅샷 (§7)

@MainActor
@Test("세션은 루틴을 복사하므로 이후 루틴 수정에 영향받지 않는다")
func sessionSnapshotIsIndependent() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    context.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    // 세션을 시작한 뒤 루틴의 무게를 올린다.
    for set in bench.sortedSets { set.targetWeight = 82.5 }

    let snapshotWeights = session.allSets.map(\.targetWeight)
    #expect(snapshotWeights == [80, 80, 80, 80, 80])
    #expect(session.routineName == "월요일 가슴")
    #expect(session.category == "가슴")
}

// MARK: - 세트 결과와 D1 불변식

@Test("성공은 추가 입력 없이 기록된다")
func successNeedsNoExtraInput() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    set.markSuccess()
    #expect(set.result == .success)
    #expect(set.performedReps == 5)
    #expect(set.actualReps == nil)
    #expect(set.recordedAt != nil)
}

@Test("실패는 실제 횟수 없이 기록될 수 없다")
func failureAlwaysCarriesActualReps() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    set.markFailure(actualReps: 3)
    #expect(set.result == .failure)
    #expect(set.actualReps == 3)
    #expect(set.performedReps == 3)
}

@Test("실패 시 무게를 낮춰 수행한 것도 남는다")
func failureCanRecordAdjustedWeight() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    set.markFailure(actualReps: 3, actualWeight: 70)
    #expect(set.performedWeight == 70)
}

// MARK: - 휴식 측정 (F-5)

@Test("탭으로 시작하고 다시 탭하면 휴식 시간이 남는다")
func restStopwatchRecordsElapsed() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    let start = Date()
    set.startRest(at: start)
    #expect(set.isRestRunning)
    #expect(set.elapsedRest(at: start.addingTimeInterval(30)) == 30)

    set.stopRest(at: start.addingTimeInterval(150))
    #expect(set.isRestRunning == false)
    #expect(set.restSeconds == 150)
}

@Test("휴식 중 다음 세트를 기록하면 휴식도 자동 종료된다")
func recordingNextSetStopsRest() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    let start = Date()
    set.startRest(at: start)
    set.markSuccess(at: start.addingTimeInterval(90))
    #expect(set.isRestRunning == false)
    #expect(set.restSeconds == 90)
}

@Test("결과를 되돌려도 실제로 쉰 시간은 남는다")
func clearingResultKeepsRest() {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    set.restSeconds = 120
    set.markSuccess()
    set.clearResult()
    #expect(set.result == .pending)
    #expect(set.restSeconds == 120)
}

// MARK: - 진행 상태와 다음 종목 (F-4)

@MainActor
@Test("종목이 끝나면 다음 종목을 가리킨다")
func advancesToNextExercise() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 2, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "케이블 플라이")
    fly.appendSets(count: 2, weight: 20, reps: 15)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let first = try #require(session.currentExercise)
    #expect(first.name == "벤치프레스")

    for set in first.sortedSets { set.markSuccess() }
    #expect(first.isComplete)

    let next = try #require(session.exercise(after: first))
    #expect(next.name == "케이블 플라이")
    #expect(session.currentExercise?.id == next.id)
}

@MainActor
@Test("세트가 0개인 종목은 완료로 간주된다")
func exerciseWithNoSetsIsComplete() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    _ = routine.appendExercise(named: "빈 종목")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 1, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let empty = session.sortedExercises[0]
    #expect(empty.isComplete)
    // 빈 종목은 건너뛰고 세트가 있는 종목이 현재 종목이어야 한다.
    #expect(session.currentExercise?.name == "벤치프레스")
}

@MainActor
@Test("남은 세트가 있는 채로 끝내면 중단으로 기록된다")
func unfinishedSessionIsAbandoned() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.allSets[0].markSuccess()
    session.finish()

    #expect(session.state == .abandoned)
    #expect(session.recordedSetCount == 1)
    #expect(session.totalSetCount == 3)
}

// MARK: - 진행률 (F-3)

@MainActor
@Test("진행률이 종목·세트 두 기준으로 계산된다")
func progressCountsByExerciseAndBySet() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 2, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "케이블 플라이")
    fly.appendSets(count: 2, weight: 20, reps: 15)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    #expect(session.totalExerciseCount == 2)
    #expect(session.completedExerciseCount == 0)
    #expect(session.totalSetCount == 4)
    #expect(session.recordedSetCount == 0)

    let benchExercise = session.sortedExercises[0]
    benchExercise.sortedSets[0].markSuccess()
    #expect(session.completedExerciseCount == 0)
    #expect(session.recordedSetCount == 1)

    benchExercise.sortedSets[1].markSuccess()
    #expect(session.completedExerciseCount == 1)
    #expect(session.recordedSetCount == 2)
}

@MainActor
@Test("세트가 하나도 없는 종목도 완료로 센다")
func exerciseWithNoSetsCountsAsCompleted() throws {
    // 처리할 세트가 없는 종목을 영원히 미완료로 두면 세션이 다음 종목으로도,
    // 완료로도 넘어가지 못하는 함정이 된다 — 종목이 0개인 루틴 버그와 뿌리가 같다.
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스") // 세트를 붙이지 않는다.

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    #expect(session.totalExerciseCount == 1)
    #expect(session.completedExerciseCount == 1)
    #expect(session.totalSetCount == 0)
}

@MainActor
@Test("전부 건너뛴 종목도 완료로 센다")
func exerciseWithAllSetsSkippedCountsAsCompleted() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 2, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    for set in session.allSets { set.markSkipped() }

    #expect(session.completedExerciseCount == 1)
    #expect(session.recordedSetCount == 2)
    #expect(session.successSetCount == 0)
}

@MainActor
@Test("빈 세션은 진행률이 전부 0이다")
func emptySessionHasZeroProgress() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "빈 루틴")
    context.insert(routine)

    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    #expect(session.totalExerciseCount == 0)
    #expect(session.completedExerciseCount == 0)
    #expect(session.totalSetCount == 0)
    #expect(session.recordedSetCount == 0)
}

// MARK: - 직전 기록 (F-9)

@MainActor
@Test("직전 기록은 끝난 세션에서만 찾고 진행 중 세션은 무시한다")
func lastRecordSkipsInProgressSessions() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 80, reps: 5)

    // 지난주 — 마지막 세트만 실패
    let past = WorkoutSession.start(from: routine, at: Date().addingTimeInterval(-7 * 86_400))
    context.insert(past)
    past.allSets[0].markSuccess()
    past.allSets[1].markSuccess()
    past.allSets[2].markFailure(actualReps: 3)
    past.finish()

    // 오늘 — 아직 진행 중
    let today = WorkoutSession.start(from: routine)
    context.insert(today)
    today.allSets[0].markSuccess()

    let key = ExerciseName.normalize("벤치프레스")
    let record = try #require(try LastRecordLookup.fetch(normalizedName: key, in: context))

    #expect(record.entries.count == 3)
    #expect(record.succeededAllSets == false)
    #expect(record.successCount == 2)
    #expect(record.topWeight == 80)
    #expect(record.summary().contains("80kg ✅✅❌(3)"))
}

@MainActor
@Test("공백 표기가 달라도 직전 기록을 찾는다")
func lastRecordMatchesAcrossSpelling() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let old = Routine(name: "가슴")
    context.insert(old)
    old.appendExercise(named: "벤치 프레스").appendSets(count: 2, weight: 75, reps: 5)
    let past = WorkoutSession.start(from: old, at: Date().addingTimeInterval(-86_400))
    context.insert(past)
    for set in past.allSets { set.markSuccess() }
    past.finish()

    let record = try LastRecordLookup.fetch(
        normalizedName: ExerciseName.normalize("벤치프레스"),
        in: context
    )
    #expect(record != nil)
    #expect(record?.succeededAllSets == true)
}

@MainActor
@Test("처음 하는 종목이면 직전 기록이 없다")
func lastRecordIsNilForNewExercise() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let record = try LastRecordLookup.fetch(
        normalizedName: ExerciseName.normalize("힙쓰러스트"),
        in: container.mainContext
    )
    #expect(record == nil)
}

// MARK: - 표기 (§6.4)

@Test("무게 표기는 필요할 때만 소수점을 붙인다")
func weightFormatting() {
    #expect(WeightFormatter.string(80) == "80kg")
    #expect(WeightFormatter.string(22.5) == "22.5kg")
    #expect(WeightFormatter.string(0) == "맨몸")
    #expect(WeightFormatter.target(weight: 80, reps: 5) == "80kg × 5")
}

@Test("휴식과 소요 시간 표기")
func timeFormatting() {
    #expect(WeightFormatter.rest(150) == "2'30\"")
    #expect(WeightFormatter.rest(70) == "1'10\"")
    #expect(WeightFormatter.duration(4_320) == "1시간 12분")
    #expect(WeightFormatter.duration(2_880) == "48분")
    #expect(WeightFormatter.duration(3_600) == "1시간")
}
