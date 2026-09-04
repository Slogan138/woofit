import Foundation
import SwiftData

/// 세션 안의 세트 한 줄. 목표를 담고 결과를 덧쓴다.
@Model
public final class SessionSet {
    public var id: UUID = UUID()
    public var order: Int = 0
    public var targetWeight: Double = 0
    public var targetReps: Int = 0
    public var resultRaw: String = SetResult.pending.rawValue
    /// 목표와 다른 무게로 수행한 경우에만 값이 있다.
    public var actualWeight: Double?
    /// 실패한 세트는 반드시 값이 있다(PRD D1). 성공이면 목표 횟수와 같으므로 비운다.
    public var actualReps: Int?
    /// 이 세트를 끝낸 뒤 측정된 휴식 시간.
    public var restSeconds: Double?
    /// 휴식 측정 중일 때만 값이 있다. 세션 복원에 쓴다.
    public var restStartedAt: Date?
    public var recordedAt: Date?

    public var exercise: SessionExercise?

    public init(
        id: UUID = UUID(),
        order: Int = 0,
        targetWeight: Double = 0,
        targetReps: Int = 0
    ) {
        self.id = id
        self.order = order
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.resultRaw = SetResult.pending.rawValue
    }
}

// MARK: - 결과 기록

public extension SessionSet {
    var result: SetResult {
        get { SetResult(rawValue: resultRaw) ?? .pending }
        set { resultRaw = newValue.rawValue }
    }

    /// 실제로 다룬 무게. 조정하지 않았으면 목표 무게.
    var performedWeight: Double { actualWeight ?? targetWeight }

    /// 실제로 수행한 횟수. 성공이면 목표 횟수.
    var performedReps: Int {
        switch result {
        case .success: targetReps
        case .failure: actualReps ?? 0
        case .pending, .skipped: 0
        }
    }

    /// 목표대로 달성. 추가 입력 없이 1탭으로 끝난다(F-3).
    ///
    /// `actualWeight` 는 **기록 수정(F-15)에서만 쓴다.** 계획과 다른 무게로 성공한 경우를
    /// 나중에 바로잡기 위해서다. 실행 중에는 목표대로 들었다는 뜻이므로 넘기지 않는다.
    func markSuccess(actualWeight weight: Double? = nil, at date: Date = Date()) {
        stopRestIfNeeded(at: date)
        result = .success
        actualReps = nil
        actualWeight = weight
        recordedAt = date
    }

    /// 목표에 못 미침. 실제 횟수가 **반드시** 필요하므로 인자로 받는다.
    /// 이 API 모양 자체가 PRD D1 의 불변식을 강제한다.
    func markFailure(actualReps reps: Int, actualWeight weight: Double? = nil, at date: Date = Date()) {
        stopRestIfNeeded(at: date)
        result = .failure
        actualReps = max(0, reps)
        actualWeight = weight
        recordedAt = date
    }

    func markSkipped(at date: Date = Date()) {
        stopRestIfNeeded(at: date)
        result = .skipped
        actualReps = nil
        actualWeight = nil
        recordedAt = date
    }

    /// 기록을 되돌린다. 휴식 시간은 그대로 둔다. 실제로 쉰 것은 사실이기 때문이다.
    func clearResult() {
        result = .pending
        actualReps = nil
        actualWeight = nil
        recordedAt = nil
    }
}

// MARK: - 휴식 측정 (F-5)

public extension SessionSet {
    var isRestRunning: Bool { restStartedAt != nil }

    /// 탭하면 측정 시작.
    func startRest(at date: Date = Date()) {
        guard restStartedAt == nil else { return }
        restStartedAt = date
    }

    /// 다시 탭하면 측정 종료. 경과 시간이 이 세트의 휴식 시간이 된다.
    func stopRest(at date: Date = Date()) {
        guard let started = restStartedAt else { return }
        restSeconds = max(0, date.timeIntervalSince(started))
        restStartedAt = nil
    }

    /// 측정 중 경과 시간. 측정 중이 아니면 `nil`.
    func elapsedRest(at date: Date = Date()) -> TimeInterval? {
        guard let started = restStartedAt else { return nil }
        return max(0, date.timeIntervalSince(started))
    }

    /// 다음 세트를 기록하면 휴식도 자동으로 종료된다. 탭을 깜빡해도 값이 남는다(F-5).
    private func stopRestIfNeeded(at date: Date) {
        guard restStartedAt != nil else { return }
        stopRest(at: date)
    }
}
