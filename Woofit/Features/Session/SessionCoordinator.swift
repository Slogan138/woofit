import Foundation
import SwiftData
import WoofitCore

/// 세션 실행 화면을 어디서든(루틴 상세, 앱 시작 복원) 띄우기 위한 진입점.
/// `RootView` 가 이 값을 들고 `fullScreenCover` 를 연다(F-3).
@Observable
final class SessionCoordinator {
    var activeRunner: SessionRunner?

    /// 루틴에서 세션을 새로 시작한다.
    func start(from routine: Routine, in context: ModelContext) {
        let session = WorkoutSession.start(from: routine)
        context.insert(session)
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: context)) ?? [:]
        )
    }

    /// 앱 시작 시 진행 중이던 세션이 있으면 이어받는다. 이미 실행 중이면 건드리지 않는다.
    func restoreIfNeeded(in context: ModelContext) {
        guard activeRunner == nil else { return }
        guard let session = try? SessionRestore.fetchInProgress(in: context) else { return }
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: context)) ?? [:]
        )
    }

    func endSession() {
        activeRunner = nil
    }
}
