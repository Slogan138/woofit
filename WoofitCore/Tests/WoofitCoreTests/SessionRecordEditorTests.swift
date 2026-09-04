import Testing
import Foundation
import SwiftData
@testable import WoofitCore

/// 끝난 세션의 기록 수정(F-15). 고친 값이 직전 기록·추이·무게 제안에 그대로 반영되어야 한다.

@MainActor
private func makeContainer() throws -> ModelContainer {
    try WoofitModelContainer.makeInMemoryContainer()
}

/// 벤치프레스 3세트를 전부 성공으로 마친 완료 세션.
@MainActor
private func completedSession(in context: ModelContext) -> WorkoutSession {
    let routine = Routine(name: "가슴", category: "가슴")
    context.insert(routine)
    routine.appendExercise(named: "벤치프레스").appendSets(count: 3, weight: 40, reps: 10)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    for set in session.allSets { set.markSuccess() }
    session.finish()
    return session
}

@MainActor
@Test("성공을 실패로 고치면 실제 횟수가 함께 남는다")
func editSuccessToFailure() throws {
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.last)

    SessionRecordEditor.apply(.failure(actualReps: 7, actualWeight: nil), to: set)

    #expect(set.result == .failure)
    #expect(set.actualReps == 7)
    #expect(set.performedReps == 7)
}

@MainActor
@Test("성공에도 실제로 든 무게를 남길 수 있다")
func editSuccessWeight() throws {
    // 계획과 다른 무게로 성공한 경우. 볼륨(F-10)이 수행값을 쓰므로 이 값이 필요하다.
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.first)

    SessionRecordEditor.apply(.success(actualWeight: 42.5), to: set)

    #expect(set.result == .success)
    #expect(set.performedWeight == 42.5)
    #expect(set.targetWeight == 40)
}

@MainActor
@Test("실패를 성공으로 되돌리면 실제 횟수가 지워진다")
func editFailureBackToSuccess() throws {
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.first)
    SessionRecordEditor.apply(.failure(actualReps: 5, actualWeight: nil), to: set)

    SessionRecordEditor.apply(.success(actualWeight: nil), to: set)

    #expect(set.result == .success)
    #expect(set.actualReps == nil)
    #expect(set.performedReps == set.targetReps)
}

@MainActor
@Test("수정해도 세션 상태는 그대로다")
func editingKeepsSessionState() throws {
    // 완료된 세션을 진행 중으로 되돌리면 워치로 릴레이되어 지금 운동 중인 것처럼
    // 보인다(PRD D13). 수정은 세션 상태를 건드리지 않는다.
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.first)

    SessionRecordEditor.apply(.skipped, to: set)

    #expect(session.state == .completed)
}

@MainActor
@Test("수정한 세트는 기록 시각이 갱신된다")
func editingUpdatesRecordedAt() throws {
    // 동기화에서 이 값이 최신으로 이겨야 상대 기기의 옛 값이 수정을 덮어쓰지 않는다(F-8).
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.first)
    let before = try #require(set.recordedAt)

    SessionRecordEditor.apply(.skipped, to: set, at: before.addingTimeInterval(60))

    #expect(try #require(set.recordedAt) > before)
}

@MainActor
@Test("고친 값이 직전 기록에 반영된다")
func editingChangesLastRecord() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let session = completedSession(in: context)
    let set = try #require(session.allSets.last)

    SessionRecordEditor.apply(.failure(actualReps: 6, actualWeight: nil), to: set)

    let records = try LastRecordLookup.fetchAll(for: session, in: context)
    let record = try #require(records["벤치프레스"])
    #expect(record.succeededAllSets == false)
}

@MainActor
@Test("현재 기록을 수정 폼의 초기값으로 그대로 옮긴다")
func currentChangeMirrorsSet() throws {
    let container = try makeContainer()
    let session = completedSession(in: container.mainContext)
    let set = try #require(session.allSets.first)

    #expect(SessionRecordEditor.currentChange(of: set) == .success(actualWeight: nil))

    SessionRecordEditor.apply(.failure(actualReps: 7, actualWeight: 35), to: set)
    #expect(SessionRecordEditor.currentChange(of: set) == .failure(actualReps: 7, actualWeight: 35))
}
