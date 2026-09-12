import SwiftUI
import WoofitCore

/// 끝내고 중단을 누르지 않은 세션이 계속 살아 있지 않게 묻는다(F-3, 계획 21).
///
/// 판정은 전부 `SessionLifetime` 에 있고 여기서는 그리기만 한다. 타이머를 돌리지 않고
/// `TimelineView(.explicit:)` 로 **바뀌는 두 시각에만** 다시 그린다(PRD §9 배터리).
struct SessionNudgeView: View {
    let idleSince: Date
    let onKeepGoing: () -> Void
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.explicit(SessionLifetime.nudgeDates(idleSince: idleSince))) { context in
            let nudge = SessionLifetime.nudge(idleSince: idleSince, at: context.date)
            content(for: nudge)
                // 화면을 안 보고 있을 때도 알아야 한다. 기록 햅틱과 구분되게 경고음을 쓴다.
                .sensoryFeedback(.warning, trigger: nudge) { _, new in new != .none }
        }
    }

    @ViewBuilder
    private func content(for nudge: SessionLifetime.Nudge) -> some View {
        switch nudge {
        case .none:
            EmptyView()
        case .asking:
            message
        case .offeringEnd:
            VStack(spacing: 6) {
                message
                HStack(spacing: 6) {
                    Button("계속", action: onKeepGoing)
                        .buttonStyle(.bordered)
                    Button("중단", role: .destructive, action: onEnd)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var message: some View {
        Label("아직 운동 중인가요?", systemImage: "questionmark.circle")
            .font(Typography.secondary)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    VStack(spacing: 12) {
        SessionNudgeView(idleSince: Date().addingTimeInterval(-25 * 60), onKeepGoing: {}, onEnd: {})
        SessionNudgeView(idleSince: Date().addingTimeInterval(-50 * 60), onKeepGoing: {}, onEnd: {})
    }
}
