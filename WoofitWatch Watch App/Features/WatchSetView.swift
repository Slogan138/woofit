import SwiftUI
import WoofitCore

/// W3 · 워치 세트 실행. 화면이 작으므로 현재 세트 하나만 크게 보여주고
/// 성공·실패 두 버튼과 직전 기록 한 줄로 압축한다(F-3, F-9).
///
/// 배치는 판독값 → 버튼 → 진행률 → 되돌리기 순이다. 폰(계획 15)처럼 액션 바를 하단에
/// 고정하지 않는 것은 41mm 에서 고정 바가 화면의 1/3 을 먹기 때문이다 — 워치의 답은
/// 고정이 아니라 순서 재배치이고, 가장 자주 누르는 버튼이 첫 화면 안에 들어오면 된다(계획 18).
struct WatchSetView: View {
    let runner: SessionRunner
    let onEnd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Environment(\.workoutSessionController) private var workoutSessionController
    @State private var pendingFailureSet: SessionSet?
    @State private var isConfirmingAbandon = false
    @State private var recordFeedback = RecordFeedback()
    /// 종료 처리를 한 번으로 묶는다. 아래 `finishSession()` 참고.
    @State private var didFinishSession = false

    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = Typography.heroMetricSize

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
        // 손목에서는 화면을 안 볼 때도 기록됐음을 알아야 한다. 성공·실패를 다른 신호로 준다.
        .sensoryFeedback(trigger: recordFeedback) { _, feedback in
            guard feedback.sequence > 0 else { return nil }
            return feedback.isSuccess ? .success : .warning
        }
        .sheet(item: $pendingFailureSet) { set in
            WatchFailureInputView(set: set) { actualReps, actualWeight in
                recordFailure(for: set, actualReps: actualReps, actualWeight: actualWeight)
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
    /// 완료(`finished` phase)·중단(`abandon`) 두 경로 모두 여기를 거치므로, 운동 세션
    /// 종료(`workoutSessionController.end()`)도 이 한 곳에서만 부르면 빠뜨릴 일이 없다(계획 17).
    private func finishSession() {
        // 완료 경로에서는 `onChange(of: phase)` 와 「완료」 버튼이 둘 다 여기를 거친다.
        // 막지 않으면 세션마다 스냅샷이 두 번 전송된다 — `transferUserInfo` 는 큐에 쌓여
        // 보장 전송되므로 실제로 두 번 나간다. 반대로 「완료」 쪽을 빼면 빈 세션이
        // 깨진다. 빈 세션은 phase 가 변하지 않아 `onChange` 가 터지지 않고, 그때는
        // 「완료」가 유일한 경로다(계획 17).
        guard !didFinishSession else { return }
        didFinishSession = true

        try? syncService?.sendSessionSnapshot(SessionSnapshotPayload.make(for: runner.session))
        try? WatchRetention.prune(in: modelContext)
        Task { await workoutSessionController?.end() }
    }

    private func recordSuccess(for set: SessionSet) {
        runner.recordSuccess(for: set)
        playRecordFeedback(isSuccess: true)
    }

    private func recordFailure(for set: SessionSet, actualReps: Int, actualWeight: Double?) {
        runner.recordFailure(for: set, actualReps: actualReps, actualWeight: actualWeight)
        playRecordFeedback(isSuccess: false)
    }

    /// 기록 햅틱. 단, 이 기록으로 종목이 끝났으면 울리지 않는다.
    /// `WatchNextExerciseView` 가 `onAppear` 에서 `.notification` 을 치는데 여기서 한 번 더
    /// 치면 두 신호가 겹쳐 "종목이 끝났다"는 F-4 의 알림이 뜻을 잃는다(계획 18).
    private func playRecordFeedback(isSuccess: Bool) {
        guard case .recording = runner.phase else { return }
        recordFeedback = RecordFeedback(isSuccess: isSuccess, sequence: recordFeedback.sequence + 1)
    }

    @ViewBuilder
    private func recordingContent(for exercise: SessionExercise) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                if let set = runner.focusedSet {
                    Text(exercise.name)
                        .font(Typography.itemName)
                        .multilineTextAlignment(.center)

                    SetProgressPips(sets: exercise.sortedSets, focusedSetID: set.id)

                    targetReadout(for: set)

                    if let record = runner.focusedLastRecord {
                        lastRecordLine(record, targetWeight: set.targetWeight)
                    }

                    HStack(spacing: 6) {
                        Button("실패") { pendingFailureSet = set }
                            .buttonStyle(.bordered)
                            .tint(SetResult.failure.tintColor)
                        Button("성공") { recordSuccess(for: set) }
                            .buttonStyle(.borderedProminent)
                            // 바를 잡은 손·땀 손이 이 앱의 실제 사용 맥락이라 더블 탭으로도
                            // 기록되게 한다. 애플이 정한 표준 제스처다(원칙 1).
                            .handGestureShortcut(.primaryAction)
                    }
                    // 땀 손으로 가장 자주 누르는 버튼이라 최소 터치 영역을 키운다(디자인 토큰 계획 ⑤).
                    .controlSize(.large)

                    // 휴식 표시가 버튼 아래인 것은, 위에 두면 나타나고 사라질 때마다
                    // 성공·실패 버튼이 손가락 밑에서 움직이기 때문이다.
                    if let resting = runner.restingSet, let startedAt = resting.restStartedAt {
                        WatchRestView(startedAt: startedAt)
                    }

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

    /// 이 화면의 주인공. 목표 무게를 가장 크게 두고 횟수는 그 절반으로 딸려 붙인다 —
    /// 손목을 흘긋 봤을 때 먼저 확인하는 값이 무게다.
    private func targetReadout(for set: SessionSet) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(WeightFormatter.string(set.targetWeight))
                .font(Typography.heroMetric(metricSize))
                .contentTransition(.numericText())
            Text("× \(set.targetReps)")
                .font(Typography.heroMetric(metricSize * 0.5))
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    /// 직전 기록과 오늘 목표의 차이를 한 줄에 붙여 둔다(F-9).
    /// 두 값이 같은 무게(`topWeight`)를 기준으로 삼는 것은 `compactSummary` 쪽에서 보장한다.
    private func lastRecordLine(_ record: LastRecord, targetWeight: Double) -> some View {
        HStack(spacing: 4) {
            Text(record.compactSummary)
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
            if let delta = record.weightDelta(toTarget: targetWeight) {
                DeltaBadge(delta: delta)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var finishedContent: some View {
        VStack(spacing: 10) {
            Text("모든 세트를 기록했습니다")
                .font(Typography.itemName)
                .multilineTextAlignment(.center)
            // 세션 완료 처리는 SessionRunner 가 phase 를 finished 로 바꿀 때 이미 끝났다(F-4).
            // 여기서 finishSession() 을 부르는 것은 onChange 한 경로에만 기대지 않으려는
            // 방어다. 두 번 실행되지 않는 것은 finishSession() 이 보장한다.
            Button("완료") {
                finishSession()
                onEnd()
            }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 2)
    }
}

/// 기록 햅틱 트리거. `sensoryFeedback(trigger:)` 는 값이 바뀔 때만 울리므로,
/// 성공을 연달아 눌러도 값이 달라지도록 순번을 함께 담는다.
/// `sequence == 0` 은 초기값이라 화면이 뜨는 순간에는 울리지 않는다.
private struct RecordFeedback: Equatable {
    var isSuccess = true
    var sequence = 0
}

/// 현재 종목의 세트 진행. `"3세트"` 텍스트를 대체한다 — 좁은 화면에서 글자보다 싸면서
/// 몇 세트 중 몇 번째인지까지 한 번에 보인다.
///
/// 색만으로 구분하지 않기 위해 기록된 세트는 채운 원, 남은 세트는 테두리 원,
/// 현재 세트는 링을 두른 원으로 그린다(PRD §9).
private struct SetProgressPips: View {
    let sets: [SessionSet]
    let focusedSetID: UUID?

    var body: some View {
        HStack(spacing: 5) {
            ForEach(sets) { set in
                pip(for: set)
                    .frame(width: 7, height: 7)
                    .overlay {
                        if set.id == focusedSetID {
                            Circle().stroke(ColorRole.accent.opacity(0.3), lineWidth: 3)
                        }
                    }
            }
        }
        // 점은 장식이라 탭을 먹지 않아야 한다 — 여기서 막히면 "화면 아무 곳이나 탭"
        // (F-5)이 이 영역에서만 조용히 죽는다.
        .allowsHitTesting(false)
        // 대체한 `"3세트"` 텍스트가 읽어주던 정보를 그대로 남긴다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let index = sets.firstIndex(where: { $0.id == focusedSetID }) else {
            return "\(sets.count)세트"
        }
        return "\(sets.count)세트 중 \(index + 1)번째"
    }

    @ViewBuilder
    private func pip(for set: SessionSet) -> some View {
        if set.result.isRecorded {
            Circle().fill(set.result.tintColor)
        } else if set.id == focusedSetID {
            Circle().fill(ColorRole.accent)
        } else {
            Circle().stroke(Color.secondary.opacity(0.6), lineWidth: 1.5)
        }
    }
}

/// 직전 기록 대비 증감(F-9). 손목에서 뺄셈을 시키지 않는 것이 전부이고,
/// **다음 무게를 제안하지 않는다** — 제안은 F-11 이고 M3 다.
private struct DeltaBadge: View {
    let delta: Double

    /// 부호가 방향을 이미 말하므로 색은 "지난번보다 올렸다"만 강조한다.
    /// 감량도 정상적인 판단이라 경고색을 쓰지 않는다.
    private var tint: Color { delta > 0 ? ColorRole.accent : .secondary }

    var body: some View {
        Text(WeightFormatter.delta(delta))
            .font(Typography.secondary.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.15), in: .capsule)
            .accessibilityLabel("지난 기록 대비 \(WeightFormatter.delta(delta))")
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
