import SwiftUI

/// 카테고리 자유 입력 + 프리셋 제안(PRD A2).
struct CategoryField: View {
    @Binding var category: String

    static let presets = ["가슴", "등", "하체", "어깨", "팔", "코어", "전신"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("카테고리 (예: 가슴)", text: $category)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.presets, id: \.self) { preset in
                        Button(preset) { category = preset }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(category == preset ? Color.accentColor : Color.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var category = "가슴"
    return CategoryField(category: $category)
        .padding()
}
