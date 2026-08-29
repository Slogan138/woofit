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

    /// 오늘 루틴을 뺀 나머지는 "최근 사용한 루틴"(PRD F-2) 이다.
    /// `routines` 가 이미 `updatedAt` 내림차순이므로 그대로 쓴다.
    private var otherRoutines: [Routine] {
        routines.filter { $0.id != todaysRoutine?.id }
    }

    var body: some View {
        NavigationStack {
            List {
                if let todaysRoutine {
                    Section("오늘 · \(today.shortName)") {
                        NavigationLink(value: todaysRoutine) {
                            RoutineCard(routine: todaysRoutine)
                        }
                    }
                }
                Section(todaysRoutine == nil ? "루틴" : "다른 루틴") {
                    ForEach(otherRoutines) { routine in
                        NavigationLink(routine.resolvedTitle, value: routine)
                    }
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                WatchRoutinePreviewView(routine: routine)
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
