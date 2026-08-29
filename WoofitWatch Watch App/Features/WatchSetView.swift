import SwiftUI
import WoofitCore

/// W3 · 워치 세트 실행. 화면이 작으므로 현재 세트 하나만 크게 보여주고
/// 성공·실패 두 버튼과 직전 기록 한 줄로 압축한다(F-3, F-9).
struct WatchSetView: View {
    let runner: SessionRunner
    let onEnd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @State private var pendingFailureSet: SessionSet?
    @State private var isConfirmingAbandon = false

    var body: some View {
        Group {
            switch runner.phase {
            case .recording(let exercise):
                recordingContent(for: exercise)
            case .transition(let from, let to):
                WatchNextExerciseView(
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
                    }
                )
            case .finished:
                finishedContent
            }
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
                finishSession()
                onEnd()
            }
            Button("계속하기", role: .cancel) {}
        }
        // 기록마다 즉시 큐에 넣는다 — 전송을 기다리게 하면 F-3 100ms 수용 기준이 깨진다(F-8).
        .onChange(of: runner.lastRecordedSet) { _, set in
            guard let set, let payload = SetResultPayload.make(for: set) else { return }
            try? syncService?.sendSetResult(payload)
        }
        // 마지막 세트를 기록하면 SessionRunner 가 세션을 자동으로 완료 처리한다(F-4).
        .onChange(of: runner.phase) { _, phase in
            guard case .finished = phase else { return }
            finishSession()
        }
    }

    /// 세션 종료 스냅샷을 보내 세트별 전송 유실을 복구하고, 워치 저장소를 정리한다(F-8).
    private func finishSession() {
        try? syncService?.sendSessionSnapshot(SessionSnapshotPayload.make(for: runner.session))
        try? WatchRetention.prune(in: modelContext)
    }

    @ViewBuilder
    private func recordingContent(for exercise: SessionExercise) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                if let set = runner.focusedSet {
                    Text(exercise.name)
                        .font(Typography.itemName)
                        .multilineTextAlignment(.center)
                    Text("\(set.order + 1)세트")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                    Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                        .font(Typography.value)
                        .monospacedDigit()

                    if let record = runner.focusedLastRecord {
                        Text(record.compactSummary)
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }

                    if let resting = runner.restingSet, let startedAt = resting.restStartedAt {
                        WatchRestView(startedAt: startedAt)
                    }

                    HStack(spacing: 6) {
                        Button("실패") { pendingFailureSet = set }
                            .buttonStyle(.bordered)
                            .tint(SetResult.failure.tintColor)
                        Button("성공") { runner.recordSuccess(for: set) }
                            .buttonStyle(.borderedProminent)
                    }
                    // 땀 손으로 가장 자주 누르는 버튼이라 최소 터치 영역을 키운다(디자인 토큰 계획 ⑤).
                    .controlSize(.large)

                    Text("\(runner.session.completedExerciseCount)/\(runner.session.totalExerciseCount) 종목 · \(runner.session.recordedSetCount)/\(runner.session.totalSetCount) 세트")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }

                // 워치는 세트 목록을 전부 보여줄 수 없어 방금 기록한 세트 하나만 되돌릴 수 있게 한다.
                // 워치는 실수 탭이 잦아 되돌리기 경로가 반드시 있어야 한다(F-3).
                if let last = runner.lastRecordedSet {
                    Button("\(last.order + 1)세트 되돌리기") { runner.undo(last) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(Typography.secondary)
                }
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            // 버튼·되돌리기 링크의 제스처가 더 안쪽이라 우선하므로, 여기 닿는 탭은
            // 그 밖의 화면 전체를 뜻한다(F-5 수용 기준). 배터리 때문에 Timer 대신
            // WatchRestView 가 TimelineView 로 표시만 갱신한다.
            .onTapGesture { runner.toggleRest() }
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 10) {
            Text("모든 세트를 기록했습니다")
                .font(Typography.itemName)
                .multilineTextAlignment(.center)
            // phase 가 finished 로 바뀌는 순간 SessionRunner 가 이미 세션을 완료 처리했으므로
            // 여기서는 화면만 닫는다(F-4).
            Button("완료", action: onEnd)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 2)
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
