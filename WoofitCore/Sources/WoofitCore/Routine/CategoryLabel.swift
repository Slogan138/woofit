import Foundation

/// 여러 부위를 담은 카테고리 문자열(F-1). `가슴 / 어깨 / 삼두` 처럼 ` / ` 로 잇는다.
///
/// **배열이 아니라 문자열로 담는 이유는 D11 에 있다.** 카테고리는 표시용 이름이지
/// 조회 키가 아니라서, 모델·마크다운·워치 payload 를 전부 문자열로 두고 화면에서만
/// 쪼개 쓴다. 이 타입이 그 쪼개고 합치는 규칙 하나를 맡는다.
public enum CategoryLabel {

    /// 화면에 다시 합칠 때 쓰는 구분자. 사용자의 기존 노트가 쓰던 모양이다.
    public static let separator = " / "

    /// 조각으로 나눈다. **빈 조각과 앞뒤 공백은 버린다** — 손으로 고치면 `가슴 / ` 처럼
    /// 끝이 열린 값이 흔하게 나오고, 그대로 두면 칩 하나가 빈 이름으로 켜진다.
    /// 구분자 좌우 공백도 요구하지 않는다(`가슴/어깨` 도 두 조각이다).
    public static func parts(of label: String) -> [String] {
        label
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static func joined(_ parts: [String]) -> String {
        parts.joined(separator: separator)
    }

    public static func contains(_ label: String, _ part: String) -> Bool {
        parts(of: label).contains(part.trimmingCharacters(in: .whitespaces))
    }

    /// 없으면 **뒤에** 붙이고 있으면 뺀다.
    ///
    /// 순서를 보존하는 것이 요점이다 — `가슴 / 어깨 / 삼두` 와 `삼두 / 어깨 / 가슴` 은
    /// 사용자에게 다른 이름이고, 마크다운으로 나가 노트에 그대로 남는다.
    public static func toggling(_ part: String, in label: String) -> String {
        let target = part.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return label }

        var current = parts(of: label)
        if let index = current.firstIndex(of: target) {
            current.remove(at: index)
        } else {
            current.append(target)
        }
        return joined(current)
    }
}
