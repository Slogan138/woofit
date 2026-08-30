import SwiftUI
import SwiftData
import WoofitCore

/// P6 · 세션 기록. 전체를 영구 보관한다(PRD D3).
/// 목록은 훑어보는 곳이라 여기서는 요약만 보여준다 — 마크다운 복사는 상세 화면(`SessionDetailView`)에서 한다.
///
/// 월 단위로 묶고 각 행에 성공 세트 비율을 깐다(계획 16). 날짜만 나열하면 "그날 얼마나
/// 해냈나"를 상세로 들어가야 알 수 있는데, 그 값은 이미 행에 숫자로 있던 것이다.
struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var pendingDeletion: WorkoutSession?

    var body: some View {
        NavigationStack {
            List {
                ForEach(SessionHistoryGrouping.byMonth(sessions)) { month in
                    Section(month.title) {
                        ForEach(month.sessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session)
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

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.routineName)
                    .font(Typography.itemName)
                Spacer(minLength: 8)
                Text("\(session.successSetCount)/\(session.totalSetCount) 세트")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(session.startedAt, format: .dateTime.month().day())
                if session.endedAt != nil {
                    Text("· \(WeightFormatter.duration(session.duration))")
                }
                if session.state != .completed {
                    StateBadge(state: session.state)
                }
            }
            .font(Typography.secondary)
            .monospacedDigit()
            .foregroundStyle(.secondary)

            SuccessBar(success: session.successSetCount, total: session.totalSetCount)
        }
        .padding(.vertical, 4)
    }
}

/// 완료가 아닌 상태만 표시한다. 완료가 기본값이라 뱃지를 달면 목록이 뱃지로 뒤덮인다.
private struct StateBadge: View {
    let state: SessionState

    private var tint: Color {
        state == .inProgress ? ColorRole.accent : SetResult.failure.tintColor
    }

    var body: some View {
        Text(state.displayName)
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: 6, style: .continuous))
    }
}

/// 성공 세트 비율. 같은 값이 바로 위에 `10/11 세트` 로 적혀 있으므로 색만으로 뜻을
/// 전달하지 않는다(PRD §9). 접근성 트리에서도 중복이라 뺀다.
private struct SuccessBar: View {
    let success: Int
    let total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(success) / Double(total)
    }

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(SetResult.success.tintColor)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
