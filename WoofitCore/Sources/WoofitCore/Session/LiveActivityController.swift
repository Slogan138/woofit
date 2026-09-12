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
public final class LiveActivityController: SessionPresence, Sendable {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "LiveActivity")

    /// 갱신이 이만큼 끊기면 시스템이 카드를 오래된 것으로 표시한다. 세션 하나가 평균
    /// 50분이라(D14) 그보다 넉넉히 잡는다.
    private nonisolated static let staleAfter: TimeInterval = 2 * 60 * 60

    public init() {}

    /// 세션 현황을 잠금화면에 반영한다. **보여줄 것이 없으면 끝낸다** —
    /// 세션이 끝났거나, 중단됐거나, 남은 세트가 없는 경우다.
    ///
    /// `WorkoutSession` 은 `Sendable` 이 아니므로 이 메서드에서 값으로 바꿔 넘긴다.
    @MainActor
    public func sessionDidChange(to session: WorkoutSession?) async {
        await refresh(for: session)
    }

    @MainActor
    public func refresh(for session: WorkoutSession?) async {
        guard let session, let snapshot = SessionLiveSnapshot.make(for: session) else {
            await end()
            return
        }
        await apply(snapshot, sessionID: session.id)
    }

    /// `nonisolated` 인 이유 — `SessionPresence` 가 `@MainActor` 라 이 타입 전체가 따라가는데,
    /// `Activity` 는 `Sendable` 이 아니어서 격리된 컨텍스트에 묶이면 `await` 를 넘지 못한다.
    public nonisolated func apply(_ snapshot: SessionLiveSnapshot, sessionID: UUID) async {
        // 사용자가 설정에서 꺼둔 경우. 기능이 없는 것처럼 조용히 넘어간다(F-14 권한과 같은 방식).
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // **끝내지 못한 카드가 최신인 척하지 않게 한다.** 상대 기기에서 중단했는데 폰이
        // 깨어나지 못하면 카드가 남는데, 그때 시스템이 흐리게 표시해 오래된 값임을 알린다.
        let content = ActivityContent(
            state: snapshot,
            staleDate: Date().addingTimeInterval(Self.staleAfter)
        )

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
    public nonisolated func end() async {
        // **지역 변수로 받지 않는다.** `Activity` 는 `Sendable` 이 아니라, 격리된
        // 컨텍스트에 묶인 값을 `await` 너머로 넘기면 Swift 6 이 막는다.
        let count = Activity<SessionActivityAttributes>.activities.count
        guard count > 0 else { return }
        Self.logger.info("Live Activity \(count, privacy: .public)개를 끝낸다")
        for activity in Activity<SessionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
