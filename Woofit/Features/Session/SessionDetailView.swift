import SwiftUI
import WoofitCore

/// F-6 작업 단위 8 · 지난 세션 상세(P6). 목록은 훑어보는 곳이고 마크다운 복사는 여기서 한다.
/// 중단된 세션도 그대로 열람할 수 있어야 한다(PRD F-3) — `pending` 세트는 빈 칸으로 보여줄 뿐 막지 않는다.
struct SessionDetailView: View {
    let session: WorkoutSession

    @State private var pendingExport: MarkdownExport?

    var body: some View {
        List {
            Section {
                SummaryRow(session: session)
            }

            ForEach(session.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sortedSets) { set in
                        DetailSetRow(set: set)
                    }
                }
            }
        }
        .navigationTitle(session.routineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    pendingExport = MarkdownExport(
                        title: "세션 마크다운",
                        markdown: SessionMarkdownExporter.export(session)
                    )
                } label: {
                    Label("마크다운", systemImage: "doc.on.doc")
                }
            }
        }
        .sheet(item: $pendingExport) { export in
            MarkdownPreviewView(title: export.title, markdown: export.markdown)
        }
    }
}

private struct SummaryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.startedAt, format: .dateTime.year().month().day())
                Text("· \(session.state.displayName)")
                    .foregroundStyle(.secondary)
            }
            .font(.headline)

            Text("\(session.successSetCount)/\(session.totalSetCount) 세트 성공")
            Text("소요 시간 \(WeightFormatter.duration(session.duration))")
            if let averageRest = session.averageRestSeconds {
                Text("평균 휴식 \(WeightFormatter.rest(averageRest))")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
    }
}

private struct DetailSetRow: View {
    let set: SessionSet

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(set.order + 1)세트")
                Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(resultText)

            if let rest = set.restSeconds {
                Text(WeightFormatter.rest(rest))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    /// PRD §6.4 표기와 같다: 성공은 기호만, 실패는 기호 + 실제 횟수, 미수행은 빈 칸.
    private var resultText: String {
        switch set.result {
        case .pending: ""
        case .failure: "\(set.result.markdownSymbol) \(set.performedReps)회"
        case .success, .skipped: set.result.markdownSymbol
        }
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴", category: "가슴")
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 3, weight: 80, reps: 5)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)
    let sets = session.allSets
    sets[0].markSuccess()
    sets[1].markFailure(actualReps: 3)
    // 세 번째 세트는 pending 으로 남겨 중단된 세션을 흉내낸다.

    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(container)
}
