import Foundation
import SwiftData
import Testing
@testable import WoofitCore

// MARK: - 픽스처

private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.current.date(from: components)!
}

/// F-06 왕복 테스트에서 쓰는 것과 같은 세션. 벤치프레스 5세트(마지막 실패), 인클라인 4세트,
/// 케이블 플라이 3세트(마지막 건너뜀). 전부 기록된 상태라 형식 A 의 "값 있는 칸" 이 세트 수와 같다.
private func makeGymSession() -> WorkoutSession {
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)
    let incline = routine.appendExercise(named: "인클라인 덤벨 프레스")
    incline.appendSets(count: 4, weight: 24, reps: 10)
    let cable = routine.appendExercise(named: "케이블 플라이")
    cable.appendSets(count: 3, weight: 20, reps: 15)

    let session = WorkoutSession.start(from: routine, at: date(2026, 8, 31))

    let benchSets = session.sortedExercises[0].sortedSets
    for set in benchSets.prefix(4) { set.markSuccess() }
    benchSets[4].markFailure(actualReps: 3)

    for set in session.sortedExercises[1].sortedSets { set.markSuccess() }

    let cableSets = session.sortedExercises[2].sortedSets
    cableSets[0].markSuccess()
    cableSets[1].markSuccess()
    cableSets[2].markSkipped()

    session.endedAt = session.startedAt.addingTimeInterval(4_320)
    session.state = .completed
    return session
}

// MARK: - 왕복 (가장 중요한 테스트)

@Test("왕복 — 루틴을 내보내고 다시 가져오면 같은 루틴이다")
func routineRoundTripPreservesRoutine() {
    let routine = Routine(name: "월요일", category: "가슴", weekdayMask: Weekday.mask(of: [.monday, .thursday]))
    routine.appendExercise(named: "벤치프레스").appendSets(count: 5, weight: 80, reps: 5)
    routine.appendExercise(named: "인클라인 덤벨 프레스").appendSets(count: 4, weight: 24, reps: 10)
    routine.appendExercise(named: "케이블 플라이").appendSets(count: 3, weight: 22.5, reps: 15)

    let markdown = RoutineMarkdownExporter.export(routine)
    let result = RoutineMarkdownImporter.parse(markdown)

    #expect(result.issues.isEmpty)
    #expect(result.routine.title == routine.name)
    #expect(result.routine.category == routine.category)
    #expect(result.routine.weekdayMask == routine.weekdayMask)
    #expect(result.routine.exercises.map(\.name) == routine.sortedExercises.map(\.name))
    for (parsed, original) in zip(result.routine.exercises, routine.sortedExercises) {
        #expect(parsed.sets.map(\.targetWeight) == original.sortedSets.map(\.targetWeight))
        #expect(parsed.sets.map(\.targetReps) == original.sortedSets.map(\.targetReps))
    }
}

@Test("왕복 — 세션을 내보내고 가져오면 그 세션의 계획이 나온다")
func sessionRoundTripRecoversPlanIgnoringResults() {
    let session = makeGymSession()
    let markdown = SessionMarkdownExporter.export(session)
    let result = RoutineMarkdownImporter.parse(markdown)

    #expect(result.issues.isEmpty)
    #expect(result.routine.category == session.category)
    #expect(result.routine.weekdayMask == Weekday.mask(of: [.monday]))
    #expect(result.routine.exercises.map(\.name) == session.sortedExercises.map(\.name))
    for (parsed, original) in zip(result.routine.exercises, session.sortedExercises) {
        #expect(parsed.sets.map(\.targetWeight) == original.sortedSets.map(\.targetWeight))
        #expect(parsed.sets.map(\.targetReps) == original.sortedSets.map(\.targetReps))
    }
}

// MARK: - 세트 수 판정

@Test("형식 A 를 읽고 세트 수를 값 있는 칸 수로 센다")
func horizontalFormatCountsOnlyFilledCells() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 1 | 2 | 3 | 평균 휴식 |
    | --- | --- | --- | --- | --- | --- |
    | 벤치프레스 | 80kg × 5 | ✅ | ✅ | | 2'00" |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.issues.isEmpty)
    #expect(result.routine.exercises.count == 1)
    #expect(result.routine.exercises[0].sets.map(\.targetWeight) == [80, 80])
    #expect(result.routine.exercises[0].sets.map(\.targetReps) == [5, 5])
}

@Test("형식 B 를 읽고 같은 종목 행을 하나로 묶는다")
func verticalFormatGroupsConsecutiveRows() {
    let markdown = """
    ## 가슴

    | 종목 | 세트 | 목표 | 결과 | 휴식 |
    | --- | --- | --- | --- | --- |
    | 벤치프레스 | 1 | 80kg × 5 | 성공 | 2'30" |
    | 벤치프레스 | 2 | 80kg × 5 | 성공 | 2'40" |
    | 벤치프레스 | 3 | 80kg × 5 | | |
    | 케이블 플라이 | 1 | 20kg × 15 | 건너뜀 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.issues.isEmpty)
    #expect(result.routine.exercises.map(\.name) == ["벤치프레스", "케이블 플라이"])
    #expect(result.routine.exercises[0].sets.count == 3)
    #expect(result.routine.exercises[1].sets.count == 1)
}

@Test("루틴 형식의 세트 열을 읽는다")
func routineFormatReadsSetsColumn() {
    let markdown = """
    ## 등

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 랫풀다운 | 40kg × 10 | 3 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.issues.isEmpty)
    #expect(result.routine.exercises[0].sets.count == 3)
    #expect(result.routine.exercises[0].sets.allSatisfy { $0.targetWeight == 40 && $0.targetReps == 10 })
}

