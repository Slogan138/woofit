import Foundation
import Testing
@testable import WoofitCore

// MARK: - 종목별 추이 (F-10)

/// 테스트가 실행 지역과 무관하게 같은 결과를 내도록 UTC 그레고리력을 고정한다.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func day(_ month: Int, _ day: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))!
}

/// `(무게, 횟수, 결과)` 목록으로 세트를 만든다. 실패는 실제 횟수를 함께 준다(PRD D1).
private func session(
    _ startedAt: Date,
    _ name: String,
    _ sets: [(weight: Double, reps: Int, result: SetResult)],
    state: SessionState = .completed
) -> WorkoutSession {
    let session = WorkoutSession(routineName: "테스트", startedAt: startedAt)
    let exercise = SessionExercise(name: name)
    exercise.session = session

    exercise.sets = sets.enumerated().map { index, spec in
        let set = SessionSet(order: index, targetWeight: spec.weight, targetReps: spec.reps)
        set.exercise = exercise
        switch spec.result {
        case .success: set.markSuccess(at: startedAt)
        case .failure: set.markFailure(actualReps: spec.reps, at: startedAt)
        case .skipped: set.markSkipped(at: startedAt)
        case .pending: break
        }
        return set
    }
    session.exercises = [exercise]
    session.endedAt = startedAt
    session.state = state
    return session
}

/// 같은 종목을 `count` 회 같은 내용으로 수행한 세션들. 최신순으로 돌려준다(`@Query` 와 같은 순서).
private func repeated(
    _ name: String,
    _ sets: [(weight: Double, reps: Int, result: SetResult)],
    count: Int,
    from startDay: Int = 1
) -> [WorkoutSession] {
    (0..<count).map { session(day(3, startDay + $0), name, sets) }.reversed()
}

private func series(_ sessions: [WorkoutSession], _ name: String = "벤치프레스") -> ExerciseSeries {
    ExerciseHistory.series(for: ExerciseName.normalize(name), in: sessions)!
}

// MARK: - 볼륨 계산

@Test("볼륨은 무게 × 횟수를 세트마다 더한 값이다")
func volumeSumsWeightTimesReps() {
    let result = series([
        session(day(3, 1), "벤치프레스", [(60, 10, .success), (60, 10, .success), (60, 8, .success)])
    ])

    let expected: Double = 600 + 600 + 480
    #expect(result.points.count == 1)
    #expect(result.points[0].volume == expected)
    #expect(result.points[0].topWeight == 60)
    #expect(result.points[0].setCount == 3)
}

@Test("실패 세트는 목표가 아니라 실제 횟수로 계산된다")
func volumeUsesActualRepsForFailure() {
    let workout = session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    let failed = SessionSet(order: 1, targetWeight: 60, targetReps: 10)
    failed.exercise = workout.sortedExercises[0]
    failed.markFailure(actualReps: 4)
    workout.sortedExercises[0].sets?.append(failed)

    let result = series([workout])

    // 목표대로면 1,200 이다. 실제로 든 값은 600 + 240 이다.
    let expected: Double = 600 + 240
    #expect(result.points[0].volume == expected)
    #expect(result.points[0].totalReps == 14)
    #expect(result.points[0].failureCount == 1)
}

@Test("건너뛴 세트는 볼륨에서 빠진다")
func volumeExcludesSkippedSets() {
    let result = series([
        session(day(3, 1), "벤치프레스", [(60, 10, .success), (60, 10, .skipped), (60, 10, .pending)])
    ])

    #expect(result.points[0].volume == 600)
    #expect(result.points[0].setCount == 1)
}

@Test("기록된 세트가 하나도 없는 세션은 계열에 점을 만들지 않는다")
func volumeSkipsSessionWithoutRecordedSets() {
    let sessions = [
        session(day(3, 8), "벤치프레스", [(60, 10, .pending), (60, 10, .skipped)], state: .abandoned),
        session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    ]

    #expect(series(sessions).points.count == 1)
}

// MARK: - 이 계획의 근거

@Test("무게가 고정이어도 세트가 늘면 볼륨이 는다")
func volumeGrowsWithSetCountAtFixedWeight() {
    // 암풀 다운 — 23회 전부 25kg 고정. 무게만 그리면 평평한 직선이다(PRD D10).
    let sessions = [
        session(day(3, 8), "암풀다운", Array(repeating: (25.0, 15, .success), count: 4)),
        session(day(3, 1), "암풀다운", Array(repeating: (25.0, 15, .success), count: 3))
    ]

    let expected: [Double] = [1_125, 1_500]
    let result = series(sessions, "암풀다운")
    #expect(result.points.map(\.topWeight) == [25, 25])
    #expect(result.values == expected)
}

