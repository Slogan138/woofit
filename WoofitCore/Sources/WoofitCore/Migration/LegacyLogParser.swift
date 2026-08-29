import Foundation

/// Obsidian `운동일지.md` → `ParsedSession`(F-13, 계획 §변환 규칙).
///
/// 순수 함수다. `ModelContext` 를 받지 않으므로 미리보기가 화면 없이 완결된다.
/// `# 날짜` 가 세션, `## 부위` 가 카테고리, 표의 각 행이 종목이다. 원본은 읽기만 하고
/// 고치지 않는다 — 아카이브는 노트가 맡는다는 전제(§1)가 여기서도 유지된다.
public enum LegacyLogParser {

    public static func parse(_ text: String) -> LegacyLogParseResult {
        let lines = text.normalizingNewlines().components(separatedBy: .newlines)
        var sessions: [ParsedSession] = []
        var issues: [ParseIssue] = []

        var index = 0
        while index < lines.count {
            guard let date = dateHeader(lines[index]) else {
                index += 1
                continue
            }
            index += 1

            var categoryTitles: [String] = []
            var entries: [ParsedLogEntry] = []
            while index < lines.count, dateHeader(lines[index]) == nil {
                guard let category = categoryHeader(lines[index]) else {
                    index += 1
                    continue
                }
                categoryTitles.append(category)
                index += 1

                let sectionStart = index
                while index < lines.count, dateHeader(lines[index]) == nil, categoryHeader(lines[index]) == nil {
                    index += 1
                }
                let sectionText = lines[sectionStart..<index].joined(separator: "\n")
                entries.append(contentsOf: parseSection(sectionText, issues: &issues))
            }

            guard !entries.isEmpty else {
                issues.append(ParseIssue(line: categoryTitles.joined(separator: " · "), reason: "가져올 수 있는 종목이 없습니다"))
                continue
            }
            sessions.append(ParsedSession(date: date, category: categoryTitles.joined(separator: " · "), entries: entries))
        }

        return LegacyLogParseResult(sessions: sessions, issues: issues)
    }
}

// MARK: - 헤더 판별

/// `# 2026-03-31` 만 세션 헤더로 본다. `##` 카테고리 헤더와 구분해야 한다.
private func dateHeader(_ line: String) -> Date? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("# "), !trimmed.hasPrefix("##") else { return nil }
    let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
    guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }

    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    components.hour = 9
    return Calendar.current.date(from: components)
}

private func categoryHeader(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("## ") else { return nil }
    return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
}

// MARK: - 표 파싱

private func parseSection(_ text: String, issues: inout [ParseIssue]) -> [ParsedLogEntry] {
    guard let table = MarkdownTableParser.parse(text) else { return [] }
    let headers = table.headers.map(stripBold)

    guard let nameIndex = headers.firstIndex(of: "운동 종목"),
          let weightIndex = headers.firstIndex(of: "중량"),
          let setsIndex = headers.firstIndex(of: "세트/횟수"),
          let successIndex = headers.firstIndex(of: "성공") else {
        issues.append(ParseIssue(line: headers.joined(separator: " | "), reason: "지원하지 않는 표 형식입니다"))
        return []
    }
    let noteIndex = headers.firstIndex(of: "비고")

    var entries: [ParsedLogEntry] = []
    for row in table.rows {
        guard let entry = parseRow(
            row,
            nameIndex: nameIndex,
            weightIndex: weightIndex,
            setsIndex: setsIndex,
            successIndex: successIndex,
            noteIndex: noteIndex,
            issues: &issues
        ) else { continue }
        entries.append(entry)
    }
    return entries
}

private func cell(_ row: MarkdownTableParser.Row, at index: Int) -> String {
    row.cells.indices.contains(index) ? row.cells[index] : ""
}

