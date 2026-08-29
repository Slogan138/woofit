import SwiftUI
import SwiftData
import WoofitCore

/// P1 · 루틴 목록. 오늘 요일에 배정된 루틴을 위에 둔다(F-2).
struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    @State private var pendingExport: MarkdownExport?
    @State private var isImportPresented = false

    private var today: Weekday { .today() }

    private var todaysRoutines: [Routine] {
        RoutineOrdering.forList(routines, today: today).filter { $0.isScheduled(on: today) }
    }

    private var otherRoutines: [Routine] {
        RoutineOrdering.forList(routines, today: today).filter { !$0.isScheduled(on: today) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !todaysRoutines.isEmpty {
                    Section("오늘 · \(today.fullName)") {
                        ForEach(todaysRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(routine: routine, onExport: { export(routine) })
                            }
                        }
                    }
                }
                if !otherRoutines.isEmpty {
                    Section(todaysRoutines.isEmpty ? "루틴" : "다른 루틴") {
                        ForEach(otherRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(routine: routine, onExport: { export(routine) })
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
                    Button {
                        isImportPresented = true
                    } label: {
                        Label("가져오기", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(item: $pendingExport) { export in
                MarkdownPreviewView(title: export.title, markdown: export.markdown)
            }
            .sheet(isPresented: $isImportPresented) {
                MarkdownImportView()
            }
        }
    }

    /// 루틴을 마크다운으로 내보낸다. `지난 기록` 열이 F-9의 주 전달 경로다.
    private func export(_ routine: Routine) {
        let lastRecords = (try? LastRecordLookup.fetchAll(for: routine, in: modelContext)) ?? [:]
        let markdown = RoutineMarkdownExporter.export(routine, lastRecords: lastRecords)
        pendingExport = MarkdownExport(title: "루틴 마크다운", markdown: markdown)
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let onExport: () -> Void

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
        .swipeActions(edge: .trailing) {
            Button("마크다운", systemImage: "doc.on.doc", action: onExport)
                .tint(.accentColor)
        }
    }
}

#Preview {
    RoutineListView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
