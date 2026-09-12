import Testing
import Foundation
import SwiftData
@testable import WoofitCore

/// 진행 중 세션의 수명(PRD D14, 계획 21).
///
/// `inProgress` 는 디스크에 남는 값이라 아무도 지우지 않으면 영원히 진행 중이다.
/// 아래는 "언제 죽은 것으로 보는가"를 고정한다. 시각은 전부 인자로 주입해 실제 시계에
/// 기대지 않는다.

@MainActor
private func makeContainer() throws -> ModelContainer {
    try WoofitModelContainer.makeInMemoryContainer()
}

@MainActor
@discardableResult
private func session(named name: String, startedAt: Date, in context: ModelContext) -> WorkoutSession {
    let routine = Routine(name: name, category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 40, reps: 10)
    let session = WorkoutSession.start(from: routine, at: startedAt)
    context.insert(session)
    return session
}

private let noon = Date(timeIntervalSince1970: 1_788_000_000)

// MARK: - 마지막 활동

@MainActor
@Test("기록이 없으면 시작 시각이 마지막 활동이다")
func lastActivityFallsBackToStart() throws {
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)

    #expect(session.lastActivityAt == noon)
}

@MainActor
@Test("마지막 활동은 가장 나중에 기록한 세트의 시각이다")
func lastActivityUsesLatestRecord() throws {
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)

    session.allSets[0].markSuccess(at: noon.addingTimeInterval(120))
    session.allSets[1].markSuccess(at: noon.addingTimeInterval(400))

    #expect(session.lastActivityAt == noon.addingTimeInterval(400))
}

// MARK: - 살아 있는가

@MainActor
@Test("오늘 시작한 진행 중 세션은 살아 있다")
func todaysSessionIsLive() throws {
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)

    #expect(session.isLive(at: noon.addingTimeInterval(3 * 3_600)))
}

@MainActor
@Test("날이 바뀐 진행 중 세션은 살아 있지 않다")
func yesterdaysSessionIsNotLive() throws {
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)

    #expect(session.isLive(at: noon.addingTimeInterval(24 * 3_600)) == false)
}

@MainActor
@Test("자정을 넘겨 기록하면 그 기록을 기준으로 계속 살아 있다")
func lateNightSessionStaysLive() throws {
    // 23:50 에 시작해 00:10 에 세트를 기록한 경우. 시작 시각으로 판단하면 이미 죽은
    // 세션이 되지만, 사람은 같은 운동을 계속하고 있다.
    let container = try makeContainer()
    var components = DateComponents()
    components.year = 2026
    components.month = 9
    components.day = 12
    components.hour = 23
    components.minute = 50
    let lateNight = try #require(Calendar.current.date(from: components))

    let session = session(named: "가슴", startedAt: lateNight, in: container.mainContext)
    let afterMidnight = lateNight.addingTimeInterval(20 * 60)
    session.allSets[0].markSuccess(at: afterMidnight)

    #expect(session.isLive(at: afterMidnight.addingTimeInterval(600)))
}

@MainActor
@Test("끝난 세션은 오늘 것이어도 살아 있지 않다")
func finishedSessionIsNotLive() throws {
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)
    for set in session.allSets { set.markSuccess(at: noon) }
    session.finish(at: noon)

    #expect(session.isLive(at: noon) == false)
}

// MARK: - 정리

@MainActor
@Test("복원은 진행 중 세션이 둘이면 최근 것을 집는다")
func restorePicksTheNewest() throws {
    // 정렬이 없으면 보통 먼저 저장된(오래된) 쪽이 나온다.
    let container = try makeContainer()
    let context = container.mainContext
    session(named: "아침", startedAt: noon, in: context)
    let later = session(named: "저녁", startedAt: noon.addingTimeInterval(6 * 3_600), in: context)

    let restored = try SessionRestore.fetchInProgress(in: context, at: noon.addingTimeInterval(7 * 3_600))

    #expect(restored?.id == later.id)
}

@MainActor
@Test("복원이 날 지난 진행 중 세션을 중단으로 정리한다")
func restoreExpiresStaleSessions() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let stale = session(named: "그저께", startedAt: noon, in: context)

    let restored = try SessionRestore.fetchInProgress(in: context, at: noon.addingTimeInterval(48 * 3_600))

    #expect(restored == nil)
    #expect(stale.state == .abandoned)
}

@MainActor
@Test("만료 정리는 세트 기록을 건드리지 않는다")
func expiringKeepsRecords() throws {
    // 정리해도 되는 유일한 이유가 이것이다 — 잃는 것이 "진행 중" 표시뿐이어야 한다(D14).
    let container = try makeContainer()
    let context = container.mainContext
    let stale = session(named: "어제", startedAt: noon, in: context)
    stale.allSets[0].markSuccess(at: noon)
    stale.allSets[1].markFailure(actualReps: 7, at: noon)

    try SessionLifetime.expireStale(in: context, at: noon.addingTimeInterval(30 * 3_600))

    #expect(stale.state == .abandoned)
    #expect(stale.allSets[0].result == .success)
    #expect(stale.allSets[1].actualReps == 7)
    #expect(stale.recordedSetCount == 2)
}

