import Foundation

/// 세션이 바뀌었을 때 **앱 밖의 표시**를 따라가게 하는 것(F-16, F-18).
///
/// 잠금화면 카드와 미종료 알림이 같은 신호를 써야 한다. 한쪽만 갱신되면 카드는 끝났는데
/// 알림은 남는 식으로 어긋난다.
///
/// **화면이 아니라 동기화 수신 경로에서 불린다.** 폰이 주머니에 있는 동안 워치가
/// 기록하면 화면이 그려지지 않아 `onChange` 가 돌지 않는다(계획 22).
///
/// 구현이 둘이 된 시점에 뽑아냈다(원칙 1).
@MainActor
public protocol SessionPresence: AnyObject {
    /// `nil` 이면 살아 있는 세션이 없다는 뜻이다 — 표시를 **지운다**.
    func sessionDidChange(to session: WorkoutSession?) async
}
