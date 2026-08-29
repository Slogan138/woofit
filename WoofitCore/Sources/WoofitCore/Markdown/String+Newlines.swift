import Foundation

extension String {
    /// CRLF/CR 을 LF 로 통일한다. `.newlines` 로 나누면 `\r\n` 을 두 줄로 잘못 잘라
    /// 파이프 표 파서의 "헤더 바로 다음이 구분자" 조건이 깨진다.
    func normalizingNewlines() -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
