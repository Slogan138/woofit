import Foundation
import Observation

/// 세션 실행 화면의 상태. 비즈니스 로직은 `WorkoutSession`/`SessionSet` 에 이미 있으므로,
/// 여기서는 "지금 어느 세트에 초점이 있나"만 다룬다(F-3).
@Observable
public final class SessionRunner: Identifiable, Hashable {
    public var id: UUID { session.id }
    public private(set) var session: WorkoutSession
    public var focusedSet: SessionSet?
    public private(set) var lastRecords: [String: LastRecord]
    /// 가장 최근에 기록한 세트. 워치처럼 세트 목록 전체를 보여줄 수 없는 화면에서
    /// "직전 기록 되돌리기" 한 곳만 노출하는 데 쓴다 — 실수 탭이 잦기 때문(F-3).
    public private(set) var lastRecordedSet: SessionSet?

    public init(session: WorkoutSession, lastRecords: [String: LastRecord] = [:]) {
        self.session = session
        self.lastRecords = lastRecords
        self.focusedSet = session.nextPendingSet
    }

    public var isPaused: Bool { session.isPaused }

    /// 초점을 둔 세트가 속한 종목의 직전 기록. 없으면 `nil`(F-9).
    public var focusedLastRecord: LastRecord? {
        guard let name = focusedSet?.exercise?.normalizedName else { return nil }
        return lastRecords[name]
    }

    public func focus(on set: SessionSet) {
        focusedSet = set
    }

    /// 목표대로 성공. 1탭으로 끝난다.
    public func recordSuccess(for set: SessionSet? = nil, at date: Date = Date()) {
        guard let target = set ?? focusedSet else { return }
        target.markSuccess(at: date)
        lastRecordedSet = target
        advanceFocus()
    }

    /// 실패. 실제 횟수가 인자로 강제되므로 D1 불변식을 우회할 수 없다.
    public func recordFailure(
        for set: SessionSet? = nil,
        actualReps: Int,
        actualWeight: Double? = nil,
        at date: Date = Date()
    ) {
        guard let target = set ?? focusedSet else { return }
        target.markFailure(actualReps: actualReps, actualWeight: actualWeight, at: date)
        lastRecordedSet = target
        advanceFocus()
    }

    public func skip(_ set: SessionSet? = nil, at date: Date = Date()) {
        guard let target = set ?? focusedSet else { return }
        target.markSkipped(at: date)
        lastRecordedSet = target
        advanceFocus()
    }

    /// 기록한 세트를 되돌린다. 휴식 시간은 남는다 — 실제로 쉰 것은 사실이기 때문이다.
    /// 되돌린 세트로 초점을 다시 옮긴다 — 그러지 않으면 화면에 하나만 보여주는
    /// 워치에서는 되돌리고 나서 아무것도 안 보이는 상태가 된다.
    public func undo(_ set: SessionSet) {
        set.clearResult()
        if lastRecordedSet?.id == set.id { lastRecordedSet = nil }
        focusedSet = set
    }

    public func pause(at date: Date = Date()) {
        session.pause(at: date)
    }

    public func resume() {
        session.resume()
    }

    public func finish(at date: Date = Date()) {
        session.finish(at: date)
    }

    public func abandon(at date: Date = Date()) {
        session.abandon(at: date)
    }

    private func advanceFocus() {
        focusedSet = session.nextPendingSet
    }

    public static func == (lhs: SessionRunner, rhs: SessionRunner) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
