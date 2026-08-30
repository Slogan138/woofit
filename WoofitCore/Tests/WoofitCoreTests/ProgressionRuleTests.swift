import Testing
import Foundation
import SwiftData
@testable import WoofitCore

/// F-11 규칙은 5개월치 실제 기록에서 나왔다(PRD D12). 아래 테스트는 그 규칙을 고정한다.
/// **컨테이너를 반환한다.** `mainContext` 만 받아 쓰면 컨테이너가 해제되면서
/// 컨텍스트가 함께 무너진다.
@MainActor
private func makeContainer() throws -> ModelContainer {
    try WoofitModelContainer.makeInMemoryContainer()
}

/// 종목 하나를 무게·결과와 함께 수행한 완료 세션을 만든다.
@MainActor
@discardableResult
private func record(
    _ name: String,
    weight: Double,
    results: [SetResult],
    daysAgo: Int,
    in context: ModelContext
) -> WorkoutSession {
    let routine = Routine(name: "루틴")
    context.insert(routine)
    routine.appendExercise(named: name).appendSets(count: results.count, weight: weight, reps: 10)

    let session = WorkoutSession.start(from: routine)
    session.startedAt = Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400))
    context.insert(session)

    for (set, result) in zip(session.sortedExercises.flatMap(\.sortedSets), results) {
        switch result {
        case .success: set.markSuccess(at: session.startedAt)
        case .failure: set.markFailure(actualReps: 5, at: session.startedAt)
        case .skipped: set.markSkipped(at: session.startedAt)
        case .pending: break
        }
    }
    session.finish(at: session.startedAt)
    return session
}

@MainActor
private func sessions(in context: ModelContext) throws -> [WorkoutSession] {
    try context.fetch(FetchDescriptor<WorkoutSession>())
}

// MARK: - 세 단계 (D12)

@MainActor
@Test("과거에 써본 다음 무게가 있으면 그것을 제안한다")
func suggestsKnownNextWeight() throws {
    // 덤벨 숄더 프레스가 5·6·7·8 을 거쳤고 직전이 7 이면 8 이 다음이다.
    // 그 기구에 그 무게가 있다는 것이 이미 증명됐다.
    let container = try makeContainer()
    let context = container.mainContext
    for (index, weight) in [5.0, 6.0, 8.0, 7.0].enumerated() {
        record("덤벨 숄더 프레스", weight: weight, results: [.success, .success], daysAgo: 40 - index * 7, in: context)
    }

    let suggestion = try #require(ProgressionRule.suggest(for: "덤벨숄더프레스", in: sessions(in: context)))
    #expect(suggestion.currentWeight == 7)
    #expect(suggestion.suggestedWeight == 8)
    #expect(suggestion.basis == .knownNextWeight)
}

@MainActor
@Test("직전이 최고 무게면 그 종목이 올려온 폭만큼 더한다")
func suggestsObservedIncrement() throws {
    // 아웃 타이는 55 → 62 → 70 으로 7~8kg 씩 올랐다. 70 다음은 관측 폭을 더한다.
    let container = try makeContainer()
    let context = container.mainContext
    for (index, weight) in [30.0, 35.0, 40.0].enumerated() {
        record("레그 컬", weight: weight, results: [.success, .success], daysAgo: 30 - index * 7, in: context)
    }

    let suggestion = try #require(ProgressionRule.suggest(for: "레그컬", in: sessions(in: context)))
    #expect(suggestion.currentWeight == 40)
    #expect(suggestion.suggestedWeight == 45)
    #expect(suggestion.basis == .observedIncrement(5))
}

@MainActor
@Test("올려본 적이 없는 종목은 무게대별 기본 단위를 쓴다")
func suggestsDefaultStep() throws {
    // 41종목 중 27종목이 여기 해당한다 — 증량 이력이 아예 없다.
    let container = try makeContainer()
    let context = container.mainContext
    record("사이드 레터럴 레이즈", weight: 5, results: [.success, .success], daysAgo: 7, in: context)

    let suggestion = try #require(ProgressionRule.suggest(for: "사이드레터럴레이즈", in: sessions(in: context)))
    #expect(suggestion.suggestedWeight == 6)
    #expect(suggestion.basis == .defaultStep(1))
}

