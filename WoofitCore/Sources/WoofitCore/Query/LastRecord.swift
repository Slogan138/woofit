import Foundation
import SwiftData

/// 한 종목의 직전 수행 결과(F-9).
///
/// 점진적 과부하 판단에 필요한 건 그래프가 아니라 이 한 줄이다.
/// 저장 모델이 아니라 조회 결과를 담는 값 타입이며, 워치로 전송할 때도 이 형태로 실어 보낸다.
public struct LastRecord: Codable, Hashable, Sendable {

    public struct Entry: Codable, Hashable, Sendable {
        public let weight: Double
        public let targetReps: Int
        public let performedReps: Int
        public let result: SetResult

        public init(weight: Double, targetReps: Int, performedReps: Int, result: SetResult) {
            self.weight = weight
            self.targetReps = targetReps
            self.performedReps = performedReps
            self.result = result
        }
    }

    public let normalizedName: String
    public let displayName: String
    public let performedAt: Date
    public let entries: [Entry]

    public init(normalizedName: String, displayName: String, performedAt: Date, entries: [Entry]) {
        self.normalizedName = normalizedName
        self.displayName = displayName
        self.performedAt = performedAt
        self.entries = entries
    }
}

public extension LastRecord {
    var succeededAllSets: Bool {
        !entries.isEmpty && entries.allSatisfy { $0.result == .success }
    }

    var successCount: Int { entries.count { $0.result == .success } }

    /// 다룬 무게 중 가장 무거운 값.
    var topWeight: Double { entries.map(\.weight).max() ?? 0 }

    /// 마크다운 `지난 기록` 열과 화면 한 줄에 함께 쓰는 요약(PRD §6.3, §6.4).
    /// 예: `80kg ✅✅✅✅❌(3) · 8/24`
    /// 이모지는 한 글자씩 붙여도 경계가 보이지만, 텍스트는 그렇지 않아 공백으로 구분한다.
    func summary(resultSymbol: MarkdownStyle.ResultSymbol = .emoji) -> String {
        guard !entries.isEmpty else { return "" }

        let weightPart = WeightFormatter.string(topWeight)
        let marks = entries.map { entry -> String in
            switch (entry.result, resultSymbol) {
            case (.success, .emoji): "✅"
            case (.success, .text): "성공"
            case (.failure, .emoji): "❌(\(entry.performedReps))"
            case (.failure, .text): "실패(\(entry.performedReps))"
            case (.skipped, .emoji): "⏭"
            case (.skipped, .text): "건너뜀"
            case (.pending, _): ""
            }
        }
        let separator = resultSymbol == .emoji ? "" : " "

        return "\(weightPart) \(marks.joined(separator: separator)) · \(LastRecord.dateFormatter.string(from: performedAt))"
    }

    /// 이번 목표 무게가 직전 기록보다 얼마나 늘었나(F-9). 늘었으면 양수, 줄였으면 음수.
    ///
    /// 비교 기준이 `topWeight` 인 것은 판단이 "지난번에 든 것보다 올렸는가"이기 때문이다.
    /// 마지막 세트만 실패해 무게를 낮춰 수행했더라도 기준은 그날 가장 무겁게 든 값이다.
    /// 맨몸 운동(0kg)은 무게 비교가 뜻을 갖지 않으므로 `nil` 이다.
    ///
    /// 다음에 얼마를 들지 **제안하지 않는다** — 그건 F-11 이고 M3 다. 여기서는 이미 있는
    /// 두 값의 차이를 보여줄 뿐이다.
    func weightDelta(toTarget target: Double) -> Double? {
        guard topWeight > 0, target > 0 else { return nil }
        return target - topWeight
    }

    /// 워치처럼 폭이 좁은 화면용. 첫 세트 목표와 전체 성공 여부만 압축한다.
    /// 예: `지난번 80kg × 5 ✅`
    var compactSummary: String {
        guard let first = entries.first else { return "" }
        let target = "\(WeightFormatter.string(first.weight)) × \(first.targetReps)"
        let mark = succeededAllSets ? "✅" : "\(successCount)/\(entries.count)"
        return "지난번 \(target) \(mark)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
