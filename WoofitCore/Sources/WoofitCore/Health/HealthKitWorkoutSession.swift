#if os(watchOS)
import Foundation
import HealthKit
import os

/// `WorkoutHealthSession` 의 실제 구현(계획 17 작업 단위 3). 근력 운동 세션을 열고
/// 건강 앱에 저장한다. `canImport(HealthKit)` 가 macOS 에서 거짓이라 이 파일이 빠져도
/// `swift test` 는 영향받지 않는다 — `os(watchOS)` 로 한 번 더 좁히는 이유는 폰 쪽은
/// 화면이 켜져 있어 문제가 없기 때문이다(PRD F-14 범위).
@MainActor
public final class HealthKitWorkoutSession: WorkoutHealthSession {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "HealthKitWorkoutSession")
    private nonisolated static let workoutType = HKObjectType.workoutType()

    /// 운동에 붙일 값들. **읽기 권한이 없으면 `HKLiveWorkoutDataSource` 가 아무것도
    /// 모으지 못해 칼로리가 0 으로 남는다**(F-14 활동 링). 시스템이 기록한 샘플을
    /// 읽어서 운동 객체에 합산하는 구조라, 쓰기 권한만으로는 부족하다.
    ///
    /// 심박수가 상세 화면에 보이는 것과는 별개다 — 그건 건강 앱이 같은 시간대 샘플을
    /// 자체적으로 읽어 그리는 것이고, 칼로리는 운동에 붙은 합계값이다.
    private nonisolated static let collectedTypes: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.heartRate),
    ]

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    public init() {}

    /// 쓰기 권한만 요청한다 — 읽기는 필요 없다(설계 §권한). 권한 요청은 첫 세션 시작
    /// 직전에만 이뤄지므로 여기서 함께 처리한다.
    public func start() async -> WorkoutSessionError? {
        guard HKHealthStore.isHealthDataAvailable() else { return .authorizationDenied }

        do {
            try await healthStore.requestAuthorization(toShare: [Self.workoutType], read: Self.collectedTypes)
        } catch {
            Self.logger.error("권한 요청 실패: \(String(describing: error), privacy: .public)")
            return .authorizationDenied
        }
        // 쓰기 권한은 읽기와 달리 상태가 그대로 노출된다 — 거부 여부를 여기서 구분할 수 있다.
        guard healthStore.authorizationStatus(for: Self.workoutType) == .sharingAuthorized else {
            return .authorizationDenied
        }

        // 앱이 죽었다 살아난 경우 돌던 세션을 되찾는다. 새로 시작하면 한 번의 운동이
        // 건강 앱에 둘로 쪼개져 남는다(계획 21). 되찾기 실패는 오류가 아니다 —
        // 앱이 죽은 지 오래면 운동 세션도 이미 끝나 있고, 그때는 새로 시작하면 된다.
        if let recovered = try? await healthStore.recoverActiveWorkoutSession() {
            let builder = recovered.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: recovered.workoutConfiguration)
            self.session = recovered
            self.builder = builder
            Self.logger.info("돌고 있던 운동 세션을 되찾았다")
            return nil
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            self.session = session
            self.builder = builder
            return nil
        } catch {
            Self.logger.error("운동 세션 시작 실패: \(String(describing: error), privacy: .public)")
            return .startFailed
        }
    }

    public func end() async -> WorkoutSessionError? {
        guard let session, let builder else { return nil }
        // 실패해도 다시 시도할 방법이 없으므로(세션은 이미 종료 신호를 받았다) 참조는 항상 비운다.
        self.session = nil
        self.builder = nil

        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
            return nil
        } catch {
            Self.logger.error("운동 세션 종료 실패: \(String(describing: error), privacy: .public)")
            return .endFailed
        }
    }
}
#endif
