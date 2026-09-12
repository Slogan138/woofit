# 22 · F-16 진행 중 세션 실시간 표시

> **개선** · 폰 · [PRD §4 F-16](../PRD.md) · 결정 근거 [D14](../PRD.md#11-확정-사항)
> **계획 21 이 먼저다.** 세션 수명이 정해지지 않은 상태로 올리면 잠금화면에
> 며칠째 안 사라지는 운동 카드가 박힌다.

## 왜 하는가

워치를 차고 운동하지만 폰은 벤치 옆에 놓여 있다. 지금은 폰을 열어 앱에 들어가야
현황이 보인다. 잠금화면과 다이내믹 아일랜드에 띄우면 **폰을 집어 드는 것만으로**
지금 몇 세트째인지 휴식이 얼마나 지났는지 알 수 있다.

부수 효과가 하나 더 있다. 애플 운동 앱이 상태를 잊을 수 없게 만드는 것과 같은 효과라,
**끝나지 않은 세션이 눈에 띈다.** 계획 21 이 사후에 정리하는 것이라면 이건 애초에
잊지 않게 하는 쪽이다.

## 범위

**하는 것** — 잠금화면·AOD·다이내믹 아일랜드에 진행 중 세션 현황.

**하지 않는 것**

- **잠금화면에서 세트 기록** — iOS 17+ 위젯 버튼(`AppIntent`)으로 되지만 넣지 않는다.
  폰을 꺼내 누를 상황이면 앱을 열면 된다. 기록 경로가 둘이 되면 어느 쪽이 이겼는지
  추적해야 하고, 그것이 지금까지 동기화 버그가 난 자리다
- **홈 화면 위젯** — 운동하지 않을 때 보여줄 현황이 없다. 이 앱은 캡처 도구다(§1)
- **워치 쪽 표시** — 워치는 운동 세션(F-14)이 앱 자체를 띄워준다. 같은 정보를 두 벌
  만들 이유가 없다
- **푸시 갱신** — ActivityKit 푸시는 서버가 필요하다. 이 앱에는 서버가 없다(§9)

## 설계

### 갱신은 화면이 아니라 수신 경로에서

핵심 제약이다. **폰이 주머니에 있는 동안 워치가 기록한다.** 그때 폰 앱은 백그라운드라
화면이 그려지지 않으므로 `onChange` 가 돌지 않는다.

다행히 경로는 이미 있다. `transferUserInfo`·`updateApplicationContext` 전달은 **폰 앱을
백그라운드에서 깨운다.** `WatchSyncService` 가 병합을 마친 그 자리에서 갱신한다.

```
워치: 성공 탭 → transferUserInfo → 폰 앱 깨어남 → 병합 → Live Activity 갱신
```

폰에서 직접 기록하는 경우는 화면이 떠 있으므로 `SessionRunnerView` 가 함께 부른다.

### 휴식 시계는 갱신하지 않는다

1초마다 Live Activity 를 갱신하는 것은 허용되지도 않고 배터리도 못 견딘다(§9).
`Text(timerInterval:)` 을 쓰면 **시작 시각만 넘기고 시간은 시스템이 흘려보낸다.**
`WatchRestView` 가 `TimelineView` 로 하는 것과 같은 원리다.

### 위젯은 판단하지 않는다

위젯 확장은 별도 프로세스라 세션도 저장소도 볼 수 없다. 앱이 `SessionLiveSnapshot` 으로
넘겨준 값이 전부다. **그래서 그 타입이 곧 잠금화면 화면의 명세다** — 거기 없는 값은
띄울 수 없다.

판단을 위젯에 두면 `swift test` 가 닿지 않는 곳에 로직이 생긴다(CLAUDE.md 경계).
`make(for:)` 가 `nil` 을 주면 "보여줄 것이 없다 = 활동을 끝내라"는 뜻이고, 그 판단까지
`WoofitCore` 에 있다.

### 열려 있는 활동을 들고 있지 않는다

시스템이 주인이다. 앱이 죽었다 살아나도 잠금화면에는 그대로 남아 있는데, 참조를
들고 있으면 그 경우를 놓쳐 활동이 둘이 된다. 필요할 때 `Activity.activities` 에서
찾는다 — `recoverActiveWorkoutSession`(계획 21)과 같은 판단이다.

## 타겟이 하나 늘어난다

```
Woofit.app
├─ PlugIns/WoofitWidget.appex     ← 새 타겟  io.jwp.woofit.widget
└─ Watch/WoofitWatch Watch App.app
```

위젯 확장은 잠금화면에 무언가를 띄우는 애플의 유일한 경로다(원칙 1). 대신 **설치되는
물건이 하나 더 생긴다** — 번들 ID 와 프로비저닝 프로파일이 따로 붙고, 무료 계정에서는
7일마다 셋을 함께 갱신하게 된다.

`WoofitWidget-Info.plist` 를 저장소 루트에 둔 것은 `NSExtension` 사전을 빌드 설정으로
표현할 수 없어서다. 위젯 폴더 안에 두면 buildable folder 가 리소스로도 복사하려 든다.

## 파일

| 파일 | 내용 |
| --- | --- |
| `WoofitCore/Session/SessionLiveSnapshot.swift` | 잠금화면에 띄우는 값. 이 타입이 화면 명세 |
| `WoofitCore/Session/SessionActivityAttributes.swift` | `ActivityAttributes` 적합. `#if canImport(ActivityKit) && os(iOS)` |
| `WoofitCore/Session/LiveActivityController.swift` | 열기·갱신·닫기 |
| `WoofitCore/Sync/WatchSyncService.swift` | 수신 경로에서 갱신 호출 |
| `WoofitWidget/WoofitWidgetBundle.swift` | 위젯 진입점 |
| `WoofitWidget/SessionLiveActivity.swift` | 잠금화면·다이내믹 아일랜드 화면 |
| `Woofit/Features/Session/LiveActivityEnvironment.swift` | 화면 주입 |
| `Woofit.xcodeproj/project.pbxproj` | 위젯 타겟 |

## 테스트 계획

`SessionLiveSnapshot` 은 순수 함수라 시뮬레이터 없이 돈다. ActivityKit 자체는
실기기에서 확인한다 — `WatchSyncService` 와 같은 판단이다.

| 테스트 | 보장 |
| --- | --- |
| 현황은 지금 기록할 세트를 가리킨다 | 세트 번호·진행률 |
| 휴식 중이면 그 시작 시각이 담긴다 | 잠금화면 시계의 입력 |
| 끝난 세션은 보여줄 현황이 없다 | `nil` = 활동 종료 |
| 중단된 세션도 보여줄 현황이 없다 | 같음 |

## 완료 기준

1. `cd WoofitCore && swift test` 통과
2. `xcodebuild build -scheme Woofit` 통과, 위젯이 `PlugIns/` 에 임베드됨
3. 앱 `Info.plist` 에 `NSSupportsLiveActivities`, 위젯에 `NSExtensionPointIdentifier`
4. 실기기 — 세션을 시작하면 잠금화면에 카드가 뜨고, **워치에서 기록하면 폰을 켜지
   않아도 세트 수가 따라 올라간다**
5. 실기기 — 세션을 끝내면 카드가 **즉시** 사라진다
6. PRD F-16 추가

## 주의점

**활동을 끝낼 때 `.immediate` 를 쓴다.** 기본 정책은 잠금화면에 한동안 남겨두는
것인데, 운동이 끝난 뒤에도 남아 있으면 "아직 진행 중"으로 읽힌다 — 이 앱이 그동안
겪은 문제의 모양 그대로다(D14).

**`Activity` 는 `Sendable` 이 아니다.** MainActor 격리를 넘길 수 없어 Swift 6 이 막는다.
컨트롤러가 값을 들고 있지 않고 조회하는 구조가 이 제약과도 맞는다.

**권한이 꺼져 있어도 앱은 그대로 동작한다.** `areActivitiesEnabled` 가 거짓이면 조용히
넘어간다 — HealthKit 권한(F-14)과 같은 방식이다.
