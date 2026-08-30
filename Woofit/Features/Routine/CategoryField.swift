import SwiftUI
import SwiftData
import WoofitCore

/// 카테고리 자유 입력 + 제안(PRD A2, F-1).
///
/// 칩은 **토글**이다. 하루에 여러 부위를 하는 것이 실제 사용 형태라 하나만 고르게 하면
/// 화·목 루틴을 만들 수 없다(계획 19). 여러 부위는 ` / ` 로 이어 한 문자열에 담는다(D11).
struct CategoryField: View {
    @Binding var category: String

    @Environment(\.modelContext) private var modelContext
    @State private var suggestions: [String] = []

    /// 기록이 없을 때만 쓰는 기본 목록. 있으면 실제로 쓴 부위가 먼저다 —
    /// 고정 목록은 이 사용자의 `삼두` · `이두` · `보충` 을 담지 못한다.
    static let defaults = ["가슴", "등", "하체", "어깨", "삼두", "이두", "코어", "전신", "보충"]

    private var chips: [String] {
        suggestions.isEmpty ? Self.defaults : suggestions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("카테고리 (예: 가슴 / 어깨 / 삼두)", text: $category)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        // 선택 여부를 `@State` 로 따로 들지 않는다. 그러면 위 `TextField` 로
                        // 고친 값과 어긋나 두 진실이 생긴다. 문자열이 진실이고 칩은 비춘다.
                        let isSelected = CategoryLabel.contains(category, chip)
                        Button(chip) {
                            category = CategoryLabel.toggling(chip, in: category)
                        }
                        .font(Typography.secondary)
                        .buttonStyle(.bordered)
                        .tint(isSelected ? Color.accentColor : Color.secondary)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
        .task {
            suggestions = (try? CategorySuggester.suggest(in: modelContext)) ?? []
        }
    }
}

#Preview {
    @Previewable @State var category = "가슴 / 어깨"
    return CategoryField(category: $category)
        .padding()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
