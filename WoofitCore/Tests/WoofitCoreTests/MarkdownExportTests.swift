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

/// PRD §6.1 예시와 같은 세션. 벤치프레스 5세트(마지막 실패), 인클라인 4세트, 케이블 플라이 3세트(마지막 건너뜀).
/// 모든 세트에 휴식을 기록해, 종목별 평균과 세션 전체 평균을 문서 예시와 맞춘다.
private func makeGymSession() -> WorkoutSession {
    let routine = Routine(name: "월요일 가슴", category: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)
    let incline = routine.appendExercise(named: "인클라인 덤벨 프레스")
    incline.appendSets(count: 4, weight: 24, reps: 10)
    let cable = routine.appendExercise(named: "케이블 플라이")
    cable.appendSets(count: 3, weight: 20, reps: 15)

    let session = WorkoutSession.start(from: routine, at: date(2026, 8, 31))

    let benchSets = session.sortedExercises[0].sortedSets
    for set in benchSets.prefix(4) {
        set.markSuccess()
        set.restSeconds = 150
    }
    benchSets[4].markFailure(actualReps: 3)
    benchSets[4].restSeconds = 150

    let inclineSets = session.sortedExercises[1].sortedSets
    for set in inclineSets {
        set.markSuccess()
        set.restSeconds = 105
    }

    let cableSets = session.sortedExercises[2].sortedSets
    cableSets[0].markSuccess()
    cableSets[0].restSeconds = 70
    cableSets[1].markSuccess()
    cableSets[1].restSeconds = 70
    cableSets[2].markSkipped()

    session.endedAt = session.startedAt.addingTimeInterval(4_320)
    session.state = .completed
    return session
}

// MARK: - 형식 A (§6.1)

@Test("형식 A 전체 출력이 PRD §6.1 예시와 일치한다")
func horizontalFormatMatchesSpecExample() {
    let expected = [
        "## 2026-08-31 (월) · 가슴",
        "",
        "- 루틴: 월요일 가슴",
        "- 소요 시간: 1시간 12분",
        "- 완료: 11/12 세트",
        "- 평균 휴식: 1'59\"",
        "",
        "| 종목 | 목표 | 1 | 2 | 3 | 4 | 5 | 평균 휴식 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
        "| 벤치프레스 | 80kg × 5 | ✅ | ✅ | ✅ | ✅ | ❌ 3 | 2'30\" |",
        "| 인클라인 덤벨 프레스 | 24kg × 10 | ✅ | ✅ | ✅ | ✅ | | 1'45\" |",
        "| 케이블 플라이 | 20kg × 15 | ✅ | ✅ | ⏭ | | | 1'10\" |",
    ].joined(separator: "\n")

    #expect(SessionMarkdownExporter.export(makeGymSession()) == expected)
}

@Test("세트 수가 다른 종목이 섞이면 모자란 칸은 빈 칸으로 채운다")
func horizontalFormatPadsShorterExercises() {
    let routine = Routine(name: "하체", category: "하체")
    routine.appendExercise(named: "스쿼트").appendSets(count: 3, weight: 100, reps: 5)
    routine.appendExercise(named: "런지").appendSets(count: 1, weight: 20, reps: 10)

    let session = WorkoutSession.start(from: routine)
    for set in session.allSets { set.markSuccess() }

    let markdown = SessionMarkdownExporter.export(session)
    #expect(markdown.contains("| 스쿼트 | 100kg × 5 | ✅ | ✅ | ✅ | |"))
    #expect(markdown.contains("| 런지 | 20kg × 10 | ✅ | | | |"))
}

@Test("중단된 세션의 pending 세트는 빈 칸이다")
func horizontalFormatBlanksPendingSets() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 2, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    session.allSets[0].markSuccess()
    // 두 번째 세트는 pending 인 채로 둔다.

    let markdown = SessionMarkdownExporter.export(session)
    #expect(markdown.contains("| 벤치프레스 | 80kg × 5 | ✅ | | |"))
}

@Test("실패 세트는 ❌ 뒤에 실제 횟수를, 무게를 바꿨으면 무게도 함께 적는다")
func horizontalFormatShowsFailureDetail() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 2, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    let sets = session.allSets
    sets[0].markFailure(actualReps: 3)
    sets[1].markFailure(actualReps: 3, actualWeight: 70)

    let markdown = SessionMarkdownExporter.export(session)
    #expect(markdown.contains("| 벤치프레스 | 80kg × 5 | ❌ 3 | ❌ 70kg 3 | |"))
}