@Test("무게가 올라도 횟수가 줄면 볼륨은 그대로일 수 있다")
func volumeCanStayFlatWhileWeightRises() {
    // 스컬크러셔 — 무게는 10→20kg 로 올랐지만 횟수를 20→10 으로 줄여 상쇄됐다.
    let sessions = [
        session(day(3, 8), "스컬크러셔", Array(repeating: (20.0, 10, .success), count: 3)),
        session(day(3, 1), "스컬크러셔", Array(repeating: (10.0, 20, .success), count: 3))
    ]

    let expected: [Double] = [600, 600]
    let result = series(sessions, "스컬크러셔")
    #expect(result.values == expected)
}

// MARK: - 묶기

@Test("공백이 다른 같은 종목이 한 계열로 묶인다")
func seriesGroupsByNormalizedName() {
    let sessions = [
        session(day(3, 8), "벤치 프레스", [(60, 10, .success)]),
        session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    ]

    let all = ExerciseHistory.allSeries(in: sessions)
    #expect(all.count == 1)
    #expect(all[0].points.count == 2)
    // 표기는 가장 최근 수행의 것을 따른다.
    #expect(all[0].displayName == "벤치 프레스")
}

@Test("계열은 오래된 것부터 정렬된다")
func seriesIsSortedOldestFirst() {
    let sessions = repeated("벤치프레스", [(60, 10, .success)], count: 4)

    #expect(series(sessions).points.map(\.performedAt) == [day(3, 1), day(3, 2), day(3, 3), day(3, 4)])
}

@Test("세션이 1건이어도 계열이 깨지지 않는다")
func seriesSurvivesSinglePoint() {
    let result = series([session(day(3, 1), "벤치프레스", [(60, 10, .success)])])

    #expect(result.points.count == 1)
    #expect(result.stagnation == nil)
    #expect(result.overallChange == nil)
}

@Test("중단된 세션도 계열에 포함된다")
func seriesIncludesAbandonedSessions() {
    let sessions = [
        session(day(3, 8), "벤치프레스", [(60, 10, .success), (60, 10, .pending)], state: .abandoned),
        session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    ]

    #expect(series(sessions).points.count == 2)
}

@Test("진행 중인 세션은 계열에서 빠진다")
func seriesExcludesInProgressSessions() {
    let sessions = [
        session(day(3, 8), "벤치프레스", [(60, 10, .success)], state: .inProgress),
        session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    ]

    #expect(series(sessions).points.count == 1)
}

@Test("한 세션에 같은 종목이 두 번 있으면 한 점으로 합쳐진다")
func seriesMergesDuplicateExercisesInOneSession() {
    let workout = session(day(3, 1), "벤치프레스", [(60, 10, .success)])
    let second = SessionExercise(name: "벤치 프레스", order: 1)
    second.session = workout
    let set = SessionSet(order: 0, targetWeight: 60, targetReps: 5)
    set.exercise = second
    set.markSuccess()
    second.sets = [set]
    workout.exercises?.append(second)

    let expected: Double = 600 + 300
    let result = series([workout])
    #expect(result.points.count == 1)
    #expect(result.points[0].volume == expected)
}

@Test("종목 목록은 최근 수행순이다")
func allSeriesIsOrderedByMostRecent() {
    let sessions = [
        session(day(3, 9), "스쿼트", [(80, 5, .success)]),
        session(day(3, 5), "벤치프레스", [(60, 10, .success)]),
        session(day(3, 1), "데드리프트", [(100, 5, .success)])
    ]

    #expect(ExerciseHistory.allSeries(in: sessions).map(\.displayName) == ["스쿼트", "벤치프레스", "데드리프트"])
}

@Test("수행한 적 없는 종목은 계열이 없다")
func seriesIsNilForUnknownExercise() {
    let sessions = [session(day(3, 1), "벤치프레스", [(60, 10, .success)])]

    #expect(ExerciseHistory.series(for: "스쿼트", in: sessions) == nil)
    #expect(ExerciseHistory.series(for: "", in: sessions) == nil)
}

// MARK: - 정체 판정

