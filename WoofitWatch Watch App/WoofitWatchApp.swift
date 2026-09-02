import SwiftUI
import SwiftData
import WoofitCore

@main
struct WoofitWatchApp: App {

    /// 워치는 폰의 캐시가 아니라 독립 저장소를 갖는다(PRD §8).
    private let container: ModelContainer
    private let syncService: WatchSyncService
    private let workoutSessionController: WorkoutSessionController

    /// 앱이 앞으로 나올 때마다 이미 도착해 있는 컨텍스트를 읽는다. 백그라운드에 있는
    /// 동안 온 것은 delegate 로 오지 않는다(F-8).
    @Environment(\.scenePhase) private var scenePhase


    init() {
        do {
            container = try WoofitModelContainer.makeContainer()
        } catch {
            fatalError("SwiftData 저장소를 열지 못했습니다: \(error)")
        }
        syncService = WatchSyncService(container: container)
        syncService.activate()
        workoutSessionController = WorkoutSessionController(healthSession: HealthKitWorkoutSession())
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
        .environment(\.watchSyncService, syncService)
        .environment(\.workoutSessionController, workoutSessionController)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            syncService.consumeReceivedContext()
        }
    }
}
