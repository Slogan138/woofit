import SwiftUI
import SwiftData
import WoofitCore

/// W2 · 시작 전 전체 스크롤 확인. 폰 없이 워치 저장소만 읽는다(F-2).
/// "시작"을 누르면 W3(`WatchSetView`)로 넘어간다(F-3).
struct WatchRoutinePreviewView: View {
    let routine: Routine

    @Environment(\.modelContext) private var modelContext
    @State private var activeRunner: SessionRunner?

    var body: some View {
        List {
            if routine.isScheduled {
                Text(Weekday.label(mask: routine.weekdayMask))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(routine.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sortedSets) { set in
                        Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                            .font(.caption)
                    }
                }
            }

            if !routine.sortedExercises.isEmpty {
                Button("시작", action: start)
                    .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(routine.resolvedTitle)
        .navigationDestination(item: $activeRunner) { runner in
            WatchSetView(runner: runner, onEnd: { activeRunner = nil })
        }
    }

    private func start() {
        let session = WorkoutSession.start(from: routine)
        modelContext.insert(session)
        activeRunner = SessionRunner(
            session: session,
            lastRecords: (try? LastRecordLookup.fetchAll(for: session, in: modelContext)) ?? [:]
        )
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)

    return NavigationStack {
        WatchRoutinePreviewView(routine: routine)
    }
    .modelContainer(container)
}
