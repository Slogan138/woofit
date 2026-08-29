import Foundation
import SwiftData
import Testing
@testable import WoofitCore

private func makeRoutine() -> Routine {
    let routine = Routine(name: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 1, weight: 80, reps: 5)
    return routine
}

// MARK: - isDeletable

@MainActor
@Test("완료된 세션은 삭제할 수 있다")
func completedSessionIsDeletable() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.allSets[0].markSuccess()
    session.finish()

    #expect(session.state == .completed)
    #expect(session.isDeletable)
}

@MainActor
@Test("중단된 세션도 삭제할 수 있다")
func abandonedSessionIsDeletable() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.abandon()

    #expect(session.isDeletable)
}

@MainActor
@Test("진행 중 세션은 삭제할 수 없다")
func inProgressSessionIsNotDeletable() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    #expect(session.isDeletable == false)
    #expect(throws: SessionDeletion.SessionInProgressError.self) {
        try SessionDeletion.delete(session, in: context)
    }
}

@MainActor
@Test("중단하면 삭제할 수 있게 된다")
func abandoningMakesSessionDeletable() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)

    #expect(session.isDeletable == false)
    session.abandon()
    #expect(session.isDeletable)
    #expect(throws: Never.self) {
        try SessionDeletion.delete(session, in: context)
    }
}

// MARK: - 삭제 효과

@MainActor
@Test("세션을 지우면 종목·세트도 저장소에서 사라진다")
func deletingSessionCascadesExercisesAndSets() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.abandon()
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<SessionExercise>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<SessionSet>()) == 1)

    try SessionDeletion.delete(session, in: context)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<SessionExercise>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SessionSet>()) == 0)
}

@MainActor
@Test("세션을 지워도 루틴은 남는다")
func deletingSessionKeepsRoutine() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)
    let session = WorkoutSession.start(from: routine)
    context.insert(session)
    session.abandon()
    try context.save()

    try SessionDeletion.delete(session, in: context)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
}

@MainActor
@Test("세션을 지워도 다른 세션의 직전 기록에 영향이 없다")
func deletingSessionDoesNotAffectOtherSessionsLastRecord() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    let routine = makeRoutine()
    context.insert(routine)

    let older = WorkoutSession.start(from: routine, at: Date().addingTimeInterval(-2 * 86_400))
    context.insert(older)
    older.allSets[0].markSuccess()
    older.finish()

    let newer = WorkoutSession.start(from: routine, at: Date().addingTimeInterval(-86_400))
    context.insert(newer)
    newer.allSets[0].markFailure(actualReps: 2)
    newer.finish()
    try context.save()

    try SessionDeletion.delete(newer, in: context)
    try context.save()

    let record = try LastRecordLookup.fetch(normalizedName: "벤치프레스", in: context)
    #expect(record?.performedAt == older.startedAt)
}
