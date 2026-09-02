import SwiftUI
import WoofitCore

/// 기록된 세트 하나를 고친다(F-15).
///
/// **세션 상태는 건드리지 않는다**(PRD D13). 규칙은 `SessionRecordEditor` 에 있고
/// 이 화면은 값을 모아 넘기기만 한다.
struct SetEditSheet: View {
    let set: SessionSet
    let onSave: (SessionRecordEditor.Change) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var result: SetResult
    @State private var reps: Int
    /// 빈 문자열이면 "목표대로 들었다" — 실제 무게를 따로 남기지 않는다.
    @State private var weightText: String

    init(set: SessionSet, onSave: @escaping (SessionRecordEditor.Change) -> Void) {
        self.set = set
        self.onSave = onSave
        let current = SessionRecordEditor.currentChange(of: set)
        switch current {
        case .success(let weight):
            _result = State(initialValue: .success)
            _reps = State(initialValue: set.targetReps)
            _weightText = State(initialValue: weight.map(Self.numberText) ?? "")
        case .failure(let actualReps, let weight):
            _result = State(initialValue: .failure)
            _reps = State(initialValue: actualReps)
            _weightText = State(initialValue: weight.map(Self.numberText) ?? "")
        case .skipped:
            _result = State(initialValue: .skipped)
            _reps = State(initialValue: set.targetReps)
            _weightText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("목표") {
                    Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                        .foregroundStyle(.secondary)
                }

                Section("결과") {
                    Picker("결과", selection: $result) {
                        Text("성공").tag(SetResult.success)
                        Text("실패").tag(SetResult.failure)
                        Text("건너뜀").tag(SetResult.skipped)
                    }
                    .pickerStyle(.segmented)

                    // 실패는 실제 횟수 없이 기록될 수 없다(PRD D1). 화면에서도 같이 강제한다.
                    if result == .failure {
                        Stepper("실제 \(reps)회", value: $reps, in: 0...99)
                            .monospacedDigit()
                    }
                }

                if result != .skipped {
                    Section("실제로 든 무게") {
                        TextField("비우면 목표대로", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text("계획과 다른 무게로 했을 때만 적습니다. 추이와 무게 제안이 이 값을 씁니다.")
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(set.order + 1)세트 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onSave(change)
                        dismiss()
                    }
                }
            }
        }
    }

    private var change: SessionRecordEditor.Change {
        switch result {
        case .failure: .failure(actualReps: reps, actualWeight: weight)
        case .skipped: .skipped
        case .success, .pending: .success(actualWeight: weight)
        }
    }

    /// 입력란에는 단위 없이 숫자만 둔다. `WeightFormatter.string` 은 "40kg" 처럼 단위를 붙여
    /// 그대로 넣으면 사용자가 지우고 다시 써야 한다.
    private static func numberText(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// 빈 칸이거나 숫자가 아니면 `nil` — 목표 무게를 그대로 쓴다는 뜻이다.
    private var weight: Double? {
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }
}
