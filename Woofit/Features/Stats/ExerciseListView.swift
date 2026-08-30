import SwiftUI
import SwiftData
import WoofitCore

/// P8 · 추이를 볼 종목을 고르는 목록(F-10).
///
/// 최근 수행순으로만 늘어놓는다. 41종목 정도라 목록으로 충분하고, 부위별 묶음은 만들지 않는다.
/// 기록 탭 안에서 들어온다 — 추이 때문에 탭을 새로 늘리지 않는다(계획 10).
struct ExerciseListView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var series: [ExerciseSeries] { ExerciseHistory.allSeries(in: sessions) }

    var body: some View {
        List {
            ForEach(series) { item in
                NavigationLink {
                    ExerciseTrendView(series: item)
                } label: {
                    ExerciseRow(series: item)
                }
            }
        }
        .navigationTitle("종목별 추이")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if series.isEmpty {
                ContentUnavailableView(
                    "수행한 종목이 없습니다",
                    systemImage: "chart.xyaxis.line",
                    description: Text("세션을 하나 끝내면 여기에 쌓입니다.")
                )
            }
        }
    }
}

private struct ExerciseRow: View {
    let series: ExerciseSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(series.displayName)
                    .font(Typography.itemName)
                Spacer(minLength: 8)
                if series.stagnation?.isStagnant == true {
                    StagnationBadge()
                }
            }

            HStack(spacing: 6) {
                if let last = series.lastPerformedAt {
                    Text(last, format: .dateTime.year().month().day())
                }
                Text("· \(series.sessionCount)회")
            }
            .font(Typography.secondary)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// 정체 표시. 6회 미만이라 판정하지 않은 종목에는 아무것도 붙이지 않는다 —
/// "정체 아님" 뱃지를 달면 목록이 뱃지로 뒤덮이고 정작 정체가 눈에 안 띈다.
struct StagnationBadge: View {
    var body: some View {
        Text("정체")
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(ColorRole.rest)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(ColorRole.rest.opacity(0.14), in: .rect(cornerRadius: 6, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
