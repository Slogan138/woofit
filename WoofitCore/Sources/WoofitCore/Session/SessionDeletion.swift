import SwiftData

/// 세션 기록 삭제(F-12, D7).
public enum SessionDeletion {
    /// 진행 중인 세션을 지우려는 시도. 먼저 `abandon()` 으로 중단해야 한다.
    public struct SessionInProgressError: Error {}

    /// 세션을 지운다. `SessionExercise`·`SessionSet` 은 `deleteRule: .cascade` 라 함께 지워진다.
    public static func delete(_ session: WorkoutSession, in context: ModelContext) throws {
        guard session.isDeletable else { throw SessionInProgressError() }
        context.delete(session)
    }
}
