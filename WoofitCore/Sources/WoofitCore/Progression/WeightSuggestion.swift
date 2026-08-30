import Foundation

/// 다음 세션의 목표 무게 제안(F-11).
///
/// **근거를 함께 담는다.** 세 단계 중 어디서 나왔느냐에 따라 신뢰도가 다르고,
/// 근거 없는 숫자는 신뢰받지 못한다(계획 11).
public struct WeightSuggestion: Hashable, Sendable {

    /// 제안이 나온 근거. 위에서부터 강하다(PRD D12).
    public enum Basis: Hashable, Sendable {
        /// 과거에 실제로 써본 다음 무게. 그 기구에 그 무게가 있다는 것이 이미 증명됐다.
        case knownNextWeight
        /// 그 종목에서 관측된 증량 폭.
        case observedIncrement(Double)
        /// 무게대별 기본 단위. 올려본 적이 없는 종목이라 근거가 가장 약하다.
        case defaultStep(Double)
        /// 직전에 실패한 세트가 있어 유지한다. **감량은 제안하지 않는다**(D12).
        case hold
    }

    public let normalizedName: String
    public let displayName: String
    public let currentWeight: Double
    public let suggestedWeight: Double
    public let basis: Basis

    public init(
        normalizedName: String,
        displayName: String,
        currentWeight: Double,
        suggestedWeight: Double,
        basis: Basis
    ) {
        self.normalizedName = normalizedName
        self.displayName = displayName
        self.currentWeight = currentWeight
        self.suggestedWeight = suggestedWeight
        self.basis = basis
    }
}

public extension WeightSuggestion {
    var isIncrease: Bool { suggestedWeight > currentWeight }

    /// 화면에 그대로 쓰는 한 줄. 근거가 약한 제안은 약하다고 말한다.
    var reason: String {
        switch basis {
        case .knownNextWeight:
            "전에 들어본 다음 무게"
        case .observedIncrement(let step):
            "이 종목은 \(WeightFormatter.string(step))씩 올려왔다"
        case .defaultStep(let step):
            "올려본 적이 없어 \(WeightFormatter.string(step)) 기본 단위로 제안"
        case .hold:
            "직전에 실패한 세트가 있어 유지"
        }
    }
}
