import SwiftUI
import WidgetKit

/// 위젯 확장의 진입점(F-16). 지금 담는 것은 진행 중 세션의 Live Activity 하나뿐이다.
///
/// **홈 화면 위젯은 만들지 않는다.** 이 앱은 운동 중에만 쓰는 도구라 운동하지 않을 때
/// 보여줄 현황이 없다(PRD §1 캡처 도구).
@main
struct WoofitWidgetBundle: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
    }
}
