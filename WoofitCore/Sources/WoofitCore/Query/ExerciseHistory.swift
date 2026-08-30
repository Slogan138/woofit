import Foundation

// MARK: - 세션 하나의 값

/// 종목 하나가 세션 하나에서 쌓은 값(F-10).
///
/// **수행값으로 계산한다.** 목표 무게·횟수가 아니라 실제로 든 값이다.
/// 실패 세트에 `actualReps` 가 반드시 있다는 불변식(PRD D1)이 여기서 값을 한다.
public struct ExerciseVolume: Identifiable, Hashable, Sendable {
    /// 한 세션에 같은 종목이 두 번 들어 있어도 점은 하나다.
    public let sessionID: UUID
    public let performedAt: Date
    /// 볼륨에 반영된 세트 수. 건너뛴 세트와 미수행 세트는 빠진다.
    public let setCount: Int
    public let totalReps: Int
    /// `무게 × 횟수` 의 세트 합.
    public let volume: Double
    public let topWeight: Double
    public let successCount: Int
    public let failureCount: Int

    public var id: UUID { sessionID }

    public init(
        sessionID: UUID,
        performedAt: Date,
        setCount: Int,
        totalReps: Int,
        volume: Double,
        topWeight: Double,
        successCount: Int,
        failureCount: Int
    ) {
        self.sessionID = sessionID
        self.performedAt = performedAt
        self.setCount = setCount
        self.totalReps = totalReps
        self.volume = volume
        self.topWeight = topWeight
        self.successCount = successCount
        self.failureCount = failureCount
    }
}

// MARK: - 두 구간 비교

/// 두 구간의 평균을 견준 결과. 정체 판정과 전체 변화율이 같은 모양을 쓴다.
public struct TrendComparison: Hashable, Sendable {
    public let previous: Double
    public let recent: Double

    public init(previous: Double, recent: Double) {
        self.previous = previous
        self.recent = recent
    }

    /// 늘지 않았으면 정체다. 무게 미갱신으로 정의하면 암풀 다운이 22회 연속 정체로 잡혀
    /// 5개월 내내 빨간불이 된다 — 신호가 되지 않는다(PRD D10).
    public var isStagnant: Bool { recent <= previous }

    /// 이전 구간 대비 증감 비율. 이전이 0 이면 비율이 성립하지 않는다.
    public var changeRate: Double? {
        guard previous > 0 else { return nil }
        return (recent - previous) / previous
    }
}

// MARK: - 계열

/// 계열을 무엇으로 읽을 것인가.
public enum TrendMetric: String, Hashable, Sendable {
    /// 주 지표. `무게 × 횟수` 의 합(PRD D10).
    case volume
    /// 맨몸 종목. 무게가 0 이라 볼륨도 0 이고, 평평한 0 선은 "진전 없음"과 구분되지 않는다.
    /// 진전이 횟수에만 남으므로 총 횟수로 읽는다.
    case reps
    /// 보조 기구 종목. 보조 중량은 **줄수록** 향상이라 볼륨 공식의 방향이 뒤집힌다.
    /// 이번 범위에서는 그리지 않는다(계획 10).
    case assisted
}

/// 종목 하나의 시간순 계열(F-10).
public struct ExerciseSeries: Identifiable, Hashable, Sendable {
    public let normalizedName: String
    public let displayName: String
    public let metric: TrendMetric
    /// **오래된 것부터.** 차트 X 축 순서이자 정체 판정의 전제다.
    public let points: [ExerciseVolume]

    public var id: String { normalizedName }

    public init(
        normalizedName: String,
        displayName: String,
        metric: TrendMetric,
        points: [ExerciseVolume]
    ) {
        self.normalizedName = normalizedName
        self.displayName = displayName
        self.metric = metric
        self.points = points
    }
}

public extension ExerciseSeries {
    var lastPerformedAt: Date? { points.last?.performedAt }
    var sessionCount: Int { points.count }

    /// 보조 기구 종목은 그래프 대신 안내 문구를 보여준다.
    var isChartable: Bool { metric != .assisted }

    /// 이 계열의 주 지표 값.
    func value(of point: ExerciseVolume) -> Double {
        switch metric {
        case .volume, .assisted: point.volume
        case .reps: Double(point.totalReps)
        }
    }

    var values: [Double] { points.map(value(of:)) }

    /// 최근 `comparisonWindow` 회 평균 대 그 직전 같은 수의 평균.
    /// 두 구간을 채우지 못하면(6회 미만) 판정하지 않는다 — 두 점으로 추세를 말할 수 없다.
    var stagnation: TrendComparison? {
        comparison(previousStart: points.count - ExerciseHistory.comparisonWindow * 2)
    }

    /// 초기 구간 대 최근 구간. "이 종목이 그동안 얼마나 늘었나" 한 줄에 쓴다.
    var overallChange: TrendComparison? {
        comparison(previousStart: 0)
    }

    /// 성공률. 그래프로 그리지 않고 숫자 한 줄로만 보여준다(PRD D10).
    /// 건너뛴 세트는 성공도 실패도 아니므로 분모에서 뺀다.
    var successRate: Double? {
        let success = points.reduce(0) { $0 + $1.successCount }
        let failure = points.reduce(0) { $0 + $1.failureCount }
        guard success + failure > 0 else { return nil }
        return Double(success) / Double(success + failure)
    }

