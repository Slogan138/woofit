import SwiftUI
import WoofitCore

/// F-4 전환 화면. 한 종목의 모든 세트가 처리되면 자동으로 뜬다.
/// 방금 끝난 종목으로 되돌아가는 경로(되돌리기)를 남겨, 마지막 세트를 잘못 눌러도
/// 화면이 이미 넘어간 채로 갇히지 않게 한다.
struct NextExerciseView: View {
    let from: SessionExercise
    let to: SessionExercise
    let lastRecordedSet: SessionSet?
    let onStart: () -> Void
    let onUndoLast: () -> Void
    let onPickAnother: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("\(from.name) 완료")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(to.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("\(to.sortedSets.count)세트")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    ForEach(to.sortedSets) { set in
                        Text(WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps))
                            .font(.body)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button("시작", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                    // 제안된 다음 종목의 기구가 사용 중일 수 있으므로 순서를 무시하고
                    // 다른 종목으로 바로 옮겨갈 경로를 남긴다(F-4).
                    Button("다른 종목 먼저 하기", action: onPickAnother)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                    if lastRecordedSet != nil {
                        Button("직전 기록 되돌리기", action: onUndoLast)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
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
    let fly = routine.appendExercise(named: "펙덱플라이")
    fly.appendSets(count: 3, weight: 40, reps: 10)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)

    return NextExerciseView(
        from: session.sortedExercises[0],
        to: session.sortedExercises[1],
        lastRecordedSet: session.allSets.first,
        onStart: {},
        onUndoLast: {},
        onPickAnother: {}
    )
}
