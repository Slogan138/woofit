import SwiftUI
import SwiftData
import WoofitCore

/// P1 · 루틴 목록(홈). 오늘 배정된 루틴을 화면 위쪽 전체에 펼치고 나머지는 가로 카드로
/// 밀어둔다(F-2, 계획 16).
///
/// 헬스장에 도착해 앱을 여는 순간 필요한 답은 "오늘 뭘 하는가" 하나다. 나머지 루틴은
/// 그다음 문제이므로 같은 크기로 나열하지 않는다.
struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.watchSyncService) private var syncService
    @Environment(SessionCoordinator.self) private var coordinator
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]

    @State private var pendingExport: MarkdownExport?
    @State private var isImportPresented = false
    @State private var newRoutineDraft: Routine?
    @State private var editingRoutine: Routine?

    private var today: Weekday { .today() }
    private var ordered: [Routine] { RoutineOrdering.forList(routines, today: today) }

    /// 화면 위쪽을 통째로 차지할 루틴. 오늘 배정된 것 중 첫 번째다.
    private var heroRoutine: Routine? {
        ordered.first { $0.isScheduled(on: today) }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Woofit")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Routine.self) { routine in
                    RoutineDetailView(routine: routine)
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

    @ViewBuilder
    private var content: some View {
        if routines.isEmpty {
            ContentUnavailableView(
                "루틴이 없습니다",
                systemImage: "dumbbell",
                description: Text("루틴을 만들거나, 노트에서 마크다운을 붙여넣어 가져오세요.")
            )
        } else if let hero = heroRoutine {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TodayHero(routine: hero, menu: { menu(for: hero) })
                    OtherRoutinesRow(
                        routines: ordered.filter { $0.id != hero.id },
                        today: today,
                        menu: { menu(for: $0) }
                    )
                }
                .padding(.vertical, 20)
            }
            .safeAreaInset(edge: .bottom) { startBar(for: hero) }
        } else {
            // 오늘 배정된 루틴이 없는 날. 히어로를 비워두면 화면 절반이 빈 채로 남으므로
            // 전체 루틴을 같은 크기 카드로 편다(계획 16 트레이드오프).
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(ordered) { routine in
                        NavigationLink(value: routine) {
                            RoutineCard(routine: routine, today: today, isWide: true)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: routine) }
                    }
                }
                .padding(16)
            }
        }
    }

    /// 홈에서 바로 세션을 시작한다(P1 역할). 종목이 없는 루틴은 시작해도 즉시 완료되므로 막는다.
    private func startBar(for routine: Routine) -> some View {
        Button {
            coordinator.start(from: routine, in: modelContext, syncService: syncService)
        } label: {
            Text("시작")
                .font(Typography.itemName)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(routine.sortedExercises.isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// 카드에는 스와이프를 걸 수 없으므로 길게 눌러 여는 메뉴로 옮겼다(계획 16).
    /// 목록에 있던 네 경로(편집·마크다운·복제·삭제)를 하나도 잃지 않는 것이 조건이었다.
    @ViewBuilder
    private func menu(for routine: Routine) -> some View {
        Button("편집", systemImage: "pencil") { editingRoutine = routine }
        Button("마크다운", systemImage: "doc.on.doc") { export(routine) }
        Button("복제", systemImage: "plus.square.on.square") { duplicate(routine) }
        Button("삭제", systemImage: "trash", role: .destructive) { delete(routine) }
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

// MARK: - 오늘

private struct TodayHero<Menu: View>: View {
    let routine: Routine
    @ViewBuilder let menu: () -> Menu

    var body: some View {
        NavigationLink(value: routine) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘 · \(Date().formatted(.dateTime.month().day().weekday(.wide)))")
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(ColorRole.accent)
                    Text(routine.resolvedTitle)
                        .font(Typography.screenTitle)
                        .multilineTextAlignment(.leading)
                    Text(RoutineSummary.text(for: routine))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                if !routine.sortedExercises.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(routine.sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                            if index > 0 {
                                Divider().padding(.leading, 16)
                            }
                            HStack(spacing: 12) {
                                Text(exercise.name)
                                Spacer(minLength: 8)
                                Text(RoutineSummary.text(for: exercise))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .background(ColorRole.cardSurface, in: .rect(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { menu() }
    }
}

// MARK: - 다른 루틴

private struct OtherRoutinesRow<Menu: View>: View {
    let routines: [Routine]
    let today: Weekday
    @ViewBuilder let menu: (Routine) -> Menu

    var body: some View {
        if !routines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("다른 루틴")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(routine: routine, today: today, isWide: false)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(routine) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                // 카드 모서리가 스크롤 영역에 잘리지 않게 한다.
                .scrollClipDisabled()
            }
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine
    let today: Weekday
    /// 오늘 루틴이 없는 날에는 같은 카드를 화면 폭으로 편다.
    let isWide: Bool

    private var scheduleLabel: String {
        if routine.isScheduled(on: today) { return "오늘" }
        return routine.isScheduled ? Weekday.label(mask: routine.weekdayMask) : "요일 미지정"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(routine.resolvedTitle)
                .font(Typography.itemName)
                .lineLimit(1)
            Text(RoutineSummary.text(for: routine))
                .font(Typography.secondary)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(scheduleLabel)
                .font(Typography.secondary)
                .foregroundStyle(routine.isScheduled(on: today) ? AnyShapeStyle(ColorRole.accent) : AnyShapeStyle(.tertiary))
        }
        .frame(width: isWide ? nil : 168, alignment: .leading)
        .frame(maxWidth: isWide ? .infinity : nil, alignment: .leading)
        .padding(14)
        .background(ColorRole.cardSurface, in: .rect(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// 루틴·종목 요약 문구를 한 곳에서 만든다. 홈의 세 자리(히어로·종목 행·카드)가
/// 같은 표기를 써야 해서 뽑았다.
private enum RoutineSummary {
    static func text(for routine: Routine) -> String {
        let category = routine.category.isEmpty ? nil : routine.category
        let composition = "\(routine.sortedExercises.count)종목 · \(routine.totalSetCount)세트"
        return [category, composition].compactMap { $0 }.joined(separator: " · ")
    }

    static func text(for exercise: PlannedExercise) -> String {
        let sets = exercise.sortedSets
        guard !sets.isEmpty else { return "세트 없음" }
        let target = WeightFormatter.targetRange(
            weights: sets.map(\.targetWeight),
            reps: sets.first?.targetReps ?? 0
        )
        return "\(sets.count)세트 · \(target)"
    }
}

#Preview {
    RoutineListView()
        .environment(SessionCoordinator())
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