    /// `previousStart` 에서 시작하는 구간과 마지막 구간을 견준다.
    /// 방향이 뒤집힌 보조 기구 종목은 판정하지 않는다.
    private func comparison(previousStart: Int) -> TrendComparison? {
        let window = ExerciseHistory.comparisonWindow
        guard isChartable, points.count >= window * 2, previousStart >= 0 else { return nil }

        let all = values
        let previous = all[previousStart..<(previousStart + window)]
        let recent = all[(all.count - window)...]
        return TrendComparison(
            previous: previous.reduce(0, +) / Double(window),
            recent: recent.reduce(0, +) / Double(window)
        )
    }
}

// MARK: - 집계

/// 종목별 추이 집계(F-10, PRD D10).
///
/// 입력을 `[WorkoutSession]` 으로 받는 것은 호출부가 이미 `@Query` 로 세션을 들고 있어서다.
/// `SessionHistoryGrouping` 과 같은 자리에 있는 순수 함수이므로 시뮬레이터 없이 검증된다.
public enum ExerciseHistory {

    /// 정체·변화율을 판단할 때 한 구간에 넣는 세션 수.
    /// 종목당 주 1회꼴이라 3회는 약 3주다 — 하루 컨디션 난조로 정체가 뜨지 않을 만큼은 길고,
    /// 5개월치에서 구간이 두 개 나올 만큼은 짧다(계획 10).
    public static let comparisonWindow = 3

    /// 종목 하나의 계열. 그 종목을 수행한 세션이 없으면 `nil`.
    public static func series(
        for normalizedName: String,
        in sessions: [WorkoutSession]
    ) -> ExerciseSeries? {
        guard !normalizedName.isEmpty else { return nil }
        return allSeries(in: sessions).first { $0.normalizedName == normalizedName }
    }

    /// 수행한 모든 종목의 계열. **최근 수행순**이다 — 목록 화면이 이 순서를 그대로 쓴다.
    ///
    /// 진행 중인 세션은 아직 결과가 아니므로 뺀다(F-9 와 같은 규칙).
    /// **중단한 세션은 넣는다** — 기록된 세트는 실제로 수행한 것이다.
    public static func allSeries(in sessions: [WorkoutSession]) -> [ExerciseSeries] {
        var pointsByName: [String: [ExerciseVolume]] = [:]
        /// 표시 이름은 가장 최근 수행의 표기를 따른다. 정규화 키는 같아도 표기는 달라질 수 있다.
        var latestNames: [String: (performedAt: Date, name: String)] = [:]

        for session in sessions where session.state.isFinished {
            var byName: [String: [SessionExercise]] = [:]
            for exercise in session.sortedExercises where !exercise.normalizedName.isEmpty {
                byName[exercise.normalizedName, default: []].append(exercise)
            }

            for (name, exercises) in byName {
                guard let point = volume(of: exercises, in: session) else { continue }
                pointsByName[name, default: []].append(point)

                let known = latestNames[name]
                if known == nil || known!.performedAt < session.startedAt {
                    latestNames[name] = (session.startedAt, exercises[0].name)
                }
            }
        }

        return pointsByName.map { name, unsorted in
            let displayName = latestNames[name]?.name ?? name
            let points = unsorted.sorted { $0.performedAt < $1.performedAt }
            return ExerciseSeries(
                normalizedName: name,
                displayName: displayName,
                metric: metric(displayName: displayName, points: points),
                points: points
            )
        }
        // 사전 순회는 순서가 없으므로 이름까지 비교해 목록이 매번 같은 순서로 나오게 한다.
        .sorted { lhs, rhs in
            let left = lhs.lastPerformedAt ?? .distantPast
            let right = rhs.lastPerformedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.displayName < rhs.displayName
        }
    }

    /// 한 세션에서 같은 종목이 두 번 나오면 합쳐 한 점으로 만든다.
    /// 기록된 세트가 하나도 없으면 점을 만들지 않는다 — 계열에 0 이 끼면 정체 판정이 흔들린다.
    private static func volume(
        of exercises: [SessionExercise],
        in session: WorkoutSession
    ) -> ExerciseVolume? {
        var setCount = 0
        var totalReps = 0
        var volume = 0.0
        var topWeight = 0.0
        var successCount = 0
        var failureCount = 0

        for set in exercises.flatMap(\.sortedSets) {
            switch set.result {
            case .success: successCount += 1
            case .failure: failureCount += 1
            // 건너뛴 세트와 미수행 세트는 수행하지 않은 것이므로 볼륨에서 뺀다.
            case .skipped, .pending: continue
            }
            setCount += 1
            totalReps += set.performedReps
            volume += set.performedWeight * Double(set.performedReps)
            topWeight = max(topWeight, set.performedWeight)
        }

        guard setCount > 0 else { return nil }
        return ExerciseVolume(
            sessionID: session.id,
            performedAt: session.startedAt,
            setCount: setCount,
            totalReps: totalReps,
            volume: volume,
            topWeight: topWeight,
            successCount: successCount,
            failureCount: failureCount
        )
    }

    private static func metric(displayName: String, points: [ExerciseVolume]) -> TrendMetric {
        if ExerciseName.isAssisted(displayName) { return .assisted }
        if points.allSatisfy({ $0.topWeight == 0 }) { return .reps }
        return .volume
    }
}
