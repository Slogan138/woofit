import SwiftUI
import WoofitCore

/// W2 · 시작 전 전체 스크롤 확인. 폰 없이 워치 저장소만 읽는다(F-2).
struct WatchRoutinePreviewView: View {
    let routine: Routine

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
        }
        .navigationTitle(routine.resolvedTitle)
    }
}

#Preview {
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)

    return NavigationStack {
        WatchRoutinePreviewView(routine: routine)
    }
}
