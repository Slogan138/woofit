import SwiftUI
import SwiftData
import WoofitCore

/// P6 · 세션 기록. 전체를 영구 보관한다(PRD D3).
/// 목록은 훑어보는 곳이라 여기서는 요약만 보여준다 — 마크다운 복사는 상세 화면(`SessionDetailView`)에서 한다.
struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var pendingDeletion: WorkoutSession?

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                NavigationLink(value: session) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.routineName)
                            .font(Typography.itemName)
                        HStack(spacing: 6) {
                            Text(session.startedAt, format: .dateTime.month().day())
                            Text("· \(session.successSetCount)/\(session.totalSetCount) 세트")
                            Text("· \(session.state.displayName)")
                        }
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                // 진행 중 세션은 먼저 중단해야 지울 수 있으므로 액션 자체를 숨긴다(F-12, D7).
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if session.isDeletable {
                        Button("삭제", systemImage: "trash", role: .destructive) {
                            pendingDeletion = session
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
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
            .confirmationDialog(
                "이 기록을 삭제하시겠습니까?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { isPresented in if !isPresented { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let session = pendingDeletion {
                        delete(session)
                    }
                    pendingDeletion = nil
                }
                Button("취소", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("마크다운으로 옮기지 않았다면 이 운동 기록이 사라집니다. 되돌릴 수 없습니다.")
            }
        }
    }

    private func delete(_ session: WorkoutSession) {
        try? SessionDeletion.delete(session, in: modelContext)
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
