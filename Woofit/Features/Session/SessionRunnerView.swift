import SwiftUI
import WoofitCore

/// P4 · 세션 실행. 현재 세트를 강조하고 성공은 1탭, 실패는 실제 횟수 입력을 강제한다(F-3).
struct SessionRunnerView: View {
    let runner: SessionRunner
    let onEnd: () -> Void

    @State private var pendingFailureSet: SessionSet?
    @State private var isConfirmingAbandon = false
    @State private var isShowingExercisePicker = false
    @State private var pendingExport: MarkdownExport?

    private var isShowingFullScreenOverlay: Bool {
        if runner.isPaused { return true }
        if case .recording = runner.phase { return false }
        return true
    }

    var body: some View {
        List {
            Section {
                ProgressRow(runner: runner)
                if let resting = runner.restingSet, let startedAt = resting.restStartedAt {
                    RestTimerView(startedAt: startedAt)
                }
                Button("다른 종목으로 이동") { isShowingExercisePicker = true }
            }

            ForEach(runner.session.sortedExercises) { exercise in
                Section {
                    if let record = runner.lastRecords[exercise.normalizedName] {
                        Text(record.summary())
                            .font(Typography.secondary)
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
                            if set.result == .pending {
                                runner.focus(on: set)
                            } else {
                                runner.toggleRest()
                            }
                        }
                    }
                } header: {
                    Text(exercise.name)
                }
            }
        }
        // 세트 행·버튼 자체의 제스처가 더 안쪽이라 우선하므로, 여기 닿는 탭은
        // 버튼도 세트 포커스도 아닌 "그 밖의 화면 전체"뿐이다(F-5 수용 기준).
        .onTapGesture { runner.toggleRest() }
        // 일시정지·전환·완료 오버레이는 화면만 가릴 뿐 탭 자체는 막지 않으므로,
        // VoiceOver 등 접근성 조작으로 뒤에서 기록되는 걸 막기 위해 직접 비활성화한다.
        .disabled(isShowingFullScreenOverlay)
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
                } else if runner.phase != .finished {
                    // 완료되면 전환 대신 SessionCompleteView 가 자동으로 뜨므로
                    // 별도 완료 버튼을 두지 않는다(F-4).
                    Button("일시정지") { runner.pause() }
                }
            }
        }
        .overlay {
            if runner.isPaused {
                PausedOverlay(onResume: { runner.resume() })
            } else if case .transition(let from, let to) = runner.phase {
                NextExerciseView(
                    from: from,
                    to: to,
                    lastRecordedSet: runner.lastRecordedSet,
                    onStart: {
                        if let next = to.nextPendingSet {
                            runner.focus(on: next)
                        }
                    },
                    onUndoLast: {
                        if let last = runner.lastRecordedSet {
                            runner.undo(last)
                        }
                    },
                    onPickAnother: { isShowingExercisePicker = true }
                )
            } else if runner.phase == .finished {
                SessionCompleteView(
                    session: runner.session,
                    onViewMarkdown: {
                        pendingExport = MarkdownExport(
                            title: "세션 마크다운",
                            markdown: SessionMarkdownExporter.export(runner.session)
                        )
                    },
                    onClose: onEnd
                )
            }
        }
        .sheet(item: $pendingFailureSet) { set in
            FailureInputSheet(set: set) { actualReps, actualWeight in
                runner.recordFailure(for: set, actualReps: actualReps, actualWeight: actualWeight)
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            ExercisePickerSheet(
                session: runner.session,
                focusedExerciseID: runner.focusedSet?.exercise?.id,
                onSelect: { exercise in
                    if let next = exercise.nextPendingSet {
                        runner.focus(on: next)
                    }
                }
            )
        }
        .sheet(item: $pendingExport) { export in
            MarkdownPreviewView(title: export.title, markdown: export.markdown)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(
                value: Double(runner.session.recordedSetCount),
                total: Double(max(runner.session.totalSetCount, 1))
            )
            HStack {
                Text("\(runner.session.completedExerciseCount)/\(runner.session.totalExerciseCount) 종목")
                Spacer()
                Text("\(runner.session.recordedSetCount)/\(runner.session.totalSetCount) 세트")
            }
            .font(Typography.secondary)
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
                    .font(isFocused ? Typography.itemName : .body)
                Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch set.result {
            case .pending:
                if isFocused {
                    HStack(spacing: 8) {
                        Button("실패", action: onFailure)
                            .buttonStyle(.bordered)
                            .tint(SetResult.failure.tintColor)
                        Button("성공", action: onSuccess)
                            .buttonStyle(.borderedProminent)
                    }
                    // 땀 손으로 가장 자주 누르는 버튼이라 최소 터치 영역을 키운다(디자인 토큰 계획 ⑤).
                    .controlSize(.large)
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
                    .foregroundStyle(set.result.tintColor)
                if set.result == .failure {
                    Text("\(set.performedReps)회")
                }
                Image(systemName: "arrow.uturn.backward")
                    .font(Typography.secondary)
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
                    .font(Typography.screenTitle)
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
