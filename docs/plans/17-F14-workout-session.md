# 17 · F-14 워치 운동 세션 유지

> **개선** · 워치 · [PRD §4 F-14](../PRD.md) · 결정 근거 [D9](../PRD.md#11-확정-사항)
> **새 기능이 아니다.** M2 가 약속한 F-3 · F-5 가 실기기에서 성립하게 만드는 일이다.

## 왜 지금인가

watchOS 는 운동 세션을 선언하지 않은 앱을 손목을 내리면 곧 정지시킨다.
이 앱은 세트 사이에 1~2분을 쉰다. 즉 **휴식마다 앱이 내려간다.**

지금 코드가 그 영향을 받는 자리는 두 군데다.

| 자리 | 지금 | 정지되면 |
| --- | --- | --- |
| `WatchRestView` | `TimelineView(.periodic)` 로 경과 시간 표시 | 화면이 멈춘다. 다시 탭해 종료할 수 없다 |
| `WatchSetView` | 세트 기록 후 다음 세트로 | 손목을 들면 시계 화면이라 앱을 다시 찾아 들어와야 한다 |

휴식 **값** 자체는 `startedAt` 에서 차를 계산하므로 복귀 후에도 맞다. 깨지는 것은
"탭으로 종료"(F-5 수용 기준)와 "세트 사이에 폰을 꺼내지 않는다"(M2 의 목적)다.

**심사 때문이 아니라 지금 헬스장에서 겪는 문제다.** 공개 배포를 하지 않아도 필요하다.

## 범위

**하는 것** — 운동 세션 시작·종료, 건강 앱에 세션 저장, 권한 거부 시 정상 동작.

**하지 않는 것**

- 심박수·칼로리 표시 — 이 앱의 기록 단위가 아니다. 세션을 시작하면 워치가 알아서
  수집하고 건강 앱에 남는다. 화면에 띄우기 시작하면 운동 트래커가 된다
- 종목별 운동 세션 분리 — 기록 단위는 세션이다
- 건강 앱에서 **읽어오기** — 원본은 이 앱이 갖는다. 단방향이다
- 폰 쪽 HealthKit — 워치가 없을 때 폰으로 실행하는 경로는 화면이 켜져 있어 문제가 없다

## 설계

### 어디에 두는가

`WoofitCore/Health/` 에 둔다. **`Sync/WatchSyncService` 가 선례다** — WatchConnectivity 라는
플랫폼 프레임워크 연동이 이미 Core 에 있고, `#if canImport` 와 `#if os(watchOS)` 로 갈라져 있다.

`canImport(HealthKit)` 가 macOS 에서 거짓이므로 `swift test` 는 영향받지 않는다.
Package.swift 의 `.macOS(.v26)` 이 그대로 유지된다.

### 상태를 하나로 묶는다

세션 시작·종료 경로는 이미 `SessionRunner` 하나로 모여 있다. 운동 세션의 수명을
거기에 붙이지 않고 **별도 객체가 `SessionRunner` 의 상태 변화를 따라가게** 하면
두 개의 진실이 생긴다. 시작은 됐는데 종료가 안 되는 조합이 나온다.

`WorkoutSessionController` 를 두고 **시작·종료 두 지점에서만** 호출한다.

| `SessionRunner` | 운동 세션 |
| --- | --- |
| 세션 시작 | `start()` |
| 완료 (`finish()`) | `end()` |
| 중단 (`abandon()`) | `end()` |
| 앱 강제 종료 후 복원 | 이미 끝난 것으로 본다. 다시 시작하지 않는다 |

마지막 줄이 중요하다. 복원(`SessionRestore`)은 며칠 전 세션을 되살릴 수도 있다.
그때 운동 세션을 시작하면 **몇 시간짜리 유령 운동**이 건강 앱에 남는다.

### 권한

거부돼도 앱은 그대로 동작한다. `WatchSyncService` 의 `lastSendError` 와 같은 방식으로
실패를 삼키지 않고 남기되, 화면을 막지 않는다.

권한 요청 시점은 **첫 세션 시작 직전**이다. 앱 첫 실행 때 물으면 무엇에 쓰는지 모르는
상태에서 거부당한다.

## 작업 단위

### 1단계 · 컨트롤러 (WoofitCore)

- [x] 1. `WorkoutSessionController` — `start()` · `end()`.
      **계획 수정**: HealthKit 의존을 `WorkoutHealthSession` 프로토콜로 뽑아 컨트롤러
      자체는 플랫폼 무관으로 둔다. 원안대로 `#if os(watchOS)` 로 파일 전체를 감싸면
      테스트 계획의 4개 항목이 `swift test` 로 못 돈다(원칙 3). HealthKit 을 실제로
      쓰는 구현체(`HealthKitWorkoutSession`)만 `#if os(watchOS)` 로 감싼다
- [x] 2. 권한 요청 — 쓰기 권한만(`workoutType`). 읽기는 요청하지 않는다
- [x] 3. `HKWorkoutBuilder` 로 세션 저장 — `traditionalStrengthTraining`, 실내
- [x] 4. 실패 기록 — `lastError` 와 `os.Logger`. `WatchSyncService` 와 같은 모양
- [x] 5. 권한 없음·시작 실패를 구분해 남긴다. 둘 다 "그냥 안 됨" 이 되면 원인을 못 찾는다

### 2단계 · 배선 (워치 앱)

- [x] 6. 세션 시작 지점에서 `start()` — `WatchRoutinePreviewView.start()` (실제 시작 경로.
      `WatchRootView` 는 목록만 보여준다)
- [x] 7. 완료·중단 지점에서 `end()` — `WatchSetView.finishSession()` 하나로 완료·중단
      두 경로가 이미 합류하므로 거기 한 번만 추가했다
- [x] 8. 복원 경로에서는 시작하지 않는다 — **현재 워치 앱에는 복원 경로 자체가 없다**
      (독립 저장소이고 `WatchRootView` 는 진행 중 세션을 되살리지 않는다). 그래서
      할 일은 "만들지 않는다": `start()` 호출을 `WatchRoutinePreviewView.start()`
      단 한 곳에만 두고, 다른 어떤 지점에서도 호출하지 않았다
- [x] 9. 빌드 설정 — `INFOPLIST_KEY_NSHealthUpdateUsageDescription`,
      `INFOPLIST_KEY_WKBackgroundModes = "workout-processing"`,
      `CODE_SIGN_ENTITLEMENTS`(`WoofitWatch Watch App.entitlements` 신설,
      `com.apple.developer.healthkit`). Debug·Release 두 구성 모두 반영

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Health/WorkoutSessionController.swift` | 세션 수명·권한 실패 상태 머신 (플랫폼 무관) |
| `WoofitCore/Sources/WoofitCore/Health/HealthKitWorkoutSession.swift` | `HKWorkoutSession`/`HKLiveWorkoutBuilder` 실제 구현 (`#if os(watchOS)`) |
| `WoofitCore/Tests/WoofitCoreTests/WorkoutSessionControllerTests.swift` | 상태 전이 테스트 |
| `WoofitWatch Watch App/WoofitWatchApp.swift` | 컨트롤러 생성·환경 주입 |
| `WoofitWatch Watch App/Features/WatchRoutinePreviewView.swift` | 시작 배선 |
| `WoofitWatch Watch App/Features/WatchSetView.swift` | 완료·중단 배선 |
| `Woofit.xcodeproj/project.pbxproj` | 권한 문구·백그라운드 모드 |

## 테스트 계획

HealthKit 자체는 시뮬레이터 없이 검증할 수 없다. **검증 가능한 것과 아닌 것을 나눈다.**

| 테스트 | 검증하는 것 |
| --- | --- |
| 시작하지 않은 상태에서 `end()` 를 불러도 안전하다 | 중복 종료 |
| `start()` 를 두 번 불러도 세션이 하나다 | 중복 시작 |
| 권한이 없으면 `start()` 가 조용히 실패하고 `lastError` 가 남는다 | 거부 시 동작 |
| 복원된 세션은 운동 세션을 시작하지 않는다 | **유령 운동 방지** |

**실기기로만 확인되는 것** — 아래 완료 기준 2·3. 계획서에 적어두고 체크한다.

## 완료 기준

1. [x] `swift test` 통과 · `xcodebuild build` 통과
2. [x] **워치에서 세션을 시작하고 손목을 내린 뒤 2분 후 들어 올렸을 때, 시계 화면이
   아니라 실행 중이던 세트 화면이 그대로 보인다** (PRD 수용 기준) — 실기기로 확인함(2026-08-30)
3. [x] 세션을 끝낸 뒤 건강 앱 · 활동 링에 근력 운동이 남는다 — 실기기로 확인함(2026-08-30).
   최초 확인 때 시작·종료 시각이 실제와 안 맞는 문제가 있었는데, `start()`·`end()` 가
   워치 화면 두 곳에서 각자 별도 `Task` 로 fire-and-forget 되어 순서가 보장되지 않던
   레이스가 원인으로 보인다(`WorkoutSessionController.end()` 가 진행 중인 `start()` 를
   기다리지 않고 조용히 무시). `end()` 가 진행 중인 시작을 먼저 기다리도록 고치고
   회귀 테스트를 추가한 뒤 재확인 — 시작·종료 시각이 실제 탭 시점과 일치함을 확인했다
   (2026-08-30)
4. [x] 권한을 거부한 상태에서도 세트 기록·휴식 측정·마크다운 내보내기가 모두 동작한다 — 실기기로 확인함(2026-08-30)
5. [x] 세션 종료 후 워치 배터리가 계속 닳지 않는다 (운동 세션이 남아 있지 않다) — 실기기로 확인함(2026-08-30)

## 주의점

**`project.pbxproj` 가 바뀌는 몇 안 되는 작업이다.** 이 프로젝트는 buildable folder 라
소스를 추가·삭제해도 pbxproj 가 안 바뀌지만, 그건 **파일 목록** 이야기다. 빌드 설정은
다르다. `GENERATE_INFOPLIST_FILE = YES` 이므로 권한 문구는 `INFOPLIST_KEY_*` 로 들어가고,
그건 pbxproj 안에 있다. 디버그·릴리즈 두 구성 모두에 넣어야 한다.

**무료 계정에서 HealthKit 이 켜지는 것을 확인했다(2026-08-30).** CloudKit 은 유료가
필요했으므로(D5) 같은 제약이 있는지 착수 전에 확인했는데, 개인 팀에도 발급된다.
워크트리에서 entitlement 만 붙여 워치 타겟을 빌드해 확인한 결과다.

```
$ codesign -d --entitlements :- "WoofitWatch Watch App.app"
    com.apple.developer.healthkit = true

$ security cms -D -i embedded.mobileprovision   # 애플이 발급한 프로파일
    com.apple.developer.healthkit                   = true
    com.apple.developer.healthkit.access            = []
    com.apple.developer.healthkit.background-delivery = true
```

**프로파일에 있다고 Info.plist 가 필요 없는 것은 아니다.** entitlement 는 권한이고,
`WKBackgroundModes` 의 `workout-processing` 과 `NSHealthUpdateUsageDescription` 은
따로 넣어야 한다(작업 단위 9).

**종료를 빠뜨리면 조용히 배터리를 먹는다.** 화면에는 아무 문제가 없어 보이고 며칠 뒤
"워치 배터리가 빨리 닳는다" 로만 드러난다. 중단(`abandon`) 경로를 특히 확인한다 —
완료 경로보다 덜 밟게 되고, 그래서 빠뜨리기 쉽다.

**복원과 운동 세션을 섞지 않는다.** 위 설계의 마지막 줄이다. 며칠 전 중단된 세션이
복원될 때 운동 세션을 시작하면 건강 앱에 몇 시간짜리 기록이 남는다. 사용자가 그걸
지우려면 건강 앱에 들어가야 하고, 이 앱은 그걸 되돌릴 방법이 없다.

---

## 후속 · 빈 루틴이면 운동 세션이 끝나지 않는다 (fix/workout-session-leak)

머지 후 검증에서 발견. **위 "주의점" 에 적어둔 실패 양상 그대로다.**

### 무엇이 일어나는가

`end()` 에 닿는 경로가 둘뿐이다.

```swift
.onChange(of: runner.phase) { _, phase in          // ① 변화가 있어야 터진다
    guard case .finished = phase else { return }
    finishSession()
}
Button("중단", role: .destructive) { ... finishSession() }   // ②
```

그런데 **빈 루틴은 `SessionRunner` 생성 시점에 이미 `.finished` 다.** 변화가 없으니
`onChange` 가 영영 안 터진다. 프로브로 확인했다.

```
빈 루틴   생성 직후 phase == .finished        → onChange 미발화
정상 루틴 생성 직후 phase == recording(...)   → 나중에 변한다
```

`WatchRoutinePreviewView.start()` 는 루틴이 비었는지 보지 않고 `start()` 를 부르고,
완료 화면의 「완료」 버튼은 `onEnd`(화면 닫기)만 하고 `finishSession()` 을 부르지 않는다.

**결과** — 빈 루틴을 워치에서 시작하면 `HKWorkoutSession` 이 시작되고 절대 종료되지
않는다. 배터리를 계속 먹고 건강 앱에 끝나지 않는 운동이 남는다.

빈 루틴은 F-04 에서도 무한 루프를 냈던 자리다. 실제로 만들어질 수 있는 상태다.

### 왜 테스트가 못 잡았나

`WorkoutSessionControllerTests` 는 컨트롤러의 상태 전이만 본다. 그건 정상이다.
**빠진 것은 "호출부가 end() 를 부르는가" 이고, 그건 화면이라 Core 테스트가 닿지 않는다.**
그래서 아래 1번(빈 루틴이면 시작하지 않는다)을 Core 로 내려 테스트 가능하게 만든다.

## 작업 단위

- [x] 1. **빈 세션이면 운동 세션을 시작하지 않는다.** 판단을 화면에 두지 말고
      `WorkoutSession` 쪽 계산 프로퍼티로 내려 `swift test` 가 닿게 한다
      — `WorkoutSession.hasRecordableSets`
- [x] 2. 완료 화면의 「완료」 버튼도 `finishSession()` 을 거치게 한다 —
      `onChange` 한 경로에만 의존하지 않도록 하는 방어
- [x] 3. 1번에 대한 테스트 — 빈 세션·종목만 있고 세트가 없는 세션·정상 세션 세 가지
- [x] 4. 회귀 테스트 — 정상 루틴은 여전히 시작·종료가 한 번씩 일어날 것

## 검증

1. `swift test` 통과, 위 테스트 존재
2. `xcodebuild build` 통과
3. **빈 루틴을 워치에서 시작 → 완료 → 건강 앱에 운동이 남지 않을 것**
4. 정상 루틴은 완료·중단 양쪽에서 건강 앱에 운동이 하나씩 남을 것
5. 종료 후 워치 배터리가 계속 닳지 않을 것

## 남겨두는 것

**워치 앱이 강제 종료되면 운동 세션이 남는다.** 애플은 `recoverActiveWorkoutSession`
으로 복구하게 하는데 이 앱엔 복원 경로가 없다(작업 단위 8 에서 "복원 경로 자체가 없다"
고 적은 그것이다). 이번 범위 밖으로 두되, 워치 복원 경로를 만들 때 함께 다룬다.

### 후속 · 「완료」가 종료 처리를 두 번 돌리던 것 (fix/duplicate-snapshot)

빈 루틴 수정에서 「완료」 버튼도 `finishSession()` 을 거치게 했는데, 그 함수는 세 가지를
한다 — 스냅샷 전송 · 워치 저장소 정리 · 운동 세션 종료. 정상 세션에서는
`onChange(of: phase)` 가 이미 한 번 돌린 뒤라 **모든 세션에서 두 번 실행됐다.**
엣지 케이스가 아니라 기본 경로다.

`end()` 는 `isActive` 를 보고 무시하지만 나머지 둘은 아니다. `transferUserInfo` 는 큐에
쌓여 보장 전송되므로 스냅샷이 실제로 두 번 나간다. 병합이 멱등이라 폰 기록은 어긋나지
않지만, 워치에서 매 세션 전송이 배로 늘어난다.

**「완료」 쪽에서 운동 세션 종료만 부르는 방식은 쓰지 않았다.** 빈 세션이 회귀한다 —
그때는 `onChange` 가 터지지 않아 「완료」가 스냅샷·정리에 닿는 유일한 경로다. 대신
`finishSession()` 자체가 한 번만 실행되게 막아, 두 경로 중 먼저 오는 쪽이 처리한다.

**테스트로 고정할 수 없다.** 화면 상태(`@State`)라 Core 테스트가 닿지 않는다. 이 판단을
모델로 내릴 수도 없다 — 세션이 아니라 화면의 수명에 묶인 값이다. 실기기에서 세션을
완주한 뒤 폰에 기록이 하나만 도착하는 것으로 확인한다.
