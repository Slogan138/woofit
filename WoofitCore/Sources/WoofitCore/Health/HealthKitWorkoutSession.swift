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

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    public init() {}

    /// 쓰기 권한만 요청한다 — 읽기는 필요 없다(설계 §권한). 권한 요청은 첫 세션 시작
    /// 직전에만 이뤄지므로 여기서 함께 처리한다.
    public func start() async -> WorkoutSessionError? {
        guard HKHealthStore.isHealthDataAvailable() else { return .authorizationDenied }

        do {
            try await healthStore.requestAuthorization(toShare: [Self.workoutType], read: [])
        } catch {
            Self.logger.error("권한 요청 실패: \(String(describing: error), privacy: .public)")
            return .authorizationDenied
        }
        // 쓰기 권한은 읽기와 달리 상태가 그대로 노출된다 — 거부 여부를 여기서 구분할 수 있다.
        guard healthStore.authorizationStatus(for: Self.workoutType) == .sharingAuthorized else {
            return .authorizationDenied
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
