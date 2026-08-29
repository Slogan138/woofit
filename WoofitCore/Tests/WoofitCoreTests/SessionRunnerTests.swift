import Foundation
import SwiftData
import Testing
@testable import WoofitCore

private func makeRoutine(sets: Int = 2) -> Routine {
    let routine = Routine(name: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: sets, weight: 80, reps: 5)
    return routine
}

/// 종목 두 개(각 `setsPerExercise` 세트)짜리 루틴. 전환 테스트용.
private func makeTwoExerciseRoutine(setsPerExercise: Int = 1) -> Routine {
    let routine = Routine(name: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: setsPerExercise, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "펙덱플라이")
    fly.appendSets(count: setsPerExercise, weight: 40, reps: 10)
    return routine
}

/// 종목 세 개(각 1세트)짜리 루틴. 임의 이동 테스트용.
private func makeThreeExerciseRoutine() -> Routine {
    let routine = Routine(name: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 1, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "펙덱플라이")
    fly.appendSets(count: 1, weight: 40, reps: 10)
    let dip = routine.appendExercise(named: "딥스")
    dip.appendSets(count: 1, weight: 0, reps: 12)
    return routine
}

// MARK: - 초점 진행

@MainActor
@Test("성공을 기록하면 다음 세트로 초점이 옮겨간다")
func recordingSuccessAdvancesFocus() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let first = try #require(runner.focusedSet)
    runner.recordSuccess()

    #expect(first.result == .success)
    #expect(runner.focusedSet?.id == session.allSets[1].id)
}

@MainActor
@Test("마지막 세트를 기록하면 종목이 완료되고 초점을 잃는다")
func recordingLastSetCompletesExercise() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.recordSuccess()

    #expect(session.currentExercise == nil)
    #expect(runner.focusedSet == nil)
}

// MARK: - D1 불변식

@MainActor
@Test("실패 기록은 실제 횟수를 함께 남긴다")
func recordFailureCarriesActualReps() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let target = try #require(runner.focusedSet)
    runner.recordFailure(actualReps: 3, actualWeight: 70)

    #expect(target.result == .failure)
    #expect(target.actualReps == 3)
    #expect(target.performedWeight == 70)
}

@MainActor
@Test("실패 입력을 취소하면 세트가 pending 으로 남는다")
func cancellingFailureInputLeavesSetPending() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    // 실패 시트를 열었다가 recordFailure 를 호출하지 않고 닫은 경우를 흉내낸다.
    let runner = SessionRunner(session: session)
    let target = try #require(runner.focusedSet)

    #expect(target.result == .pending)
    #expect(runner.focusedSet?.id == target.id)
}

// MARK: - 되돌리기

@MainActor
@Test("기록을 되돌리면 다시 pending 이 되지만 측정된 휴식 시간은 남는다")
func undoRestoresPendingButKeepsRest() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let target = try #require(runner.focusedSet)
    target.restSeconds = 90
    runner.recordSuccess()

    runner.undo(target)

    #expect(target.result == .pending)
    #expect(target.restSeconds == 90)
}

@MainActor
@Test("되돌린 세트가 가장 앞이 아니어도 그 세트로 초점이 옮겨간다")
func undoRefocusesTheUndoneSetEvenWhenNotEarliestPending() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 4)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    // 세트 1·2·4 기록, 3은 pending 으로 남긴다.
    let sets = session.allSets
    sets[0].markSuccess()
    sets[1].markSuccess()
    sets[3].markSuccess()

    let runner = SessionRunner(session: session)
    runner.undo(sets[3])

    #expect(runner.focusedSet?.id == sets[3].id)
}

@MainActor
@Test("되돌리면 그 세트로 초점이 다시 옮겨간다")
func undoRefocusesTheUndoneSet() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let first = try #require(runner.focusedSet)
    runner.recordSuccess()
    #expect(runner.focusedSet?.id == session.allSets[1].id)

    runner.undo(first)

    #expect(runner.focusedSet?.id == first.id)
}

