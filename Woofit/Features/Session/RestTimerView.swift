import SwiftUI
import WoofitCore

/// 휴식 스톱워치 표시(F-5). 저장하는 것은 시작 시각뿐이고 경과는 `TimelineView` 가
/// 매초 다시 계산하므로, 백그라운드에 다녀오거나 세션을 복원해도 그대로 정확하다.
struct RestTimerView: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Label(
                WeightFormatter.rest(context.date.timeIntervalSince(startedAt)),
                systemImage: "stopwatch"
            )
            .font(Typography.value)
            .monospacedDigit()
            .foregroundStyle(ColorRole.rest)
        }
    }
}

#Preview {
    RestTimerView(startedAt: Date().addingTimeInterval(-95))
}
