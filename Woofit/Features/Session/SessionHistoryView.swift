import SwiftUI
import SwiftData
import WoofitCore

/// P6 · 세션 기록. 전체를 영구 보관한다(PRD D3).
/// 목록은 훑어보는 곳이라 여기서는 요약만 보여준다 — 마크다운 복사는 상세 화면(`SessionDetailView`)에서 한다.
struct SessionHistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

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
        }
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
