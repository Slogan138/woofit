import SwiftUI
import WoofitCore

/// F-4 세션 완료 화면(P5). 마지막 종목까지 끝나면 전환 화면 대신 자동으로 뜬다.
/// 요약 · 마크다운 미리보기 · 복사는 F-6 화면(`MarkdownPreviewView`)을 그대로 재사용한다.
struct SessionCompleteView: View {
    let session: WorkoutSession
    let onViewMarkdown: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("세션 완료")
                        .font(Typography.screenTitle)
                }

                VStack(spacing: 4) {
                    Text("\(session.successSetCount)/\(session.totalSetCount) 세트 성공")
                        .font(Typography.itemName)
                    if let averageRest = session.averageRestSeconds {
                        Text("평균 휴식 \(WeightFormatter.rest(averageRest))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button("마크다운 보기", action: onViewMarkdown)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("닫기", action: onClose)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
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
    for set in session.allSets { set.markSuccess() }

    return SessionCompleteView(session: session, onViewMarkdown: {}, onClose: {})
}
