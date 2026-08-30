import Foundation
import Testing
@testable import WoofitCore

/// `WorkoutHealthSession` 의 가짜 구현. HealthKit 없이(시뮬레이터 없이) 컨트롤러의
/// 상태 전이만 검증한다(계획 17 테스트 계획).
private final class FakeWorkoutHealthSession: WorkoutHealthSession, @unchecked Sendable {
    private(set) var startCallCount = 0
    private(set) var endCallCount = 0
    var startResult: WorkoutSessionError?
    var endResult: WorkoutSessionError?
    /// 0 보다 크면 `start()` 가 그만큼 걸린다 — 시작이 끝나기 전에 `end()` 가 먼저
    /// 불리는 실기기 타이밍(짧은 세션)을 흉내내는 데 쓴다.
    var startDelayNanoseconds: UInt64 = 0

    func start() async -> WorkoutSessionError? {
        startCallCount += 1
        if startDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: startDelayNanoseconds)
        }
        return startResult
    }

    func end() async -> WorkoutSessionError? {
        endCallCount += 1
        return endResult
    }
}

@MainActor
@Test("시작하지 않은 상태에서 end 를 불러도 안전하다")
func endWithoutStartIsSafe() async {
    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)

    await controller.end()

    #expect(fake.endCallCount == 0)
}

@MainActor
@Test("start 를 두 번 불러도 세션이 하나다")
func startTwiceOpensOneSession() async {
    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)

    await controller.start()
    await controller.start()

    #expect(fake.startCallCount == 1)
}

@MainActor
@Test("권한이 없으면 start 가 조용히 실패하고 lastError 가 남는다")
func startWithoutAuthorizationRecordsError() async {
    let fake = FakeWorkoutHealthSession()
    fake.startResult = .authorizationDenied
    let controller = WorkoutSessionController(healthSession: fake)

    await controller.start()

    #expect(controller.lastError == .authorizationDenied)
    // 시작 실패로 끝난 세션은 진행 중이 아니므로, 이후 종료 호출은 여전히 무시된다.
    await controller.end()
    #expect(fake.endCallCount == 0)
}

@MainActor
@Test("시작 실패와 종료 실패는 서로 다른 원인으로 남는다")
func startFailureAndEndFailureAreDistinguished() async {
    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)

    await controller.start()
    #expect(controller.lastError == nil)

    fake.endResult = .endFailed
    await controller.end()

    #expect(controller.lastError == .endFailed)
}

@MainActor
@Test("시작이 끝나기 전에 end 를 불러도 시작을 기다렸다가 정상 종료된다")
func endWaitsForInFlightStart() async {
    // 실기기에서는 start()·end() 가 서로 다른 화면의 별개 Task 로 fire-and-forget 되므로,
    // 세션이 짧으면 시작이 끝나기 전에 종료가 먼저 실행될 수 있다. 이때 종료를 조용히
    // 무시하면 운동 세션이 시작된 채로 영영 남는다(건강 앱 시작·종료 시각 불일치의 원인).
    let fake = FakeWorkoutHealthSession()
    fake.startDelayNanoseconds = 20_000_000
    let controller = WorkoutSessionController(healthSession: fake)

    // 실제 화면 배선처럼 별개의(unstructured) Task 로 시작을 fire-and-forget 한다.
    let startTask = Task { await controller.start() }
    // 실제 앱은 시작 탭 이후 화면 전환·세트 기록에 최소한의 스케줄링 간격이 있다.
    // yield 로 시작 Task 가 `inFlightStart` 를 채울 시간을 준다.
    await Task.yield()
    await controller.end()
    await startTask.value

    #expect(fake.startCallCount == 1)
    #expect(fake.endCallCount == 1)

    // 이미 끝났으므로 한 번 더 불러도 조용히 무시된다.
    await controller.end()
    #expect(fake.endCallCount == 1)
}

@MainActor
@Test("복원된 세션은 컨트롤러를 부르지 않으므로 운동 세션이 시작되지 않는다")
func restoredSessionNeverStartsWorkout() async {
    // 복원(SessionRestore)은 며칠 전 중단된 세션을 되살릴 수 있다. 그 경로에서 재구성한
    // SessionRunner 는 WorkoutSessionController 를 전혀 모른다 — 유령 운동을 막는 장치는
    // "컨트롤러가 SessionRunner 를 관찰하지 않는다"는 설계 자체다(계획 17 설계).
    let routine = Routine(name: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 1, weight: 40, reps: 10)
    let restoredSession = WorkoutSession.start(from: routine)
    _ = SessionRunner(session: restoredSession)

    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)

    #expect(fake.startCallCount == 0)
    #expect(controller.lastError == nil)
}

@MainActor
@Test("기록할 세트가 없는 세션은 운동 세션을 시작하지 않는다")
func sessionWithoutRecordableSetsNeverStartsWorkout() async {
    // 워치 화면(WatchRoutinePreviewView.start)의 배선을 그대로 흉내낸다. 빈 세션은
    // SessionRunner 가 생성 즉시 finished 라 phase 가 변하지 않고, 종료를 부르는
    // onChange 가 영영 안 터진다 — 시작을 막지 않으면 운동 세션이 남는다(계획 17).
    let routine = Routine(name: "빈 루틴")
    let session = WorkoutSession.start(from: routine)

    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)
    if session.hasRecordableSets {
        await controller.start()
    }

    #expect(fake.startCallCount == 0)
    #expect(fake.endCallCount == 0)
}

@MainActor
@Test("정상 세션은 시작과 종료가 한 번씩 일어난다")
func normalSessionStartsAndEndsOnce() async {
    let routine = Routine(name: "가슴")
    routine.appendExercise(named: "벤치프레스").appendSets(count: 1, weight: 40, reps: 10)
    let session = WorkoutSession.start(from: routine)

    let fake = FakeWorkoutHealthSession()
    let controller = WorkoutSessionController(healthSession: fake)
    if session.hasRecordableSets {
        await controller.start()
    }

    // 완료 화면의 「완료」 버튼과 onChange(of: phase) 가 둘 다 종료를 부를 수 있다.
    await controller.end()
    await controller.end()

    #expect(fake.startCallCount == 1)
    #expect(fake.endCallCount == 1)
}
