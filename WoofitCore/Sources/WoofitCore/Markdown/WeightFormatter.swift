import Foundation

/// 무게 표기. 소수점이 필요할 때만 붙인다. `80kg`, `22.5kg`, 맨몸이면 `맨몸`.
public enum WeightFormatter {

    public static func string(_ weight: Double) -> String {
        guard weight > 0 else { return "맨몸" }
        if weight.rounded() == weight {
            return "\(Int(weight))kg"
        }
        return String(format: "%.1fkg", weight)
    }

    /// `80kg × 5` 형태. 마크다운 `목표` 열(PRD §6.4).
    public static func target(weight: Double, reps: Int) -> String {
        "\(string(weight)) × \(reps)"
    }

    /// 세트마다 무게가 다른 피라미드 세트의 목표 표기. `70~80kg × 5`(PRD §6.1).
    /// 무게가 전부 같으면 `target(weight:reps:)` 과 같은 결과를 낸다.
    public static func targetRange(weights: [Double], reps: Int) -> String {
        guard let low = weights.min(), let high = weights.max() else { return "" }
        guard low != high else { return target(weight: low, reps: reps) }
        let lowLabel = string(low).replacingOccurrences(of: "kg", with: "")
        return "\(lowLabel)~\(string(high)) × \(reps)"
    }

    /// 직전 기록 대비 증감. `+2.5kg`, `-5kg`, 차이가 없으면 `유지`(F-9).
    /// 부호를 붙여야 하므로 `string(_:)` 을 그대로 쓸 수 없다 — 0 을 `맨몸` 으로
    /// 표기하는 규칙도 여기서는 뜻이 다르다.
    public static func delta(_ delta: Double) -> String {
        guard delta != 0 else { return "유지" }
        return (delta > 0 ? "+" : "-") + string(abs(delta))
    }

    /// `2'30"` 형태. 마크다운 `휴식` 열.
    public static func rest(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    /// `1시간 12분`, `48분` 형태. 마크다운 `소요 시간` 항목.
    public static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds.rounded()) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
        }
        return "\(minutes)분"
    }
}