@Test("6회 미만이면 정체를 판정하지 않는다")
func stagnationNeedsSixSessions() {
    let five = repeated("벤치프레스", [(60, 10, .success)], count: 5)
    #expect(series(five).stagnation == nil)

    let six = repeated("벤치프레스", [(60, 10, .success)], count: 6)
    #expect(series(six).stagnation != nil)
}

@Test("최근 3회가 직전 3회보다 크면 정체가 아니다")
func stagnationIsFalseWhenRecentIsHigher() {
    let older = (0..<3).map { session(day(3, 1 + $0), "벤치프레스", [(60, 10, .success)]) }
    let newer = (0..<3).map { session(day(3, 4 + $0), "벤치프레스", [(60, 10, .success), (60, 10, .success)]) }

    let result = series((older + newer).reversed())
    let stagnation = result.stagnation!
    #expect(stagnation.previous == 600)
    #expect(stagnation.recent == 1_200)
    #expect(stagnation.isStagnant == false)
    #expect(stagnation.changeRate == 1.0)
}

@Test("최근 3회가 직전 3회와 같으면 정체다")
func stagnationIsTrueWhenFlat() {
    // 스컬크러셔 사례 — 무게를 올리고 횟수를 줄여 볼륨이 제자리다.
    let older = (0..<3).map { session(day(3, 1 + $0), "스컬크러셔", [(10, 20, .success)]) }
    let newer = (0..<3).map { session(day(3, 4 + $0), "스컬크러셔", [(20, 10, .success)]) }

    let stagnation = series((older + newer).reversed(), "스컬크러셔").stagnation!
    #expect(stagnation.isStagnant)
    #expect(stagnation.changeRate == 0)
}

@Test("전체 변화율은 초기 3회와 최근 3회를 견준다")
func overallChangeComparesFirstAndLastWindow() {
    // 덤벨 숄더 프레스 — 5kg/3s/15r 로 시작해 8kg/4s/10r 로 끝난 실제 궤적(계획 10).
    let plan: [(weight: Double, sets: Int, reps: Int)] = [
        (5, 3, 15), (5, 3, 15), (5, 3, 15), (6, 4, 10), (7, 4, 12), (8, 4, 10)
    ]
    let sessions = plan.enumerated().map { index, spec in
        session(
            day(3, 1 + index),
            "덤벨숄더프레스",
            Array(repeating: (spec.weight, spec.reps, SetResult.success), count: spec.sets)
        )
    }.reversed()

    let recentAverage: Double = (240 + 336 + 320) / 3
    let overall = series(Array(sessions), "덤벨숄더프레스").overallChange!
    #expect(overall.previous == 225)
    #expect(overall.recent == recentAverage)
    #expect(overall.isStagnant == false)
}

// MARK: - 성공률

@Test("성공률은 건너뛴 세트를 분모에서 뺀다")
func successRateExcludesSkippedSets() {
    let result = series([
        session(day(3, 1), "벤치프레스", [
            (60, 10, .success), (60, 10, .success), (60, 10, .failure), (60, 10, .skipped)
        ])
    ])

    let expected: Double = 2.0 / 3.0
    #expect(result.successRate == expected)
}

// MARK: - 지표 선택

@Test("보조 기구 종목은 그리지 않는다")
func assistedExerciseIsNotChartable() {
    let sessions = repeated("어시스트 풀업 (보조)", [(65, 10, .success)], count: 6)
    let result = series(sessions, "어시스트 풀업 (보조)")

    #expect(result.metric == .assisted)
    #expect(result.isChartable == false)
    // 방향이 뒤집혀 있으므로 정체 판정도 하지 않는다.
    #expect(result.stagnation == nil)
}

@Test("맨몸 종목은 볼륨 대신 총 횟수로 읽는다")
func bodyweightExerciseUsesRepsAsMetric() {
    // 무게가 0 이라 볼륨도 0 이다. 평평한 0 선은 "진전 없음"과 구분되지 않는다.
    let sessions = [
        session(day(3, 8), "풀업", [(0, 12, .success), (0, 12, .success)]),
        session(day(3, 1), "풀업", [(0, 10, .success)])
    ]

    let expected: [Double] = [10, 24]
    let result = series(sessions, "풀업")
    #expect(result.metric == .reps)
    #expect(result.values == expected)
    #expect(result.isChartable)
}

@Test("무게를 다룬 종목은 볼륨을 지표로 쓴다")
func weightedExerciseUsesVolumeAsMetric() {
    #expect(series([session(day(3, 1), "벤치프레스", [(60, 10, .success)])]).metric == .volume)
}
