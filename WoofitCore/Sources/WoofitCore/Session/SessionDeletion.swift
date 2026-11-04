import Foundation
import SwiftData

/// 세션 기록 삭제(F-12, D7).
public enum SessionDeletion {
    /// 진행 중인 세션을 지우려는 시도. 먼저 `abandon()` 으로 중단해야 한다.
    public struct SessionInProgressError: Error {}

    /// 세션을 지운다. `SessionExercise`·`SessionSet` 은 `deleteRule: .cascade` 라 함께 지워진다.
    public static func delete(_ session: WorkoutSession, in context: ModelContext) throws {
        guard session.isDeletable else { throw SessionInProgressError() }
        // 삭제와 이력을 함께 저장해야 앱 재시작 후에도 과거 수신이 세션을 되살리지 않는다.
        if try !contains(session.id, in: context) {
            context.insert(DeletedSession(sessionID: session.id))
        }
        context.delete(session)
        try context.save()
    }

    static func contains(_ sessionID: UUID, in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<DeletedSession>(predicate: #Predicate { $0.sessionID == sessionID })
        return try context.fetchCount(descriptor) > 0
    }
}
