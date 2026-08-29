import Foundation

/// 루틴 → 마크다운(PRD §6.3).
///
/// 순수 함수다. `지난 기록` 은 호출하는 쪽에서 `LastRecordLookup.fetchAll` 로 조회해 넘긴다.
/// 그래야 화면 없이 테스트가 완결된다.
public enum RoutineMarkdownExporter {

    public static func export(
        _ routine: Routine,
        lastRecords: [String: LastRecord] = [:],
        style: MarkdownStyle = .default
    ) -> String {
        var lines = [headerLine(for: routine)]
        lines.append("")
        lines.append(contentsOf: metaLines(for: routine))
        lines.append("")
        lines.append(table(for: routine, lastRecords: lastRecords, style: style))
        return lines.joined(separator: "\n")
    }

    private static func headerLine(for routine: Routine) -> String {
        let title = routine.resolvedTitle
        guard !routine.category.isEmpty, routine.category != title else {
            return "## \(title)"
        }
        return "## \(title) · \(routine.category)"
    }

    private static func metaLines(for routine: Routine) -> [String] {
        var lines = ["- 부위: \(routine.category)"]
        if routine.isScheduled {
            lines.append("- 반복: \(Weekday.label(mask: routine.weekdayMask))")
        }
        return lines
    }

    private static func table(for routine: Routine, lastRecords: [String: LastRecord], style: MarkdownStyle) -> String {
        let headers = ["종목", "목표", "세트", "지난 기록"]
        let rows = routine.sortedExercises.map { exercise -> [String] in
            let sets = exercise.sortedSets
            return [
                exercise.name,
                targetLabel(for: sets),
                "\(sets.count)",
                lastRecords[exercise.normalizedName]?.summary(resultSymbol: style.resultSymbol) ?? "",
            ]
        }
        return MarkdownTable.render(headers: headers, rows: rows)
    }

    private static func targetLabel(for sets: [PlannedSet]) -> String {
        guard let first = sets.first else { return "" }
        let uniform = sets.allSatisfy { $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps }
        if uniform {
            return WeightFormatter.target(weight: first.targetWeight, reps: first.targetReps)
        }
        return WeightFormatter.targetRange(weights: sets.map(\.targetWeight), reps: first.targetReps)
    }
}
