import SwiftUI
import SwiftData
import WoofitCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
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
        .task { coordinator.restoreIfNeeded(in: modelContext) }
        .fullScreenCover(item: $coordinator.activeRunner) { runner in
            NavigationStack {
                SessionRunnerView(runner: runner, onEnd: coordinator.endSession)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