@Test("이모지 대신 텍스트 표기 옵션이 동작한다")
func horizontalFormatSupportsTextSymbols() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    let sets = session.allSets
    sets[0].markSuccess()
    sets[1].markFailure(actualReps: 3)
    sets[2].markSkipped()

    let style = MarkdownStyle(resultSymbol: .text)
    let markdown = SessionMarkdownExporter.export(session, style: style)
    #expect(markdown.contains("| 벤치프레스 | 80kg × 5 | 성공 | 실패 3 | 건너뜀 | |"))
}

@Test("휴식을 측정하지 않은 종목은 휴식 칸이 빈 칸이고, 세션 전체에도 평균 휴식 줄이 없다")
func horizontalFormatBlanksMissingRest() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 2, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    for set in session.allSets { set.markSuccess() }

    let markdown = SessionMarkdownExporter.export(session)
    #expect(markdown.contains("| 벤치프레스 | 80kg × 5 | ✅ | ✅ | |"))
    #expect(markdown.contains("- 평균 휴식") == false)
}

// MARK: - 형식 B (§6.2)

@Test("형식 B는 세트마다 한 줄로 목표·결과·휴식을 담는다")
func verticalFormatListsOneRowPerSet() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 80, reps: 5)
    routine.appendExercise(named: "케이블 플라이").appendSets(count: 1, weight: 20, reps: 15)

    let session = WorkoutSession.start(from: routine, at: date(2026, 8, 31))
    let benchSets = session.sortedExercises[0].sortedSets
    benchSets[0].markSuccess()
    benchSets[0].restSeconds = 150
    benchSets[1].markSuccess()
    benchSets[1].restSeconds = 160
    // 세 번째 세트는 pending 인 채로 둔다.

    let cableSets = session.sortedExercises[1].sortedSets
    cableSets[0].markSkipped()

    session.endedAt = session.startedAt.addingTimeInterval(1_800)

    let expected = [
        "## 2026-08-31 (월) · 가슴",
        "",
        "- 루틴: 가슴",
        "- 소요 시간: 30분",
        "- 완료: 2/4 세트",
        "- 평균 휴식: 2'35\"",
        "",
        "| 종목 | 세트 | 목표 | 결과 | 휴식 |",
        "| --- | --- | --- | --- | --- |",
        "| 벤치프레스 | 1 | 80kg × 5 | 성공 | 2'30\" |",
        "| 벤치프레스 | 2 | 80kg × 5 | 성공 | 2'40\" |",
        "| 벤치프레스 | 3 | 80kg × 5 | | |",
        "| 케이블 플라이 | 1 | 20kg × 15 | 건너뜀 | |",
    ].joined(separator: "\n")

    let markdown = SessionMarkdownExporter.export(session, style: MarkdownStyle(layout: .verticalSets))
    #expect(markdown == expected)
}

@Test("형식 B는 resultSymbol 설정과 무관하게 항상 텍스트로 결과를 적는다")
func verticalFormatIgnoresResultSymbolStyle() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 1, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    session.allSets[0].markSuccess()

    let style = MarkdownStyle(layout: .verticalSets, resultSymbol: .text)
    let markdown = SessionMarkdownExporter.export(session, style: style)
    #expect(markdown.contains("| 벤치프레스 | 1 | 80kg × 5 | 성공 | |"))
}

// MARK: - 루틴 형식 (§6.3)

