import SwiftUI
import SwiftData
import WoofitCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Environment(\.scenePhase) private var scenePhase
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
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .environment(coordinator)
        .task {
            coordinator.restoreIfNeeded(in: modelContext)
            try? syncService?.pushRoutines(in: modelContext)
        }
        // 워치에서 시작한 세션이 도착하면 그 자리에서 연다(F-8). 앱이 이미 떠 있으면
        // scenePhase 가 바뀌지 않아 이 값의 변화로만 알 수 있다.
        .onChange(of: syncService?.latestInProgressSession) { _, payload in
            coordinator.restoreIfNeeded(in: modelContext)
            // 이미 열려 있는 세션이면 진행 위치를 다시 잡는다 — 상대가 다음 종목으로
            // 넘어간 것을 따라가야 한다(F-8).
            if let runner = coordinator.activeRunner, runner.id == payload?.sessionID {
                runner.refreshFromRemoteChange()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.restoreIfNeeded(in: modelContext)
        }
        .fullScreenCover(item: $coordinator.activeRunner) { runner in
            NavigationStack {
                SessionRunnerView(runner: runner, onEnd: endSession)
            }
        }
    }

    /// 세션이 끝나면 직전 기록이 바뀌므로, 루틴을 다시 내려보내 워치에도 반영한다(F-9).
    private func endSession() {
        // 끝난 세션의 최종 상태를 보내야 워치가 계속 진행 중으로 보여주지 않는다(F-8).
        coordinator.push(coordinator.activeRunner?.session, to: syncService)
        coordinator.endSession()
        try? syncService?.pushRoutines(in: modelContext)
    }
}

#Preview {
    RootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
