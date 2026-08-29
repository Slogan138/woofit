import Foundation
import Observation

/// 세션 화면이 지금 무엇을 보여줘야 하는가(F-4).
///
/// `focusedSet` 은 다음에 기록할 세트를 가리키도록 종목 경계를 넘어 미리 전진하지만,
/// `phase` 는 사용자가 전환을 확인하기 전까지 `transition` 에 머문다 — 그래야 전환 화면이
/// 뜬 채로 유지되고, "이전 종목으로 돌아가기" 경로(되돌리기)가 화면을 덮어쓰지 않는다.
public enum RunnerPhase {
    case recording(SessionExercise)
    case transition(from: SessionExercise, to: SessionExercise)
    case finished
}

extension RunnerPhase: Equatable {
    public static func == (lhs: RunnerPhase, rhs: RunnerPhase) -> Bool {
        switch (lhs, rhs) {
        case (.recording(let l), .recording(let r)):
            l.id == r.id
        case (.transition(let lf, let lt), .transition(let rf, let rt)):
            lf.id == rf.id && lt.id == rt.id
        case (.finished, .finished):
            true
        default:
            false
        }
    }
}

/// 세션 실행 화면의 상태. 비즈니스 로직은 `WorkoutSession`/`SessionSet` 에 이미 있으므로,
/// 여기서는 "지금 어느 세트에 초점이 있나"만 다룬다(F-3).
@Observable
public final class SessionRunner: Identifiable, Hashable {
    public var id: UUID { session.id }
    public private(set) var session: WorkoutSession
    public var focusedSet: SessionSet?
    public private(set) var phase: RunnerPhase
    public private(set) var lastRecords: [String: LastRecord]
    /// 가장 최근에 기록한 세트. 워치처럼 세트 목록 전체를 보여줄 수 없는 화면에서
    /// "직전 기록 되돌리기" 한 곳만 노출하는 데 쓴다 — 실수 탭이 잦기 때문(F-3).
    public private(set) var lastRecordedSet: SessionSet?

    public init(session: WorkoutSession, lastRecords: [String: LastRecord] = [:]) {
        self.session = session
        self.lastRecords = lastRecords
        self.focusedSet = session.nextPendingSet
        self.phase = session.currentExercise.map(RunnerPhase.recording) ?? .finished
        // refreshPhase 는 .finished 판정과 session.finish() 를 함께 하지만, 여기서는
        // phase 만 계산했다. 시작하자마자 끝난 세션(예: 종목이 0개인 루틴)을 이 경로로
        // 놓치면 state 가 inProgress 로 남아 복원 대상에 계속 잡힌다.
        if case .finished = phase, session.state == .inProgress {
            session.finish()
        }
    }

    public var isPaused: Bool { session.isPaused }

    /// 초점을 둔 세트가 속한 종목의 직전 기록. 없으면 `nil`(F-9).
    public var focusedLastRecord: LastRecord? {
        guard let name = focusedSet?.exercise?.normalizedName else { return nil }
        return lastRecords[name]
    }

    public func focus(on set: SessionSet) {
        focusedSet = set
        refreshPhase(around: set.exercise)
    }

    /// 목표대로 성공. 1탭으로 끝난다.
    public func recordSuccess(for set: SessionSet? = nil, at date: Date = Date()) {
        guard let target = set ?? focusedSet else { return }
        target.markSuccess(at: date)
        lastRecordedSet = target
        advanceFocus()
        refreshPhase(around: target.exercise)
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
        refreshPhase(around: target.exercise)
    }

    public func skip(_ set: SessionSet? = nil, at date: Date = Date()) {
        guard let target = set ?? focusedSet else { return }
        target.markSkipped(at: date)
        lastRecordedSet = target
        advanceFocus()
        refreshPhase(around: target.exercise)
    }

    /// 기록한 세트를 되돌린다. 휴식 시간은 남는다 — 실제로 쉰 것은 사실이기 때문이다.
    /// 되돌린 세트로 초점을 다시 옮긴다 — 그러지 않으면 화면에 하나만 보여주는
    /// 워치에서는 되돌리고 나서 아무것도 안 보이는 상태가 된다.
    /// 되돌린 종목이 전환·완료 화면 뒤로 이미 넘어가 있었다면 그 종목의 기록 화면으로
    /// phase 도 함께 되돌린다 — 마지막 세트를 잘못 눌러 되돌리려는데 화면이 이미
    /// 넘어가 있으면 곤란하다.
    public func undo(_ set: SessionSet) {
        set.clearResult()
        if lastRecordedSet?.id == set.id { lastRecordedSet = nil }
        focusedSet = set
        refreshPhase(around: set.exercise)
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

    /// 모든 phase 변경이 거치는 단일 진입점. `exercise` 가 아직 안 끝났으면 계속
    /// 그 종목을 기록 중인 것으로, 끝났으면 다음 종목으로 전환하거나 세션을 완료한다.
    private func refreshPhase(around exercise: SessionExercise?) {
        guard let exercise else { return }
        guard exercise.isComplete else {
            // 자동 완료 뒤에 마지막 세트를 되돌린 경우를 대칭으로 되돌린다.
            if session.state != .inProgress { session.reopen() }
            phase = .recording(exercise)
            return
        }
        if let next = nextIncompleteExercise(after: exercise) {
            phase = .transition(from: exercise, to: next)
        } else {
            phase = .finished
            session.finish()
        }
    }

    /// 순서상 다음 종목이 이미 끝나 있으면(임의 이동으로 먼저 마친 경우) 세션에서
    /// 아직 안 끝난 첫 종목으로 건너뛴다(F-4: 순서 무시 이동).
    private func nextIncompleteExercise(after exercise: SessionExercise) -> SessionExercise? {
        if let next = session.exercise(after: exercise), !next.isComplete {
            return next
        }
        return session.currentExercise
    }

    public static func == (lhs: SessionRunner, rhs: SessionRunner) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