/// 종목 행 하나 → `ParsedLogEntry`. 미수행 행(핵심 칸이 비어 있음)은 종목을 만들지 않는다.
private func parseRow(
    _ row: MarkdownTableParser.Row,
    nameIndex: Int,
    weightIndex: Int,
    setsIndex: Int,
    successIndex: Int,
    noteIndex: Int?,
    issues: inout [ParseIssue]
) -> ParsedLogEntry? {
    let rawName = stripBold(cell(row, at: nameIndex)).trimmingCharacters(in: .whitespaces)
    let rawWeight = cell(row, at: weightIndex).trimmingCharacters(in: .whitespaces)
    let rawSets = stripBold(cell(row, at: setsIndex)).trimmingCharacters(in: .whitespaces)
    let rawSuccess = cell(row, at: successIndex).trimmingCharacters(in: .whitespaces)

    guard !rawName.isEmpty, !rawWeight.isEmpty, rawWeight != "X", !rawSets.isEmpty, !rawSuccess.isEmpty else {
        issues.append(ParseIssue(line: row.rawLine, reason: "미수행 행입니다"))
        return nil
    }

    guard let weightInfo = parseWeight(rawWeight) else {
        issues.append(ParseIssue(line: row.rawLine, reason: "중량을 읽을 수 없습니다: \(rawWeight)"))
        return nil
    }
    if let notice = weightInfo.issue {
        issues.append(ParseIssue(line: row.rawLine, reason: notice))
    }

    guard let setsInfo = parseSetsReps(rawSets) else {
        issues.append(ParseIssue(line: row.rawLine, reason: "세트/횟수를 읽을 수 없습니다: \(rawSets)"))
        return nil
    }

    var sets = (0..<setsInfo.setCount).map { _ in
        ParsedLogSet(targetWeight: weightInfo.weight, targetReps: setsInfo.targetReps, result: .success)
    }
    if let notice = applySuccess(rawSuccess, to: &sets) {
        issues.append(ParseIssue(line: row.rawLine, reason: notice))
    }

    // 어시스트 머신은 무게가 클수록 쉬워져 추이 해석이 뒤집힌다. 종목명에 표시를 남긴다.
    var name = rawName
    if weightInfo.isAssisted, !name.contains("(보조)") {
        name += " (보조)"
    }

    let rawNote = noteIndex.map { stripBold(cell(row, at: $0)).trimmingCharacters(in: .whitespaces) }
    let note = (rawNote?.isEmpty ?? true) ? nil : rawNote

    return ParsedLogEntry(name: name, sets: sets, note: note)
}

// MARK: - `중량` 열

private struct WeightInfo {
    let weight: Double
    let isAssisted: Bool
    /// 세트마다 무게가 달라 값을 하나만 취했을 때 남기는 안내.
    let issue: String?
}

private func parseWeight(_ raw: String) -> WeightInfo? {
    if raw.contains("맨몸") { return WeightInfo(weight: 0, isAssisted: false, issue: nil) }

    let numbers = numbers(in: raw)
    guard let first = numbers.first else { return nil }
    let issue = numbers.count > 1 ? "세트마다 무게가 달라 첫 값만 사용했습니다: \(raw)" : nil
    return WeightInfo(weight: first, isAssisted: raw.contains("보조"), issue: issue)
}

// MARK: - `세트/횟수` 열

private struct SetsInfo {
    let setCount: Int
    let targetReps: Int
}

/// `3s / 15r` → 세트 3개, 목표 15회. `1s / Failure` → 세트 1개, 목표 횟수 미상(0).
private func parseSetsReps(_ raw: String) -> SetsInfo? {
    let parts = raw.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 2, parts[0].hasSuffix("s"), let setCount = Int(parts[0].dropLast()), setCount > 0 else {
        return nil
    }
    if parts[1].caseInsensitiveCompare("failure") == .orderedSame {
        return SetsInfo(setCount: setCount, targetReps: 0)
    }
    guard parts[1].hasSuffix("r"), let reps = Int(parts[1].dropLast()) else { return nil }
    return SetsInfo(setCount: setCount, targetReps: reps)
}

// MARK: - `성공` 열 (D8 근사)

/// 마지막 세트에만 실패를 반영한다. 알아볼 수 없는 표기는 성공으로 두고 issue 로 남긴다.
private func applySuccess(_ raw: String, to sets: inout [ParsedLogSet]) -> String? {
    guard let lastIndex = sets.indices.last else { return nil }

    switch raw {
    case "✅":
        return nil
    case "❌":
        let target = sets[lastIndex].targetReps
        sets[lastIndex].result = .failure
        sets[lastIndex].actualReps = max(0, target - 1)
        return nil
    default:
        if let count = numbers(in: raw).first {
            sets[lastIndex].result = .failure
            sets[lastIndex].actualReps = Int(count)
            return nil
        }
        return "성공 여부를 알 수 없어 성공으로 처리했습니다: \(raw)"
    }
}

// MARK: - 공통

private func stripBold(_ text: String) -> String {
    text.replacingOccurrences(of: "**", with: "")
}

/// 문자열 안의 숫자(정수·소수)를 순서대로 뽑는다. `40kg, 32kg` → `[40, 32]`.
private func numbers(in text: String) -> [Double] {
    var results: [Double] = []
    var current = ""
    for character in text {
        if character.isNumber || character == "." {
            current.append(character)
        } else if !current.isEmpty {
            if let value = Double(current) { results.append(value) }
            current = ""
        }
    }
    if !current.isEmpty, let value = Double(current) { results.append(value) }
    return results
}
