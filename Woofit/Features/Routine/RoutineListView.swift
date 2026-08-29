import SwiftUI
import SwiftData
import WoofitCore

/// P1 · 루틴 목록. 오늘 요일에 배정된 루틴을 위에 둔다(F-2).
struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    @State private var pendingExport: MarkdownExport?
    @State private var isImportPresented = false
    @State private var newRoutineDraft: Routine?
    @State private var editingRoutine: Routine?

    private var today: Weekday { .today() }

    var body: some View {
        let ordered = RoutineOrdering.forList(routines, today: today)
        let todaysRoutines = ordered.filter { $0.isScheduled(on: today) }
        let otherRoutines = ordered.filter { !$0.isScheduled(on: today) }

        NavigationStack {
            List {
                if !todaysRoutines.isEmpty {
                    Section("오늘 · \(today.fullName)") {
                        ForEach(todaysRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(
                                    routine: routine,
                                    onExport: { export(routine) },
                                    onEdit: { editingRoutine = routine },
                                    onDuplicate: { duplicate(routine) },
                                    onDelete: { delete(routine) }
                                )
                            }
                        }
                    }
                }
                if !otherRoutines.isEmpty {
                    Section(todaysRoutines.isEmpty ? "루틴" : "다른 루틴") {
                        ForEach(otherRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(
                                    routine: routine,
                                    onExport: { export(routine) },
                                    onEdit: { editingRoutine = routine },
                                    onDuplicate: { duplicate(routine) },
                                    onDelete: { delete(routine) }
                                )
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newRoutineDraft = Routine()
                        } label: {
                            Label("새 루틴", systemImage: "plus")
                        }
                        Button {
                            isImportPresented = true
                        } label: {
                            Label("가져오기", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $pendingExport) { export in
                MarkdownPreviewView(title: export.title, markdown: export.markdown)
            }
            .sheet(isPresented: $isImportPresented) {
                MarkdownImportView()
            }
            .sheet(item: $newRoutineDraft) { draft in
                NavigationStack {
                    RoutineEditorView(routine: draft, isNew: true)
                }
            }
            .sheet(item: $editingRoutine) { routine in
                NavigationStack {
                    RoutineEditorView(routine: routine)
                }
            }
        }
    }

    /// 루틴을 마크다운으로 내보낸다. `지난 기록` 열이 F-9의 주 전달 경로다.
    private func export(_ routine: Routine) {
        let lastRecords = (try? LastRecordLookup.fetchAll(for: routine, in: modelContext)) ?? [:]
        let markdown = RoutineMarkdownExporter.export(routine, lastRecords: lastRecords)
        pendingExport = MarkdownExport(title: "루틴 마크다운", markdown: markdown)
    }

    private func duplicate(_ routine: Routine) {
        modelContext.insert(routine.duplicate())
        pushRoutines()
    }

    private func delete(_ routine: Routine) {
        modelContext.delete(routine)
        pushRoutines()
    }

    /// 루틴 목록이 바뀔 때마다 워치로 최신 상태를 다시 내려보낸다(F-8).
    private func pushRoutines() {
        try? syncService?.pushRoutines(in: modelContext)
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let onExport: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

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
        // allowsFullSwipe: false — 안 그러면 끝까지 미는 동작(메일 앱 스와이프 삭제 습관)이
        // 맨 앞 액션(삭제)을 확인 없이 바로 실행한다. 루틴은 이메일 한 통보다 훨씬 무겁다.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("삭제", systemImage: "trash", role: .destructive, action: onDelete)
            Button("복제", systemImage: "plus.square.on.square", action: onDuplicate)
                .tint(.orange)
            Button("마크다운", systemImage: "doc.on.doc", action: onExport)
                .tint(.accentColor)
        }
        .swipeActions(edge: .leading) {
            Button("편집", systemImage: "pencil", action: onEdit)
                .tint(.blue)
        }
    }
}

#Preview {
    RoutineListView()
        .environment(SessionCoordinator())
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
