import Foundation

/// 파이프 표 → 행·셀. GFM 표를 파싱한다. 렌더링은 `MarkdownTable` 이 맡는다.
///
/// **관대하게 파싱한다**(F-7). 표 앞뒤의 다른 문단, 구분자 줄의 대시 길이(`---` vs `-----`),
/// 줄 앞의 들여쓰기를 전부 허용한다. 셀 개수가 헤더와 다른 줄은 그대로 반환하고,
/// 형식 판별과 값 파싱은 호출하는 쪽(`RoutineMarkdownImporter`)이 맡는다.
public enum MarkdownTableParser {

    public struct Row: Sendable, Equatable {
        public let cells: [String]
        public let rawLine: String
    }

    public struct ParsedTable: Sendable, Equatable {
        public let headers: [String]
        public let rows: [Row]
    }

    /// 텍스트 안에서 첫 번째 표를 찾아 돌려준다. 표가 없으면 `nil`.
    public static func parse(_ text: String) -> ParsedTable? {
        let lines = text.normalizingNewlines().components(separatedBy: .newlines)
        var index = 0
        while index < lines.count - 1 {
            if isRow(lines[index]), isSeparatorRow(lines[index + 1]) {
                let headers = splitCells(lines[index])
                var rowIndex = index + 2
                var rows: [Row] = []
                while rowIndex < lines.count, isRow(lines[rowIndex]) {
                    rows.append(Row(cells: splitCells(lines[rowIndex]), rawLine: lines[rowIndex]))
                    rowIndex += 1
                }
                return ParsedTable(headers: headers, rows: rows)
            }
            index += 1
        }
        return nil
    }

    private static func isRow(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    /// 헤더 바로 다음 줄이 전부 `-`·`:` 로만 이루어진 구분자 줄인지 확인한다.
    private static func isSeparatorRow(_ line: String) -> Bool {
        guard isRow(line) else { return false }
        let cells = splitCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    /// `\|` 는 이스케이프된 파이프로 되돌리고, 그 외 `|` 로 나눈 뒤 앞뒤 빈 칸(테두리 파이프)을 뗀다.
    private static func splitCells(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count, chars[i + 1] == "|" {
                current.append("|")
                i += 2
                continue
            }
            if chars[i] == "|" {
                cells.append(current)
                current = ""
                i += 1
                continue
            }
            current.append(chars[i])
            i += 1
        }
        cells.append(current)

        var trimmed = cells.map { $0.trimmingCharacters(in: .whitespaces) }
        if trimmed.first == "" { trimmed.removeFirst() }
        if trimmed.last == "" { trimmed.removeLast() }
        return trimmed
    }
}
