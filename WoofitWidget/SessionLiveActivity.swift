import ActivityKit
import SwiftUI
import WidgetKit
import WoofitCore

/// 잠금화면·AOD·다이내믹 아일랜드에 띄우는 진행 중 세션(F-16).
///
/// **여기서는 판단하지 않는다.** 무엇을 보여줄지는 앱이 `SessionLiveSnapshot` 으로
/// 넘겨준 값이 전부다 — 위젯은 별도 프로세스라 세션도 저장소도 볼 수 없고, 판단을
/// 여기에 두면 `swift test` 가 닿지 않는 곳에 로직이 생긴다(CLAUDE.md 경계).
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreen(context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(target(context.state))
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(context.state.setIndex)/\(context.state.setCount)세트")
                            .monospacedDigit()
                        Spacer()
                        rest(context.state)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
            } compactTrailing: {
                // 쉬는 중이면 남은 것보다 지금 흐르는 시간이 궁금하다.
                if let startedAt = context.state.restStartedAt {
                    Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                } else {
                    Text("\(context.state.setIndex)/\(context.state.setCount)")
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
        }
    }

    private func lockScreen(_ state: SessionLiveSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(target(state))
                    .font(.headline)
                    .monospacedDigit()
            }

            HStack {
                Text("\(state.setIndex)/\(state.setCount)세트 · 전체 \(state.recordedSetCount)/\(state.totalSetCount)")
                    .monospacedDigit()
                Spacer(minLength: 8)
                rest(state)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .activityBackgroundTint(nil)
    }

    /// 휴식은 **갱신 없이** 흐른다. 앱이 주머니에 있어도 맞는 값이 보이는 유일한 방법이고,
    /// 1초마다 Live Activity 를 갱신하는 것은 애초에 허용되지도 않는다(PRD §9 배터리).
    @ViewBuilder
    private func rest(_ state: SessionLiveSnapshot) -> some View {
        if let startedAt = state.restStartedAt {
            Label {
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "stopwatch")
            }
        } else {
            Text(state.routineName)
                .lineLimit(1)
        }
    }

    private func target(_ state: SessionLiveSnapshot) -> String {
        WeightFormatter.target(weight: state.targetWeight, reps: state.targetReps)
    }
}
