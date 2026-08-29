import Foundation

/// 마크다운 → `ParsedRoutine`(PRD §6.5).
///
/// 순수 함수다. `ModelContext` 를 받지 않으므로 미리보기가 화면 없이 완결된다.
/// 세 형식(§6.1 세트 가로 · §6.2 세트 세로 · §6.3 루틴)을 헤더 행으로 판별해 모두 받는다.
public enum RoutineMarkdownImporter {

    public static func parse(_ text: String) -> ParseResult {
        let normalized = text.normalizingNewlines()
        let lines = normalized.components(separatedBy: .newlines)
        let metadata = parseMetadata(lines: lines)

        guard let table = MarkdownTableParser.parse(normalized) else {
            return ParseResult(
                routine: ParsedRoutine(title: metadata.title, category: metadata.category, weekdayMask: metadata.weekdayMask, exercises: []),
                issues: [ParseIssue(line: "", reason: "표를 찾을 수 없습니다")]
            )
        }

        guard let format = TableFormat(headers: table.headers) else {
            return ParseResult(
                routine: ParsedRoutine(title: metadata.title, category: metadata.category, weekdayMask: metadata.weekdayMask, exercises: []),
                issues: [ParseIssue(line: table.headers.joined(separator: " | "), reason: "지원하지 않는 표 형식입니다")]
            )
        }

        var issues: [ParseIssue] = []
        let exercises: [ParsedExercise]
        switch format {
        case .routine(let nameIndex, let targetIndex, let setsIndex):
            exercises = parseRoutineRows(table.rows, nameIndex: nameIndex, targetIndex: targetIndex, setsIndex: setsIndex, issues: &issues)
        case .horizontalSession(let nameIndex, let targetIndex, let setColumns):
            exercises = parseHorizontalRows(table.rows, nameIndex: nameIndex, targetIndex: targetIndex, setColumns: setColumns, issues: &issues)
        case .verticalSession(let nameIndex, let targetIndex):
            exercises = parseVerticalRows(table.rows, nameIndex: nameIndex, targetIndex: targetIndex, issues: &issues)
        }

        let routine = ParsedRoutine(title: metadata.title, category: metadata.category, weekdayMask: metadata.weekdayMask, exercises: exercises)
        return ParseResult(routine: routine, issues: issues)
    }
}

// MARK: - 형식 판별

private enum TableFormat {
    case routine(nameIndex: Int, targetIndex: Int, setsIndex: Int)
    case verticalSession(nameIndex: Int, targetIndex: Int)
    case horizontalSession(nameIndex: Int, targetIndex: Int, setColumns: [Int])

    /// `세트` 열이 있고 `결과` 열이 없으면 루틴, `결과` 열이 있으면 형식 B,
    /// 숫자 헤더(`1`, `2`, …)가 있으면 형식 A(PRD §6.5).
    init?(headers: [String]) {
        guard let targetIndex = headers.firstIndex(of: "목표") else { return nil }
        let nameIndex = headers.firstIndex(of: "종목") ?? 0

        if headers.contains("결과") {
            self = .verticalSession(nameIndex: nameIndex, targetIndex: targetIndex)
            return
        }
        if let setsIndex = headers.firstIndex(of: "세트") {
            self = .routine(nameIndex: nameIndex, targetIndex: targetIndex, setsIndex: setsIndex)
            return
        }
        let setColumns = headers.indices.filter { Int(headers[$0]) != nil }
        guard !setColumns.isEmpty else { return nil }
        self = .horizontalSession(nameIndex: nameIndex, targetIndex: targetIndex, setColumns: setColumns)
    }
}

// MARK: - 행 파싱

private func parseRoutineRows(
    _ rows: [MarkdownTableParser.Row],
    nameIndex: Int,
    targetIndex: Int,
    setsIndex: Int,
    issues: inout [ParseIssue]
) -> [ParsedExercise] {
    var exercises: [ParsedExercise] = []
    for row in rows {
        guard let name = cell(row, at: nameIndex, issues: &issues) else { continue }
        guard row.cells.indices.contains(setsIndex), let setCount = Int(row.cells[setsIndex]), setCount > 0 else {
            issues.append(ParseIssue(line: row.rawLine, reason: "세트 수를 읽을 수 없습니다"))
            continue
        }
        guard let target = target(row, at: targetIndex, issues: &issues) else { continue }
        let sets = target.weights(forSetCount: setCount).map { ParsedSet(targetWeight: $0, targetReps: target.reps) }
        exercises.append(ParsedExercise(name: name, sets: sets))
    }
    return exercises
}

