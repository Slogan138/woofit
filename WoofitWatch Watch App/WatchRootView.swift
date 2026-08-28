import SwiftUI
import SwiftData
import WoofitCore

/// W1 · 워치 홈. 오늘 요일에 배정된 루틴을 최우선으로 띄운다(F-2).
struct WatchRootView: View {
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    private var today: Weekday { .today() }

    private var todaysRoutine: Routine? {
        routines.first { $0.isScheduled(on: today) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let todaysRoutine {
                    Section("오늘 · \(today.shortName)") {
                        RoutineCard(routine: todaysRoutine)
                    }
                }
                Section(todaysRoutine == nil ? "루틴" : "다른 루틴") {
                    ForEach(routines.filter { $0.id != todaysRoutine?.id }) { routine in
                        Text(routine.resolvedTitle)
                    }
                }
            }
            .navigationTitle("Woofit")
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "루틴 없음",
                        systemImage: "dumbbell",
                        description: Text("폰에서 루틴을 만드세요.")
                    )
                }
            }
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(routine.resolvedTitle)
                .font(.headline)
            Text("\(routine.sortedExercises.count)종목 · \(routine.totalSetCount)세트")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchRootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
