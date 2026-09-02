import SwiftUI
import SwiftData
import WoofitCore

/// W2 · 시작 전 전체 스크롤 확인. 폰 없이 워치 저장소만 읽는다(F-2).
/// "시작"을 누르면 W3(`WatchSetView`)로 넘어간다(F-3).
struct WatchRoutinePreviewView: View {
    let routine: Routine

    @Environment(\.modelContext) private var modelContext
    @Environment(\.workoutSessionController) private var workoutSessionController
    @Environment(\.watchSyncService) private var syncService
    @State private var activeRunner: SessionRunner?

    var body: some View {
        List {
            if !routine.sortedExercises.isEmpty {
                Button("시작", action: start)
                    .buttonStyle(.borderedProminent)
                    // 워치 List 행은 자체 배경 컨테이너를 그린다. 버튼을 그대로 넣으면
                    // 버튼 모양이 행 테두리에 한 번 더 감싸여 이중으로 보인다.
                    // 배경만 지운다 — listRowInsets 까지 없애면 행이 넓어지는데 버튼은
                    // 고유 너비를 유지해 왼쪽으로 치우친다.
                    .listRowBackground(Color.clear)
            }

            if routine.isScheduled {
                Text(Weekday.label(mask: routine.weekdayMask))
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }

            ForEach(routine.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sortedSets) { set in
                        Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                            .font(Typography.secondary)
                    }
                }
            }
        }
        .navigationTitle(routine.resolvedTitle)
        .navigationDestination(item: $activeRunner) { runner in
            WatchSetView(runner: runner, onEnd: { activeRunner = nil })
        }
    }

    /// 여기가 워치에서 세션을 새로 시작하는 유일한 경로다 — 복원 경로가 따로 없으므로
    /// `workoutSessionController.start()` 를 여기 한 곳에서만 부르면 유령 운동을 피할 수 있다(계획 17).
    private func start() {
        let session = WorkoutSession.start(from: routine)
        modelContext.insert(session)
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: modelContext)) ?? [:]
        )
        // 기록할 세트가 없으면 SessionRunner 가 생성 즉시 finished 라 phase 가 변하지 않고,
        // 종료를 부르는 onChange 가 영영 안 터진다 — 시작하지 않는 것으로 막는다(계획 17).
        if session.hasRecordableSets {
            Task { await workoutSessionController?.start() }
        }
        // 폰이 곧바로 이어받도록 진행 상태를 보낸다(F-8). 종료 시점의 전송은
        // `WatchSetView.finishSession()` 이 맡는다.
        try? syncService?.sendInProgressSession(SessionSnapshotPayload.make(for: session))
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)

    return NavigationStack {
        WatchRoutinePreviewView(routine: routine)
    }
    .modelContainer(container)
}
