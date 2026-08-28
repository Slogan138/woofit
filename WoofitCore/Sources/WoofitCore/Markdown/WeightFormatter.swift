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
