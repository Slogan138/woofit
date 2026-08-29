import SwiftUI
import WoofitCore

/// 휴식 스톱워치 표시(F-5, W4). `RestTimerView`(폰) 와 같은 원리지만 워치 화면
/// 크기에 맞춘 별도 뷰다 — 공유 추상화를 만들 만큼 복잡하지 않다.
struct WatchRestView: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Label(
                WeightFormatter.rest(context.date.timeIntervalSince(startedAt)),
                systemImage: "stopwatch"
            )
            .font(.title3.monospacedDigit())
            .foregroundStyle(.orange)
        }
    }
}

#Preview {
    WatchRestView(startedAt: Date().addingTimeInterval(-95))
}
