import Foundation
import os

/// 운동 세션 시작·종료 중 실패한 원인. 권한 거부와 시작·종료 실패를 구분해 남긴다 —
/// 셋 다 "그냥 안 됨"으로 뭉치면 실기기에서 원인을 못 찾는다(계획 17 작업 단위 5).
public enum WorkoutSessionError: Error, Equatable, Sendable {
    case authorizationDenied
    case startFailed
    case endFailed
}

/// `HKWorkoutSession` 을 실제로 열고 닫는 동작만 추상화한다. `WorkoutSessionController` 가
/// 이 프로토콜에만 의존해, HealthKit 이 없는 macOS 에서도(`swift test`) 상태 전이를 검증한다.
/// 실제 구현은 `HealthKitWorkoutSession`(watchOS 전용)이다.
public protocol WorkoutHealthSession: AnyObject, Sendable {
    /// 실패하면 원인을 돌려준다. 성공하면 `nil`.
    func start() async -> WorkoutSessionError?
    /// 시작한 적이 없으면 아무 것도 하지 않는다.
    func end() async -> WorkoutSessionError?
}

/// 운동 세션의 수명을 `SessionRunner` 의 시작·종료 두 지점에만 묶는다(계획 17 설계).
///
/// 이 타입은 `SessionRunner`·`SessionRestore` 를 전혀 모른다 — 알게 하면 그쪽 상태 변화를
/// 따라가는 두 번째 진실이 생긴다. 대신 호출부(워치 화면)가 시작·종료 두 지점에서만
/// `start()`·`end()` 를 명시적으로 부른다. 복원된 세션에 대해서는 호출부가 아예 부르지
/// 않는 것으로 "다시 시작하지 않는다"를 보장한다.
@MainActor
public final class WorkoutSessionController {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "WorkoutSession")

    private let healthSession: any WorkoutHealthSession
    private var isActive = false
    /// 진행 중인 시작 작업. `start()`·`end()` 는 워치 화면 두 곳에서 각자 별개의
    /// `Task { }` 로 fire-and-forget 되므로 호출 순서가 보장되지 않는다 — 짧은 세션에서는
    /// 시작이 끝나기도 전에 종료가 먼저 실행될 수 있다. 예전엔 그때 `end()` 가 `isActive`
    /// 를 아직 `false` 로 보고 조용히 무시해, 세션이 시작된 채로 영영 남는 버그가 있었다
    /// (건강 앱에 시작·종료 시각이 안 맞는 기록으로 남은 원인). `end()` 가 이 작업을 먼저
    /// 기다리게 해서 막는다.
    private var inFlightStart: Task<Void, Never>?

    /// 가장 최근 시작·종료에서 발생한 오류. `WatchSyncService.lastSendError` 와 같은 모양이다.
    public private(set) var lastError: WorkoutSessionError?

    public init(healthSession: any WorkoutHealthSession) {
        self.healthSession = healthSession
    }

    /// 이미 진행 중이거나 진행 중인 시작이 있으면 그 결과를 기다린다 — 두 번 불러도 세션은 하나다.
    public func start() async {
        if let inFlightStart {
            await inFlightStart.value
            return
        }
        guard !isActive else { return }
        let task = Task { await self.performStart() }
        inFlightStart = task
        await task.value
        inFlightStart = nil
    }

    private func performStart() async {
        if let error = await healthSession.start() {
            lastError = error
            Self.logger.error("운동 세션 시작 실패: \(String(describing: error), privacy: .public)")
            return
        }
        isActive = true
        lastError = nil
    }

    /// 시작한 적이 없으면 안전하게 무시한다 — 중복 종료도, 복원 뒤 잘못된 종료 호출도 이걸로 막는다.
    /// 진행 중인 시작이 있으면 먼저 끝나길 기다린 뒤 판단한다.
    public func end() async {
        await inFlightStart?.value
        guard isActive else { return }
        isActive = false
        if let error = await healthSession.end() {
            lastError = error
            Self.logger.error("운동 세션 종료 실패: \(String(describing: error), privacy: .public)")
            return
        }
        lastError = nil
    }
}
