#if canImport(WatchConnectivity)
import Foundation
import SwiftData
import WatchConnectivity

/// `WCSession` 래퍼(F-8). 전송·수신만 담당하고, 반영은 순수 함수인 `SyncMerger` 에 맡긴다.
///
/// 전송 방식은 방향별로 나뉜다(PRD §8).
/// - 루틴 + 진행 중 세션(폰 → 워치): `updateApplicationContext` — 덮어쓰기, 최신 것만 도착하면 충분
/// - 세트 결과 + 종료 스냅샷(워치 → 폰): `transferUserInfo` — 큐잉 보장 전달
///
/// `sendMessage` 는 쓰지 않는다. 상대가 그 순간 도달 가능해야만 동작해 헬스장에서 유실된다.
@MainActor
public final class WatchSyncService: NSObject {
    // 상수 문자열이라 격리와 무관하지만, 델리게이트 콜백(nonisolated)에서 그대로 읽어야 해서 명시한다.
    private nonisolated static let routinesKey = "routines"
    private nonisolated static let inProgressSessionKey = "inProgressSession"
    private nonisolated static let setResultKey = "setResult"
    private nonisolated static let sessionSnapshotKey = "sessionSnapshot"

    private let container: ModelContainer
    private let session: WCSession

    /// 가장 최근에 받은 루틴 목록. 세션을 시작할 때 직전 기록을 꺼내 쓰는 데 쓴다(F-9).
    public private(set) var latestRoutines: [RoutinePayload] = []

    public init(container: ModelContainer, session: WCSession = .default) {
        self.container = container
        self.session = session
        super.init()
        session.delegate = self
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        session.activate()
    }

    // MARK: - 폰 → 워치

    /// 루틴 전체를 워치로 내려보낸다. 항상 최신 상태로 덮어쓴다.
    public func sendRoutines(_ payloads: [RoutinePayload]) throws {
        latestRoutines = payloads
        var context = session.applicationContext
        context[Self.routinesKey] = try JSONEncoder().encode(payloads)
        try session.updateApplicationContext(context)
    }

    /// 로컬 저장소의 루틴 전체와 직전 기록을 모아 payload 를 만들고 그대로 내려보낸다.
    /// 화면은 언제 다시 보낼지만 정하면 되고, payload 를 어떻게 만드는지는 몰라도 된다.
    public func pushRoutines(in context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let payloads = try routines.map { routine in
            RoutinePayload.make(from: routine, lastRecords: try LastRecordLookup.fetchAll(for: routine, in: context))
        }
        try sendRoutines(payloads)
    }

    /// 폰에서 시작한 세션을 워치가 이어받도록 진행 상태를 내려보낸다. `nil` 이면 이어받을 세션이 없다는 뜻.
    public func sendInProgressSession(_ payload: SessionSnapshotPayload?) throws {
        var context = session.applicationContext
        if let payload {
            context[Self.inProgressSessionKey] = try JSONEncoder().encode(payload)
        } else {
            context.removeValue(forKey: Self.inProgressSessionKey)
        }
        try session.updateApplicationContext(context)
    }

    // MARK: - 워치 → 폰

    /// 세트 하나를 기록하자마자 큐에 넣는다. 기록 자체는 로컬에 이미 끝나 있으므로
    /// 이 호출이 세트 기록 흐름을 기다리게 만들지 않는다(F-3 100ms 수용 기준).
    public func sendSetResult(_ payload: SetResultPayload) throws {
        let data = try JSONEncoder().encode(payload)
        session.transferUserInfo([Self.setResultKey: data])
    }

    /// 세션 종료 스냅샷. 세트별 전송이 하나라도 새면 이것으로 복구된다.
    public func sendSessionSnapshot(_ payload: SessionSnapshotPayload) throws {
        let data = try JSONEncoder().encode(payload)
        session.transferUserInfo([Self.sessionSnapshotKey: data])
    }

    // MARK: - 수신 처리

    private func handleUserInfo(setResultData: Data?, snapshotData: Data?) {
        let context = ModelContext(container)
        do {
            if let setResultData {
                let payload = try JSONDecoder().decode(SetResultPayload.self, from: setResultData)
                try SyncMerger.merge(payload, into: context)
                try context.save()
            }
            if let snapshotData {
                let payload = try JSONDecoder().decode(SessionSnapshotPayload.self, from: snapshotData)
                try SyncMerger.merge(payload, into: context)
                try context.save()
            }
        } catch {
            assertionFailure("동기화 수신 실패: \(error)")
        }
    }

    private func handleApplicationContext(routinesData: Data?) {
        // "inProgressSession" 은 워치·폰 세션 이어받기 화면이 직접 디코드해 쓴다.
        // SwiftData 세션으로 바로 반영하면 이미 로컬에서 진행 중인 세션과 충돌할 수 있어서다.
        guard let routinesData, let payloads = try? JSONDecoder().decode([RoutinePayload].self, from: routinesData) else {
            return
        }
        latestRoutines = payloads
        let context = ModelContext(container)
        do {
            try SyncMerger.replaceRoutines(with: payloads, in: context)
            try context.save()
        } catch {
            assertionFailure("동기화 수신 실패: \(error)")
        }
    }
}

extension WatchSyncService: WCSessionDelegate {
    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    // `[String: Any]` 는 Sendable 이 아니라 MainActor 클로저로 그대로 넘길 수 없다.
    // Data 만 미리 꺼내 넘긴다 — Data 는 Sendable 이다.
    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let setResultData = userInfo[Self.setResultKey] as? Data
        let snapshotData = userInfo[Self.sessionSnapshotKey] as? Data
        Task { @MainActor in
            self.handleUserInfo(setResultData: setResultData, snapshotData: snapshotData)
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let routinesData = applicationContext[Self.routinesKey] as? Data
        Task { @MainActor in
            self.handleApplicationContext(routinesData: routinesData)
        }
    }
}
#endif
