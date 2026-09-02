import SwiftUI
import SwiftData
import WoofitCore

/// W1 · 워치 홈. 오늘 요일에 배정된 루틴을 최우선으로 띄운다(F-2).
struct WatchRootView: View {
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = WatchSessionCoordinator()

    private var today: Weekday { .today() }

    private var todaysRoutine: Routine? {
        routines.first { $0.isScheduled(on: today) }
    }

    /// 오늘 루틴을 뺀 나머지는 "최근 사용한 루틴"(PRD F-2) 이다.
    /// `routines` 가 이미 `updatedAt` 내림차순이므로 그대로 쓴다.
    private var otherRoutines: [Routine] {
        routines.filter { $0.id != todaysRoutine?.id }
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack {
            List {
                if let todaysRoutine {
                    Section("오늘 · \(today.shortName)") {
                        NavigationLink(value: todaysRoutine) {
                            RoutineCard(routine: todaysRoutine)
                        }
                    }
                }
                Section(todaysRoutine == nil ? "루틴" : "다른 루틴") {
                    ForEach(otherRoutines) { routine in
                        NavigationLink(routine.resolvedTitle, value: routine)
                    }
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                WatchRoutinePreviewView(routine: routine)
            }
            .navigationTitle("Woofit")
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "루틴 없음",
                        systemImage: "dumbbell",
                        description: Text("폰에서 루틴을 만드세요.")
                    )
                }
            }
        }
        .environment(coordinator)
        // 폰에서 시작한 세션을 그대로 연다(F-8). 워치에서 시작한 세션도 같은 자리로 열린다.
        .fullScreenCover(item: $coordinator.activeRunner) { runner in
            NavigationStack {
                WatchSetView(runner: runner, onEnd: { coordinator.endSession() })
            }
        }
        .task {
            // 앱이 꺼져 있는 동안 폰에서 시작한 세션은 활성화 시점에 저장소로 들어온다.
            syncService?.consumeReceivedContext()
            coordinator.restoreIfNeeded(in: modelContext)
        }
        // 앱이 이미 떠 있는데 세션이 도착하는 경우는 이 값의 변화로만 알 수 있다.
        .onChange(of: syncService?.latestInProgressSession) { _, _ in
            coordinator.restoreIfNeeded(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.restoreIfNeeded(in: modelContext)
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(routine.resolvedTitle)
                .font(Typography.itemName)
            Text("\(routine.sortedExercises.count)종목 · \(routine.totalSetCount)세트")
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchRootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
