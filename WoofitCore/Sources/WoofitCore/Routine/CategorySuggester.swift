import Foundation
import SwiftData

/// 카테고리 제안(F-1). 과거 루틴·세션에 쓰인 부위를 모아 빈도·최근순으로 정렬한다.
/// `ExerciseNameSuggester` 와 같은 구조다 — 같은 문제라서 같은 모양으로 둔다.
///
/// **한 칸씩 쪼개서 센다.** `가슴 / 어깨` 는 `가슴` 한 번과 `어깨` 한 번이지
/// `가슴 / 어깨` 라는 항목 하나가 아니다. 그래야 칩을 조합해 쓸 수 있다.
public enum CategorySuggester {

    public static func suggest(in context: ModelContext) throws -> [String] {
        var usage: [String: (count: Int, lastUsedAt: Date)] = [:]

        for routine in try context.fetch(FetchDescriptor<Routine>()) {
            record(routine.category, at: routine.updatedAt, into: &usage)
        }
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) {
            record(session.category, at: session.startedAt, into: &usage)
        }

        return usage
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.value.lastUsedAt > rhs.value.lastUsedAt
            }
            .map(\.key)
    }

    private static func record(
        _ label: String,
        at usedAt: Date,
        into usage: inout [String: (count: Int, lastUsedAt: Date)]
    ) {
        for part in CategoryLabel.parts(of: label) {
            if var existing = usage[part] {
                existing.count += 1
                existing.lastUsedAt = max(existing.lastUsedAt, usedAt)
                usage[part] = existing
            } else {
                usage[part] = (1, usedAt)
            }
        }
    }
}
