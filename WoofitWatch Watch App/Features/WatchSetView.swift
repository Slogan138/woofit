import SwiftUI
import WoofitCore

/// W3 · 워치 세트 실행. 화면이 작으므로 현재 세트 하나만 크게 보여주고
/// 성공·실패 두 버튼과 직전 기록 한 줄로 압축한다(F-3, F-9).
struct WatchSetView: View {
    let runner: SessionRunner
    let onEnd: () -> Void

    @State private var pendingFailureSet: SessionSet?
    @State private var isConfirmingAbandon = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let set = runner.focusedSet, let exercise = set.exercise {
                    Text(exercise.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("\(set.order + 1)세트")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                        .font(.title3.monospacedDigit())

                    if let record = runner.focusedLastRecord {
                        Text(record.compactSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Button("실패") { pendingFailureSet = set }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Button("성공") { runner.recordSuccess(for: set) }
                            .buttonStyle(.borderedProminent)
                    }

                    Text("\(runner.session.recordedSetCount)/\(runner.session.totalSetCount) 세트")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("모든 세트를 기록했습니다")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("완료") {
                        runner.finish()
                        onEnd()
                    }
                    .buttonStyle(.borderedProminent)
                }

                // 워치는 세트 목록을 전부 보여줄 수 없어 방금 기록한 세트 하나만 되돌릴 수 있게 한다.
                // 워치는 실수 탭이 잦아 되돌리기 경로가 반드시 있어야 한다(F-3).
                if let last = runner.lastRecordedSet {
                    Button("\(last.order + 1)세트 되돌리기") { runner.undo(last) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(runner.session.routineName)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("중단", role: .destructive) { isConfirmingAbandon = true }
            }
        }
        .sheet(item: $pendingFailureSet) { set in
            WatchFailureInputView(set: set) { actualReps, actualWeight in
                runner.recordFailure(for: set, actualReps: actualReps, actualWeight: actualWeight)
            }
        }
        .confirmationDialog(
            "세션을 중단할까요?",
            isPresented: $isConfirmingAbandon,
            titleVisibility: .visible
        ) {
            Button("중단", role: .destructive) {
                runner.abandon()
                onEnd()
            }
            Button("계속하기", role: .cancel) {}
        }
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴")
    container.mainContext.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 40, reps: 10)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)
    let runner = SessionRunner(session: session)

    return NavigationStack {
        WatchSetView(runner: runner, onEnd: {})
    }
    .modelContainer(container)
}
