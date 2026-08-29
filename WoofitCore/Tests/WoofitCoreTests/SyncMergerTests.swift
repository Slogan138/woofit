import Foundation
import SwiftData
import Testing
@testable import WoofitCore

private func makeRoutine(sets: Int = 1) -> Routine {
    let routine = Routine(name: "가슴")
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: sets, weight: 80, reps: 5)
    return routine
}

private func makeSetPayload(
    sessionID: UUID = UUID(),
    exerciseID: UUID = UUID(),
    setID: UUID = UUID(),
    result: SetResult = .success,
    actualWeight: Double? = nil,
    actualReps: Int? = nil,
    restSeconds: Double? = nil,
    recordedAt: Date
) -> SetResultPayload {
    SetResultPayload(
        sessionID: sessionID,
        routineID: nil,
        routineName: "가슴",
        category: "가슴",
        startedAt: Date(timeIntervalSince1970: 0),
        exerciseID: exerciseID,
        exerciseName: "벤치프레스",
        exerciseOrder: 0,
        setID: setID,
        order: 0,
        targetWeight: 80,
        targetReps: 5,
        result: result,
        actualWeight: actualWeight,
        actualReps: actualReps,
        restSeconds: restSeconds,
        recordedAt: recordedAt
    )
}

// MARK: - 세트 결과 병합

@MainActor
@Test("같은 세트 payload 를 두 번 병합해도 결과가 같다")
func mergingSamePayloadTwiceIsIdempotent() throws {
    let payload = makeSetPayload(result: .success, recordedAt: Date(timeIntervalSince1970: 1000))
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    try SyncMerger.merge(payload, into: context)
    try SyncMerger.merge(payload, into: context)

    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    #expect(sessions.count == 1)
    let set = try #require(sessions.first?.allSets.first)
    #expect(sessions.first?.allSets.count == 1)
    #expect(set.result == .success)
    #expect(set.recordedAt == payload.recordedAt)
}

@MainActor
@Test("recordedAt 이 나중인 payload 가 이긴다")
func laterRecordedAtWins() throws {
    let sessionID = UUID(), exerciseID = UUID(), setID = UUID()
    let earlier = makeSetPayload(
        sessionID: sessionID, exerciseID: exerciseID, setID: setID,
        result: .failure, actualReps: 3, recordedAt: Date(timeIntervalSince1970: 1000)
    )
    let later = makeSetPayload(
        sessionID: sessionID, exerciseID: exerciseID, setID: setID,
        result: .success, recordedAt: Date(timeIntervalSince1970: 2000)
    )

    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    try SyncMerger.merge(earlier, into: context)
    try SyncMerger.merge(later, into: context)

    let set = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first?.allSets.first)
    #expect(set.result == .success)
    #expect(set.recordedAt == later.recordedAt)
}

@MainActor
@Test("recordedAt 이 이전인 payload 는 무시된다")
func earlierRecordedAtIsIgnored() throws {
    let sessionID = UUID(), exerciseID = UUID(), setID = UUID()
    let later = makeSetPayload(
        sessionID: sessionID, exerciseID: exerciseID, setID: setID,
        result: .success, recordedAt: Date(timeIntervalSince1970: 2000)
    )
    let earlier = makeSetPayload(
        sessionID: sessionID, exerciseID: exerciseID, setID: setID,
        result: .failure, actualReps: 2, recordedAt: Date(timeIntervalSince1970: 1000)
    )

    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    try SyncMerger.merge(later, into: context)
    try SyncMerger.merge(earlier, into: context)

    let set = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first?.allSets.first)
    #expect(set.result == .success)
    #expect(set.recordedAt == later.recordedAt)
}

@MainActor
@Test("없는 세션의 세트 payload 가 오면 세션을 만든다")
func missingSessionIsCreatedFromPayload() throws {
    let payload = makeSetPayload(result: .success, recordedAt: Date(timeIntervalSince1970: 1000))
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    try SyncMerger.merge(payload, into: context)

    let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
    #expect(session.id == payload.sessionID)
    #expect(session.routineName == payload.routineName)
    #expect(session.allSets.count == 1)
    #expect(session.allSets.first?.id == payload.setID)
}

// MARK: - 세션 종료 스냅샷

