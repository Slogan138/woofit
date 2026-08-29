import SwiftUI
import SwiftData
import WoofitCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @State private var coordinator = SessionCoordinator()

    var body: some View {
        @Bindable var coordinator = coordinator

        TabView {
            Tab("루틴", systemImage: "list.bullet.rectangle") {
                RoutineListView()
            }
            Tab("기록", systemImage: "clock.arrow.circlepath") {
                SessionHistoryView()
            }
        }
        .environment(coordinator)
        .task {
            coordinator.restoreIfNeeded(in: modelContext)
            try? syncService?.pushRoutines(in: modelContext)
        }
        .fullScreenCover(item: $coordinator.activeRunner) { runner in
            NavigationStack {
                SessionRunnerView(runner: runner, onEnd: endSession)
            }
        }
    }

    /// 세션이 끝나면 직전 기록이 바뀌므로, 루틴을 다시 내려보내 워치에도 반영한다(F-9).
    private func endSession() {
        coordinator.endSession()
        try? syncService?.pushRoutines(in: modelContext)
    }
}

#Preview {
    RootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
