import Foundation
import SwiftData

/// 종목명 자동완성 후보(F-1). 과거 루틴·세션에 쓰인 이름을 모아 사용 빈도·최근순으로 정렬한다.
public enum ExerciseNameSuggester {

    public struct Candidate: Equatable, Sendable {
        public let normalizedName: String
        /// 가장 최근에 쓰인 표기. 목록에 이 값을 보여준다.
        public let displayName: String
    }

    /// `normalizedName` 으로 표기 차이를 하나로 묶은 뒤, 사용 빈도가 높은 순으로,
    /// 빈도가 같으면 최근에 쓴 순으로 정렬한다.
    public static func suggest(in context: ModelContext) throws -> [Candidate] {
        var usage: [String: (displayName: String, count: Int, lastUsedAt: Date)] = [:]

        for exercise in try context.fetch(FetchDescriptor<PlannedExercise>()) {
            record(exercise.normalizedName, exercise.name, exercise.routine?.updatedAt ?? .distantPast, into: &usage)
        }
        for exercise in try context.fetch(FetchDescriptor<SessionExercise>()) {
            record(exercise.normalizedName, exercise.name, exercise.session?.startedAt ?? .distantPast, into: &usage)
        }

        return usage
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.value.lastUsedAt > rhs.value.lastUsedAt
            }
            .map { Candidate(normalizedName: $0.key, displayName: $0.value.displayName) }
    }

    private static func record(
        _ normalizedName: String,
        _ displayName: String,
        _ usedAt: Date,
        into usage: inout [String: (displayName: String, count: Int, lastUsedAt: Date)]
    ) {
        guard !normalizedName.isEmpty else { return }
        if var existing = usage[normalizedName] {
            existing.count += 1
            if usedAt > existing.lastUsedAt {
                existing.lastUsedAt = usedAt
                existing.displayName = displayName
            }
            usage[normalizedName] = existing
        } else {
            usage[normalizedName] = (displayName, 1, usedAt)
        }
    }
}