@Test("기본 단위는 무게대에 따라 갈린다")
func defaultStepByWeightBand() {
    #expect(ProgressionRule.defaultStep(forWeight: 5) == 1)
    #expect(ProgressionRule.defaultStep(forWeight: 9.5) == 1)
    #expect(ProgressionRule.defaultStep(forWeight: 10) == 2.5)
    #expect(ProgressionRule.defaultStep(forWeight: 20) == 2.5)
    #expect(ProgressionRule.defaultStep(forWeight: 30) == 5)
    #expect(ProgressionRule.defaultStep(forWeight: 100) == 5)
}

@MainActor
@Test("증량 폭이 여러 가지면 가장 자주 쓴 폭을 고른다")
func picksMostCommonIncrement() throws {
    let container = try makeContainer()
    let context = container.mainContext
    // 10 → 15(+5) → 20(+5) → 30(+10). 최빈은 +5 다.
    for (index, weight) in [10.0, 15.0, 20.0, 30.0].enumerated() {
        record("스컬크러셔", weight: weight, results: [.success], daysAgo: 40 - index * 7, in: context)
    }

    let suggestion = try #require(ProgressionRule.suggest(for: "스컬크러셔", in: sessions(in: context)))
    #expect(suggestion.suggestedWeight == 35)
    #expect(suggestion.basis == .observedIncrement(5))
}

// MARK: - 올리지 않는 경우

@MainActor
@Test("직전에 실패한 세트가 있으면 무게를 유지한다")
func holdsAfterFailure() throws {
    // 감량은 제안하지 않는다 — 내린 7회 중 5회가 직전 성공이라 근거가 없다(D12).
    let container = try makeContainer()
    let context = container.mainContext
    record("벤치 프레스", weight: 40, results: [.success, .failure], daysAgo: 7, in: context)

    let suggestion = try #require(ProgressionRule.suggest(for: "벤치프레스", in: sessions(in: context)))
    #expect(suggestion.suggestedWeight == 40)
    #expect(suggestion.basis == .hold)
    #expect(suggestion.isIncrease == false)
}

@MainActor
@Test("건너뛴 세트가 있으면 전 세트 성공으로 치지 않는다")
func skippedSetBlocksIncrease() throws {
    // 수행하지 않은 것을 증량의 근거로 삼을 수 없다.
    let container = try makeContainer()
    let context = container.mainContext
    record("펙덱 플라이", weight: 30, results: [.success, .skipped], daysAgo: 7, in: context)

    let suggestion = try #require(ProgressionRule.suggest(for: "펙덱플라이", in: sessions(in: context)))
    #expect(suggestion.basis == .hold)
}

@MainActor
@Test("기록이 없는 종목에는 제안이 없다")
func noSuggestionWithoutHistory() throws {
    let container = try makeContainer()
    let context = container.mainContext
    #expect(try ProgressionRule.suggest(for: "없는종목", in: sessions(in: context)) == nil)
}

@MainActor
@Test("맨몸 종목에는 제안하지 않는다")
func noSuggestionForBodyweight() throws {
    let container = try makeContainer()
    let context = container.mainContext
    record("풀업", weight: 0, results: [.success, .success], daysAgo: 7, in: context)
    #expect(try ProgressionRule.suggest(for: "풀업", in: sessions(in: context)) == nil)
}

@MainActor
@Test("보조 기구 종목에는 제안하지 않는다")
func noSuggestionForAssisted() throws {
    // 보조 중량은 줄수록 향상이라 방향이 뒤집힌다(F-10 과 같은 이유).
    let container = try makeContainer()
    let context = container.mainContext
    record("어시스트 풀업 (보조)", weight: 65, results: [.success, .success], daysAgo: 7, in: context)
    #expect(try ProgressionRule.suggest(for: ExerciseName.normalize("어시스트 풀업 (보조)"), in: sessions(in: context)) == nil)
}

// MARK: - 표시

@MainActor
@Test("제안에는 어느 근거에서 나왔는지가 남는다")
func suggestionCarriesReason() throws {
    let container = try makeContainer()
    let context = container.mainContext
    record("사이드 레터럴 레이즈", weight: 5, results: [.success], daysAgo: 7, in: context)

    let suggestion = try #require(ProgressionRule.suggest(for: "사이드레터럴레이즈", in: sessions(in: context)))
    // 근거가 약한 제안은 약하다고 말한다(계획 11).
    #expect(suggestion.reason.contains("올려본 적이 없어"))
}
