import HealthKit
import os
import SwiftUI
import WoofitCore

/// 폰이 `startWatchApp(toHandle:)` 로 이 앱을 띄웠을 때 호출된다(F-17).
///
/// **여기서 운동 세션을 시작해야 한다.** 애플이 이 메서드를 부르는 이유가 그것이고,
/// 시작하지 않으면 watchOS 가 앱을 앞에 유지할 이유가 없어 곧바로 내려간다 —
/// 실기기에서 "띄웠다는 로그는 찍히는데 화면이 안 뜬다"로 드러났다.
///
/// 그렇다고 `HKWorkoutSession` 을 직접 만들지는 않는다. 수명은 `WorkoutSessionController`
/// 한 곳이 쥐어야 하고(계획 17), 여기서 또 만들면 두 개가 된다. **컨트롤러를 이 타입이
/// 소유하고** 앱이 그것을 환경으로 내려보낸다 — 시스템 진입점이 시스템 자원을 갖는 모양이다.
final class WatchWorkoutLaunchDelegate: NSObject, WKApplicationDelegate {
    private static let logger = Logger(subsystem: "io.jwp.woofit", category: "WatchLaunch")

    @MainActor
    let workoutSessionController = WorkoutSessionController(healthSession: HealthKitWorkoutSession())

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Self.logger.info("폰이 운동 세션으로 워치 앱을 띄웠다")
        // 세션 데이터는 아직 안 왔을 수 있다. 운동 세션을 먼저 열어 앱을 앞에 붙들어두고,
        // 이어받기는 도착하는 대로 `WatchRootView` 가 한다(계획 21).
        Task { @MainActor in await workoutSessionController.start() }
    }
}
