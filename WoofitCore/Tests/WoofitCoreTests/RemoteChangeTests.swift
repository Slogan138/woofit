import Testing
import Foundation
import SwiftData
@testable import WoofitCore

/// 상대 기기에서 온 변경을 러너가 따라가는가(F-8).
///
/// `refreshPhase` 는 로컬 조작에서만 불린다. 그래서 같은 종목 안에서는 결과가 반영되는데
/// **상대가 종목을 넘어가면 따라가지 못했다.** 아래는 그 경계를 고정한다.

@MainActor
private func makeContainer() throws -> ModelContainer {
    try WoofitModelContainer.makeInMemoryContainer()
}

/// 종목 두 개짜리 세션. 각 종목에 세트 두 개.
@MainActor
private func twoExerciseSession(in context: ModelContext) -> WorkoutSession {
    let routine = Routine(name: "가슴", category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 2, weight: 40, reps: 10)
    routine.appendExercise(named: "펙덱 플라이").appendSets(count: 2, weight: 30, reps: 15)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    return session
}

@MainActor
@Test("상대가 종목을 끝내면 러너가 다음 종목으로 따라간다")
func remoteChangeAdvancesToNextExercise() throws {
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    let first = try #require(session.sortedExercises.first)
    #expect(runner.phase == .recording(first))

    // 상대 기기가 첫 종목을 전부 기록했다 — 이쪽 러너를 거치지 않는다.
    for set in first.sortedSets { set.markSuccess() }
    // 이 시점에는 아직 이전 종목을 기록 중으로 알고 있다.
    #expect(runner.phase == .recording(first))

    runner.refreshFromRemoteChange()

    let second = try #require(session.sortedExercises.last)
    #expect(runner.phase == .recording(second))
    #expect(runner.focusedSet?.exercise?.id == second.id)
}

@MainActor
@Test("같은 종목 안에서는 남은 세트로 초점이 옮겨간다")
func remoteChangeMovesFocusWithinExercise() throws {
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    let first = try #require(session.sortedExercises.first)
    let sets = first.sortedSets
    sets[0].markSuccess()

    runner.refreshFromRemoteChange()

    #expect(runner.phase == .recording(first))
    #expect(runner.focusedSet?.id == sets[1].id)
}

@MainActor
@Test("상대가 세션을 끝내면 러너도 완료로 간다")
func remoteChangeFinishesSession() throws {
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    for set in session.allSets { set.markSuccess() }
    runner.refreshFromRemoteChange()

    #expect(runner.phase == .finished)
    #expect(session.state == .completed)
}

@MainActor
@Test("상대가 되돌리면 그 세트로 돌아간다")
func remoteChangeFollowsUndo() throws {
    // 되돌리기도 상대 기기에서 일어날 수 있다. 남은 첫 세트를 다시 잡으므로 따라가야 한다.
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    let first = try #require(session.sortedExercises.first)
    for set in first.sortedSets { set.markSuccess() }
    runner.refreshFromRemoteChange()

    // 상대가 첫 종목의 두 번째 세트를 되돌렸다.
    first.sortedSets[1].clearResult()
    runner.refreshFromRemoteChange()

    #expect(runner.phase == .recording(first))
    #expect(runner.focusedSet?.id == first.sortedSets[1].id)
}

// MARK: - 종료 릴레이 (F-8)

@MainActor
@Test("상대가 중단한 세션을 되살리지 않는다")
func remoteChangeDoesNotReopenAbandoned() throws {
    // refreshPhase 는 남은 세트가 있으면 reopen() 을 부른다 — 로컬에서 마지막 세트를
    // 되돌린 경우를 위한 경로다. 중단이 도착했을 때 그 경로를 타면 다시 진행 중이 되고,
    // 그 상태가 상대 기기로 되돌아가 중단이 풀린다.
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    // 상대가 세트를 남긴 채 중단했다.
    session.abandon()
    runner.refreshFromRemoteChange()

    #expect(session.state == .abandoned)
    #expect(runner.phase == .finished)
}

@MainActor
@Test("상대가 완료한 세션도 되살리지 않는다")
func remoteChangeDoesNotReopenCompleted() throws {
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    for set in session.allSets { set.markSuccess() }
    session.finish()
    runner.refreshFromRemoteChange()

    #expect(session.state == .completed)
    #expect(runner.phase == .finished)
}

@MainActor
@Test("로컬에서 마지막 세트를 되돌리는 경로는 그대로 세션을 다시 연다")
func localUndoStillReopens() throws {
    // 위 두 테스트가 막은 것은 원격 경로다. 로컬 되돌리기는 계속 reopen 되어야 한다(F-3).
    let container = try makeContainer()
    let session = twoExerciseSession(in: container.mainContext)
    let runner = SessionRunner(session: session)

    for set in session.allSets { runner.recordSuccess(for: set) }
    #expect(session.state == .completed)

    let last = try #require(session.allSets.last)
    runner.undo(last)

    #expect(session.state == .inProgress)
}
