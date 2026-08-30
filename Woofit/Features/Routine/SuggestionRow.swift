import SwiftUI
import WoofitCore

/// 다음 무게 제안 한 줄(F-11). 제안 무게와 **그 근거**를 함께 보여준다 —
/// 근거 없는 숫자는 신뢰받지 못한다(계획 11).
struct SuggestionRow: View {
    let suggestion: WeightSuggestion
    /// 루틴에 지금 적혀 있는 목표 무게. 제안과 비교해 보여준다.
    let plannedWeight: Double
    let onApply: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayName)
                    .font(Typography.itemName)
                HStack(spacing: 4) {
                    Text(WeightFormatter.string(plannedWeight))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(WeightFormatter.string(suggestion.suggestedWeight))
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorRole.accent)
                }
                .font(Typography.value)
                .monospacedDigit()
                Text(suggestion.reason)
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("적용", action: onApply)
                .buttonStyle(.bordered)
                .font(Typography.secondary)
        }
    }
}

/// 제안을 루틴에 반영한다(F-11).
enum SuggestionApplier {

    /// **증감분을 각 세트에 더한다.** 모든 세트를 제안 무게로 덮으면 피라미드 세트가
    /// 평평해진다 — 사용자가 일부러 다르게 잡아둔 값을 지우는 셈이다.
    static func apply(_ suggestion: WeightSuggestion, to exercise: PlannedExercise) {
        let sets = exercise.sortedSets
        guard let top = sets.map(\.targetWeight).max() else { return }
        let delta = suggestion.suggestedWeight - top
        guard delta != 0 else { return }
        for set in sets {
            set.targetWeight = max(0, set.targetWeight + delta)
        }
    }
}
