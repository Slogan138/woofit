import Foundation
import SwiftUI

/// 세트 하나의 처리 결과. PRD §7 의 4상태.
public enum SetResult: String, Codable, CaseIterable, Sendable {
    /// 아직 수행하지 않음. 세션을 중단하면 이 상태로 남는다.
    case pending
    /// 목표 무게와 횟수를 그대로 달성.
    case success
    /// 목표에 못 미침. 반드시 실제 횟수가 함께 기록된다(PRD D1).
    case failure
    /// 의도적으로 건너뜀.
    case skipped

    public var displayName: String {
        switch self {
        case .pending: "미수행"
        case .success: "성공"
        case .failure: "실패"
        case .skipped: "건너뜀"
        }
    }

    /// 마크다운 출력용 기호(PRD §6.4). `pending` 은 빈 칸이다.
    public var markdownSymbol: String {
        switch self {
        case .pending: ""
        case .success: "✅"
        case .failure: "❌"
        case .skipped: "⏭"
        }
    }

    /// 결과가 기록된 상태인지. `pending` 만 미처리로 본다.
    public var isRecorded: Bool { self != .pending }

    /// 결과를 나타내는 색조. 화면마다 색이 즉흥적으로 갈리는 문제(디자인 토큰 계획 ①)를
    /// 막기 위해 결과의 시각 표현을 모델 한 곳에 둔다. 기호(`markdownSymbol`)가 이미
    /// 상태를 구분하므로 색은 항상 보조 정보로만 쓴다.
    public var tintColor: Color {
        switch self {
        case .pending: .secondary
        case .success: .green
        case .failure: .red
        case .skipped: .secondary
        }
    }
}
