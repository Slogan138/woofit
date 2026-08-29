import SwiftUI
import WoofitCore

/// 종목 하나의 편집 행. 이름·직전 기록·세트 목록·순서 이동을 담당한다.
///
/// 순서 변경은 드래그 대신 위/아래 버튼으로 둔다 — 편집기는 F-7 의 대안 경로일 뿐이라
/// 과하게 투자하지 않는다(06-F01 계획 "주의점").
struct ExerciseEditorRow: View {
    @Bindable var exercise: PlannedExercise
    let lastRecord: LastRecord?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @State private var newSetCount = 1
    @State private var draftWeight: Double
    @State private var draftReps: Int

    /// 무게·횟수는 한 번만 입력해 여러 세트에 동일하게 적용한다 — 5세트를 만들 때마다
    /// 매번 입력하는 번거로움을 없애기 위함이다. 기존 세트가 있으면 그 값을 이어받아
    /// 시작하고, 없으면 0에서 시작한다. 만든 뒤에는 세트별로 각각 고쳐 피라미드로 바꿀 수 있다.
    init(
        exercise: PlannedExercise,
        lastRecord: LastRecord?,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.lastRecord = lastRecord
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onDelete = onDelete
        let uniform = exercise.uniformTarget ?? exercise.sortedSets.last.map { ($0.targetWeight, $0.targetReps) }
        _draftWeight = State(initialValue: uniform?.weight ?? 0)
        _draftReps = State(initialValue: uniform?.reps ?? 0)
    }

    /// `name` 에 직접 대입하면 `normalizedName` 이 갱신되지 않아 직전 기록이 조용히
    /// 끊기므로 `rename(to:)` 를 거치는 바인딩을 쓴다.
    private var nameBinding: Binding<String> {
        Binding(get: { exercise.name }, set: { exercise.rename(to: $0) })
    }

    var body: some View {
        Section {
            TextField("종목명", text: nameBinding)
                .font(.headline)

            if let lastRecord {
                LabeledContent("직전 기록", value: lastRecord.summary())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(exercise.sortedSets) { set in
                PlannedSetRow(set: set)
            }
            .onDelete(perform: deleteSets)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("무게", value: $draftWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                    Text("kg ×")
                        .foregroundStyle(.secondary)
                    TextField("횟수", value: $draftReps, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 40)
                    Text("회 —")
                        .foregroundStyle(.secondary)
                    Stepper("\(newSetCount)세트", value: $newSetCount, in: 1...10)
                }
                Button("추가", action: addSets)
            }
        } header: {
            HStack {
                Text(exercise.name.isEmpty ? "이름 없는 종목" : exercise.name)
                Spacer()
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        var sets = exercise.sortedSets
        sets.remove(atOffsets: offsets)
        exercise.sets = sets
        exercise.reindexSets()
    }

    private func addSets() {
        exercise.appendSets(count: newSetCount, weight: draftWeight, reps: draftReps)
    }
}

private struct PlannedSetRow: View {
    @Bindable var set: PlannedSet

    var body: some View {
        HStack {
            Text("\(set.order + 1)")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField("무게", value: $set.targetWeight, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 60)
            Text("kg ×")
                .foregroundStyle(.secondary)
            TextField("횟수", value: $set.targetReps, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 40)
            Text("회")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let exercise = PlannedExercise(name: "벤치프레스")
    exercise.appendSets(count: 3, weight: 80, reps: 5)

    return Form {
        ExerciseEditorRow(
            exercise: exercise,
            lastRecord: nil,
            canMoveUp: false,
            canMoveDown: true,
            onMoveUp: {},
            onMoveDown: {},
            onDelete: {}
        )
    }
}
