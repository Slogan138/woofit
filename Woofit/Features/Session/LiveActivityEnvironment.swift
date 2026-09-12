import SwiftUI
import WoofitCore

/// 화면이 `@Environment(\.liveActivity)` 로 꺼내 쓰도록 앱 시작 시 주입한다(F-16).
/// `WatchSyncEnvironment`·`WorkoutSessionEnvironment` 와 같은 모양이다.
private struct LiveActivityKey: EnvironmentKey {
    static let defaultValue: LiveActivityController? = nil
}

extension EnvironmentValues {
    var liveActivity: LiveActivityController? {
        get { self[LiveActivityKey.self] }
        set { self[LiveActivityKey.self] = newValue }
    }
}
