import SwiftUI
import WoofitCore

/// 화면이 `@Environment(\.workoutSessionController)` 로 꺼내 쓰도록 앱 시작 시 주입한다(계획 17).
/// `HKHealthStore` 는 앱마다 하나만 있어야 하므로 `WoofitWatchApp` 이 한 번만 만든다.
private struct WorkoutSessionControllerKey: EnvironmentKey {
    static let defaultValue: WorkoutSessionController? = nil
}

extension EnvironmentValues {
    var workoutSessionController: WorkoutSessionController? {
        get { self[WorkoutSessionControllerKey.self] }
        set { self[WorkoutSessionControllerKey.self] = newValue }
    }
}
