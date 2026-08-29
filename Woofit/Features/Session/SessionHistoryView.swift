import SwiftUI
import SwiftData
import WoofitCore

/// P6 · 세션 기록. 전체를 영구 보관한다(PRD D3).
struct SessionHistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var pendingExport: MarkdownExport?

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.routineName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text(session.startedAt, format: .dateTime.month().day())
                        Text("· \(session.successSetCount)/\(session.totalSetCount) 세트")
                        Text("· \(session.state.displayName)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .trailing) {
                    Button("마크다운", systemImage: "doc.on.doc") {
                        pendingExport = MarkdownExport(
                            title: "세션 마크다운",
                            markdown: SessionMarkdownExporter.export(session)
                        )
                    }
                    .tint(.accentColor)
                }
            }
            .navigationTitle("기록")
            .sheet(item: $pendingExport) { export in
                MarkdownPreviewView(title: export.title, markdown: export.markdown)
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "기록이 없습니다",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("루틴을 시작하면 여기에 쌓입니다.")
                    )
                }
            }
        }
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
