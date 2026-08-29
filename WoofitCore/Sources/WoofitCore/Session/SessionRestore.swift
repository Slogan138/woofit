import Foundation
import SwiftData

/// 진행 중인 세션 복원(F-3). 앱을 강제 종료했다가 다시 열어도 진행 위치를 이어받기 위함이다.
public enum SessionRestore {

    /// 진행 중인 세션. 동시에 하나만 진행한다는 전제이므로 있으면 그것 하나를 돌려준다.
    /// 일시정지 중이어도 `stateRaw` 는 여전히 `inProgress` 이므로 함께 찾힌다.
    public static func fetchInProgress(in context: ModelContext) throws -> WorkoutSession? {
        let inProgress = SessionState.inProgress.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.stateRaw == inProgress }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
