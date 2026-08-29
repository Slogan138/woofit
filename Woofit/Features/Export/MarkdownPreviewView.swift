import SwiftUI
import UIKit

/// `.sheet(item:)` 로 화면에 넘길 내보내기 결과.
/// 제목·내용을 한 번에 담아야 `isPresented` 와 내용 문자열을 별도 `@State` 로 두었을 때 생기는
/// 경쟁 상태(시트가 갱신 전 값으로 뜨는 문제)를 피한다.
struct MarkdownExport: Identifiable {
    let id = UUID()
    let title: String
    let markdown: String
}

/// 미리보기 + 복사(F-6). 세션·루틴 어느 쪽이든 완성된 마크다운 문자열만 받는다.
/// 워치에는 두지 않는다(PRD F-6) — 폰 전용 화면이다.
struct MarkdownPreviewView: View {
    let title: String
    let markdown: String

    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = markdown
                        didCopy = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            didCopy = false
                        }
                    } label: {
                        Label(didCopy ? "복사됨" : "마크다운 복사", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }
}

#Preview {
    MarkdownPreviewView(
        title: "미리보기",
        markdown: "## 월요일 · 가슴\n\n| 종목 | 목표 | 세트 |\n| --- | --- | --- |\n| 벤치프레스 | 80kg × 5 | 5 |"
    )
}
