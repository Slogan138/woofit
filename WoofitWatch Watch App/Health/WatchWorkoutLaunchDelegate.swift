import HealthKit
import os
import SwiftUI
import WoofitCore

/// 폰이 `startWatchApp(toHandle:)` 로 이 앱을 띄웠을 때 호출된다(F-17).
///
/// **`WKApplicationDelegate` 의 메서드는 전부 `@optional` 이다.** 이름이 조금만 달라도
/// 컴파일은 되고 영영 불리지 않으므로, 무엇이 불리고 무엇이 안 불리는지 로그로 남긴다 —
/// 실기기에서 이것 없이는 "안 뜬다"만 보이고 어느 단계에서 끊겼는지 알 수 없다.
///
/// **여기서 운동 세션을 시작해야 한다.** 헤더 주석이 그렇게 적혀 있고, 시작하지 않으면
/// watchOS 가 앱을 앞에 유지할 이유가 없다.
///
/// 그렇다고 `HKWorkoutSession` 을 직접 만들지는 않는다. 수명은 `WorkoutSessionController`
/// 한 곳이 쥐어야 하므로(계획 17) **컨트롤러를 이 타입이 소유하고** 앱이 환경으로 내려보낸다.
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

    func applicationDidFinishLaunching() {
        Self.logger.info("워치 앱이 떴다")
    }

    func applicationDidBecomeActive() {
        Self.logger.info("워치 앱이 앞으로 나왔다")
    }

    /// 운동 중에 앱이 죽었다 다시 떴을 때 불린다. 돌고 있던 운동 세션을 되찾는다 —
    /// `start()` 안에서 `recoverActiveWorkoutSession` 이 그 일을 한다(계획 21).
    func handleActiveWorkoutRecovery() {
        Self.logger.info("운동 중에 죽었던 앱이 다시 떴다")
        Task { @MainActor in await workoutSessionController.start() }
    }
}
