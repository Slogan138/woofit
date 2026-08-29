import SwiftUI
import WoofitCore

/// F-4 종목 이동 시트. 기구가 사용 중일 때 순서를 무시하고 아직 안 끝난
/// 다른 종목으로 바로 옮겨갈 수 있다. 이미 끝난 종목은 기록할 세트가 없으므로 막는다.
struct ExercisePickerSheet: View {
    let session: WorkoutSession
    let focusedExerciseID: SessionExercise.ID?
    let onSelect: (SessionExercise) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.sortedExercises) { exercise in
                    ExercisePickerRow(
                        exercise: exercise,
                        isFocused: exercise.id == focusedExerciseID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !exercise.isComplete else { return }
                        onSelect(exercise)
                        dismiss()
                    }
                }
            }
            .navigationTitle("종목 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct ExercisePickerRow: View {
    let exercise: SessionExercise
    let isFocused: Bool

    private var recordedCount: Int {
        exercise.sortedSets.filter { $0.result.isRecorded }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(exercise.isComplete ? .secondary : .primary)
                Text("\(recordedCount)/\(exercise.sortedSets.count) 세트")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFocused {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            } else if exercise.isComplete {
                Text("완료")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴", category: "가슴")
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 3, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "펙덱플라이")
    fly.appendSets(count: 3, weight: 40, reps: 10)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)

    return ExercisePickerSheet(
        session: session,
        focusedExerciseID: session.sortedExercises.first?.id,
        onSelect: { _ in }
    )
}