/// **세트 수 = 값이 있는 칸의 개수.** 빈 칸(미수행 세트)은 세지 않는다.
private func parseHorizontalRows(
    _ rows: [MarkdownTableParser.Row],
    nameIndex: Int,
    targetIndex: Int,
    setColumns: [Int],
    issues: inout [ParseIssue]
) -> [ParsedExercise] {
    var exercises: [ParsedExercise] = []
    for row in rows {
        guard let name = cell(row, at: nameIndex, issues: &issues) else { continue }
        let setCount = setColumns.filter { row.cells.indices.contains($0) && !row.cells[$0].isEmpty }.count
        guard setCount > 0 else {
            issues.append(ParseIssue(line: row.rawLine, reason: "세트가 없습니다"))
            continue
        }
        guard let target = target(row, at: targetIndex, issues: &issues) else { continue }
        let sets = target.weights(forSetCount: setCount).map { ParsedSet(targetWeight: $0, targetReps: target.reps) }
        exercises.append(ParsedExercise(name: name, sets: sets))
    }
    return exercises
}

/// **세트 수 = 같은 종목의 행 수.** 세로 배치라 같은 이름이 연속된 행을 하나로 묶는다.
private func parseVerticalRows(
    _ rows: [MarkdownTableParser.Row],
    nameIndex: Int,
    targetIndex: Int,
    issues: inout [ParseIssue]
) -> [ParsedExercise] {
    var exercises: [ParsedExercise] = []
    for row in rows {
        guard let name = cell(row, at: nameIndex, issues: &issues) else { continue }
        guard let target = target(row, at: targetIndex, issues: &issues) else { continue }
        let weight: Double
        switch target {
        case .uniform(let value, _): weight = value
        case .range(let low, let high, _): weight = (low + high) / 2
        }
        let set = ParsedSet(targetWeight: weight, targetReps: target.reps)

        if let last = exercises.last, last.name == name {
            exercises[exercises.count - 1].sets.append(set)
        } else {
            exercises.append(ParsedExercise(name: name, sets: [set]))
        }
    }
    return exercises
}

/// 종목명 칸을 읽는다. 열이 없거나 비어 있으면 issue 를 남기고 `nil`.
private func cell(_ row: MarkdownTableParser.Row, at index: Int, issues: inout [ParseIssue]) -> String? {
    guard row.cells.indices.contains(index) else {
        issues.append(ParseIssue(line: row.rawLine, reason: "열 개수가 맞지 않습니다"))
        return nil
    }
    let value = row.cells[index]
    guard !value.isEmpty else {
        issues.append(ParseIssue(line: row.rawLine, reason: "종목명이 비어 있습니다"))
        return nil
    }
    return value
}

/// `목표` 칸을 읽는다. 파싱할 수 없으면 issue 를 남기고 `nil`.
private func target(_ row: MarkdownTableParser.Row, at index: Int, issues: inout [ParseIssue]) -> ParsedTarget? {
    guard row.cells.indices.contains(index), let target = ParsedTarget(raw: row.cells[index]) else {
        let raw = row.cells.indices.contains(index) ? row.cells[index] : ""
        issues.append(ParseIssue(line: row.rawLine, reason: "목표를 읽을 수 없습니다: \(raw)"))
        return nil
    }
    return target
}

// MARK: - `목표` 열 파싱

/// `80kg × 5`, `맨몸 × 15`, `22.5kg × 5`, `70~80kg × 5`(피라미드 범위).
private enum ParsedTarget {
    case uniform(weight: Double, reps: Int)
    case range(low: Double, high: Double, reps: Int)

    var reps: Int {
        switch self {
        case .uniform(_, let reps): reps
        case .range(_, _, let reps): reps
        }
    }

