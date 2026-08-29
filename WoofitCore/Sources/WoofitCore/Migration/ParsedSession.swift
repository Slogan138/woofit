import Foundation

/// 과거 운동일지 가져오기(F-13) 결과. SwiftData 가 아닌 값 타입이라 `ModelContext` 없이 미리보기에 쓸 수 있다.
///
/// `LegacyLogParser.parse` 가 이 값을 만들고, 사용자가 미리보기에서 확인한 뒤에야
/// `ParsedSession.makeSession()` 이 SwiftData 에 쓴다.
public struct ParsedSession: Sendable, Equatable {
    public var date: Date
    /// `## 부위` 헤더에서 읽은 값. 한 날짜에 여러 부위 섹션이 있으면 이어붙인다.
    public var category: String
    public var entries: [ParsedLogEntry]

    public init(date: Date, category: String, entries: [ParsedLogEntry]) {
        self.date = date
        self.category = category
        self.entries = entries
    }
}

public struct ParsedLogEntry: Sendable, Equatable {
    public var name: String
    public var sets: [ParsedLogSet]
    /// 비고 열. 종목명에는 붙이지 않는다 — 이름이 갈라지면 직전 기록(F-9)이 끊긴다.
    public var note: String?

    public init(name: String, sets: [ParsedLogSet], note: String? = nil) {
        self.name = name
        self.sets = sets
        self.note = note
    }
}

public struct ParsedLogSet: Sendable, Equatable {
    public var targetWeight: Double
    public var targetReps: Int
    public var result: SetResult
    /// `result == .failure` 일 때만 값이 있다(PRD D1).
    public var actualReps: Int?

    public init(targetWeight: Double, targetReps: Int, result: SetResult, actualReps: Int? = nil) {
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.result = result
        self.actualReps = actualReps
    }
}

/// `LegacyLogParser.parse` 의 반환값. 세션과 건너뛴 줄을 함께 담는다.
public struct LegacyLogParseResult: Sendable, Equatable {
    public var sessions: [ParsedSession]
    public var issues: [ParseIssue]

    public init(sessions: [ParsedSession], issues: [ParseIssue]) {
        self.sessions = sessions
        self.issues = issues
    }
}
