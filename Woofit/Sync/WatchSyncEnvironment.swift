import SwiftUI
import WoofitCore

/// 화면이 `@Environment(\.watchSyncService)` 로 꺼내 쓰도록 앱 시작 시 주입한다(F-8).
/// `WCSession` 은 앱마다 하나만 있어야 하므로 `WoofitApp` 이 한 번만 만든다.
private struct WatchSyncServiceKey: EnvironmentKey {
    static let defaultValue: WatchSyncService? = nil
}

extension EnvironmentValues {
    var watchSyncService: WatchSyncService? {
        get { self[WatchSyncServiceKey.self] }
        set { self[WatchSyncServiceKey.self] = newValue }
    }
}
