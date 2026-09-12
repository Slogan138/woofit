#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Live Activity 의 정적 부분(F-16). 세션마다 하나씩 열고 세션이 끝나면 닫는다.
///
/// 바뀌는 값은 전부 `ContentState`(`SessionLiveSnapshot`)에 있다. 여기 담는 것은
/// **세션이 바뀌었는지 판단할 식별자**뿐이다 — 다른 세션이 시작되면 열려 있던 것을
/// 끝내고 새로 열어야 한다.
/// `Sendable` 을 명시하는 이유 — `ActivityAttributes` 가 요구하지 않아서, 없으면
/// `Activity` 값을 `await` 너머로 넘길 때 Swift 6 이 데이터 경쟁으로 막는다.
public struct SessionActivityAttributes: ActivityAttributes, Sendable {
    public typealias ContentState = SessionLiveSnapshot

    public var sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
#endif