@MainActor
@Test("마지막 세트를 되돌리면 화면이 완료 상태에 머무르지 않는다")
func undoingLastSetRefocusesEvenAfterCompletion() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let target = try #require(runner.focusedSet)
    runner.recordSuccess()
    #expect(runner.focusedSet == nil)

    runner.undo(target)

    #expect(runner.focusedSet?.id == target.id)
}

@MainActor
@Test("가장 최근에 기록한 세트를 워치 화면에서 되돌릴 수 있다")
func lastRecordedSetTracksMostRecentRecordAndClearsOnUndo() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    #expect(runner.lastRecordedSet == nil)

    let first = try #require(runner.focusedSet)
    runner.recordSuccess()
    #expect(runner.lastRecordedSet?.id == first.id)

    runner.undo(first)
    #expect(runner.lastRecordedSet == nil)
}

// MARK: - 일시정지·재개·중단

@MainActor
@Test("일시정지하면 pausedAt 이 남고, 재개하면 지워진다")
func pauseAndResumeRoundTrip() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let pausedAt = Date()
    runner.pause(at: pausedAt)

    #expect(runner.isPaused)
    #expect(session.pausedAt == pausedAt)
    #expect(session.state == .inProgress)

    runner.resume()

    #expect(runner.isPaused == false)
    #expect(session.pausedAt == nil)
}

@MainActor
@Test("중단한 세션은 abandoned 로 남고 일시정지 표시는 지워진다")
func abandonClearsAndRecordsAsAbandoned() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.pause()
    runner.abandon()

    #expect(session.state == .abandoned)
    #expect(session.pausedAt == nil)
}

// MARK: - 세션 복원

@MainActor
@Test("앱 재시작 시 진행 중 세션을 찾아 이어받는다")
func restoreFindsInProgressSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.allSets[0].markSuccess()

    let restored = try #require(try SessionRestore.fetchInProgress(in: context))
    #expect(restored.id == session.id)
}

@MainActor
@Test("일시정지 중이어도 복원 대상에 포함된다")
func restoreFindsPausedSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.pause()

    let restored = try SessionRestore.fetchInProgress(in: context)
    #expect(restored?.id == session.id)
}

@MainActor
@Test("진행 중 세션이 없으면 복원 결과가 nil 이다")
func restoreIsNilWhenNothingInProgress() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.allSets[0].markSuccess()
    session.finish()

    let restored = try SessionRestore.fetchInProgress(in: context)
    #expect(restored == nil)
}

// MARK: - 전환 상태 (F-4)

@MainActor
@Test("마지막 세트를 기록하면 phase 가 다음 종목으로 전환된다")
func recordingLastSetOfExerciseTransitionsPhase() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let bench = session.sortedExercises[0]
    let fly = session.sortedExercises[1]
    #expect(runner.phase == .recording(bench))

    runner.recordSuccess()

    #expect(runner.phase == .transition(from: bench, to: fly))
}

@MainActor
@Test("건너뛴 세트만 남아도 종목은 완료로 쳐서 전환된다")
func skippedSetsStillCompleteExerciseForTransition() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.skip()

    let bench = session.sortedExercises[0]
    let fly = session.sortedExercises[1]
    #expect(runner.phase == .transition(from: bench, to: fly))
}

@MainActor
@Test("마지막 종목을 끝내면 phase 가 finished 가 된다")
func finishingLastExerciseSetsPhaseToFinished() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.recordSuccess()
    runner.recordSuccess()

    #expect(runner.phase == .finished)
}

@MainActor
@Test("전환 화면으로 넘어간 뒤에도 직전 종목의 마지막 세트를 되돌리면 그 종목 기록 화면으로 돌아온다")
func undoingLastSetAfterTransitionReturnsToRecordingPhase() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let bench = session.sortedExercises[0]
    let fly = session.sortedExercises[1]
    let benchSet = try #require(bench.sortedSets.first)
    runner.recordSuccess()
    #expect(runner.phase == .transition(from: bench, to: fly))

    runner.undo(benchSet)

    #expect(runner.phase == .recording(bench))
}

