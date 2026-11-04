import Foundation
import SwiftData
import Testing
@testable import WoofitCore

@MainActor
@Test("삭제 후 과거 진행 상태·종료 스냅샷·세트 결과가 와도 세션은 되살아나지 않는다")
func deletedSessionIgnoresEveryChannel() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext
    let routine = Routine(name: "수요일")
    context.insert(routine)
    routine.appendExercise(named: "스쿼트").appendSets(count: 2, weight: 60, reps: 10)
    let deleted = WorkoutSession.start(from: routine)
    context.insert(deleted)
    let progress = SessionSnapshotPayload.make(for: deleted)
    deleted.allSets[0].markSuccess()
    let set = try #require(SetResultPayload.make(for: deleted.allSets[0]))
    deleted.abandon()
    let ended = SessionSnapshotPayload.make(for: deleted)
    try SessionDeletion.delete(deleted, in: context)
    let completed = WorkoutSession.start(from: routine)
    context.insert(completed)
    for set in completed.allSets { set.markSuccess() }
    completed.finish()
    let active = WorkoutSession.start(from: routine, at: progress.startedAt.addingTimeInterval(-60))
    context.insert(active)
    try context.save()
    try SyncMerger.mergeInProgress(progress, into: context)
    try SyncMerger.merge(ended, into: context)
    try SyncMerger.merge(set, into: context)
    try context.save()
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    #expect(sessions.count == 2)
    #expect(!sessions.contains { $0.id == progress.sessionID })
    #expect(completed.state == .completed)
    #expect(completed.recordedSetCount == 2)
    #expect(active.state == .inProgress)
    #expect(try context.fetchCount(FetchDescriptor<SessionSet>()) == 4)
}

@MainActor
@Test("기존 저장소를 갱신하고 삭제한 뒤 재개방해도 과거 세션은 재생성되지 않는다")
func deletionSurvivesStoreReopeningAndMigration() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "sessions.store")
    let oldSchema = Schema([Routine.self, PlannedExercise.self, PlannedSet.self,
                            WorkoutSession.self, SessionExercise.self, SessionSet.self])

    func seedOldStore() throws -> SessionSnapshotPayload {
        let container = try ModelContainer(for: oldSchema, configurations:
            ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        let routine = Routine(name: "수요일")
        context.insert(routine)
        routine.appendExercise(named: "스쿼트").appendSets(count: 1, weight: 60, reps: 10)
        let session = WorkoutSession.start(from: routine)
        context.insert(session)
        let payload = SessionSnapshotPayload.make(for: session)
        session.abandon()
        try context.save()
        return payload
    }
    func openUpdatedStore() throws -> ModelContainer {
        let schema = WoofitModelContainer.schema
        return try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    }
    func deleteFromUpdatedStore() throws {
        let container = try openUpdatedStore()
        let context = container.mainContext
        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(session.totalSetCount == 1)
        try SessionDeletion.delete(session, in: context)
    }

    let payload = try seedOldStore()
    try deleteFromUpdatedStore()
    let reopened = try openUpdatedStore()
    let context = reopened.mainContext
    #expect(try context.fetchCount(FetchDescriptor<DeletedSession>()) == 1)
    #expect(try SyncMerger.mergeInProgress(payload, into: context) == false)
    #expect(try SyncMerger.merge(payload, into: context) == false)
    #expect(try SyncMerger.merge(payload.sets[0], into: context) == nil)
    #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SessionSet>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
}

@MainActor
@Test("진행 중 삭제를 거부하면 삭제 이력도 남기지 않는다")
func rejectedDeletionDoesNotBlockSync() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext
    let session = WorkoutSession(routineName: "수요일")
    context.insert(session)
    #expect(throws: SessionDeletion.SessionInProgressError.self) {
        try SessionDeletion.delete(session, in: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<DeletedSession>()) == 0)
    #expect(try SyncMerger.merge(SessionSnapshotPayload.make(for: session), into: context))
}
