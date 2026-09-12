# 23 · F-17 폰에서 시작하면 워치 앱이 뜬다

> **개선** · 폰 · 워치 · [PRD §4 F-17](../PRD.md) · 계획 21 의 남은 절반

## 왜 지금인가

계획 21 로 **손목을 올리면 앱으로 돌아오게** 했지만, 그건 워치 앱이 이미 떠 있을 때
이야기다. 폰에서 세션을 시작하면 워치 앱은 여전히 꺼져 있고, 손으로 열어야 이어받는다.

`WatchConnectivity` 로는 워치 앱을 실행시킬 수 없다. 컨텍스트를 보내도 받는 앱이
떠야 처리된다. **워치 앱을 앞으로 띄우는 경로는 `startWatchApp(toHandle:)` 하나뿐이다.**

## 설계

```
폰: 시작 → 세션 저장 → 진행 상태 전송 → startWatchApp
                                          ↓
워치: 앱이 뜸 → handle(_:) → 컨텍스트 읽음 → 세션 이어받기 → 운동 세션 시작
```

### 순서가 중요하다

`sendInProgressSession` 을 **먼저** 부르고 띄운다. 워치 앱이 뜨자마자 읽을 컨텍스트가
있어야 곧바로 그 세션을 연다(F-8). 반대로 하면 빈 목록을 잠깐 보여주게 된다.

### 델리게이트는 운동 세션을 만들지 않는다

`handle(_ workoutConfiguration:)` 에서 `HKWorkoutSession` 을 직접 만들 수도 있지만
그러지 않는다. 운동 세션의 수명은 `WorkoutSessionController` 한 곳이 쥐고 있고(계획 17),
여기서 또 만들면 **두 개가 된다.** 앱이 앞으로 나오면 `WatchRootView` 가 세션을
이어받으면서 운동 세션까지 시작한다(계획 21) — 이미 있는 경로다.

그래서 델리게이트가 하는 일은 로그를 남기는 것뿐이다. **앱이 뜨는 것 자체가 목적**이었다.

### 폰의 HealthKit 권한은 통로다

폰은 건강 앱에 아무것도 기록하지 않는다. `startWatchApp` 이 HealthKit API 라서 권한이
필요할 뿐이다. 거부해도 앱은 그대로 동작하고 워치를 손으로 열면 된다 — F-14 와 같은 방식이다.

## 파일

| 파일 | 내용 |
| --- | --- |
| `WoofitCore/Health/WatchAppLauncher.swift` | `startWatchApp` 호출. `#if os(iOS)` |
| `WoofitWatch Watch App/Health/WatchWorkoutLaunchDelegate.swift` | 띄워진 것을 받는다 |
| `WoofitWatch Watch App/WoofitWatchApp.swift` | `@WKApplicationDelegateAdaptor` |
| `Woofit/Features/Session/SessionCoordinator.swift` | 시작할 때 띄운다 |
| `Woofit/Woofit.entitlements` | 폰 HealthKit 권한 |

## 테스트 계획

**도메인 로직이 없다.** 이 기능은 플랫폼 호출 한 번이 전부라 `swift test` 로 확인할
것이 없다 — `WatchSyncService` 의 전송과 같은 성격이다(계획 08).

테스트가 잡아주는 것은 하나뿐이다. **기록할 세트가 없으면 띄우지 않는다**는 판단은
`hasRecordableSets` 를 쓰고, 그 값은 이미 테스트로 고정돼 있다(계획 17). 빈 루틴에서
운동 세션만 열고 끝나지 않던 버그가 같은 자리에서 났었다.

## 완료 기준

1. `cd WoofitCore && swift test` 통과
2. `xcodebuild build -scheme Woofit` 통과
3. 실기기 — **폰에서 시작을 누르면 손목을 들었을 때 이미 세트 화면이 떠 있다**
4. 실기기 — 폰 권한을 거부해도 앱이 정상 동작하고, 워치를 열면 이어받는다
5. PRD F-17 추가

## 주의점

**폰에 권한 프롬프트가 새로 뜬다.** 지금까지 HealthKit 은 워치에만 있었다. 처음
세션을 시작할 때 폰에서 한 번 묻는다.

**워치가 다른 운동 중이면 실패한다.** 애플 운동 앱으로 러닝 중에 이걸 부르면 거부된다.
정상 상황이므로 조용히 넘긴다 — 그때는 워치를 손으로 열면 된다.

**무료 계정에서도 된다.** 워치 앱이 이미 같은 권한으로 동작하고 있다(D5).
