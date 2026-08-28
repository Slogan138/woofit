import SwiftUI
import SwiftData
import WoofitCore

struct RootView: View {
    var body: some View {
        TabView {
            Tab("루틴", systemImage: "list.bullet.rectangle") {
                RoutineListView()
            }
            Tab("기록", systemImage: "clock.arrow.circlepath") {
                SessionHistoryView()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(try! WoofitModelContainer.makeInMemoryContainer())
}
