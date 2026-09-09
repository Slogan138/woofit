import Testing
import Foundation
import SwiftData
@testable import WoofitCore

/// 세션 이어받기(F-8). 폰에서 시작한 세션이 워치에, 워치에서 시작한 세션이 폰에 나타나야 한다.
///
/// **이 기능은 절반만 구현된 채로 오래 남아 있었다.** `sendInProgressSession` 은 있었지만
/// 부르는 곳이 없었고, 받는 쪽도 그 키를 꺼내지 않았다. 테스트가 없어서 조용했다.
/// 아래는 화면을 거치지 않고 병합 규칙만 고정한다 — 전송 자체는 실기기에서 확인한다.

@MainActor
private func makeContainer() throws -> ModelContainer {
    try WoofitModelContainer.makeInMemoryContainer()
}

@MainActor
private func startedSession(named name: String, in context: ModelContext) -> WorkoutSession {
    let routine = Routine(name: name, category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 40, reps: 10)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    return session
}

@MainActor
@Test("다른 기기에서 시작한 세션이 그대로 반영된다")
func inProgressSessionArrives() throws {
    let container = try makeContainer()
    let source = container.mainContext
    let session = startedSession(named: "월요일 가슴", in: source)
    let payload = SessionSnapshotPayload.make(for: session)

    // 받는 쪽 — 아직 이 세션을 모른다. **컨테이너를 잡아둔다** — `mainContext` 만 받으면
    // 컨테이너가 해제되면서 컨텍스트가 함께 무너진다.
    let targetContainer = try makeContainer()
    let target = targetContainer.mainContext
    #expect(try target.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)

    try SyncMerger.mergeInProgress(payload, into: target)

    let merged = try #require(try target.fetch(FetchDescriptor<WorkoutSession>()).first)
    #expect(merged.id == session.id)
    #expect(merged.routineName == "월요일 가슴")
    #expect(merged.state == .inProgress)
    #expect(merged.totalSetCount == 3)
}

@MainActor
@Test("이미 받은 세션이 다시 와도 중복되지 않는다")
func mergingTwiceKeepsOneSession() throws {
    let container = try makeContainer()
    let session = startedSession(named: "월요일 가슴", in: container.mainContext)
    let payload = SessionSnapshotPayload.make(for: session)

    let targetContainer = try makeContainer()
    let target = targetContainer.mainContext
    try SyncMerger.mergeInProgress(payload, into: target)
    try SyncMerger.mergeInProgress(payload, into: target)

    #expect(try target.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
}

@MainActor
@Test("상대가 세션을 끝내면 그 상태까지 따라온다")
func finishedStateArrives() throws {
    let container = try makeContainer()
    let session = startedSession(named: "월요일 가슴", in: container.mainContext)

    let targetContainer = try makeContainer()
    let target = targetContainer.mainContext
    try SyncMerger.mergeInProgress(SessionSnapshotPayload.make(for: session), into: target)

    // 세트를 남긴 채 끝내면 중단으로 기록되므로(기존 규칙) 전부 기록한 뒤 끝낸다.
    for set in session.allSets { set.markSuccess() }
    session.finish()
    try SyncMerger.mergeInProgress(SessionSnapshotPayload.make(for: session), into: target)

    let merged = try #require(try target.fetch(FetchDescriptor<WorkoutSession>()).first)
    #expect(merged.state == .completed)
}

@MainActor
@Test("남아 있던 다른 진행 중 세션은 지워지지 않고 중단으로 남는다")
func staleSessionIsAbandonedNotDeleted() throws {
    // 두 기기에서 동시에 시작하는 일은 없다는 전제지만, 어긋났을 때 기록이 조용히
    // 사라지는 것이 이 앱에서 가장 나쁜 결과다. 중단으로 남으면 목록에서 확인할 수 있다.
    let container = try makeContainer()
    let target = container.mainContext
    let local = startedSession(named: "로컬 세션", in: target)
    let localID = local.id

    let otherContainer = try makeContainer()
    let incoming = startedSession(named: "다른 기기 세션", in: otherContainer.mainContext)
    try SyncMerger.mergeInProgress(SessionSnapshotPayload.make(for: incoming), into: target)

    let all = try target.fetch(FetchDescriptor<WorkoutSession>())
    #expect(all.count == 2)
    let stale = try #require(all.first { $0.id == localID })
    #expect(stale.state == .abandoned)
    let arrived = try #require(all.first { $0.id == incoming.id })
    #expect(arrived.state == .inProgress)
}