@MainActor
@Test("살아 있는 세션은 만료 정리에 걸리지 않는다")
func expiringSparesLiveSessions() throws {
    // `abandon()` 은 휴식 측정을 함께 끝낸다. 살아 있는 세션을 실수로 정리하면 운동
    // 중에 타이머가 사라진다 — 실제로 그 경로로 났던 버그다.
    let container = try makeContainer()
    let context = container.mainContext
    let live = session(named: "오늘", startedAt: noon, in: context)
    live.allSets[0].markSuccess(at: noon)
    live.allSets[0].startRest(at: noon.addingTimeInterval(5))

    try SessionLifetime.expireStale(in: context, at: noon.addingTimeInterval(3_600))

    #expect(live.state == .inProgress)
    #expect(live.restingSet != nil)
}

@MainActor
@Test("새 세션을 시작하면 남아 있던 진행 중 세션이 중단된다")
func startingClosesOpenSessions() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let open = session(named: "아까", startedAt: noon, in: context)

    try SessionLifetime.closeOpenSessions(in: context, at: noon.addingTimeInterval(600))

    #expect(open.state == .abandoned)
}

// MARK: - 안내 (F-3)

@Test("마지막 기록 후 20분이면 묻고 45분이면 선택지를 준다")
func nudgeThresholds() {
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(20 * 60)) == .asking)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(45 * 60)) == .offeringEnd)
}

@Test("19분·44분에는 아직 아니다")
func nudgeBoundaries() {
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(19 * 60)) == .none)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(44 * 60)) == .asking)
}

@MainActor
@Test("세트를 기록하면 안내가 사라진다")
func recordingClearsNudge() throws {
    // 안내 기준이 경과 시간이 아니라 무기록 시간이라는 것(D14). 세션을 한 시간 넘게
    // 하고 있어도 기록이 이어지면 아무 말도 하지 않는다.
    let container = try makeContainer()
    let session = session(named: "가슴", startedAt: noon, in: container.mainContext)
    let now = noon.addingTimeInterval(70 * 60)
    session.allSets[0].markSuccess(at: now.addingTimeInterval(-90))

    #expect(SessionLifetime.nudge(idleSince: session.lastActivityAt, at: now) == .none)
}

// MARK: - 안내 임계값 설정 (F-3)

@Test("설정한 임계값을 그대로 쓴다")
func nudgeUsesConfiguredThresholds() {
    let thresholds = NudgeThresholds(askMinutes: 10, offerEndMinutes: 30)

    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(9 * 60), thresholds: thresholds) == .none)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(10 * 60), thresholds: thresholds) == .asking)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(30 * 60), thresholds: thresholds) == .offeringEnd)
}

@Test("0 분은 그 안내를 쓰지 않는다는 뜻이다")
func zeroDisablesNudge() {
    let askOnly = NudgeThresholds(askMinutes: 20, offerEndMinutes: 0)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(3 * 3_600), thresholds: askOnly) == .asking)

    let off = NudgeThresholds(askMinutes: 0, offerEndMinutes: 0)
    #expect(SessionLifetime.nudge(idleSince: noon, at: noon.addingTimeInterval(3 * 3_600), thresholds: off) == .none)
}

@Test("끈 안내는 다시 그릴 시각도 만들지 않는다")
func disabledNudgeHasNoSchedule() {
    // `TimelineView` 가 쓰는 값이라, 끈 임계값이 남아 있으면 아무 일도 없는 시각에
    // 화면이 다시 그려진다(PRD §9 배터리).
    let off = NudgeThresholds(askMinutes: 0, offerEndMinutes: 0)
    #expect(SessionLifetime.nudgeDates(idleSince: noon, thresholds: off) == [noon])
}

@Test("저장한 적이 없으면 기본값 20·45분이다")
func storedFallsBackToDefault() throws {
    // UserDefaults 는 없는 키에 0 을 돌려준다. 그것을 "끔"으로 읽으면 아무도 설정한
    // 적 없는데 안내가 꺼진 채로 시작된다.
    let defaults = try #require(UserDefaults(suiteName: "NudgeThresholdsTests.empty"))
    defaults.removePersistentDomain(forName: "NudgeThresholdsTests.empty")

    #expect(NudgeThresholds.stored(in: defaults) == .default)
}

@Test("저장한 값을 그대로 읽는다")
func storedRoundTrips() throws {
    let defaults = try #require(UserDefaults(suiteName: "NudgeThresholdsTests.roundTrip"))
    defaults.removePersistentDomain(forName: "NudgeThresholdsTests.roundTrip")

    NudgeThresholds(askMinutes: 15, offerEndMinutes: 0).save(to: defaults)

    #expect(NudgeThresholds.stored(in: defaults) == NudgeThresholds(askMinutes: 15, offerEndMinutes: 0))
}
