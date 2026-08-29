import Foundation
import SwiftData

/// `ParsedSession` 여러 개를 한 번에 반영한다(F-13).
///
/// 73개 세션이 한 번에 들어가고 되돌리기 어려우므로(F-12 로 하나씩 지워야 한다) **멱등하게**
/// 만든다 — 같은 날짜의 세션이 이미 있으면 건너뛴다. 재실행이 안전해야 미리보기 확인 뒤
/// 안심하고 적용할 수 있다.
public enum LegacyLogImporter {

    public struct Summary: Sendable, Equatable {
        public var addedSessionCount: Int
        public var skippedDates: [Date]

        public init(addedSessionCount: Int, skippedDates: [Date]) {
            self.addedSessionCount = addedSessionCount
            self.skippedDates = skippedDates
        }
    }

    public static func apply(_ sessions: [ParsedSession], in context: ModelContext) throws -> Summary {
        let existingDays = Set(
            try context.fetch(FetchDescriptor<WorkoutSession>())
                .map { Calendar.current.startOfDay(for: $0.startedAt) }
        )

        var addedSessionCount = 0
        var skippedDates: [Date] = []
        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.date)
            guard !existingDays.contains(day) else {
                skippedDates.append(session.date)
                continue
            }
            context.insert(session.makeSession())
            addedSessionCount += 1
        }
        return Summary(addedSessionCount: addedSessionCount, skippedDates: skippedDates)
    }
}
