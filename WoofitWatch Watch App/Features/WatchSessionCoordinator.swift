import Foundation
import SwiftData
import WoofitCore

/// 워치의 세션 실행 진입점. 폰의 `SessionCoordinator` 와 같은 구조다 — 같은 문제라서 같은 모양으로 둔다.
///
/// **루트가 세션을 소유해야 하는 이유**는 폰에서 넘어온 세션 때문이다(F-8). 루틴 미리보기가
/// 세션을 들고 있으면, 폰에서 시작한 세션을 워치가 받아도 열어줄 화면이 없다.
@MainActor
@Observable
final class WatchSessionCoordinator {
    var activeRunner: SessionRunner?

    /// 워치에서 세션을 새로 시작한다. 폰이 곧바로 이어받도록 진행 상태도 보낸다(F-8).
    func start(
        from routine: Routine,
        in context: ModelContext,
        syncService: WatchSyncService?,
        workoutSessionController: WorkoutSessionController?
    ) {
        let session = WorkoutSession.start(from: routine)
        context.insert(session)
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: context)) ?? [:]
        )
        // 기록할 세트가 없으면 운동 세션을 시작하지 않는다 — phase 가 변하지 않아
        // 종료를 부르는 onChange 가 영영 안 터진다(계획 17).
        if session.hasRecordableSets {
            Task { await workoutSessionController?.start() }
        }
        try? syncService?.sendInProgressSession(SessionSnapshotPayload.make(for: session))
    }

    /// 진행 중인 세션이 있으면 이어받는다. 앱 시작 시와 폰에서 세션이 도착했을 때 부른다.
    ///
    /// **운동 세션(F-14)은 시작하지 않는다.** 며칠 전 중단된 세션이 복원될 수도 있어,
    /// 그때 시작하면 건강 앱에 몇 시간짜리 유령 운동이 남는다(계획 17).
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
