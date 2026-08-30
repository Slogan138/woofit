import SwiftUI
import WoofitCore

/// P2 · 루틴 상세. 전 종목·전 세트를 보여준다(F-2).
/// 이 화면에 들어오는 이유가 대부분 "시작"이므로 버튼을 하단에 고정한다(계획 16).
struct RoutineDetailView: View {
    let routine: Routine

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionCoordinator.self) private var coordinator

    @State private var isEditing = false

    var body: some View {
        List {
            Section {
                LabeledContent("부위", value: routine.category.isEmpty ? "미지정" : routine.category)
                LabeledContent("반복 요일", value: routine.isScheduled ? Weekday.label(mask: routine.weekdayMask) : "미지정")
                LabeledContent("구성", value: "\(routine.sortedExercises.count)종목 · \(routine.totalSetCount)세트")
                if !routine.note.isEmpty {
                    LabeledContent("메모", value: routine.note)
                }
            }

            ForEach(routine.sortedExercises) { exercise in
                Section {
                    // 무게·횟수가 전부 같으면 한 줄로 접는다. 같은 값이 다섯 줄 반복되면
                    // 피라미드 세트처럼 값이 실제로 다른 종목과 구분이 안 된다.
                    if let uniform = exercise.uniformTarget {
                        LabeledContent(
                            "\(exercise.sortedSets.count)세트",
                            value: WeightFormatter.target(weight: uniform.weight, reps: uniform.reps)
                        )
                    } else {
                        ForEach(exercise.sortedSets) { set in
                            LabeledContent(
                                "\(set.order + 1)세트",
                                value: WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps)
                            )
                        }
                    }
                } header: {
                    Text(exercise.name)
                }
            }
        }
        .navigationTitle(routine.resolvedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("편집") { isEditing = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !routine.sortedExercises.isEmpty {
                Button {
                    coordinator.start(from: routine, in: modelContext)
                } label: {
                    Text("시작")
                        .font(Typography.itemName)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .overlay {
            if routine.sortedExercises.isEmpty {
                ContentUnavailableView(
                    "종목이 없습니다",
                    systemImage: "list.bullet",
                    description: Text("루틴을 편집하거나 마크다운을 가져와 종목을 추가하세요.")
                )
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                RoutineEditorView(routine: routine)
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
    .environment(SessionCoordinator())
    .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
