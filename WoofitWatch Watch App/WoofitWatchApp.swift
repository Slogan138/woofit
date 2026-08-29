import SwiftUI
import SwiftData
import WoofitCore

@main
struct WoofitWatchApp: App {

    /// 워치는 폰의 캐시가 아니라 독립 저장소를 갖는다(PRD §8).
    private let container: ModelContainer
    private let syncService: WatchSyncService

    init() {
        do {
            container = try WoofitModelContainer.makeContainer()
        } catch {
            fatalError("SwiftData 저장소를 열지 못했습니다: \(error)")
        }
        syncService = WatchSyncService(container: container)
        syncService.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
        .environment(\.watchSyncService, syncService)
    }
}
