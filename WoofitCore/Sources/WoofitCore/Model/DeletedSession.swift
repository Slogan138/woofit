import Foundation
import SwiftData

/// 과거 동기화 데이터가 삭제한 세션을 재생성하지 못하도록 ID를 보존한다(F-12).
@Model
public final class DeletedSession {
    public var sessionID: UUID = UUID()

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
