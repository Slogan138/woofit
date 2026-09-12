import Foundation
import SwiftData

/// 진행 중 세션이 언제 끝난 것으로 보이는가(PRD D14, 계획 21).
///
/// `inProgress` 를 빠져나가는 길은 `finish()` 와 `abandon()` 둘뿐이고 둘 다 앱이 살아
/// 있어야 불린다. 워치 앱은 휴식마다 내려가므로 끝내지 않은 세션이 남는다. 애플 운동
/// 앱에서 "진행 중"이 기기에서 살아 있는 동안만 존재하는 것과 달리, 우리는 그것을
/// 디스크에 적어두었기 때문에 **언제 죽은 것으로 볼지를 따로 정해야 한다.**
///
/// 정리해도 되는 것은 세트 기록이 이미 영속돼 있어 잃는 것이 "진행 중" 표시뿐이기
/// 때문이다. 그래서 **지우지 않고 중단으로 돌린다** — 지우면 그날 기록이 통째로 사라진다.
public enum SessionLifetime {

    /// 살아 있지 않은 진행 중 세션을 중단으로 정리한다. 정리한 것을 돌려준다.
    @discardableResult
    public static func expireStale(
        in context: ModelContext,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [WorkoutSession] {
        let stale = try openSessions(in: context).filter { !$0.isLive(at: date, calendar: calendar) }
        for session in stale { session.abandon(at: date) }
        return stale
    }

    /// 새 세션을 시작하기 전에 부른다. 남아 있던 진행 중 세션을 전부 중단으로 돌린다.
    ///
    /// **같은 규칙이 `SyncMerger.mergeInProgress` 에도 있다**(상대 기기에서 새 세션이
    /// 도착한 경우). 지금까지 이 정리가 없어도 드러나지 않은 것은 동기화가 대신 해줬기
    /// 때문이고, 한 기기만 쓰면 그대로 쌓였다.
    @discardableResult
    public static func closeOpenSessions(
        in context: ModelContext,
        at date: Date = Date()
    ) throws -> [WorkoutSession] {
        let open = try openSessions(in: context)
        for session in open { session.abandon(at: date) }
        return open
    }

    // MARK: - 안내 (F-3)

    /// 화면이 지금 무엇을 보여줘야 하는가.
    public enum Nudge: Hashable, Sendable {
        /// 평소.
        case none
        /// "아직 운동 중인가요?" — 물어보기만 한다.
        case asking
        /// 계속·중단 선택지까지 준다.
        case offeringEnd
    }

    /// `idleSince` 는 마지막 기록 시각이다. 사용자가 "계속"을 눌렀다면 그 시각이 대신 들어온다 —
    /// 누르고도 곧바로 다시 뜨면 안 되기 때문이다.
    ///
    /// **경과 시간이 아니라 무기록 시간으로 판단한다.** 실측 평균 세션이 50분이라 경과
    /// 시간을 기준으로 삼으면 정상적으로 운동하는 중에 자주 걸리고, 그런 알림은 곧
    /// 무시하게 된다(D14).
    public static func nudge(
        idleSince: Date,
        at date: Date = Date(),
        thresholds: NudgeThresholds = .default
    ) -> Nudge {
        let idle = date.timeIntervalSince(idleSince)
        if let offerEnd = thresholds.offerEndAfter, idle >= offerEnd { return .offeringEnd }
        if let ask = thresholds.askAfter, idle >= ask { return .asking }
        return .none
    }

    /// 안내가 바뀌는 시각들. 화면은 이 시각에만 다시 그리면 된다 — 타이머를 돌리지
    /// 않는다(PRD §9 배터리).
    ///
    /// 첫 항목이 `idleSince` 자신인 것은 `TimelineView(.explicit:)` 때문이다. 앞으로의
    /// 시각만 주면 첫 항목 전에는 보여줄 기준 시각이 없다.
    public static func nudgeDates(idleSince: Date, thresholds: NudgeThresholds = .default) -> [Date] {
        [idleSince]
            + [thresholds.askAfter, thresholds.offerEndAfter]
                .compactMap { $0 }
                .map(idleSince.addingTimeInterval)
    }

    // MARK: - 내부

    private static func openSessions(in context: ModelContext) throws -> [WorkoutSession] {
        let inProgress = SessionState.inProgress.rawValue
        return try context.fetch(
            FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.stateRaw == inProgress })
        )
    }
}
