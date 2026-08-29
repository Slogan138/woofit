import Foundation

/// 가져오기 도중 파싱에 실패해 건너뛴 줄. 미리보기에서 사용자에게 그대로 보여준다.
///
/// 파싱 실패한 줄이 하나 있다고 전체를 거부하지 않는다 — 오타 한 줄 때문에
/// 기능을 못 쓰게 되면 안 된다(F-7).
public struct ParseIssue: Sendable, Equatable {
    public var line: String
    public var reason: String

    public init(line: String, reason: String) {
        self.line = line
        self.reason = reason
    }
}

/// `RoutineMarkdownImporter.parse` 의 반환값. 루틴과 건너뛴 줄을 함께 담는다.
public struct ParseResult: Sendable, Equatable {
    public var routine: ParsedRoutine
    public var issues: [ParseIssue]

    public init(routine: ParsedRoutine, issues: [ParseIssue]) {
        self.routine = routine
        self.issues = issues
    }
}
