#if os(iOS) && canImport(HealthKit)
import Foundation
import HealthKit
import os

/// 폰에서 세션을 시작하면 워치 앱을 함께 띄운다(F-17).
///
/// **`WatchConnectivity` 로는 워치 앱을 실행시킬 수 없다.** 세션을 보내도 워치 앱을
/// 직접 열어야 이어받는다. 운동 세션을 여는 `startWatchApp(with:)` 만이 워치 앱을
/// 앞으로 띄우는 경로다 — 애플 운동 앱과 같은 흐름을 만드는 유일한 방법이라, 이것
/// 하나 때문에 폰에도 HealthKit 권한이 필요하다.
///
/// 권한을 거부해도 앱은 그대로 동작한다. 워치를 손으로 열면 지금처럼 이어받는다(F-8).
@MainActor
public final class WatchAppLauncher {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "WatchAppLauncher")
    private nonisolated static let workoutType = HKObjectType.workoutType()

    private let healthStore = HKHealthStore()

    public init() {}

    /// 워치 앱을 띄우고 운동 세션을 시작시킨다. 실패는 삼킨다 —
    /// **세션 시작을 기다리게 하지 않는다**(F-3 100ms 수용 기준).
    public func launch() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [Self.workoutType], read: [])
        } catch {
            Self.logger.error("권한 요청 실패: \(String(describing: error), privacy: .public)")
            return
        }
        guard healthStore.authorizationStatus(for: Self.workoutType) == .sharingAuthorized else { return }

        // 워치가 실제로 여는 세션의 종류다. 워치 쪽 `HealthKitWorkoutSession` 과 같은 값을
        // 보내야 한 번의 운동으로 이어진다(F-14).
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            try await healthStore.startWatchApp(toHandle: configuration)
            Self.logger.info("워치 앱을 띄웠다")
        } catch {
            // 워치가 없거나, 꺼져 있거나, 이미 다른 운동 중일 수 있다. 전부 정상 상황이다.
            Self.logger.notice("워치 앱 실행 실패: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
