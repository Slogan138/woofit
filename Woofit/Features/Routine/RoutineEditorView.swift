import SwiftUI
import SwiftData
import WoofitCore

/// P2 · 루틴 편집기. 새 루틴 작성과 기존 루틴 수정을 함께 맡는다(F-1).
///
/// `isNew` 면 `routine` 은 아직 컨텍스트에 들어가지 않은 상태로 넘어온다. 화면 안에서는
/// 메모리 위에서만 종목·세트를 쌓다가, 저장을 눌러야 비로소 컨텍스트에 들어간다.
/// 그래야 만들다 만 빈 루틴이 목록에 유령처럼 남지 않는다.
///
/// 기존 루틴 편집은 반대다 — `routine` 이 이미 컨텍스트에 있어 `@Bindable` 로 고치는 즉시
/// 저장소에 반영된다. 되돌리기를 지원하려면 진입 시 스냅샷을 떠 취소 시 복원해야 하는데,
/// 이 화면 규모에 비해 과한 장치라 판단해 "취소" 자체를 없앴다 — 요일도 같은 즉시 반영으로
/// 맞춰 "완료" 하나만 남긴다.
struct RoutineEditorView: View {
    @Bindable var routine: Routine
    let isNew: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.watchSyncService) private var syncService

    @State private var weekdaySelection: Set<Weekday>
    @State private var lastRecords: [String: LastRecord] = [:]
    @State private var suggestions: [ExerciseNameSuggester.Candidate] = []
    @State private var newExerciseName = ""
    @State private var emptyExerciseNames: [String] = []
    @State private var isShowingEmptyExerciseAlert = false

    init(routine: Routine, isNew: Bool = false) {
        self.routine = routine
        self.isNew = isNew
        _weekdaySelection = State(initialValue: Set(routine.weekdays))
    }

    var body: some View {
        Form {
            Section("이름") {
                TextField("루틴 이름", text: $routine.name)
            }
            Section("카테고리") {
                CategoryField(category: $routine.category)
            }
            Section("반복 요일") {
                WeekdayPicker(selection: $weekdaySelection)
            }

            ForEach(routine.sortedExercises) { exercise in
                ExerciseEditorRow(
                    exercise: exercise,
                    lastRecord: lastRecords[exercise.normalizedName],
                    canMoveUp: exercise.order > 0,
                    canMoveDown: exercise.order < routine.sortedExercises.count - 1,
                    onMoveUp: { moveExercise(exercise, by: -1) },
                    onMoveDown: { moveExercise(exercise, by: 1) },
                    onDelete: { removeExercise(exercise) }
                )
            }

            Section("종목 추가") {
                TextField("종목명", text: $newExerciseName)
                if !filteredSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(filteredSuggestions, id: \.normalizedName) { candidate in
                                Button(candidate.displayName) { addExercise(named: candidate.displayName) }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Button("추가") { addExercise(named: newExerciseName) }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(isNew ? "새 루틴" : "루틴 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: attemptSave)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", action: attemptSave)
                }
            }
        }
        .onAppear {
            refreshLastRecords()
            suggestions = (try? ExerciseNameSuggester.suggest(in: modelContext)) ?? []
        }
        .onChange(of: weekdaySelection) { _, newValue in
            // 기존 루틴은 다른 필드처럼 요일도 즉시 반영한다 — "취소"가 없으므로
            // 저장 시점까지 미룰 이유가 없다. `isNew` 는 컨텍스트에 없어 여기서 배정하면
            // 다른 루틴의 요일을 앞당겨 해제해버리므로 저장 시점까지 미룬다.
            guard !isNew else { return }
            // 인메모리 fetch 실패(= SwiftData 저장소 손상)만 던진다. 이 화면의 다른 fetch 도
            // 같은 이유로 조용히 무시한다(refreshLastRecords, suggestions).
            try? RoutineScheduler.assign(Array(newValue), to: routine, in: modelContext)
        }
        .alert("세트가 없는 종목이 있습니다", isPresented: $isShowingEmptyExerciseAlert) {
            Button("계속 편집", role: .cancel) {}
            Button("종목 빼고 저장", role: .destructive) { save(droppingEmptyExercises: true) }
        } message: {
            Text("\(emptyExerciseNames.joined(separator: ", ")) 에 세트가 없습니다. 그대로 저장하면 마크다운으로 내보냈다 다시 가져올 때 이 종목이 사라집니다.")
        }
    }

    // MARK: - 종목 추가·이동·삭제

    private var filteredSuggestions: [ExerciseNameSuggester.Candidate] {
        let existing = Set(routine.sortedExercises.map(\.normalizedName))
        let pool = suggestions.filter { !existing.contains($0.normalizedName) }
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(pool.prefix(8)) }
        let query = ExerciseName.normalize(trimmed)
        return Array(pool.filter { $0.normalizedName.contains(query) }.prefix(8))
    }

    private func addExercise(named rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        routine.appendExercise(named: trimmed)
        newExerciseName = ""
        refreshLastRecords()
    }

    /// 두 항목의 `order` 를 맞바꾼다. `reindexExercises()` 는 기존 `order` 로 다시 정렬하므로
    /// 스왑 뒤에는 못 쓰고, 새 위치를 직접 대입해야 한다.
    private func moveExercise(_ exercise: PlannedExercise, by offset: Int) {
        var ordered = routine.sortedExercises
        guard let index = ordered.firstIndex(where: { $0.id == exercise.id }) else { return }
        let newIndex = index + offset
        guard ordered.indices.contains(newIndex) else { return }
        ordered.swapAt(index, newIndex)
        for (position, item) in ordered.enumerated() { item.order = position }
        routine.touch()
    }

    private func removeExercise(_ exercise: PlannedExercise) {
        routine.removeExercise(exercise)
        refreshLastRecords()
    }

    private func refreshLastRecords() {
        lastRecords = (try? LastRecordLookup.fetchAll(for: routine, in: modelContext)) ?? [:]
    }

    // MARK: - 저장

    /// 세트가 0개인 종목은 저장 시점에 막는다(06-F01 계획 "빈 종목 처리").
    /// 허용하면 마크다운 왕복에서 그 종목이 조용히 사라진다.
    private func attemptSave() {
        let empty = routine.emptyExercises
        guard empty.isEmpty else {
            emptyExerciseNames = empty.map { $0.name.isEmpty ? "(이름 없음)" : $0.name }
            isShowingEmptyExerciseAlert = true
            return
        }
        save()
    }

    private func save(droppingEmptyExercises: Bool = false) {
        if droppingEmptyExercises {
            routine.removeEmptyExercises()
        }
        if isNew {
            modelContext.insert(routine)
            // 인메모리 fetch 실패(= SwiftData 저장소 손상)만 던진다. 위 onChange 와 같은 이유로 무시한다.
            try? RoutineScheduler.assign(Array(weekdaySelection), to: routine, in: modelContext)
        }
        try? syncService?.pushRoutines(in: modelContext)
        dismiss()
    }
}

#Preview {
    let routine = Routine(name: "월요일 가슴", category: "가슴", weekdayMask: Weekday.mask(of: [.monday]))
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 3, weight: 80, reps: 5)

    return NavigationStack {
        RoutineEditorView(routine: routine)
    }
    .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
