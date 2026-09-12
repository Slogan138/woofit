import SwiftUI
import WoofitCore

/// P7 · 설정. 지금은 최소 상태다 — F-13 이 진입점을 필요로 해서 신설했다.
/// 마크다운 형식·카테고리 프리셋 등 나머지 항목은 그 기능(F-6)과 함께 생긴다.
struct SettingsView: View {
    @Environment(\.watchSyncService) private var syncService

    @AppStorage(NudgeThresholds.askKey) private var askMinutes = NudgeThresholds.default.askMinutes
    @AppStorage(NudgeThresholds.offerEndKey) private var offerEndMinutes = NudgeThresholds.default.offerEndMinutes

    private var thresholds: NudgeThresholds {
        NudgeThresholds(askMinutes: askMinutes, offerEndMinutes: offerEndMinutes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("확인 묻기", selection: $askMinutes) {
                        ForEach(Self.askOptions, id: \.self) { minutes in
                            Text(Self.label(minutes)).tag(minutes)
                        }
                    }
                    Picker("중단 선택지", selection: $offerEndMinutes) {
                        ForEach(Self.offerEndOptions, id: \.self) { minutes in
                            Text(Self.label(minutes)).tag(minutes)
                        }
                    }
                } header: {
                    Text("세션 안내")
                } footer: {
                    // 왜 "세션 시작 후"가 아닌지를 적어둔다 — 설정을 보다가 헷갈리는 지점이다.
                    Text("마지막 세트를 기록한 뒤 이만큼 지나면 아직 운동 중인지 확인합니다. 운동을 끝내고 중단을 누르지 않은 세션이 계속 남지 않게 하기 위한 것이라, 세션을 시작한 지 얼마나 됐는지는 보지 않습니다.")
                }

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
        // 워치에는 설정 화면이 없다. 바뀔 때마다 내려보내야 양쪽이 같은 값을 쓴다(F-3).
        .onChange(of: thresholds) { _, new in
            try? syncService?.sendNudgeThresholds(new)
        }
    }

    private static let askOptions: [Double] = [0, 10, 15, 20, 30, 45]
    private static let offerEndOptions: [Double] = [0, 30, 45, 60, 90]

    private static func label(_ minutes: Double) -> String {
        minutes <= 0 ? "사용 안 함" : "\(Int(minutes))분"
    }
}

#Preview {
    SettingsView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
