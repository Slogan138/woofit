import SwiftData
import SwiftUI
import WoofitCore

/// 화면 전환이 끝난 뒤에 세션을 지운다(F-12).
///
/// 삭제를 버튼 액션에서 곧바로 하면 다이얼로그 닫힘·행 닫힘·목록 변화가 한 프레임에 겹쳐
/// 끊겨 보이고, 닫히는 중인 상세 화면이 **이미 지워진 SwiftData 객체를 렌더**할 수도 있다.
/// SwiftUI 가 전환 완료 콜백을 주지 않으므로 시간으로 미룬다.
@MainActor
enum DeferredSessionDeletion {
    /// 표준 다이얼로그 닫힘·pop 애니메이션이 끝나기를 기다리는 시간.
    private static let transition = Duration.milliseconds(320)

    /// 뷰가 사라진 뒤에도 삭제는 끝나야 하므로 구조화되지 않은 `Task` 를 쓰고,
    /// 화면에서 떼어낸 `context` 를 캡처한다.
    static func delete(_ session: WorkoutSession, in context: ModelContext) {
        Task { @MainActor in
            try? await Task.sleep(for: transition)
            withAnimation {
                try? SessionDeletion.delete(session, in: context)
            }
        }
    }
}
