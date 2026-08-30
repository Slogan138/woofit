import SwiftUI
import WoofitCore

/// P4 · 세션 실행. 현재 세트를 카드로 띄우고 성공·실패 버튼을 화면 하단에 고정한다(F-3).
///
/// 버튼을 세트 행 안에 두면 세트마다 손가락 위치가 달라진다. 여기는 땀 손으로 팔 뻗은
/// 거리에서 가장 자주 누르는 자리이므로, 위치가 고정돼 화면을 보지 않고도 누를 수
/// 있어야 한다(계획 15).
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

    /// 아직 안 끝난 종목 중 지금 하는 것을 뺀 나머지. 순서는 세션 그대로다(F-4).
    private var upcomingExercises: [SessionExercise] {
        let currentID = runner.focusedSet?.exercise?.id
        return runner.session.sortedExercises.filter { !$0.isComplete && $0.id != currentID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProgressHeader(session: runner.session)

                if let focused = runner.focusedSet {
                    CurrentSetCard(set: focused, lastRecord: runner.focusedLastRecord)
                        .animation(.snappy, value: focused.id)
                }

                if let resting = runner.restingSet, let startedAt = resting.restStartedAt {
                    RestTimerView(startedAt: startedAt)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ColorRole.rest.opacity(0.14), in: .capsule)
                }

                if let exercise = runner.focusedSet?.exercise {
                    SetListSection(
                        exercise: exercise,
                        focusedSetID: runner.focusedSet?.id,
                        onFocus: { runner.focus(on: $0) },
                        onUndo: { runner.undo($0) },
                        onRest: { runner.toggleRest() }
                    )
                }

                if !upcomingExercises.isEmpty {
                    UpcomingSection(exercises: upcomingExercises) { exercise in
                        if let next = exercise.nextPendingSet { runner.focus(on: next) }
                    }
                }

                Button("다른 종목으로 이동") { isShowingExercisePicker = true }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 세트 행·버튼 자체의 제스처가 더 안쪽이라 우선하므로, 여기 닿는 탭은
        // 버튼도 세트 포커스도 아닌 "그 밖의 화면 전체"뿐이다(F-5 수용 기준).
        .contentShape(Rectangle())
        .onTapGesture { runner.toggleRest() }
        .safeAreaInset(edge: .bottom) { actionBar }
        // 일시정지·전환·완료 오버레이는 화면만 가릴 뿐 탭 자체는 막지 않으므로,
        // VoiceOver 등 접근성 조작으로 뒤에서 기록되는 걸 막기 위해 직접 비활성화한다.
        // `safeAreaInset` 뒤에 붙여야 하단 버튼까지 함께 잠긴다.
        .disabled(isShowingFullScreenOverlay)
        // 화면을 보지 않고 누르는 버튼이라 기록이 실제로 남았음을 촉각으로 확인시킨다.
        // 되돌리기(기록 수 감소)에는 울리지 않는다.
        .sensoryFeedback(trigger: runner.session.recordedSetCount) { old, new in
            guard new > old else { return nil }
            return runner.lastRecordedSet?.result == .failure ? .warning : .success
        }
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

    /// 화면 하단에 고정되는 기록 버튼. 성공이 넓고 실패가 좁은 것은 빈도 차이 그대로다.
    @ViewBuilder
    private var actionBar: some View {
        if let focused = runner.focusedSet {
            HStack(spacing: 12) {
                Button {
                    pendingFailureSet = focused
                } label: {
                    Text("실패")
                        .font(Typography.itemName)
                        .frame(width: 96)
                        // .controlSize(.large) 의 50pt 위에 얹어 64pt 를 만든다.
                        // 고정 높이가 아니라 여백이라 Dynamic Type 을 따라 함께 커진다.
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(SetResult.failure.tintColor)
                .accessibilityLabel("실패, \(focused.order + 1)세트")

                Button {
                    runner.recordSuccess(for: focused)
                } label: {
                    Text("성공")
                        .font(Typography.itemName)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("성공, \(focused.order + 1)세트")
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

// MARK: - 진행률

private struct ProgressHeader: View {
    let session: WorkoutSession

    private var fraction: Double {
        guard session.totalSetCount > 0 else { return 0 }
        return Double(session.recordedSetCount) / Double(session.totalSetCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ProgressView 의 tint 는 Color 만 받아 브랜드 램프를 넣을 수 없어 직접 그린다.
            Capsule()
                .fill(.quaternary)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(ColorRole.progress)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("진행률")
                .accessibilityValue("\(session.recordedSetCount)/\(session.totalSetCount) 세트")

            HStack {
                Text("\(session.completedExerciseCount)/\(session.totalExerciseCount) 종목")
                Spacer()
                Text("\(session.recordedSetCount)/\(session.totalSetCount) 세트")
                    .monospacedDigit()
            }
            .font(Typography.secondary)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 현재 세트

private struct CurrentSetCard: View {
    let set: SessionSet
    let lastRecord: LastRecord?

    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = Typography.heroMetricSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(set.exercise?.name ?? "")
                    .font(Typography.itemName)
                    .lineLimit(2)
                Spacer(minLength: 0)
                SetProgressPips(sets: set.exercise?.sortedSets ?? [], focusedSetID: set.id)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(WeightFormatter.string(set.targetWeight))
                    .font(Typography.heroMetric(metricSize))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("× \(set.targetReps)")
                    .font(Typography.heroMetric(metricSize * 0.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(set.order + 1)세트")
                    .font(Typography.value)
                    .foregroundStyle(ColorRole.accent)
            }

            if let lastRecord {
                LastRecordComparison(record: lastRecord, targetWeight: set.targetWeight)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorRole.cardSurface, in: .rect(cornerRadius: 26, style: .continuous))
    }
}

/// 현재 종목의 세트 진행. 색만으로 구분하지 않기 위해 기록된 세트는 채운 원, 남은 세트는
/// 테두리 원으로 그린다(PRD §9). 같은 정보를 아래 세트 목록이 기호와 함께 읽어주므로
/// 여기서는 접근성 트리에서 뺀다.
private struct SetProgressPips: View {
    let sets: [SessionSet]
    let focusedSetID: UUID?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sets) { set in
                pip(for: set)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if set.id == focusedSetID {
                            Circle().stroke(ColorRole.accent.opacity(0.3), lineWidth: 4)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
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

/// 지난 기록과 오늘 목표를 한 카드 안에 나란히 둔다(F-9).
/// "무게를 올릴지 판단하려고 다른 화면으로 이동할 필요가 없다"가 F-9 의 수용 기준이다.
///
/// 증감 배지는 이미 있는 두 값의 차이일 뿐 **다음 무게를 제안하지 않는다** — 제안은 F-11(M3).
private struct LastRecordComparison: View {
    let record: LastRecord
    let targetWeight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("지난 기록")
                        .font(Typography.secondary)
                        .foregroundStyle(.tertiary)
                    Text(record.summary())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let delta = record.weightDelta(toTarget: targetWeight) {
                    DeltaBadge(delta: delta)
                }
            }
        }
    }
}

private struct DeltaBadge: View {
    let delta: Double

    /// 부호가 방향을 이미 말하므로 색은 "지난번보다 올렸다"만 강조한다.
    /// 감량도 정상적인 판단이라 경고색을 쓰지 않는다.
    private var tint: Color { delta > 0 ? ColorRole.accent : .secondary }

    var body: some View {
        Text(WeightFormatter.delta(delta))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: .capsule)
            .accessibilityLabel("지난 기록 대비 \(WeightFormatter.delta(delta))")
    }
}

// MARK: - 세트 목록

private struct SetListSection: View {
    let exercise: SessionExercise
    let focusedSetID: UUID?
    let onFocus: (SessionSet) -> Void
    let onUndo: (SessionSet) -> Void
    let onRest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("세트")
                .font(Typography.secondary)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    SetRow(
                        set: set,
                        isFocused: set.id == focusedSetID,
                        onUndo: { onUndo(set) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if set.result == .pending {
                            onFocus(set)
                        } else {
                            onRest()
                        }
                    }
                }
            }
            .background(ColorRole.cardSurface, in: .rect(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct SetRow: View {
    let set: SessionSet
    let isFocused: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.order + 1)세트")
                .font(isFocused ? Typography.itemName : .body)
            Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                .font(Typography.secondary)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            switch set.result {
            case .pending:
                Text(isFocused ? "기록 대기" : "대기")
                    .font(Typography.secondary)
                    .foregroundStyle(isFocused ? AnyShapeStyle(ColorRole.accent) : AnyShapeStyle(.secondary))
                    .accessibilityHint(isFocused ? "" : "탭하면 이 세트로 이동합니다")
            case .success, .failure, .skipped:
                Button(action: onUndo) {
                    HStack(spacing: 6) {
                        Text(set.result.markdownSymbol)
                            .foregroundStyle(set.result.tintColor)
                        if set.result == .failure {
                            Text("\(set.performedReps)회").monospacedDigit()
                        }
                        Image(systemName: "arrow.uturn.backward")
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(set.order + 1)세트 \(set.result.displayName), 되돌리기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 다음 종목

private struct UpcomingSection: View {
    let exercises: [SessionExercise]
    let onSelect: (SessionExercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("다음")
                .font(Typography.secondary)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 {
                        Divider().padding(.leading, 16)
                    }
                    Button {
                        onSelect(exercise)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                Text(summary(of: exercise))
                                    .font(Typography.secondary)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(Typography.secondary.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ColorRole.cardSurface, in: .rect(cornerRadius: 18, style: .continuous))
        }
    }

    private func summary(of exercise: SessionExercise) -> String {
        let sets = exercise.sortedSets
        let target = WeightFormatter.targetRange(
            weights: sets.map(\.targetWeight),
            reps: sets.first?.targetReps ?? 0
        )
        return "\(sets.count)세트 · \(target)"
    }
}

// MARK: - 일시정지

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
                    .controlSize(.large)
            }
        }
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴", category: "가슴")
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)
    let incline = routine.appendExercise(named: "인클라인 덤벨프레스")
    incline.appendSets(count: 3, weight: 22.5, reps: 10)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)

    let lastRecord = LastRecord(
        normalizedName: ExerciseName.normalize("벤치프레스"),
        displayName: "벤치프레스",
        performedAt: Date().addingTimeInterval(-6 * 86_400),
        entries: (0..<5).map { _ in
            .init(weight: 77.5, targetReps: 5, performedReps: 5, result: .success)
        }
    )
    let runner = SessionRunner(session: session, lastRecords: [lastRecord.normalizedName: lastRecord])
    runner.recordSuccess()
    runner.recordFailure(actualReps: 4)
    runner.recordSuccess()

    return NavigationStack {
        SessionRunnerView(runner: runner, onEnd: {})
    }
    .modelContainer(container)
}
