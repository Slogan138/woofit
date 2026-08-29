import Foundation

public extension Routine {
    /// 종목·세트를 전부 복사한 새 루틴을 만든다. 컨텍스트에 넣는 것은 호출자의 몫이다.
    ///
    /// 요일 배정은 물려주지 않는다 — 물려주면 `RoutineScheduler` 의 배타 규칙(A1)에
    /// 걸려 원본의 배정이 곧바로 해제된다.
    func duplicate() -> Routine {
        let copy = Routine(name: "\(name) 사본", category: category, note: note)
        for exercise in sortedExercises {
            let exerciseCopy = copy.appendExercise(named: exercise.name)
            for set in exercise.sortedSets {
                exerciseCopy.appendSet(weight: set.targetWeight, reps: set.targetReps)
            }
        }
        return copy
    }
}
