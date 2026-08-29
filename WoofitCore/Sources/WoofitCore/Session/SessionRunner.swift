import Foundation
import Observation

/// 세션 실행 화면의 상태. 비즈니스 로직은 `WorkoutSession`/`SessionSet` 에 이미 있으므로,
/// 여기서는 "지금 어느 세트에 초점이 있나"만 다룬다(F-3).
@Observable
public final class SessionRunner: Identifiable {
    public var id: UUID { session.id }
    public private(set) var session: WorkoutSession
    public var focusedSet: SessionSet?
    public private(set) var lastRecords: [String: LastRecord]

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
        advanceFocus()
    }

    public func skip(_ set: SessionSet? = nil, at date: Date = Date()) {
        guard let target = set ?? focusedSet else { return }
        target.markSkipped(at: date)
        advanceFocus()
    }

    /// 기록한 세트를 되돌린다. 휴식 시간은 남는다 — 실제로 쉰 것은 사실이기 때문이다.
    public func undo(_ set: SessionSet) {
        set.clearResult()
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
}
