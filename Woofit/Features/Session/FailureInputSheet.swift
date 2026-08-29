import SwiftUI
import WoofitCore

/// 실패 기록 시트. 실제 횟수 입력이 필수이고 취소할 수 있다(D1).
/// 취소하거나 스와이프로 내리면 `onRecord` 를 호출하지 않으므로 세트는 `pending` 으로 남는다.
struct FailureInputSheet: View {
    let set: SessionSet
    let onRecord: (_ actualReps: Int, _ actualWeight: Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actualReps: Int
    @State private var actualWeight: Double

    init(set: SessionSet, onRecord: @escaping (Int, Double?) -> Void) {
        self.set = set
        self.onRecord = onRecord
        // 대부분 한두 개 모자라므로 목표보다 1 적은 값을 기본으로 둔다.
        _actualReps = State(initialValue: max(0, set.targetReps - 1))
        _actualWeight = State(initialValue: set.targetWeight)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("실제 횟수") {
                    Stepper(value: $actualReps, in: 0...max(set.targetReps, actualReps)) {
                        Text("\(actualReps)회")
                            .font(.title2.monospacedDigit())
                    }
                }
                Section("무게") {
                    Stepper(value: $actualWeight, in: 0...max(set.targetWeight, actualWeight), step: 2.5) {
                        Text(WeightFormatter.string(actualWeight))
                            .font(.title2.monospacedDigit())
                    }
                }
            }
            .navigationTitle("\(set.order + 1)세트 실패")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("기록") {
                        let weight = actualWeight == set.targetWeight ? nil : actualWeight
                        onRecord(actualReps, weight)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let set = SessionSet(order: 0, targetWeight: 80, targetReps: 5)
    return FailureInputSheet(set: set, onRecord: { _, _ in })
}
