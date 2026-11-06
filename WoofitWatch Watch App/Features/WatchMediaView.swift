import SwiftUI
import WatchKit

/// W7 · 시스템 미디어 화면. 재생 소스와 조작은 NowPlayingView가 관리한다(F-20).
struct WatchMediaView: View {
    var body: some View {
        GeometryReader { geometry in
            let version = ProcessInfo.processInfo.operatingSystemVersion
            // 27.2의 211×257pt 화면에서 내부 플레이어가 205×251pt로 그려진다.
            // frame 확대는 내부 크기를 바꾸지 않아 전체 컨트롤과 터치 영역을 함께 보정한다(AGENTS 표준 예외).
            let needsCorrection = version.majorVersion == 27 && version.minorVersion == 2
                && geometry.size == CGSize(width: 211, height: 257)

            NowPlayingView()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(
                    x: needsCorrection ? 211.0 / 205.0 : 1,
                    y: needsCorrection ? 257.0 / 251.0 : 1,
                    anchor: .topLeading
                )
        }
        // 바깥에서 clipped를 적용하면 확장된 미디어가 중앙 안전 영역에서 잘린다(F-20).
        .ignoresSafeArea()
    }
}

#Preview("세션 전체 화면 안의 미디어 페이지") {
    @Previewable @State var isPresented = true
    @Previewable @State var selectedPage = 1

    Text("세션")
        .fullScreenCover(isPresented: $isPresented) {
            TabView(selection: $selectedPage) {
                NavigationStack { Text("운동") }
                    .tag(0)
                WatchMediaView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
}
