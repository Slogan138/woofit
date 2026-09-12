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

    /// 워치 앱을 띄울 수 있는 상태인가. 설정 화면이 그대로 보여준다(F-17) —
    /// 실기기에서 "왜 안 뜨는지"를 로그 없이 확인할 유일한 경로다.
    public var status: Status {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch healthStore.authorizationStatus(for: Self.workoutType) {
        case .sharingAuthorized: return .ready
        case .sharingDenied: return .denied
        default: return .notAsked
        }
    }

    public enum Status: Hashable, Sendable {
        case ready
        case denied
        case notAsked
        case unavailable

        public var label: String {
            switch self {
            case .ready: "켜짐"
            case .denied: "건강 앱에서 꺼짐"
            case .notAsked: "첫 세션에서 물어봄"
            case .unavailable: "이 기기에서 사용 불가"
            }
        }
    }

    /// 워치 앱을 띄우고 운동 세션을 시작시킨다. 실패는 삼킨다 —
    /// **세션 시작을 기다리게 하지 않는다**(F-3 100ms 수용 기준).
    public func launch() async {
        // **빠져나가는 길마다 이유를 남긴다.** 조용히 실패하면 실기기에서 "워치 앱이 안
        // 뜬다"만 보이고 원인을 가릴 수 없다(`WatchSyncService.lastSendError` 와 같은 이유).
        guard HKHealthStore.isHealthDataAvailable() else {
            Self.logger.notice("HealthKit 을 쓸 수 없다")
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [Self.workoutType], read: [])
        } catch {
            Self.logger.error("권한 요청 실패: \(String(describing: error), privacy: .public)")
            return
        }
        let status = healthStore.authorizationStatus(for: Self.workoutType)
        guard status == .sharingAuthorized else {
            // 한 번 거부하면 앱이 다시 물어볼 수 없다. 설정에서 켜야 한다.
            Self.logger.notice("운동 쓰기 권한이 없어 워치 앱을 띄우지 않는다 (status=\(status.rawValue, privacy: .public))")
            return
        }

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
            Self.logger.error("워치 앱 실행 실패: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
