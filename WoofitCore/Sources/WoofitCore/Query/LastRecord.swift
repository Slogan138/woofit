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

    /// 마크다운 `지난 기록` 열과 화면 한 줄에 함께 쓰는 요약(PRD §6.3).
    /// 예: `80kg ✅✅✅✅❌(3) · 8/24`
    var summary: String {
        guard !entries.isEmpty else { return "" }

        let weightPart = WeightFormatter.string(topWeight)
        let marks = entries.map { entry -> String in
            switch entry.result {
            case .success: "✅"
            case .failure: "❌(\(entry.performedReps))"
            case .skipped: "⏭"
            case .pending: ""
            }
        }.joined()

        return "\(weightPart) \(marks) · \(LastRecord.dateFormatter.string(from: performedAt))"
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
