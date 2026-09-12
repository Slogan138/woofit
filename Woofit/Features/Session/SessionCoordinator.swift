import Foundation
import SwiftData
import WoofitCore

/// 세션 실행 화면을 어디서든(루틴 상세, 앱 시작 복원) 띄우기 위한 진입점.
/// `RootView` 가 이 값을 들고 `fullScreenCover` 를 연다(F-3).
// 화면에서만 쓰이고 `WatchSyncService`(@MainActor)를 부르므로 메인 액터에 둔다.
@MainActor
@Observable
final class SessionCoordinator {
    var activeRunner: SessionRunner?

    /// 루틴에서 세션을 새로 시작한다. 워치가 곧바로 이어받도록 진행 상태도 함께 보낸다(F-8).
    /// 폰에서 세션을 시작하면 워치 앱도 함께 띄운다(F-17). `WatchConnectivity` 로는
    /// 워치 앱을 실행시킬 수 없어, 지금까지는 워치를 손으로 열어야 이어받았다.
    var watchAppLauncher: WatchAppLauncher?

    func start(from routine: Routine, in context: ModelContext, syncService: WatchSyncService? = nil) {
        // 남아 있던 진행 중 세션을 먼저 정리한다(계획 21).
        _ = try? SessionLifetime.closeOpenSessions(in: context)
        let session = WorkoutSession.start(from: routine)
        context.insert(session)
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: context)) ?? [:]
        )
        push(session, to: syncService)
        // 진행 상태를 먼저 보낸 뒤 띄운다. 워치 앱이 뜨자마자 읽을 컨텍스트가 있어야
        // 곧바로 그 세션을 연다(F-8).
        // 기록할 세트가 없으면 띄우지 않는다. 워치가 운동 세션만 열고 끝낼 일이 없어
        // 유령 운동이 남는다 — 계획 17 에서 같은 자리에 났던 버그다.
        if session.hasRecordableSets, let watchAppLauncher {
            Task { await watchAppLauncher.launch() }
        }
    }

    /// 진행 상태를 상대 기기로 보낸다. 시작·종료 두 지점에서만 부르면 충분하다 —
    /// `updateApplicationContext` 는 최신 것만 도착하면 되는 채널이다(PRD §8).
    /// 전송 실패는 삼킨다. 헬스장에서 전송을 기다리게 할 수 없다(F-3).
    func push(_ session: WorkoutSession?, to syncService: WatchSyncService?) {
        guard let syncService else { return }
        try? syncService.sendInProgressSession(session.map(SessionSnapshotPayload.make(for:)))
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
