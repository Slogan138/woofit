import SwiftUI
import WoofitCore

/// P4 · 세션 실행. 현재 세트를 강조하고 성공은 1탭, 실패는 실제 횟수 입력을 강제한다(F-3).
struct SessionRunnerView: View {
    let runner: SessionRunner
    let onEnd: () -> Void

    @State private var pendingFailureSet: SessionSet?
    @State private var isConfirmingAbandon = false

    var body: some View {
        List {
            Section {
                ProgressRow(runner: runner)
            }

            ForEach(runner.session.sortedExercises) { exercise in
                Section {
                    if let record = runner.lastRecords[exercise.normalizedName] {
                        Text(record.summary())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(exercise.sortedSets) { set in
                        SetRow(
                            set: set,
                            isFocused: runner.focusedSet?.id == set.id,
                            onSuccess: { runner.recordSuccess(for: set) },
                            onFailure: { pendingFailureSet = set },
                            onUndo: { runner.undo(set) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if set.result == .pending { runner.focus(on: set) }
                        }
                    }
                } header: {
                    Text(exercise.name)
                }
            }
        }
        // 일시정지 중에는 오버레이가 화면만 가릴 뿐 탭 자체는 막지 않으므로,
        // VoiceOver 등 접근성 조작으로 뒤에서 기록되는 걸 막기 위해 직접 비활성화한다.
        .disabled(runner.isPaused)
        .navigationTitle(runner.session.routineName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("중단", role: .destructive) { isConfirmingAbandon = true }
            }
            ToolbarItem(placement: .primaryAction) {
                if runner.isPaused {
                    Button("재개") { runner.resume() }
                } else if runner.session.isFullyRecorded {
                    Button("완료") {
                        runner.finish()
                        onEnd()
                    }
                } else {
                    Button("일시정지") { runner.pause() }
                }
            }
        }
        .overlay {
            if runner.isPaused {
                PausedOverlay(onResume: { runner.resume() })
            }
        }
        .sheet(item: $pendingFailureSet) { set in
            FailureInputSheet(set: set) { actualReps, actualWeight in
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
        } message: {
            Text("중단해도 지금까지 기록은 남습니다.")
        }
    }
}

private struct ProgressRow: View {
    let runner: SessionRunner

    private var exerciseTotal: Int { runner.session.sortedExercises.count }
    private var exerciseDone: Int {
        runner.session.sortedExercises.count { $0.isComplete }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(
                value: Double(runner.session.recordedSetCount),
                total: Double(max(runner.session.totalSetCount, 1))
            )
            HStack {
                Text("\(exerciseDone)/\(exerciseTotal) 종목")
                Spacer()
                Text("\(runner.session.recordedSetCount)/\(runner.session.totalSetCount) 세트")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SetRow: View {
    let set: SessionSet
    let isFocused: Bool
    let onSuccess: () -> Void
    let onFailure: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(set.order + 1)세트")
                    .font(isFocused ? .headline : .body)
                Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch set.result {
            case .pending:
                if isFocused {
                    HStack(spacing: 8) {
                        Button("실패", action: onFailure)
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Button("성공", action: onSuccess)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("대기").foregroundStyle(.secondary)
                }
            case .success, .failure, .skipped:
                ResultBadge(set: set, onUndo: onUndo)
            }
        }
        .padding(.vertical, isFocused ? 4 : 0)
    }
}

private struct ResultBadge: View {
    let set: SessionSet
    let onUndo: () -> Void

    var body: some View {
        Button(action: onUndo) {
            HStack(spacing: 4) {
                Text(set.result.markdownSymbol)
                if set.result == .failure {
                    Text("\(set.performedReps)회")
                }
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PausedOverlay: View {
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("일시정지됨")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Button("재개", action: onResume)
                    .buttonStyle(.borderedProminent)
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

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)
    let runner = SessionRunner(session: session)

    return NavigationStack {
        SessionRunnerView(runner: runner, onEnd: {})
    }
    .modelContainer(container)
}
