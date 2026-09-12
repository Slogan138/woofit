#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import os

/// 진행 중 세션의 Live Activity 를 열고 닫는다(F-16).
///
/// **화면이 아니라 여기서 부르는 이유** — 폰이 주머니에 있는 동안 워치가 기록하면
/// `transferUserInfo` 가 폰 앱을 백그라운드에서 깨운다. 그때 화면은 그려지지 않으므로
/// `onChange` 로는 갱신할 수 없다. 잠금화면에 맞는 값이 뜨려면 **수신 경로에서** 직접
/// 갱신해야 한다(계획 22).
///
/// **열려 있는 활동을 들고 있지 않고 그때그때 조회한다.** 시스템이 주인이라 앱이
/// 죽었다 살아나도 잠금화면에는 그대로 남아 있는데, 참조를 들고 있으면 그 경우를
/// 놓쳐 활동이 둘이 된다 — `recoverActiveWorkoutSession`(F-14)과 같은 이유다.
public final class LiveActivityController: Sendable {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "LiveActivity")

    public init() {}

    /// 세션 현황을 잠금화면에 반영한다. **보여줄 것이 없으면 끝낸다** —
    /// 세션이 끝났거나, 중단됐거나, 남은 세트가 없는 경우다.
    ///
    /// `WorkoutSession` 은 `Sendable` 이 아니므로 이 메서드에서 값으로 바꿔 넘긴다.
    @MainActor
    public func refresh(for session: WorkoutSession?) async {
        guard let session, let snapshot = SessionLiveSnapshot.make(for: session) else {
            await end()
            return
        }
        await apply(snapshot, sessionID: session.id)
    }

    public func apply(_ snapshot: SessionLiveSnapshot, sessionID: UUID) async {
        // 사용자가 설정에서 꺼둔 경우. 기능이 없는 것처럼 조용히 넘어간다(F-14 권한과 같은 방식).
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: snapshot, staleDate: nil)

        if let running = Activity<SessionActivityAttributes>.activities
            .first(where: { $0.attributes.sessionID == sessionID }) {
            await running.update(content)
            return
        }
        // 다른 세션이 열려 있으면 먼저 닫는다. 둘이 동시에 떠 있으면 어느 쪽이 지금
        // 하는 운동인지 알 수 없다.
        await end()

        do {
            _ = try Activity.request(
                attributes: SessionActivityAttributes(sessionID: sessionID),
                content: content
            )
        } catch {
            Self.logger.error("Live Activity 시작 실패: \(String(describing: error), privacy: .public)")
        }
    }

    /// 즉시 사라지게 한다. 기본 정책은 잠금화면에 한동안 남겨두는 것인데, 운동이 끝난
    /// 뒤에도 남아 있으면 "아직 진행 중"으로 읽힌다 — 이 앱이 그동안 겪은 문제의 모양이다(D14).
    public func end() async {
        for activity in Activity<SessionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
