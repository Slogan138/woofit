import Foundation

/// 끝난 세션의 기록을 고친다(F-15).
///
/// **세션 상태는 건드리지 않는다.** 완료된 세션을 `inProgress` 로 되돌리면 몇 주 전
/// 세션이 워치로 릴레이되어 지금 운동 중인 것처럼 보인다(PRD D13).
///
/// 규칙을 화면이 아니라 여기 두는 이유는 `swift test` 가 닿게 하기 위해서다 —
/// 실패에 횟수가 반드시 따라붙는다는 불변식(D1)이 여기서도 지켜져야 한다.
public enum SessionRecordEditor {

    /// 고쳐 넣을 결과. 실패는 실제 횟수를 **타입 차원에서** 요구한다(PRD D1).
    public enum Change: Hashable, Sendable {
        case success(actualWeight: Double?)
        case failure(actualReps: Int, actualWeight: Double?)
        case skipped
    }

    /// 세트 하나를 고친다.
    ///
    /// `recordedAt` 이 갱신되므로 동기화에서 이 값이 최신으로 이긴다 — 상대 기기의
    /// 옛 값이 수정을 덮어쓰지 않는다(F-8 의 병합 규칙).
    public static func apply(_ change: Change, to set: SessionSet, at date: Date = Date()) {
        switch change {
        case .success(let weight):
            set.markSuccess(actualWeight: weight, at: date)
        case .failure(let reps, let weight):
            set.markFailure(actualReps: reps, actualWeight: weight, at: date)
        case .skipped:
            set.markSkipped(at: date)
        }
    }

    /// 지금 기록을 그대로 옮긴 `Change`. 화면이 수정 폼의 초기값으로 쓴다.
    public static func currentChange(of set: SessionSet) -> Change {
        switch set.result {
        case .failure:
            .failure(actualReps: set.actualReps ?? 0, actualWeight: set.actualWeight)
        case .skipped:
            .skipped
        // 아직 기록하지 않은 세트도 성공부터 고르게 한다 — 중단된 세션을 뒤늦게 채우는 경우다.
        case .success, .pending:
            .success(actualWeight: set.actualWeight)
        }
    }
}
