import Foundation
import SwiftData

/// 앱과 워치가 공유하는 SwiftData 스택 정의.
///
/// 지금은 각 기기에 로컬 저장소를 두고 `WatchConnectivity` 로 맞춘다(PRD §8).
/// 유료 개발자 계정을 붙인 뒤에는 `makeContainer(cloudKitContainerID:)` 에
/// 컨테이너 식별자를 넘기고 타겟의 iCloud capability 를 켜면
/// 같은 스키마 그대로 iCloud 동기화로 넘어간다(PRD D5).
public enum WoofitModelContainer {

    /// 스키마에 포함되는 모델 전체. 모델을 추가하면 여기에도 넣어야 한다.
    public static let schema = Schema([
        Routine.self,
        PlannedExercise.self,
        PlannedSet.self,
        WorkoutSession.self,
        SessionExercise.self,
        SessionSet.self
    ])

    /// 앱에서 쓰는 영구 저장소.
    ///
    /// - Parameter cloudKitContainerID: `nil` 이면 로컬 전용.
    ///   유료 계정 등록 후 `"iCloud.io.jwp.woofit"` 같은 값을 넘기면 iCloud 동기화로 전환된다.
    public static func makeContainer(cloudKitContainerID: String? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let cloudKitContainerID {
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// 프리뷰와 테스트용 인메모리 저장소.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
