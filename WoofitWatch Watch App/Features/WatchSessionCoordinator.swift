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
        // 남아 있던 진행 중 세션을 먼저 정리한다(계획 21). 상대 기기에서 새 세션이
        // 도착할 때 `SyncMerger` 가 하는 것과 같은 일을 로컬 시작 경로에서도 한다.
        _ = try? SessionLifetime.closeOpenSessions(in: context)
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
    /// **이어받은 세션도 운동 세션(F-14)을 시작한다.** 계획 17 이 이 경로를 막아둔 것은
    /// 며칠 전 세션이 복원돼 건강 앱에 몇 시간짜리 유령 운동이 남는 것을 막기 위해서였다.
    /// `fetchInProgress` 가 날이 바뀐 세션을 중단으로 정리하게 된 지금은 그 전제가
    /// 사라졌고(PRD D14), 켜지 않으면 이어받기로 운동하는 내내 워치 앱이 휴식마다
    /// 내려간다 — 그것이 끝나지 않은 세션이 쌓이는 주된 경로였다(계획 21).
    func restoreIfNeeded(in context: ModelContext, workoutSessionController: WorkoutSessionController? = nil) {
        guard activeRunner == nil else { return }
        guard let session = try? SessionRestore.fetchInProgress(in: context) else { return }
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: context)) ?? [:]
        )
        if session.hasRecordableSets {
            Task { await workoutSessionController?.start() }
        }
    }

    func endSession() {
        activeRunner = nil
    }
}
