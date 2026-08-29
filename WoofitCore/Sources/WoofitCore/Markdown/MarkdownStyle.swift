import Foundation

/// 마크다운 내보내기 형식 선택(PRD §6). 설정 화면과 exporter 가 함께 쓰는 순수 값 타입이다.
public struct MarkdownStyle: Hashable, Sendable {

    /// 세션 기록 표 레이아웃.
    public enum Layout: Hashable, Sendable {
        /// 세트를 열로 펼친다(§6.1). 기본값.
        case horizontalSets
        /// 세트마다 한 줄(§6.2).
        case verticalSets
    }

    /// 결과 표기를 이모지 대신 텍스트로 바꾸는 옵션.
    public enum ResultSymbol: Hashable, Sendable {
        case emoji
        case text
    }

    public var layout: Layout
    public var resultSymbol: ResultSymbol

    public init(layout: Layout = .horizontalSets, resultSymbol: ResultSymbol = .emoji) {
        self.layout = layout
        self.resultSymbol = resultSymbol
    }

    public static let `default` = MarkdownStyle()
}
