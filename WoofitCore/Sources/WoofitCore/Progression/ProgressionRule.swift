import Foundation

/// 직전 기록 → 다음 무게 제안(F-11). 순수 함수다.
///
/// 규칙은 **5개월치 실제 기록에서 나왔다**(PRD D12, 계획 11). 요약하면 셋이다.
/// ① 전 세트 성공일 때만 올린다 — 올린 24회 중 22회가 직전 성공이었다.
/// ② 폭은 기록에서 배운다 — 고정 2.5kg 는 31회 중 한 번 쓰였을 뿐이다.
/// ③ 감량은 제안하지 않는다 — 내린 7회 중 5회가 직전 성공이라 근거가 없다.
public enum ProgressionRule {

    /// 올려본 적이 없는 종목의 기본 단위. **관측 비율 중앙값(20%)을 쓰지 않는다** —
    /// 저중량 종목의 큰 비율이 끌어올린 값이라 과대 제안이 된다. 과대 제안은 실패를
    /// 부르고, 실패가 반복되면 기능을 끄게 된다. 모자란 쪽으로 틀리는 편이 낫다(D12).
    public static func defaultStep(forWeight weight: Double) -> Double {
        switch weight {
        case ..<10: 1
        case ..<30: 2.5
        default: 5
        }
    }

    /// 종목 하나의 제안. 근거가 없으면 `nil`.
    ///
    /// 맨몸(`무게 0`)과 보조 기구 종목은 제안하지 않는다 — 전자는 올릴 무게가 없고,
    /// 후자는 보조 중량이 줄수록 향상이라 방향이 뒤집힌다(F-10 과 같은 이유).
    public static func suggest(
        for normalizedName: String,
        in sessions: [WorkoutSession]
    ) -> WeightSuggestion? {
        guard let series = ExerciseHistory.series(for: normalizedName, in: sessions),
              series.metric == .volume,
              let last = series.points.last,
              last.topWeight > 0
        else { return nil }

        let current = last.topWeight
        let make = { (weight: Double, basis: WeightSuggestion.Basis) in
            WeightSuggestion(
                normalizedName: series.normalizedName,
                displayName: series.displayName,
                currentWeight: current,
                suggestedWeight: weight,
                basis: basis
            )
        }

        guard succeededAllSets(of: normalizedName, inSessionWith: last.sessionID, among: sessions) else {
            return make(current, .hold)
        }

        // ① 과거에 실제로 써본 다음 무게.
        let heavier = series.points.map(\.topWeight).filter { $0 > current }
        if let next = heavier.min() {
            return make(next, .knownNextWeight)
        }
        // ② 그 종목의 관측 증량 폭.
        if let step = observedIncrement(in: series) {
            return make(current + step, .observedIncrement(step))
        }
        // ③ 무게대별 기본 단위.
        let step = defaultStep(forWeight: current)
        return make(current + step, .defaultStep(step))
    }

    /// 모든 종목의 제안. 최근 수행순이다 — 목록 화면이 이 순서를 그대로 쓴다.
    public static func suggestAll(in sessions: [WorkoutSession]) -> [WeightSuggestion] {
        ExerciseHistory.allSeries(in: sessions)
            .compactMap { suggest(for: $0.normalizedName, in: sessions) }
    }

    /// 관측된 증량 폭 중 **최빈값**. 동률이면 작은 쪽을 고른다 — 과대 제안을 피한다.
    private static func observedIncrement(in series: ExerciseSeries) -> Double? {
        let weights = series.points.map(\.topWeight)
        var counts: [Double: Int] = [:]
        for (previous, current) in zip(weights, weights.dropFirst()) where current > previous {
            counts[current - previous, default: 0] += 1
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first?.key
    }

    /// 그 세션에서 이 종목의 세트가 **전부 성공**이었나.
    ///
    /// 건너뛴 세트와 미수행 세트가 있으면 성공으로 치지 않는다 — 수행하지 않은 것을
    /// 증량의 근거로 삼을 수 없다(계획 11).
    private static func succeededAllSets(
        of normalizedName: String,
        inSessionWith sessionID: UUID,
        among sessions: [WorkoutSession]
    ) -> Bool {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return false }
        let sets = session.sortedExercises
            .filter { $0.normalizedName == normalizedName }
            .flatMap(\.sortedSets)
        return !sets.isEmpty && sets.allSatisfy { $0.result == .success }
    }
}