@Test("지난 기록 열이 있어도 무시한다")
func routineFormatIgnoresLastRecordColumn() {
    let markdown = """
    ## 등

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 랫풀다운 | 40kg × 10 | 3 | 40kg ✅✅✅ · 8/24 |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.issues.isEmpty)
    #expect(result.routine.exercises[0].sets.count == 3)
}

// MARK: - 메타데이터

@Test("- 반복: 월, 목 을 마스크 18 로 읽는다")
func metadataParsesRepeatBulletIntoMask() {
    let markdown = """
    ## 월요일 · 가슴

    - 부위: 가슴
    - 반복: 월, 목

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 80kg × 5 | 5 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.weekdayMask == 18)
}

@Test("제목 ## 2026-08-31 (월) · 가슴 에서 요일과 이름을 뽑는다")
func metadataInfersWeekdayAndCategoryFromTitle() {
    let markdown = """
    ## 2026-08-31 (월) · 가슴

    - 루틴: 월요일 가슴
    - 소요 시간: 30분

    | 종목 | 목표 | 1 | 평균 휴식 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 80kg × 5 | ✅ | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.category == "가슴")
    #expect(result.routine.weekdayMask == Weekday.monday.bit)
}

@Test("- 부위: 가 없으면 카테고리가 비어 미리보기에서 지정 대상이 된다")
func metadataLeavesCategoryEmptyWhenBulletMissing() {
    let markdown = """
    ## 벤치프레스만

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 80kg × 5 | 5 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.category.isEmpty)
}

// MARK: - 목표 열 파싱

@Test("맨몸 × 15 를 무게 0 으로 읽는다")
func targetParsesBodyweightAsZero() {
    let markdown = """
    ## 코어

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 플랭크 | 맨몸 × 15 | 3 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.exercises[0].sets.allSatisfy { $0.targetWeight == 0 && $0.targetReps == 15 })
}

@Test("22.5kg × 5 소수 무게를 읽는다")
func targetParsesDecimalWeight() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 케이블 플라이 | 22.5kg × 5 | 3 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.exercises[0].sets.allSatisfy { $0.targetWeight == 22.5 })
}

@Test("70~80kg × 5 범위를 세트 수만큼 균등 보간한다")
func targetInterpolatesWeightRangeAcrossSets() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 70~80kg × 5 | 3 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.exercises[0].sets.map(\.targetWeight) == [70, 75, 80])
}

@Test("범위 표기이고 세트가 1개면 낮은 쪽 값을 쓴다")
func targetRangeWithSingleSetUsesLowValue() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 70~80kg × 5 | 1 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.exercises[0].sets.map(\.targetWeight) == [70])
}

// MARK: - 관대한 파싱

@Test("깨진 행 하나가 있어도 나머지는 읽힌다")
func parsingSkipsOnlyBrokenRows() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 벤치프레스 | 80kg × 5 | 5 | |
    | 깨진줄 | 이상한값 | abc | |
    | 스쿼트 | 100kg × 5 | 3 | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.routine.exercises.map(\.name) == ["벤치프레스", "스쿼트"])
}

@Test("깨진 행이 issues 에 담긴다")
func brokenRowIsReportedAsIssue() {
    let markdown = """
    ## 가슴

    | 종목 | 목표 | 세트 | 지난 기록 |
    | --- | --- | --- | --- |
    | 깨진줄 | 이상한값 | abc | |
    """
    let result = RoutineMarkdownImporter.parse(markdown)
    #expect(result.issues.count == 1)
    #expect(result.issues[0].line.contains("깨진줄"))
}

@Test("표가 아예 없으면 종목 0개와 issue 를 돌려준다")
func missingTableReturnsEmptyRoutineWithIssue() {
    let result = RoutineMarkdownImporter.parse("## 그냥 텍스트\n\n아무 표도 없음")
    #expect(result.routine.exercises.isEmpty)
    #expect(result.issues.count == 1)
}

// MARK: - 반영

@Test("새 루틴 생성은 파싱 결과를 그대로 반영한다")
func makeRoutineBuildsFromParsedData() {
    let parsed = ParsedRoutine(
        title: "등",
        category: "등",
        weekdayMask: 0,
        exercises: [ParsedExercise(name: "랫풀다운", sets: [ParsedSet(targetWeight: 40, targetReps: 10)])]
    )
    let routine = parsed.makeRoutine()
    #expect(routine.name == "등")
    #expect(routine.sortedExercises.map(\.name) == ["랫풀다운"])
    #expect(routine.sortedExercises[0].sortedSets.map(\.targetWeight) == [40])
}

@MainActor
@Test("덮어쓰기 시 기존 종목·세트가 교체된다")
func applyReplacesExistingExercisesAndSets() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = Routine(name: "가슴", category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 80, reps: 5)

    let parsed = ParsedRoutine(
        title: "가슴",
        category: "가슴",
        weekdayMask: 0,
        exercises: [ParsedExercise(name: "스쿼트", sets: [ParsedSet(targetWeight: 100, targetReps: 5)])]
    )
    parsed.apply(to: routine)

    #expect(routine.sortedExercises.map(\.name) == ["스쿼트"])
    #expect(routine.sortedExercises[0].sortedSets.map(\.targetWeight) == [100])

    let remainingExercises = try context.fetch(FetchDescriptor<PlannedExercise>())
    #expect(remainingExercises.map(\.name) == ["스쿼트"])
}
