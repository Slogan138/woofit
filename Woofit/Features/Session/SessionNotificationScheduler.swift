import Foundation
import SwiftData
import UserNotifications
import WoofitCore
import os

/// 세션 미종료 알림을 예약하고, 알림에서 누른 `중단` 을 처리한다(F-18).
///
/// **무엇을 언제 걸지는 `SessionNotificationPlan` 이 정한다.** 여기서는 그 목록을
/// `UNUserNotificationCenter` 에 옮기기만 한다 — 규칙이 두 곳에 있으면 앱 안 배너와
/// 알림이 어긋난다.
@MainActor
final class SessionNotificationScheduler: NSObject, SessionPresence {
    private nonisolated static let logger = Logger(subsystem: "io.jwp.woofit", category: "SessionNotification")
    private nonisolated static let categoryID = "session.nudge"
    private nonisolated static let abandonActionID = "session.nudge.abandon"
    private nonisolated static let sessionIDKey = "sessionID"

    private let container: ModelContainer
    /// 알림에서 중단하면 워치도 닫아야 한다(F-8). 앱이 만들어질 때 주입된다.
    weak var syncService: WatchSyncService?

    private var didRequestAuthorization = false

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    /// 앱 시작 시 한 번. 델리게이트와 `중단` 버튼을 등록한다.
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let abandon = UNNotificationAction(
            identifier: Self.abandonActionID,
            title: "중단",
            options: [.destructive, .authenticationRequired]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryID,
                actions: [abandon],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    // MARK: - SessionPresence

    func sessionDidChange(to session: WorkoutSession?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: SessionNotificationPlan.allIdentifiers)

        let scheduled = SessionNotificationPlan.requests(for: session, thresholds: .stored())
        guard !scheduled.isEmpty else { return }

        // **권한은 첫 예약 직전에 묻는다.** 앱 첫 실행 때 물으면 무엇에 쓰는지 모르는
        // 상태에서 거부당한다(F-14 와 같은 판단).
        guard await hasAuthorization() else { return }

        for item in scheduled {
            let request = UNNotificationRequest(
                identifier: item.identifier,
                content: content(for: item, session: session),
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, item.fireDate.timeIntervalSinceNow),
                    repeats: false
                )
            )
            do {
                try await center.add(request)
            } catch {
                Self.logger.error("알림 예약 실패: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - 내부

    private func hasAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard !didRequestAuthorization else { return false }
            didRequestAuthorization = true
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            // 거부해도 앱은 그대로 동작한다. 앱 안 배너는 계속 뜬다(F-18).
            return false
        }
    }

    private func content(for item: SessionNotificationPlan.ScheduledNudge, session: WorkoutSession?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        if let session {
            content.userInfo = [Self.sessionIDKey: session.id.uuidString]
        }
        switch item.nudge {
        case .offeringEnd:
            content.title = "세션이 아직 열려 있습니다"
            content.body = "중단하면 지금까지 기록은 그대로 남습니다."
            // 버튼은 45분 알림에만 단다. 앱을 열어야 끝낼 수 있으면 달라지는 게 없다(F-18).
            content.categoryIdentifier = Self.categoryID
        case .asking, .none:
            content.title = "아직 운동 중인가요?"
            content.body = "마지막 세트를 기록한 지 꽤 지났습니다."
        }
        return content
    }

    /// 알림에서 중단한 세션을 처리한다. 앱을 열지 않고도 끝나야 한다(F-18 수용 기준).
    private func abandon(sessionID: UUID) {
        let context = container.mainContext
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        descriptor.fetchLimit = 1
        guard let session = try? context.fetch(descriptor).first, session.state == .inProgress else { return }

        session.abandon()
        try? context.save()
        // 워치가 계속 진행 중으로 보여주지 않도록 최종 상태를 보낸다(F-8).
        try? syncService?.sendInProgressSession(SessionSnapshotPayload.make(for: session))
        Self.logger.info("알림에서 세션을 중단했다")
    }
}

extension SessionNotificationScheduler: UNUserNotificationCenterDelegate {

    /// 앱이 떠 있으면 띄우지 않는다. 배너가 이미 같은 말을 하고 있다(F-18).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let raw = userInfo[Self.sessionIDKey] as? String
        let action = response.actionIdentifier
        await MainActor.run {
            guard action == Self.abandonActionID, let raw, let id = UUID(uuidString: raw) else { return }
            self.abandon(sessionID: id)
        }
    }
}
