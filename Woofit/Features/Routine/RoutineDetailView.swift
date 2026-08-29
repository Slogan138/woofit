import SwiftUI
import WoofitCore

/// P2 · 루틴 상세. 전 종목·전 세트를 보여준다(F-2).
struct RoutineDetailView: View {
    let routine: Routine

    var body: some View {
        List {
            Section {
                LabeledContent("부위", value: routine.category.isEmpty ? "미지정" : routine.category)
                LabeledContent("반복 요일", value: routine.isScheduled ? Weekday.label(mask: routine.weekdayMask) : "미지정")
                if !routine.note.isEmpty {
                    LabeledContent("메모", value: routine.note)
                }
            }

            ForEach(routine.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sortedSets) { set in
                        LabeledContent(
                            "\(set.order + 1)세트",
                            value: WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps)
                        )
                    }
                }
            }
        }
        .navigationTitle(routine.resolvedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if routine.sortedExercises.isEmpty {
                ContentUnavailableView(
                    "종목이 없습니다",
                    systemImage: "list.bullet",
                    description: Text("루틴을 편집하거나 마크다운을 가져와 종목을 추가하세요.")
                )
            }
        }
    }
}

#Preview {
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 5, weight: 80, reps: 5)

    return NavigationStack {
        RoutineDetailView(routine: routine)
    }
}
