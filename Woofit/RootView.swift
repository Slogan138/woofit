import SwiftUI
import SwiftData
import WoofitCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Environment(\.liveActivity) private var liveActivity
    @Environment(\.sessionNotifications) private var sessionNotifications
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = SessionCoordinator()
    @State private var watchAppLauncher = WatchAppLauncher()

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
            coordinator.watchAppLauncher = watchAppLauncher
            coordinator.restoreIfNeeded(in: modelContext)
            try? syncService?.pushRoutines(in: modelContext)
            reconcilePresence()
        }
        // 워치에서 시작한 세션이 도착하면 그 자리에서 연다(F-8). 앱이 이미 떠 있으면
        // scenePhase 가 바뀌지 않아 이 값의 변화로만 알 수 있다.
        .onChange(of: syncService?.latestInProgressSession) { _, payload in
            coordinator.restoreIfNeeded(in: modelContext)
            // 이미 열려 있는 세션이면 진행 위치를 다시 잡는다 — 상대가 다음 종목으로
            // 넘어간 것을 따라가야 한다(F-8).
            if let runner = coordinator.activeRunner, runner.id == payload?.sessionID {
                runner.refreshFromRemoteChange()
                // 상대가 끝냈으면 이쪽 화면도 닫는다. 요약은 끝낸 기기가 보여준다.
                if runner.session.state != .inProgress {
                    if let liveActivity { Task { await liveActivity.end() } }
                    if let sessionNotifications { Task { await sessionNotifications.sessionDidChange(to: nil) } }
                    coordinator.endSession()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.restoreIfNeeded(in: modelContext)
            reconcilePresence()
        }
        .fullScreenCover(item: $coordinator.activeRunner) { runner in
            NavigationStack {
                SessionRunnerView(runner: runner, onEnd: endSession)
            }
        }
    }

    /// 잠금화면을 저장소와 맞춘다(F-16).
    ///
    /// **못 받은 종료를 여기서 정리한다.** 워치에서 중단했는데 폰이 그때 깨어나지 못하면
    /// (강제 종료 상태 등) 카드가 그대로 남는다. 앱이 앞으로 나올 때 한 번 맞춰주면
    /// 살아 있는 세션이 없을 때 카드도 함께 사라진다 — 계획 21 의 "그물"과 같은 장치다.
    private func reconcilePresence() {
        let session = try? SessionRestore.fetchInProgress(in: modelContext)
        for presence in [liveActivity as (any SessionPresence)?, sessionNotifications].compactMap(\.self) {
            Task { await presence.sessionDidChange(to: session) }
        }
    }

    /// 세션이 끝나면 직전 기록이 바뀌므로, 루틴을 다시 내려보내 워치에도 반영한다(F-9).
    private func endSession() {
        // 끝난 세션의 최종 상태를 보내야 워치가 계속 진행 중으로 보여주지 않는다(F-8).
        coordinator.push(coordinator.activeRunner?.session, to: syncService)
        if let liveActivity { Task { await liveActivity.end() } }
        if let sessionNotifications { Task { await sessionNotifications.sessionDidChange(to: nil) } }
        coordinator.endSession()
        try? syncService?.pushRoutines(in: modelContext)
    }
}

#Preview {
    RootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
