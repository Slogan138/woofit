import SwiftUI
import WoofitCore

/// 끝내고 중단을 누르지 않은 세션이 계속 살아 있지 않게 묻는다(F-3, 계획 21).
///
/// 워치판(`WoofitWatch/Features/SessionNudgeView`)과 같은 원리지만 화면 크기가 달라
/// 따로 둔다 — 공유 추상화를 만들 만큼 복잡하지 않다(휴식 표시와 같은 판단).
struct SessionNudgeView: View {
    let idleSince: Date
    let onKeepGoing: () -> Void
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.explicit(SessionLifetime.nudgeDates(idleSince: idleSince))) { context in
            let nudge = SessionLifetime.nudge(idleSince: idleSince, at: context.date)
            content(for: nudge)
                .sensoryFeedback(.warning, trigger: nudge) { _, new in new != .none }
        }
    }

    @ViewBuilder
    private func content(for nudge: SessionLifetime.Nudge) -> some View {
        switch nudge {
        case .none:
            EmptyView()
        case .asking:
            banner { EmptyView() }
        case .offeringEnd:
            banner {
                HStack(spacing: 10) {
                    Button("계속", action: onKeepGoing)
                        .buttonStyle(.bordered)
                    Button("중단", role: .destructive, action: onEnd)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func banner(@ViewBuilder actions: () -> some View) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("아직 운동 중인가요?")
                    .font(.subheadline.weight(.medium))
                Text("마지막 기록 이후 시간이 꽤 지났습니다.")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }
}

#Preview {
    VStack(spacing: 12) {
        SessionNudgeView(idleSince: Date().addingTimeInterval(-25 * 60), onKeepGoing: {}, onEnd: {})
        SessionNudgeView(idleSince: Date().addingTimeInterval(-50 * 60), onKeepGoing: {}, onEnd: {})
    }
    .padding()
}
