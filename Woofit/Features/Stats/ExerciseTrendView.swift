import SwiftUI
import Charts
import WoofitCore

/// P8 · 종목 하나의 추이(F-10).
///
/// 주 지표는 **볼륨**이다. 무게는 5개월간 거의 변하지 않았고 진전은 세트 수와 횟수에서
/// 일어났기 때문이다(PRD D10). 최고 무게는 보조 그래프로 함께 둔다 — 볼륨이 늘 때
/// 무게로 늘었는지 횟수로 늘었는지 구분해야 한다.
///
/// **정체 구간이 눈에 보이면 목적을 달성한 것이다.** 세부 수치 열람 화면이 아니다.
struct ExerciseTrendView: View {
    let series: ExerciseSeries

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary

                if series.isChartable {
                    metricChart
                    // 맨몸 종목은 무게가 늘 0 이라 보조 그래프가 0 에 붙은 직선만 그린다.
                    if series.metric != .reps {
                        weightChart
                    }
                } else {
                    assistedNotice
                }
            }
            .padding()
        }
        .navigationTitle(series.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 요약

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(series.sessionCount)회 수행")
                    .font(Typography.value)
                    .monospacedDigit()
                Spacer(minLength: 8)
                if series.stagnation?.isStagnant == true {
                    StagnationBadge()
                }
            }

            HStack(spacing: 16) {
                if let overall = series.overallChange, let rate = overall.changeRate {
                    // 표기가 0% 인데 화살표만 위를 가리키면 두 값이 서로 다른 말을 한다.
                    // 반올림해서 0 이 되는 구간은 화살표도 수평이어야 한다.
                    let rounded = TrendFormat.roundedPercent(rate)
                    Label {
                        Text("초기 대비 \(TrendFormat.percent(rate))")
                    } icon: {
                        Image(systemName: arrowName(rounded))
                    }
                    .foregroundStyle(rounded > 0 ? SetResult.success.tintColor : .secondary)
                }

                // 성공률은 그래프로 그리지 않는다 — 목표를 달성 가능하게 잡으므로
                // 82% 언저리에 머물고 시간에 따라 의미 있게 움직이지 않는다(PRD D10).
                if let rate = series.successRate {
                    Text("성공률 \(TrendFormat.percent(rate, signed: false))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
        }
    }

    // MARK: - 주 그래프

    private var metricChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(series.metric == .reps ? "총 횟수" : "볼륨")
                .font(Typography.itemName)
            if series.metric == .reps {
                Text("맨몸 종목이라 무게가 0 입니다. 볼륨 대신 총 횟수로 봅니다.")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }

            Chart(series.points) { point in
                LineMark(
                    x: .value("날짜", point.performedAt),
                    y: .value("값", series.value(of: point))
                )
                .foregroundStyle(ColorRole.accent)
                PointMark(
                    x: .value("날짜", point.performedAt),
                    y: .value("값", series.value(of: point))
                )
                .foregroundStyle(ColorRole.accent)
            }
            .chartXScale(domain: xDomain)
            .frame(height: 220)
        }
    }

    // MARK: - 보조 그래프

    /// 축을 겹쳐 그리지 않고 아래에 따로 둔다. 볼륨과 무게는 단위도 자릿수도 달라
    /// 한 축에 얹으면 둘 중 하나가 바닥에 붙는다. X 축 범위만 맞춰 같은 시점을 가리키게 한다.
    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최고 무게")
                .font(Typography.itemName)
                .foregroundStyle(.secondary)

            Chart(series.points) { point in
                LineMark(
                    x: .value("날짜", point.performedAt),
                    y: .value("무게", point.topWeight)
                )
                .foregroundStyle(.secondary)
                PointMark(
                    x: .value("날짜", point.performedAt),
                    y: .value("무게", point.topWeight)
                )
                .foregroundStyle(.secondary)
            }
            .chartXScale(domain: xDomain)
            .frame(height: 120)
        }
    }

    private func arrowName(_ percent: Int) -> String {
        if percent > 0 { return "arrow.up.right" }
        if percent < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    /// 점이 하나뿐이면 시작과 끝이 같아 범위가 성립하지 않는다. 그때는 Charts 에 맡긴다.
    private var xDomain: ClosedRange<Date> {
        guard let first = series.points.first?.performedAt,
              let last = series.points.last?.performedAt,
              first < last
        else {
            let today = Date()
            return today.addingTimeInterval(-86_400)...today.addingTimeInterval(86_400)
        }
        return first...last
    }

    // MARK: - 보조 기구 종목

    private var assistedNotice: some View {
        ContentUnavailableView {
            Label("보조 기구 종목은 추이를 그리지 않습니다", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("보조 중량은 줄수록 향상이라 볼륨이 늘면 오히려 후퇴로 그려집니다. 방향을 뒤집으려면 종목에 속성이 필요합니다.")
        }
    }
}

/// 추이 화면의 숫자 표기. 소수점을 붙이면 판독만 느려진다.
enum TrendFormat {
    static func roundedPercent(_ rate: Double) -> Int {
        Int((rate * 100).rounded())
    }

    static func percent(_ rate: Double, signed: Bool = true) -> String {
        let value = roundedPercent(rate)
        return signed && value > 0 ? "+\(value)%" : "\(value)%"
    }
}
