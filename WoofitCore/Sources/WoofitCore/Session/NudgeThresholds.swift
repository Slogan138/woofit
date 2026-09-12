import Foundation

/// 세션 안내를 언제 띄울지(F-3). 설정에서 바꾼다.
///
/// **분 단위로 저장한다.** 화면이 분으로 고르고 사용자가 분으로 생각하는 값이라,
/// 초로 저장하면 읽는 쪽마다 60 을 곱하고 나누게 된다.
///
/// `0` 은 사용하지 않는다는 뜻이다. 안내 자체를 끄고 싶을 수 있고, 별도의 켜고 끄는
/// 값을 하나 더 두는 것보다 낫다.
public struct NudgeThresholds: Codable, Hashable, Sendable {

    /// 마지막 기록 후 이만큼(분) 지나면 아직 운동 중인지 묻는다.
    public var askMinutes: Double
    /// 마지막 기록 후 이만큼(분) 지나면 계속·중단 선택지를 준다.
    public var offerEndMinutes: Double

    public init(askMinutes: Double, offerEndMinutes: Double) {
        self.askMinutes = askMinutes
        self.offerEndMinutes = offerEndMinutes
    }

    /// 실측 평균 세션이 50분이고 세트 간격이 1~3분이라, 20분 무기록은 운동 중에는 거의
    /// 걸리지 않으면서 자리를 떴다는 것만 집는다(PRD D14).
    public static let `default` = NudgeThresholds(askMinutes: 20, offerEndMinutes: 45)

    public var askAfter: TimeInterval? { askMinutes > 0 ? askMinutes * 60 : nil }
    public var offerEndAfter: TimeInterval? { offerEndMinutes > 0 ? offerEndMinutes * 60 : nil }
}

// MARK: - 저장

public extension NudgeThresholds {
    /// 화면이 `@AppStorage(NudgeThresholds.askKey)` 로 직접 묶을 수 있도록 키를 공개한다.
    /// 폰과 워치가 같은 키를 써야 폰에서 바꾼 값이 워치에 그대로 얹힌다.
    static let askKey = "nudge.askMinutes"
    static let offerEndKey = "nudge.offerEndMinutes"

    /// 저장된 값. 한 번도 저장한 적이 없으면 기본값이다.
    /// `UserDefaults` 는 없는 키에 대해 `0` 을 돌려주므로 그 경우를 구분해야 한다 —
    /// `0` 은 "끔"이라는 뜻이라 기본값과 섞이면 안 된다.
    static func stored(in defaults: UserDefaults = .standard) -> NudgeThresholds {
        NudgeThresholds(
            askMinutes: defaults.object(forKey: askKey) as? Double ?? `default`.askMinutes,
            offerEndMinutes: defaults.object(forKey: offerEndKey) as? Double ?? `default`.offerEndMinutes
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(askMinutes, forKey: Self.askKey)
        defaults.set(offerEndMinutes, forKey: Self.offerEndKey)
    }
}
