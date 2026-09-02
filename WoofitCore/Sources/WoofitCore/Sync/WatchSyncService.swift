#if canImport(WatchConnectivity)
import Foundation
import SwiftData
import WatchConnectivity
import os

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
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "WatchSync")

    private let container: ModelContainer
    private let session: WCSession

    /// 가장 최근에 받은 루틴 목록. 세션을 시작할 때 직전 기록을 꺼내 쓰는 데 쓴다(F-9).
    public private(set) var latestRoutines: [RoutinePayload] = []

    /// 가장 최근 전송 시도에서 발생한 오류. 화면 호출부는 대부분 `try?` 로 실패를 버리므로
    /// (헬스장에서 전송을 기다리게 할 수 없다, F-3) 실기기 진단은 이 값과 로그에 의존한다(리뷰 지적 ②).
    public private(set) var lastSendError: Error?

    /// 가장 최근에 받은 진행 중 세션. 반영은 자동으로 끝나 있고, 화면이 알림을 띄우고 싶을 때 쓴다.
    public private(set) var latestInProgressSession: SessionSnapshotPayload?

    /// 진행 중 세션을 받아 저장소에 반영한 직후 불린다. 화면이 그 세션을 열도록 하는 용도다(F-8).
    ///
    /// 이 타입이 `@Observable` 이 아니라 콜백을 쓴다. `NSObject` 를 상속해야 하는
    /// `WCSessionDelegate` 라서 관찰 매크로를 얹기보다 이쪽이 단순하다.
    public var didReceiveInProgressSession: (() -> Void)?

    /// `.notActivated` 면 아직 `activate()` 가 끝나지 않은 것이다 — "워치 없음"과 구분해야 한다(리뷰 지적 ③).
    public var activationState: WCSessionActivationState { session.activationState }

    #if os(iOS)
    /// 워치가 페어링돼 있는지. false 면 애초에 동기화 대상이 없다는 뜻으로, 전송 실패와는 다른 원인이다.
    public var isPaired: Bool { session.isPaired }
    /// 짝지어진 워치에 Woofit 워치 앱이 설치돼 있는지.
    public var isWatchAppInstalled: Bool { session.isWatchAppInstalled }
    #endif

    #if os(watchOS)
    /// 짝지어진 폰에 Woofit 이 설치돼 있는지.
    public var isCompanionAppInstalled: Bool { session.isCompanionAppInstalled }
    #endif

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
        try track {
            latestRoutines = payloads
            var context = session.applicationContext
            context[Self.routinesKey] = try JSONEncoder().encode(payloads)
            try session.updateApplicationContext(context)
        }
    }

    /// 로컬 저장소의 루틴 전체와 직전 기록을 모아 payload 를 만들고 그대로 내려보낸다.
    /// 화면은 언제 다시 보낼지만 정하면 되고, payload 를 어떻게 만드는지는 몰라도 된다.
    public func pushRoutines(in context: ModelContext) throws {
        try track {
            let routines = try context.fetch(FetchDescriptor<Routine>())
            let payloads = try routines.map { routine in
                RoutinePayload.make(from: routine, lastRecords: try LastRecordLookup.fetchAll(for: routine, in: context))
            }
            try sendRoutines(payloads)
        }
    }

    /// 진행 상태를 상대 기기로 보낸다. **양방향이다** — 폰에서 시작해도 워치에서 시작해도
    /// 같은 경로를 쓴다. `updateApplicationContext` 는 각 기기가 자기 것을 따로 갖는다.
    /// `nil` 이면 이어받을 세션이 없다는 뜻이다(세션을 지웠을 때).
    public func sendInProgressSession(_ payload: SessionSnapshotPayload?) throws {
        try track {
            var context = session.applicationContext
            if let payload {
                context[Self.inProgressSessionKey] = try JSONEncoder().encode(payload)
            } else {
                context.removeValue(forKey: Self.inProgressSessionKey)
            }
            try session.updateApplicationContext(context)
        }
    }

    // MARK: - 워치 → 폰

    /// 세트 하나를 기록하자마자 큐에 넣는다. 기록 자체는 로컬에 이미 끝나 있으므로
    /// 이 호출이 세트 기록 흐름을 기다리게 만들지 않는다(F-3 100ms 수용 기준).
    public func sendSetResult(_ payload: SetResultPayload) throws {
        try track {
            let data = try JSONEncoder().encode(payload)
            session.transferUserInfo([Self.setResultKey: data])
        }
    }

    /// 세션 종료 스냅샷. 세트별 전송이 하나라도 새면 이것으로 복구된다.
    public func sendSessionSnapshot(_ payload: SessionSnapshotPayload) throws {
        try track {
            let data = try JSONEncoder().encode(payload)
            session.transferUserInfo([Self.sessionSnapshotKey: data])
        }
    }

    /// 전송 성공·실패를 `lastSendError` 에 남기고, 실패는 로그로도 남긴다(리뷰 지적 ②).
    /// 호출부의 `try?` 가 오류를 버려도 여기서는 사라지지 않는다.
    private func track<T>(_ operation: () throws -> T) rethrows -> T {
        do {
            let value = try operation()
            lastSendError = nil
            return value
        } catch {
            lastSendError = error
            Self.logger.error("동기화 전송 실패: \(String(describing: error), privacy: .public)")
            throw error
        }
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

    /// `activate()` 는 비동기라, 그 전에 호출된 `pushRoutines` 는 실기기에서 조용히 실패해 있을 수 있다.
    /// 활성화가 끝난 시점에 최신 루틴을 다시 내려보내 재시도한다(리뷰 지적 ①).
    /// 루틴은 폰 → 워치 방향뿐이라 워치 쪽에서는 재전송할 것이 없다.
    private func handleActivationDidComplete(activationState: WCSessionActivationState, error: Error?) {
        if let error {
            lastSendError = error
            Self.logger.error("WCSession 활성화 실패: \(String(describing: error), privacy: .public)")
        }
        guard activationState == .activated else {
            Self.logger.notice("WCSession 활성화 미완료 (state=\(activationState.rawValue, privacy: .public))")
            return
        }
        Self.logger.info("WCSession 활성화 완료")
        // 앱이 꺼져 있는 동안 도착한 컨텍스트는 delegate 로 오지 않는다. 활성화 직후
        // 한 번 읽어줘야 한다 — 이것이 없어서 세션 이어받기가 실기기에서 동작하지
        // 않았다(F-8). 폰에서 세션을 시작할 때 워치 앱은 대개 꺼져 있다.
        consumeReceivedContext()
        #if os(iOS)
        try? pushRoutines(in: ModelContext(container))
        #endif
    }

    /// 이미 도착해 있는 `receivedApplicationContext` 를 delegate 와 똑같이 처리한다.
    ///
    /// 활성화 직후와 앱이 앞으로 나올 때 부른다. **여러 번 불러도 안전하다** —
    /// 루틴은 전체 교체이고 세션 병합은 같은 `sessionID` 를 갱신할 뿐이다.
    public func consumeReceivedContext() {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        handleApplicationContext(
            routinesData: context[Self.routinesKey] as? Data,
            inProgressData: context[Self.inProgressSessionKey] as? Data
        )
    }

    /// **두 키를 독립적으로 처리한다.** 워치가 보내는 컨텍스트에는 루틴이 없고, 폰이 보내는
    /// 컨텍스트에는 둘 다 들어 있다. 하나가 비었다고 먼저 빠져나오면 나머지를 놓친다.
    private func handleApplicationContext(routinesData: Data?, inProgressData: Data?) {
        let context = ModelContext(container)
        var changed = false
        var receivedInProgress = false

        if let routinesData,
           let payloads = try? JSONDecoder().decode([RoutinePayload].self, from: routinesData) {
            latestRoutines = payloads
            do {
                try SyncMerger.replaceRoutines(with: payloads, in: context)
                changed = true
            } catch {
                assertionFailure("루틴 동기화 수신 실패: \(error)")
            }
        }

        // 상대 기기에서 시작한 세션을 그대로 반영한다(F-8 이어받기).
        if let inProgressData,
           let payload = try? JSONDecoder().decode(SessionSnapshotPayload.self, from: inProgressData) {
            latestInProgressSession = payload
            do {
                try SyncMerger.mergeInProgress(payload, into: context)
                changed = true
                receivedInProgress = true
            } catch {
                assertionFailure("세션 동기화 수신 실패: \(error)")
            }
        }

        guard changed else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("동기화 저장 실패: \(error)")
            return
        }
        // 저장이 끝난 뒤에 알린다 — 화면이 곧바로 저장소를 다시 읽기 때문이다.
        if receivedInProgress { didReceiveInProgressSession?() }
    }
}

extension WatchSyncService: WCSessionDelegate {
    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.handleActivationDidComplete(activationState: activationState, error: error)
        }
    }

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
        let inProgressData = applicationContext[Self.inProgressSessionKey] as? Data
        Task { @MainActor in
            self.handleApplicationContext(routinesData: routinesData, inProgressData: inProgressData)
        }
    }
}
#endif
