import Foundation

/// GFM 파이프 표 조립. 셀 이스케이프를 한 곳으로 모은다.
///
/// 종목명은 자유 입력이라 `|` 가 들어올 수 있고, 그대로 두면 표 전체가 깨지는데
/// 붙여넣기 전까지 모른다. 개행도 셀을 갈라놓으므로 공백으로 치환한다.
public enum MarkdownTable {

    public static func escape(_ cell: String) -> String {
        cell
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// 헤더 + 구분자 + 본문 행을 개행으로 이은 표 전체.
    public static func render(headers: [String], rows: [[String]]) -> String {
        var lines = [row(headers)]
        lines.append(row(Array(repeating: "---", count: headers.count)))
        lines.append(contentsOf: rows.map(row))
        return lines.joined(separator: "\n")
    }

    /// 빈 셀은 `|  |` 처럼 공백이 겹치지 않고 `| |` 한 칸으로 남는다(PRD §6.1 예시 표기).
    private static func row(_ cells: [String]) -> String {
        let padded = cells.map(escape).map { $0.isEmpty ? " " : " \($0) " }
        return "|" + padded.joined(separator: "|") + "|"
    }
}
