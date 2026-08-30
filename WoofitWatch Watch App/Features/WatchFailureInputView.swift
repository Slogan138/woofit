import SwiftUI
import WoofitCore

/// 워치의 실패 횟수 입력. Digital Crown 으로 횟수를 돌린다(F-3).
/// "기록"을 눌러야만 `onRecord` 를 호출하므로, 취소하면 세트가 `pending` 으로 남는다(D1).
struct WatchFailureInputView: View {
    let set: SessionSet
    let onRecord: (_ actualReps: Int, _ actualWeight: Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actualReps: Double
    @State private var actualWeight: Double
    @FocusState private var repsFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = Typography.heroMetricSize

    init(set: SessionSet, onRecord: @escaping (Int, Double?) -> Void) {
        self.set = set
        self.onRecord = onRecord
        // 대부분 한두 개 모자라므로 목표보다 1 적은 값을 기본으로 둔다.
        _actualReps = State(initialValue: Double(max(0, set.targetReps - 1)))
        _actualWeight = State(initialValue: set.targetWeight)
    }

    private var repsUpperBound: Double { Double(max(set.targetReps, Int(actualReps)) + 5) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("실제 횟수")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                // Digital Crown 으로 돌리는 이 화면의 유일한 값이라 크게 키운다.
                // 세트 화면의 목표 판독값과 같은 토큰을 쓴다 — 두 화면의 큰 숫자가
                // 서로 다른 크기면 무엇이 주된 값인지가 흐려진다(계획 18).
                Text("\(Int(actualReps))회")
                    .font(Typography.heroMetric(metricSize))
                    .monospacedDigit()
                    .focusable(true)
                    .focused($repsFocused)
                    .digitalCrownRotation(
                        $actualReps,
                        from: 0,
                        through: repsUpperBound,
                        by: 1,
                        sensitivity: .low,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                Stepper(value: $actualWeight, in: 0...max(set.targetWeight, actualWeight), step: 2.5) {
                    Text(WeightFormatter.string(actualWeight))
                        .font(Typography.secondary)
                }

                Button("기록") {
                    let weight = actualWeight == set.targetWeight ? nil : actualWeight
                    onRecord(Int(actualReps), weight)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("취소", role: .cancel) { dismiss() }
                    .buttonStyle(.plain)
                    .font(Typography.secondary)
            }
            .padding(.horizontal, 2)
        }
        .onAppear { repsFocused = true }
    }
}

#Preview {
    let set = SessionSet(order: 0, targetWeight: 40, targetReps: 10)
    return WatchFailureInputView(set: set, onRecord: { _, _ in })
}
