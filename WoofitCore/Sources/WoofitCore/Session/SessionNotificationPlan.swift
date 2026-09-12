import Foundation

/// 세션 미종료 알림을 **무엇을 언제** 걸지(F-18).
///
/// `UNUserNotificationCenter` 를 모른다 — 예약은 화면 쪽이 하고 여기서는 목록만 만든다.
/// 그래서 시뮬레이터 없이 규칙 전부를 테스트할 수 있다.
///
/// **빈 배열은 "전부 지우라"는 뜻이다.** 세션이 끝났거나 없으면 걸어둔 알림도 남아 있으면
/// 안 된다 — 운동이 끝난 한참 뒤에 "아직 운동 중인가요?"가 울린다.
public enum SessionNotificationPlan {

    public struct ScheduledNudge: Hashable, Sendable {
        public let nudge: SessionLifetime.Nudge
        public let fireDate: Date

        /// 예약을 지우고 다시 걸 때 쓰는 식별자. 종류마다 하나씩이라 **항상 덮어쓴다** —
        /// 세트를 기록할 때마다 새로 걸어도 알림이 쌓이지 않는다.
        public var identifier: String {
            switch nudge {
            case .asking: "session.nudge.asking"
            case .offeringEnd: "session.nudge.offeringEnd"
            case .none: "session.nudge.none"
            }
        }

        public init(nudge: SessionLifetime.Nudge, fireDate: Date) {
            self.nudge = nudge
            self.fireDate = fireDate
        }
    }

    /// 지울 수 있게 식별자 전체를 공개한다. 목록이 비어도 지울 대상은 알아야 한다.
    public static let allIdentifiers = [
        ScheduledNudge(nudge: .asking, fireDate: .distantPast).identifier,
        ScheduledNudge(nudge: .offeringEnd, fireDate: .distantPast).identifier,
    ]

    public static func requests(
        for session: WorkoutSession?,
        thresholds: NudgeThresholds = .default,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ScheduledNudge] {
        guard let session, session.isLive(at: date, calendar: calendar) else { return [] }

        let idleSince = session.lastActivityAt
        let candidates: [(SessionLifetime.Nudge, TimeInterval?)] = [
            (.asking, thresholds.askAfter),
            (.offeringEnd, thresholds.offerEndAfter),
        ]

        return candidates.compactMap { nudge, after in
            guard let after else { return nil }
            let fireDate = idleSince.addingTimeInterval(after)
            // **이미 지난 시각은 걸지 않는다.** 복원 직후 과거 알림이 즉시 울리면,
            // 사용자는 방금 기록했는데 "아직 운동 중인가요?"를 받는다.
            guard fireDate > date else { return nil }
            return ScheduledNudge(nudge: nudge, fireDate: fireDate)
        }
    }
}
