import SwiftUI
import SwiftData
import WoofitCore

@main
struct WoofitApp: App {

    /// 로컬 전용 저장소. CloudKit 전환은 여기에 컨테이너 식별자를 넘기면 된다(PRD D5).
    private let container: ModelContainer
    private let syncService: WatchSyncService

    init() {
        do {
            container = try WoofitModelContainer.makeContainer()
        } catch {
            // 저장소를 못 열면 앱이 할 수 있는 일이 없다. 조용히 넘기지 않고 즉시 드러낸다.
            fatalError("SwiftData 저장소를 열지 못했습니다: \(error)")
        }
        syncService = WatchSyncService(container: container)
        syncService.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(\.watchSyncService, syncService)
    }
}
