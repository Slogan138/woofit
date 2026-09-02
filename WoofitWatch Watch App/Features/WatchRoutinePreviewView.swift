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
    @Environment(WatchSessionCoordinator.self) private var coordinator

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
    }

    /// 세션 소유는 루트(`WatchSessionCoordinator`)가 갖는다 — 폰에서 넘어온 세션도
    /// 같은 자리에서 열려야 하기 때문이다(F-8).
    private func start() {
        coordinator.start(
            from: routine,
            in: modelContext,
            syncService: syncService,
            workoutSessionController: workoutSessionController
        )
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
