import SwiftUI
import SwiftData
import WoofitCore

/// P1 · 루틴 목록. 오늘 요일에 배정된 루틴을 위에 둔다(F-2).
struct RoutineListView: View {
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    private var today: Weekday { .today() }

    private var todaysRoutines: [Routine] {
        routines.filter { $0.isScheduled(on: today) }
    }

    private var otherRoutines: [Routine] {
        routines.filter { !$0.isScheduled(on: today) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !todaysRoutines.isEmpty {
                    Section("오늘 · \(today.fullName)") {
                        ForEach(todaysRoutines) { RoutineRow(routine: $0) }
                    }
                }
                if !otherRoutines.isEmpty {
                    Section(todaysRoutines.isEmpty ? "루틴" : "다른 루틴") {
                        ForEach(otherRoutines) { RoutineRow(routine: $0) }
                    }
                }
            }
            .navigationTitle("Woofit")
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "루틴이 없습니다",
                        systemImage: "dumbbell",
                        description: Text("루틴을 만들거나, 노트에서 마크다운을 붙여넣어 가져오세요.")
                    )
                }
            }
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.resolvedTitle)
                .font(.headline)
            HStack(spacing: 6) {
                if !routine.category.isEmpty {
                    Text(routine.category)
                }
                Text("\(routine.sortedExercises.count)종목 · \(routine.totalSetCount)세트")
                if routine.isScheduled {
                    Text("· \(Weekday.label(mask: routine.weekdayMask))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RoutineListView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
