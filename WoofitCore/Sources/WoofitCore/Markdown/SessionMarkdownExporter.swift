import Foundation

/// 세션 → 마크다운(PRD §6.1, §6.2).
///
/// 순수 함수다. `ModelContext` 를 받지 않으므로 화면 없이 테스트가 완결된다.
public enum SessionMarkdownExporter {

    public static func export(_ session: WorkoutSession, style: MarkdownStyle = .default) -> String {
        var lines = [headerLine(for: session)]
        lines.append("")
        lines.append(contentsOf: metaLines(for: session))
        lines.append("")
        switch style.layout {
        case .horizontalSets:
            lines.append(horizontalTable(for: session, style: style))
        case .verticalSets:
            lines.append(verticalTable(for: session, style: style))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 헤더

    private static func headerLine(for session: WorkoutSession) -> String {
        let weekday = Weekday(calendarWeekday: Calendar.current.component(.weekday, from: session.startedAt)) ?? .sunday
        return "## \(dateFormatter.string(from: session.startedAt)) (\(weekday.shortName)) · \(session.category)"
    }

    private static func metaLines(for session: WorkoutSession) -> [String] {
        var lines = [
            "- 루틴: \(session.routineName)",
            "- 소요 시간: \(WeightFormatter.duration(session.duration))",
            "- 완료: \(performedSetCount(of: session))/\(session.totalSetCount) 세트",
        ]
        if let average = session.averageRestSeconds {
            lines.append("- 평균 휴식: \(WeightFormatter.rest(average))")
        }
        return lines
    }

    /// 실제로 시도한 세트 수. 성공·실패만 센다 — 건너뛴 세트는 "완료" 가 아니다.
    private static func performedSetCount(of session: WorkoutSession) -> Int {
        session.allSets.count { $0.result == .success || $0.result == .failure }
    }

    // MARK: - 형식 A · 세트 가로

    private static func horizontalTable(for session: WorkoutSession, style: MarkdownStyle) -> String {
        let exercises = session.sortedExercises
        let maxSetCount = exercises.map(\.sortedSets.count).max() ?? 0
        let setNumberHeaders = maxSetCount > 0 ? (1...maxSetCount).map(String.init) : []
        let headers = ["종목", "목표"] + setNumberHeaders + ["평균 휴식"]

        let rows = exercises.map { exercise -> [String] in
            let sets = exercise.sortedSets
            var row = [exercise.name, targetLabel(for: sets)]
            for index in 0..<maxSetCount {
                row.append(index < sets.count ? symbol(for: sets[index], style: style) : "")
            }
            row.append(exercise.averageRestSeconds.map(WeightFormatter.rest) ?? "")
            return row
        }
        return MarkdownTable.render(headers: headers, rows: rows)
    }

    private static func targetLabel(for sets: [SessionSet]) -> String {
        guard let first = sets.first else { return "" }
        let uniform = sets.allSatisfy { $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps }
        if uniform {
            return WeightFormatter.target(weight: first.targetWeight, reps: first.targetReps)
        }
        return WeightFormatter.targetRange(weights: sets.map(\.targetWeight), reps: first.targetReps)
    }

    private static func symbol(for set: SessionSet, style: MarkdownStyle) -> String {
        switch set.result {
        case .pending:
            return ""
        case .success:
            return style.resultSymbol == .emoji ? "✅" : "성공"
        case .skipped:
            return style.resultSymbol == .emoji ? "⏭" : "건너뜀"
        case .failure:
            let mark = style.resultSymbol == .emoji ? "❌" : "실패"
            let reps = set.actualReps ?? 0
            if let actualWeight = set.actualWeight {
                return "\(mark) \(WeightFormatter.string(actualWeight)) \(reps)"
            }
            return "\(mark) \(reps)"
        }
    }

    // MARK: - 형식 B · 세트 세로

    private static func verticalTable(for session: WorkoutSession, style: MarkdownStyle) -> String {
        let headers = ["종목", "세트", "목표", "결과", "휴식"]
        let rows = session.sortedExercises.flatMap { exercise in
            exercise.sortedSets.map { set -> [String] in
                [
                    exercise.name,
                    "\(set.order + 1)",
                    WeightFormatter.target(weight: set.targetWeight, reps: set.targetReps),
                    resultLabel(for: set),
                    set.restSeconds.map(WeightFormatter.rest) ?? "",
                ]
            }
        }
        return MarkdownTable.render(headers: headers, rows: rows)
    }

    private static func resultLabel(for set: SessionSet) -> String {
        switch set.result {
        case .pending:
            return ""
        case .success:
            return "성공"
        case .skipped:
            return "건너뜀"
        case .failure:
            let reps = set.actualReps ?? 0
            if let actualWeight = set.actualWeight {
                return "실패 (\(WeightFormatter.string(actualWeight)) \(reps)회)"
            }
            return "실패 (\(reps)회)"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
