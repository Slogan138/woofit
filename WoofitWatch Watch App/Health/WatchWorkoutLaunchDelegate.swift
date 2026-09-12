import HealthKit
import os
import SwiftUI

/// 폰이 `startWatchApp(toHandle:)` 로 이 앱을 띄웠을 때 호출된다(F-17).
///
/// **여기서 운동 세션을 직접 만들지 않는다.** 운동 세션의 수명은 `WorkoutSessionController`
/// 한 곳이 쥐고 있고(계획 17), 여기서 또 만들면 두 개가 된다. 앱이 앞으로 나오면
/// `WatchRootView` 가 폰에서 온 세션을 이어받으면서 운동 세션까지 시작한다(계획 21).
///
/// 그래서 이 델리게이트가 하는 일은 **띄워졌다는 사실을 로그로 남기는 것**뿐이다.
/// 앱이 앞으로 나오는 것 자체가 목적이었다 — 워치 앱을 띄우는 경로가 이것 하나뿐이다.
final class WatchWorkoutLaunchDelegate: NSObject, WKApplicationDelegate {
    private static let logger = Logger(subsystem: "io.jwp.woofit", category: "WatchLaunch")

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Self.logger.info("폰이 운동 세션으로 워치 앱을 띄웠다")
    }
}
