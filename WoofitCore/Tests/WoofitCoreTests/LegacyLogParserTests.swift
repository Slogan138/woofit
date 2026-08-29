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

private func session(_ markdown: String) -> ParsedSession {
    let result = LegacyLogParser.parse(markdown)
    return result.sessions[0]
}

// MARK: - 기본 변환

@Test("3s / 15r + ✅ → 15회 세트 3개 전부 성공")
func normalRowAllSuccess() {
    let markdown = """
    # 2026-03-31
    ## 가슴 / 어깨 / 삼두
    | **운동 종목** | **중량** | **세트/횟수** | **성공** | **비고** |
    | ------------- | ------- | --------- | ------ | ------ |
    | 펙덱 플라이 | 30kg | 3s / 15r | ✅ | |
    """
    let parsed = session(markdown)
    #expect(parsed.date == date(2026, 3, 31))
    #expect(parsed.category == "가슴 / 어깨 / 삼두")
    #expect(parsed.entries.count == 1)

    let entry = parsed.entries[0]
    #expect(entry.name == "펙덱 플라이")
    #expect(entry.sets.count == 3)
    #expect(entry.sets.allSatisfy { $0.result == .success && $0.targetReps == 15 && $0.targetWeight == 30 })
}

@Test("3s / 15r + ❌ → 마지막 세트만 실패, 실제 횟수는 목표보다 1 적게 근사")
func normalRowLastSetFails() {
    let markdown = """
    # 2026-03-31
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 벤치프레스 | 60kg | 3s / 15r | ❌ | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.sets[0].result == .success)
    #expect(entry.sets[1].result == .success)
    #expect(entry.sets[2].result == .failure)
    #expect(entry.sets[2].actualReps == 14)
}

@Test("4s / 12r + 10회 → 마지막 세트 실패, 실제 횟수는 그 숫자")
func numericSuccessColumnUsesExactCount() {
    let markdown = """
    # 2026-04-01
    ## 하체
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 레그프레스 | 100kg | 4s / 12r | 10회 | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.sets.count == 4)
    #expect(entry.sets[3].result == .failure)
    #expect(entry.sets[3].actualReps == 10)
}

@Test("1s / Failure → 세트 1개, 목표 횟수 미상은 0, skipped 가 아닌 success")
func failureUntilFailureRowIsSingleSuccessSet() {
    let markdown = """
    # 2026-04-02
    ## 등 / 이두
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 랫풀다운 | 50kg | 1s / Failure | ✅ | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.sets.count == 1)
    #expect(entry.sets[0].targetReps == 0)
    #expect(entry.sets[0].result == .success)
}

// MARK: - 중량

@Test("65kg 보조 → 종목명에 (보조) 표시가 남는다")
func assistedMachineTagsExerciseName() {
    let markdown = """
    # 2026-04-03
    ## 등 / 이두
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 어시스트 풀업 | 65kg 보조 | 3s / 10r | ✅ | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.name == "어시스트 풀업 (보조)")
    #expect(entry.sets.allSatisfy { $0.targetWeight == 65 })
}

@Test("양쪽 15kg → 한쪽 무게 15 만 취한다")
func doubleSidedWeightTakesSingleSideValue() {
    let markdown = """
    # 2026-04-04
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 덤벨 프레스 | 양쪽 15kg | 3s / 10r | ✅ | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.sets.allSatisfy { $0.targetWeight == 15 })
}

@Test("맨몸 → 무게 0")
func bodyweightIsZero() {
    let markdown = """
    # 2026-04-05
    ## 보충
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 딥스 | 맨몸 | 3s / 12r | ✅ | |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.sets.allSatisfy { $0.targetWeight == 0 })
}

@Test("40kg, 32kg 처럼 세트마다 무게가 다르면 첫 값만 쓰고 issue 를 남긴다")
func mixedWeightsPerSetUseFirstValueAndReportIssue() {
    let markdown = """
    # 2026-04-06
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 벤치프레스 | 40kg, 32kg | 3s / 10r | ✅ | |
    """
    let result = LegacyLogParser.parse(markdown)
    let entry = result.sessions[0].entries[0]
    #expect(entry.sets.allSatisfy { $0.targetWeight == 40 })
    #expect(result.issues.contains { $0.reason.contains("40kg, 32kg") })
}

@Test("X 행은 종목을 만들지 않는다")
func unperformedRowCreatesNoEntry() {
    let markdown = """
    # 2026-04-07
    ## 기타
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 레그컬 | X | | | |
    """
    let result = LegacyLogParser.parse(markdown)
    #expect(result.sessions.isEmpty)
    #expect(!result.issues.isEmpty)
}

// MARK: - 종목명

@Test("볼드 종목명이 일반 종목명과 같은 종목으로 묶인다")
func boldExerciseNameMatchesPlainNameAfterNormalize() {
    let markdown = """
    # 2026-04-08
    ## 등 / 이두
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | **랫풀다운** | 50kg | 1s / 8r | ✅ | |
    | 랫풀다운 | 50kg | 2s / 8r | ✅ | |
    """
    let entries = session(markdown).entries
    #expect(entries.count == 2)
    #expect(ExerciseName.normalize(entries[0].name) == ExerciseName.normalize(entries[1].name))
}

// MARK: - 비고

@Test("비고 열은 종목명 뒤에 붙지 않고 별도로 파싱된다")
func noteColumnIsKeptSeparateFromName() {
    let markdown = """
    # 2026-04-09
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 벤치프레스 | 62kg | 3s / 9r | ✅ | 55kg 다음이 62kg 라 62kg 로 수행 |
    """
    let entry = session(markdown).entries[0]
    #expect(entry.name == "벤치프레스")
    #expect(entry.note == "55kg 다음이 62kg 라 62kg 로 수행")
}

// MARK: - 전체 거부 금지

@Test("읽지 못한 행이 issue 로 남고 나머지 행은 정상 반영된다")
func unreadableRowBecomesIssueWithoutBlockingOthers() {
    let markdown = """
    # 2026-04-10
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 벤치프레스 | 알수없음 | 3s / 10r | ✅ | |
    | 인클라인 프레스 | 40kg | 3s / 10r | ✅ | |
    """
    let result = LegacyLogParser.parse(markdown)
    let entries = result.sessions[0].entries
    #expect(entries.count == 1)
    #expect(entries[0].name == "인클라인 프레스")
    #expect(result.issues.contains { $0.reason.contains("중량을 읽을 수 없습니다") })
}

// MARK: - 반영 · 멱등성

@MainActor
@Test("같은 세션을 두 번 반영해도 중복 세션이 생기지 않는다")
func applyingTwiceDoesNotDuplicateSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let markdown = """
    # 2026-03-31
    ## 가슴
    | 운동 종목 | 중량 | 세트/횟수 | 성공 | 비고 |
    | --- | --- | --- | --- | --- |
    | 펙덱 플라이 | 30kg | 3s / 15r | ✅ | |
    """
    let sessions = LegacyLogParser.parse(markdown).sessions

    let first = try LegacyLogImporter.apply(sessions, in: context)
    #expect(first.addedSessionCount == 1)
    #expect(first.skippedDates.isEmpty)

    let second = try LegacyLogImporter.apply(sessions, in: context)
    #expect(second.addedSessionCount == 0)
    #expect(second.skippedDates.count == 1)

    let all = try context.fetch(FetchDescriptor<WorkoutSession>())
    #expect(all.count == 1)
    #expect(all[0].state == .completed)
    #expect(all[0].allSets.count == 3)
}