@Test("루틴 형식이 PRD §6.3 예시와 일치한다")
func routineFormatMatchesSpecExample() {
    let routine = Routine(name: "월요일", category: "가슴", weekdayMask: Weekday.mask(of: [.monday, .thursday]))
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)
    let incline = routine.appendExercise(named: "인클라인 덤벨 프레스")
    incline.appendSets(count: 4, weight: 24, reps: 10)
    let cable = routine.appendExercise(named: "케이블 플라이")
    cable.appendSets(count: 3, weight: 22.5, reps: 15)

    let performedAt = date(2026, 8, 24)
    let lastRecords: [String: LastRecord] = [
        bench.normalizedName: LastRecord(
            normalizedName: bench.normalizedName,
            displayName: bench.name,
            performedAt: performedAt,
            entries: Array(repeating: LastRecord.Entry(weight: 80, targetReps: 5, performedReps: 5, result: .success), count: 4)
                + [LastRecord.Entry(weight: 80, targetReps: 5, performedReps: 3, result: .failure)]
        ),
        incline.normalizedName: LastRecord(
            normalizedName: incline.normalizedName,
            displayName: incline.name,
            performedAt: performedAt,
            entries: Array(repeating: LastRecord.Entry(weight: 24, targetReps: 10, performedReps: 10, result: .success), count: 4)
        ),
        cable.normalizedName: LastRecord(
            normalizedName: cable.normalizedName,
            displayName: cable.name,
            performedAt: performedAt,
            entries: Array(repeating: LastRecord.Entry(weight: 20, targetReps: 15, performedReps: 15, result: .success), count: 3)
        ),
    ]

    let expected = [
        "## 월요일 · 가슴",
        "",
        "- 부위: 가슴",
        "- 반복: 월, 목",
        "",
        "| 종목 | 목표 | 세트 | 지난 기록 |",
        "| --- | --- | --- | --- |",
        "| 벤치프레스 | 80kg × 5 | 5 | 80kg ✅✅✅✅❌(3) · 8/24 |",
        "| 인클라인 덤벨 프레스 | 24kg × 10 | 4 | 24kg ✅✅✅✅ · 8/24 |",
        "| 케이블 플라이 | 22.5kg × 15 | 3 | 20kg ✅✅✅ · 8/24 |",
    ].joined(separator: "\n")

    #expect(RoutineMarkdownExporter.export(routine, lastRecords: lastRecords) == expected)
}

@Test("직전 기록이 없는 종목은 지난 기록 칸이 빈 칸이다")
func routineFormatBlanksMissingLastRecord() {
    let routine = Routine(name: "등", category: "등")
    routine.appendExercise(named: "랫풀다운").appendSets(count: 3, weight: 40, reps: 10)

    let markdown = RoutineMarkdownExporter.export(routine)
    #expect(markdown.contains("| 랫풀다운 | 40kg × 10 | 3 | |"))
}

@Test("이모지 대신 텍스트 표기 옵션이 루틴의 지난 기록 열에도 적용된다")
func routineFormatSupportsTextSymbolsInLastRecordColumn() {
    let routine = Routine(name: "가슴", category: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 2, weight: 80, reps: 5)

    let lastRecords: [String: LastRecord] = [
        bench.normalizedName: LastRecord(
            normalizedName: bench.normalizedName,
            displayName: bench.name,
            performedAt: date(2026, 8, 24),
            entries: [
                LastRecord.Entry(weight: 80, targetReps: 5, performedReps: 5, result: .success),
                LastRecord.Entry(weight: 80, targetReps: 5, performedReps: 3, result: .failure),
            ]
        ),
    ]

    let style = MarkdownStyle(resultSymbol: .text)
    let markdown = RoutineMarkdownExporter.export(routine, lastRecords: lastRecords, style: style)
    #expect(markdown.contains("| 벤치프레스 | 80kg × 5 | 2 | 80kg 성공 실패(3) · 8/24 |"))
}

// MARK: - MarkdownTable 이스케이프

@Test("종목명에 파이프가 있으면 이스케이프되어 표가 깨지지 않는다")
func markdownTableEscapesPipes() {
    #expect(MarkdownTable.escape("벤치|프레스") == "벤치\\|프레스")
}

@Test("개행은 공백으로 바뀐다")
func markdownTableReplacesNewlines() {
    #expect(MarkdownTable.escape("벤치\n프레스") == "벤치 프레스")
}

@Test("종목명의 파이프는 세션 출력에서도 이스케이프된다")
func horizontalFormatEscapesPipeInExerciseName() {
    let routine = Routine(name: "가슴", category: "가슴")
    routine.appendExercise(named: "벤치|프레스").appendSets(count: 1, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    session.allSets[0].markSuccess()

    let markdown = SessionMarkdownExporter.export(session)
    #expect(markdown.contains("벤치\\|프레스"))
}

// MARK: - WeightFormatter.targetRange

@Test("피라미드 세트는 무게 범위로 표기한다")
func targetRangeFormatsPyramidSets() {
    #expect(WeightFormatter.targetRange(weights: [70, 75, 80], reps: 5) == "70~80kg × 5")
    #expect(WeightFormatter.targetRange(weights: [80, 80], reps: 5) == "80kg × 5")
}
