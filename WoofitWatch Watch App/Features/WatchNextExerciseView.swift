import SwiftUI
import WatchKit
import WoofitCore

/// W5 · 워치 전환 화면. 종목이 끝나면 자동으로 뜨고 햅틱으로 알린다 — 손목을 내리고
/// 있어 화면을 안 보고 있어도 진동으로 종목이 끝났음을 안다(F-4).
/// `.notification` 을 쓴다 — `.success` 는 세트 기록(성공) 피드백과 헷갈린다.
struct WatchNextExerciseView: View {
    let from: SessionExercise
    let to: SessionExercise
    let lastRecordedSet: SessionSet?
    let onStart: () -> Void
    let onUndoLast: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("\(from.name) 완료")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(to.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("\(to.sortedSets.count)세트")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // 화면이 작아 세트별 목표를 다 보여줄 수 없다. 세트마다 목표가
                // 같을 때만 대표값을 보여주고, 피라미드 세트는 시작해서 확인한다.
                if let target = to.uniformTarget {
                    Text(WeightFormatter.target(weight: target.weight, reps: target.reps))
                        .font(.title3.monospacedDigit())
                }

                Button("시작", action: onStart)
                    .buttonStyle(.borderedProminent)

                if lastRecordedSet != nil {
                    Button("직전 기록 되돌리기", action: onUndoLast)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 2)
        }
        .onAppear {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

#Preview {
    let container = try! WoofitModelContainer.makeInMemoryContainer()
    let routine = Routine(name: "월요일 가슴")
    container.mainContext.insert(routine)
    let bench = routine.appendExercise(named: "벤치프레스")
    bench.appendSets(count: 3, weight: 80, reps: 5)
    let fly = routine.appendExercise(named: "펙덱플라이")
    fly.appendSets(count: 3, weight: 40, reps: 10)

    let session = WorkoutSession.start(from: routine)
    container.mainContext.insert(session)

    return NavigationStack {
        WatchNextExerciseView(
            from: session.sortedExercises[0],
            to: session.sortedExercises[1],
            lastRecordedSet: session.allSets.first,
            onStart: {},
            onUndoLast: {}
        )
    }
}
