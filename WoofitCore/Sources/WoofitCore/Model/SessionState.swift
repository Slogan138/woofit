import Foundation

/// 세션의 진행 상태.
public enum SessionState: String, Codable, CaseIterable, Sendable {
    case inProgress
    case completed
    /// 중간에 그만둔 세션. 기록으로 남고 마크다운으로도 뽑을 수 있다.
    case abandoned

    public var displayName: String {
        switch self {
        case .inProgress: "진행 중"
        case .completed: "완료"
        case .abandoned: "중단"
        }
    }

    /// 직전 기록 조회(F-9)의 대상이 되는 상태.
    /// 진행 중인 세션은 아직 결과가 아니므로 제외한다.
    public var isFinished: Bool { self != .inProgress }
}