@MainActor
@Test("이어받은 세션에 기록한 세트가 상대에게 반영된다")
func recordedSetsArrive() throws {
    let container = try makeContainer()
    let session = startedSession(named: "월요일 가슴", in: container.mainContext)

    let targetContainer = try makeContainer()
    let target = targetContainer.mainContext
    try SyncMerger.mergeInProgress(SessionSnapshotPayload.make(for: session), into: target)

    let first = try #require(session.allSets.first)
    first.markSuccess()
    try SyncMerger.mergeInProgress(SessionSnapshotPayload.make(for: session), into: target)

    let merged = try #require(try target.fetch(FetchDescriptor<WorkoutSession>()).first)
    #expect(merged.recordedSetCount == 1)
}

// MARK: - 옛 컨텍스트 재병합 (F-8, F-5)

/// `updateApplicationContext` 로 받은 것은 상대 기기에 계속 남아 있고, 앱이 앞으로 나올
/// 때마다(`consumeReceivedContext`) 다시 읽힌다. **손목을 올릴 때마다 같은 옛 스냅샷이
/// 병합된다**는 뜻이라, 그 병합이 지금 진행 중인 세션을 건드리면 안 된다.

@MainActor
@Test("끝난 세션 스냅샷이 도착해도 진행 중인 세션은 중단되지 않는다")
func finishedSnapshotDoesNotAbandonLiveSession() throws {
    let container = try makeContainer()
    let context = container.mainContext

    // 폰이 마지막으로 보낸 컨텍스트가 이미 끝난 세션일 수 있다.
    let previous = startedSession(named: "아침 가슴", in: context)
    for set in previous.allSets { set.markSuccess() }
    previous.finish()
    let stale = SessionSnapshotPayload.make(for: previous)

    let live = startedSession(named: "저녁 가슴", in: context)

    try SyncMerger.mergeInProgress(stale, into: context)

    #expect(live.state == .inProgress)
}

@MainActor
@Test("먼저 시작한 세션이 도착해도 나중에 시작한 진행 중 세션이 이긴다")
func olderInProgressSnapshotDoesNotAbandonNewerSession() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let routine = Routine(name: "가슴", category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 40, reps: 10)

    let earlier = WorkoutSession.start(from: routine, at: Date().addingTimeInterval(-3_600))
    context.insert(earlier)
    let payload = SessionSnapshotPayload.make(for: earlier)

    let later = WorkoutSession.start(from: routine)
    context.insert(later)

    try SyncMerger.mergeInProgress(payload, into: context)

    #expect(later.state == .inProgress)
    #expect(earlier.state == .inProgress)
}

@MainActor
@Test("옛 컨텍스트를 다시 병합해도 재던 휴식이 멈추지 않는다")
func staleContextKeepsRestRunning() throws {
    // 손목을 내렸다 올리면 휴식 타이머가 리셋되던 버그. 세션이 중단 처리되면서
    // `abandon()` 이 휴식 측정을 함께 끝냈고, 다음 세트를 기록하면 `reopen()` 으로
    // 되살아나 세션은 멀쩡해 보이고 타이머만 사라진 것처럼 보였다(F-5).
    let container = try makeContainer()
    let context = container.mainContext

    let previous = startedSession(named: "아침 가슴", in: context)
    for set in previous.allSets { set.markSuccess() }
    previous.finish()
    let stale = SessionSnapshotPayload.make(for: previous)

    let live = startedSession(named: "저녁 가슴", in: context)
    let runner = SessionRunner(session: live)
    let now = Date()
    runner.recordSuccess(for: live.allSets[0], at: now)
    runner.toggleRest(at: now.addingTimeInterval(2))

    try SyncMerger.mergeInProgress(stale, into: context)

    #expect(runner.restingSet != nil)
    #expect(live.allSets[0].restSeconds == nil)
}
