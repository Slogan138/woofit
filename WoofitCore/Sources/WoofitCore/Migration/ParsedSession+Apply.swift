import Foundation
import SwiftData

/// `ParsedSession` → SwiftData 반영. 사용자가 미리보기에서 확인한 뒤에만 호출한다.
public extension ParsedSession {

    /// 새 세션을 만든다. 컨텍스트에 넣는 것은 호출하는 쪽이 한다.
    ///
    /// 원본에는 시각 정보가 없어 `date` 를 그대로 시작·종료 시각으로 쓴다(계획 §변환 규칙).
    /// 상태는 전부 `completed` 다 — 원본이 이미 끝난 과거 기록이기 때문이다.
    func makeSession() -> WorkoutSession {
        let session = WorkoutSession(routineName: category, category: category, startedAt: date)
        session.endedAt = date
        session.state = .completed
        session.note = aggregatedNote

        var copiedExercises: [SessionExercise] = []
        for (order, entry) in entries.enumerated() {
            let exercise = SessionExercise(name: entry.name, order: order)
            exercise.session = session

            var copiedSets: [SessionSet] = []
            for (setOrder, parsedSet) in entry.sets.enumerated() {
                let set = SessionSet(order: setOrder, targetWeight: parsedSet.targetWeight, targetReps: parsedSet.targetReps)
                set.exercise = exercise
                switch parsedSet.result {
                case .success:
                    set.markSuccess(at: date)
                case .failure:
                    set.markFailure(actualReps: parsedSet.actualReps ?? 0, at: date)
                case .pending, .skipped:
                    break
                }
                copiedSets.append(set)
            }
            exercise.sets = copiedSets
            copiedExercises.append(exercise)
        }
        session.exercises = copiedExercises
        return session
    }

    /// 비고 열은 종목별로 달려 있지만 `WorkoutSession.note` 는 세션 하나에 한 값이라 이어붙인다.
    /// 종목명 뒤에 붙이지 않는 이유는 `ParsedLogEntry.note` 문서 참고.
    private var aggregatedNote: String {
        entries.compactMap { entry -> String? in
            guard let note = entry.note, !note.isEmpty else { return nil }
            return "\(entry.name): \(note)"
        }.joined(separator: "\n")
    }
}
