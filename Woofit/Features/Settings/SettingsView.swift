import SwiftUI
import WoofitCore

/// P7 · 설정. 지금은 최소 상태다 — F-13 이 진입점을 필요로 해서 신설했다.
/// 마크다운 형식·카테고리 프리셋·증량 폭 등 나머지 항목은 그 기능(F-6, F-11)과 함께 생긴다.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("과거 운동일지 가져오기") {
                        LogMigrationView()
                    }
                } footer: {
                    Text("Obsidian 등 다른 곳에 적어둔 과거 운동 기록을 한 번에 옮깁니다. 일회성 기능입니다.")
                }
            }
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