@MainActor
@Test("종료 스냅샷 병합 결과가 세트별 병합 결과와 같다")
func snapshotMergeMatchesPerSetMerge() throws {
    let sessionID = UUID(), exerciseID = UUID()
    let firstSetID = UUID(), secondSetID = UUID()
    let payloads = [
        makeSetPayload(
            sessionID: sessionID, exerciseID: exerciseID, setID: firstSetID,
            result: .success, recordedAt: Date(timeIntervalSince1970: 1000)
        ),
        makeSetPayload(
            sessionID: sessionID, exerciseID: exerciseID, setID: secondSetID,
            result: .failure, actualReps: 3, recordedAt: Date(timeIntervalSince1970: 1010)
        )
    ]

    let viaSetsContainer = try WoofitModelContainer.makeInMemoryContainer()
    for payload in payloads {
        try SyncMerger.merge(payload, into: viaSetsContainer.mainContext)
    }

    let viaSnapshotContainer = try WoofitModelContainer.makeInMemoryContainer()
    let snapshot = SessionSnapshotPayload(
        sessionID: sessionID,
        routineID: nil,
        routineName: "가슴",
        category: "가슴",
        startedAt: Date(timeIntervalSince1970: 0),
        endedAt: Date(timeIntervalSince1970: 1010),
        state: .completed,
        sets: payloads
    )
    try SyncMerger.merge(snapshot, into: viaSnapshotContainer.mainContext)

    let setsA = try #require(
        try viaSetsContainer.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
    ).allSets.sorted { $0.id.uuidString < $1.id.uuidString }
    let setsB = try #require(
        try viaSnapshotContainer.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
    ).allSets.sorted { $0.id.uuidString < $1.id.uuidString }

    #expect(setsA.count == setsB.count)
    for (a, b) in zip(setsA, setsB) {
        #expect(a.id == b.id)
        #expect(a.result == b.result)
        #expect(a.actualReps == b.actualReps)
        #expect(a.actualWeight == b.actualWeight)
        #expect(a.recordedAt == b.recordedAt)
    }
}

// MARK: - 루틴 전송

@MainActor
@Test("루틴 전송은 전체를 교체한다")
func replacingRoutinesOverwritesExisting() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext
    context.insert(makeRoutine())

    let payload = RoutinePayload(
        id: UUID(),
        name: "하체",
        category: "하체",
        weekdayMask: 0,
        note: "",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        exercises: [
            RoutinePayload.ExercisePayload(
                id: UUID(),
                name: "스쿼트",
                order: 0,
                sets: [RoutinePayload.SetPayload(id: UUID(), order: 0, targetWeight: 100, targetReps: 5)],
                lastRecord: nil
            )
        ]
    )

    try SyncMerger.replaceRoutines(with: [payload], in: context)

    let routines = try context.fetch(FetchDescriptor<Routine>())
    #expect(routines.count == 1)
    #expect(routines.first?.name == "하체")
    #expect(routines.first?.sortedExercises.first?.name == "스쿼트")
    #expect(routines.first?.sortedExercises.first?.sortedSets.first?.targetWeight == 100)
}

@MainActor
@Test("루틴 payload 에 직전 기록이 포함된다")
func routinePayloadIncludesLastRecord() throws {
    let routine = makeRoutine()
    let exercise = routine.sortedExercises[0]
    let lastRecord = LastRecord(
        normalizedName: exercise.normalizedName,
        displayName: exercise.name,
        performedAt: Date(timeIntervalSince1970: 500),
        entries: [LastRecord.Entry(weight: 80, targetReps: 5, performedReps: 5, result: .success)]
    )

    let payload = RoutinePayload.make(from: routine, lastRecords: [exercise.normalizedName: lastRecord])

    #expect(payload.exercises.first?.lastRecord == lastRecord)
}

// MARK: - 워치 보관 정리

@MainActor
@Test("워치 보관 정리가 최근 10건과 진행 중 세션을 남긴다")
func pruneKeepsRecentTenFinishedSessions() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    for i in 0..<12 {
        let session = WorkoutSession(routineName: "가슴", startedAt: Date(timeIntervalSince1970: Double(i)))
        session.finish(at: Date(timeIntervalSince1970: Double(i) + 1))
        context.insert(session)
    }

    try WatchRetention.prune(in: context)

    let remaining = try context.fetch(FetchDescriptor<WorkoutSession>())
    #expect(remaining.count == WatchRetention.keepCount)
    #expect(!remaining.contains { $0.startedAt == Date(timeIntervalSince1970: 0) })
    #expect(!remaining.contains { $0.startedAt == Date(timeIntervalSince1970: 1) })
}

@MainActor
@Test("진행 중 세션은 10건 밖이어도 지워지지 않는다")
func pruneNeverDeletesInProgressSession() throws {
    let container = try WoofitModelContainer.makeInMemoryContainer()
    let context = container.mainContext

    // 진행 중 세션이 가장 오래됐다 — 최근순으로만 세면 10건 밖으로 밀려난다.
    let inProgress = WorkoutSession(routineName: "가슴", startedAt: Date(timeIntervalSince1970: 0))
    context.insert(inProgress)

    for i in 1...12 {
        let session = WorkoutSession(routineName: "가슴", startedAt: Date(timeIntervalSince1970: Double(i)))
        session.finish(at: Date(timeIntervalSince1970: Double(i) + 1))
        context.insert(session)
    }

    try WatchRetention.prune(in: context)

    let remaining = try context.fetch(FetchDescriptor<WorkoutSession>())
    #expect(remaining.contains { $0.id == inProgress.id })
    #expect(remaining.count == WatchRetention.keepCount + 1)
}