    init?(raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard let separatorRange = text.range(of: #"×|[xX]"#, options: .regularExpression) else { return nil }
        let weightPart = text[text.startIndex..<separatorRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let repsPart = text[separatorRange.upperBound...].trimmingCharacters(in: .whitespaces)
        guard let reps = Int(repsPart) else { return nil }

        if weightPart == "맨몸" {
            self = .uniform(weight: 0, reps: reps)
            return
        }
        if let tildeRange = weightPart.range(of: "~") {
            let lowText = weightPart[weightPart.startIndex..<tildeRange.lowerBound].replacingOccurrences(of: "kg", with: "")
            let highText = weightPart[tildeRange.upperBound...].replacingOccurrences(of: "kg", with: "")
            guard let low = Double(lowText.trimmingCharacters(in: .whitespaces)),
                  let high = Double(highText.trimmingCharacters(in: .whitespaces)) else { return nil }
            self = .range(low: low, high: high, reps: reps)
            return
        }
        let weightText = weightPart.replacingOccurrences(of: "kg", with: "").trimmingCharacters(in: .whitespaces)
        guard let weight = Double(weightText) else { return nil }
        self = .uniform(weight: weight, reps: reps)
    }

    /// 균일 무게면 그대로 `count` 번 반복하고, 범위면 낮은 값에서 높은 값까지 균등 보간한다.
    /// 세트가 1개면 낮은 값을 쓴다(PRD §6.5).
    func weights(forSetCount count: Int) -> [Double] {
        switch self {
        case .uniform(let weight, _):
            return Array(repeating: weight, count: count)
        case .range(let low, let high, _):
            guard count > 1 else { return [low] }
            return (0..<count).map { low + (high - low) * Double($0) / Double(count - 1) }
        }
    }
}

// MARK: - 메타데이터 파싱

private struct ParsedMetadata {
    let title: String
    let category: String
    let weekdayMask: Int
}

/// 제목, `- 부위:`, `- 반복:` 을 읽는다. `- 반복:` 이 없으면 제목의 요일을 추론한다.
private func parseMetadata(lines: [String]) -> ParsedMetadata {
    guard let headerLine = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("## ") }) else {
        return ParsedMetadata(title: "", category: "", weekdayMask: 0)
    }
    let headerText = String(headerLine.trimmingCharacters(in: .whitespaces).dropFirst(3))
        .trimmingCharacters(in: .whitespaces)
    let (headerTitle, headerCategory) = splitHeaderText(headerText)

    let category = bulletValue("부위", in: lines) ?? headerCategory

    let weekdayMask: Int
    if let repeatBullet = bulletValue("반복", in: lines) {
        weekdayMask = parseWeekdayList(repeatBullet)
    } else if let inferred = inferWeekday(from: headerText) {
        weekdayMask = inferred.bit
    } else {
        weekdayMask = 0
    }

    return ParsedMetadata(title: headerTitle, category: category, weekdayMask: weekdayMask)
}

/// `## ` 뒤의 텍스트를 이름·부위로 나눈다. 날짜가 앞에 있으면(세션 헤더) `·` 뒤쪽을 이름으로 쓴다.
private func splitHeaderText(_ text: String) -> (title: String, category: String) {
    guard let range = text.range(of: " · ") else { return (text, "") }
    let left = String(text[text.startIndex..<range.lowerBound])
    let right = String(text[range.upperBound...])
    if isDateLike(left) {
        return (right, right)
    }
    return (left, right)
}

private func isDateLike(_ text: String) -> Bool {
    text.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil
}

private func bulletValue(_ key: String, in lines: [String]) -> String? {
    let prefix = "- \(key):"
    guard let line = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }) else {
        return nil
    }
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
}

private func parseWeekdayList(_ text: String) -> Int {
    let weekdays = text.split(separator: ",").compactMap { Weekday(shortName: $0.trimmingCharacters(in: .whitespaces)) }
    return Weekday.mask(of: weekdays)
}

/// `(월)` 같은 괄호 표기나 `월요일` 같은 전체 이름을 찾는다.
private func inferWeekday(from text: String) -> Weekday? {
    if let range = text.range(of: #"\(([일월화수목금토])\)"#, options: .regularExpression) {
        let letter = String(text[range].dropFirst().dropLast())
        if let weekday = Weekday(shortName: letter) { return weekday }
    }
    return Weekday.allCases.first { text.contains($0.fullName) }
}
