import Foundation
import SwiftData

/// `ParsedRoutine` → SwiftData 반영. 사용자가 미리보기에서 확인한 뒤에만 호출한다.
public extension ParsedRoutine {

    /// 새 루틴을 만든다. 컨텍스트에 넣는 것은 호출하는 쪽이 한다.
    func makeRoutine() -> Routine {
        let routine = Routine(name: title, category: category, weekdayMask: weekdayMask)
        appendExercises(to: routine)
        return routine
    }

    /// 기존 루틴에 덮어쓴다. **되돌릴 수 없다** — 기존 종목·세트가 전부 교체된다.
    func apply(to routine: Routine) {
        for exercise in routine.sortedExercises {
            routine.modelContext?.delete(exercise)
        }
        routine.exercises = []

        routine.name = title
        routine.category = category
        routine.weekdayMask = weekdayMask
        appendExercises(to: routine)
        routine.touch()
    }

    private func appendExercises(to routine: Routine) {
        for parsedExercise in exercises {
            let exercise = routine.appendExercise(named: parsedExercise.name)
            for set in parsedExercise.sets {
                exercise.appendSet(weight: set.targetWeight, reps: set.targetReps)
            }
        }
    }
}