@MainActor
@Test("임의 이동으로 순서상 다음 종목을 먼저 끝내도 아직 안 끝난 종목으로 전환된다")
func completingOutOfOrderExerciseTransitionsToRemainingIncompleteExercise() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let bench = session.sortedExercises[0]
    let fly = session.sortedExercises[1]
    let flySet = try #require(fly.sortedSets.first)

    // 벤치프레스를 미룬 채 순서를 무시하고 펙덱플라이부터 끝낸다.
    runner.focus(on: flySet)
    #expect(runner.phase == .recording(fly))
    runner.recordSuccess()

    #expect(runner.phase == .transition(from: fly, to: bench))
}

@MainActor
@Test("전환 상태가 다음 종목의 세트 수와 목표를 담는다")
func transitionPhaseCarriesNextExerciseSetsAndTargets() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeTwoExerciseRoutine(setsPerExercise: 2)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.recordSuccess()
    runner.recordSuccess()

    guard case .transition(_, let to) = runner.phase else {
        Issue.record("phase 가 transition 이 아니다: \(runner.phase)")
        return
    }
    #expect(to.sortedSets.count == 2)
    #expect(to.uniformTarget?.weight == 40)
    #expect(to.uniformTarget?.reps == 10)
}

@MainActor
@Test("마지막 세트를 기록하면 세션이 자동으로 완료 처리된다")
func recordingLastSetOfSessionAutoFinishesSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    runner.recordSuccess()

    #expect(runner.phase == .finished)
    #expect(session.state == .completed)
    #expect(session.endedAt != nil)
}

@MainActor
@Test("자동 완료 뒤 마지막 세트를 되돌리면 세션이 다시 진행 중이 된다")
func undoingAfterAutoFinishReopensSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let target = try #require(runner.focusedSet)
    runner.recordSuccess()
    #expect(session.state == .completed)

    runner.undo(target)

    #expect(session.state == .inProgress)
    #expect(session.endedAt == nil)
    #expect(runner.phase == .recording(session.sortedExercises[0]))
}

@MainActor
@Test("순서를 건너뛰어 3번째 종목으로 이동할 수 있다")
func canJumpDirectlyToThirdExerciseOutOfOrder() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeThreeExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let dip = session.sortedExercises[2]
    let dipSet = try #require(dip.nextPendingSet)

    runner.focus(on: dipSet)

    #expect(runner.focusedSet?.id == dipSet.id)
    #expect(runner.phase == .recording(dip))
}

@MainActor
@Test("이동 후 미완료 종목으로 돌아올 수 있다")
func canReturnToAnIncompleteExerciseAfterJumping() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeThreeExerciseRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    let runner = SessionRunner(session: session)
    let bench = session.sortedExercises[0]
    let dip = session.sortedExercises[2]
    let dipSet = try #require(dip.nextPendingSet)

    runner.focus(on: dipSet)
    #expect(runner.phase == .recording(dip))

    let benchSet = try #require(bench.nextPendingSet)
    runner.focus(on: benchSet)

    #expect(runner.focusedSet?.id == benchSet.id)
    #expect(runner.phase == .recording(bench))
}

// MARK: - 직전 기록 연동 (F-9)

@MainActor
@Test("초점을 둔 세트의 종목으로 직전 기록을 찾는다")
func focusedLastRecordLooksUpByExercise() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine(sets: 1)
    context.insert(routine)
    let past = WorkoutSession.start(from: routine, at: Date().addingTimeInterval(-86_400))
    context.insert(past)
    past.allSets[0].markSuccess()
    past.finish()

    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    let lastRecords = try LastRecordLookup.fetchAll(for: session, in: context)

    let runner = SessionRunner(session: session, lastRecords: lastRecords)
    #expect(runner.focusedLastRecord?.succeededAllSets == true)
}
