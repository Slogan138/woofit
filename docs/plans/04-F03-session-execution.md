# F-03 · 세션 실행과 성공·실패 기록

> **M1**(폰) / **M2**(워치) · [PRD §4 F-3](../PRD.md#f-3--세션-실행과-성공실패-기록-폰-워치-m1--m2)

## 요구사항

- 시작 시 루틴을 **복사(스냅샷)**
- 현재 종목·현재 세트를 뚜렷하게 구분
- **성공은 1탭.** 추가 입력 없음
- **실패는 실제 횟수 입력 필수. 건너뛸 수 없다**(D1). 무게도 조정 가능
- 기록한 세트를 되돌려 수정 가능
- 진행률 — 종목 기준·세트 기준 둘 다
- 현재 종목의 직전 기록 유지(F-09)
- 일시정지·재개·중단. 중단해도 기록으로 남는다

**수용 기준** — 성공 세트 기록에 워치 탭 1회, 응답 100ms 이내.

## 선행 조건

- ✅ `WorkoutSession.start(from:)`, `markSuccess()`, `markFailure(actualReps:)`, `clearResult()`
- ✅ 진행 상태 프로퍼티 (`currentExercise`, `nextPendingSet`, `recordedSetCount`)
- ✅ `LastRecordLookup` — 직전 기록 조회. **여기서 직접 호출한다**

**03-F02 의 세션 진입 버튼도 여기서 만든다.** `RoutineListView`/`RoutineDetailView` 에
`WorkoutSession.start(from:)` 을 호출해 `SessionRunnerView` 로 넘어가는 버튼이 아직 없다 —
목적지 화면(`SessionRunnerView`)이 이 계획 소관이라 F-02 에서는 만들지 않았다.

**07-F09 를 기다리지 않는다.** 조회 로직은 이미 완료돼 있어 이 작업에서 바로 쓴다.
07-F09 가 다루는 것은 편집기·워치 등 **나머지 통합 지점**이라 이 문서보다 뒤에 온다.

**도메인 로직은 이미 완료.** 남은 것은 화면과 상태 관리다.

## 작업 단위

**M1 (폰)**
- [x] 1. `SessionRunner` — `@Observable` 실행 상태 (현재 종목/세트, 진행률)
- [x] 2. `SessionRunnerView` — 현재 세트 강조, 진행률 (P4)
- [x] 3. 성공 버튼 — 1탭
- [x] 4. 실패 시트 — 횟수 스테퍼(필수) + 무게 조정
- [x] 5. 기록 수정 — 지난 세트 탭해서 되돌리기
- [x] 6. 일시정지·재개·중단 — `WorkoutSession.pausedAt` 에 저장하므로 앱을 껐다 켜도 유지된다
- [x] 7. 세션 복원 — `SessionRestore.fetchInProgress` 로 `stateRaw == inProgress` 세션을 찾아 앱 시작 시 `SessionRunnerView` 로 바로 진입한다(`SessionCoordinator`)
- [x] 8. 테스트

**M2 (워치)**
- [x] 9. `WatchSetView` — 성공/실패 두 버튼 (W3)
- [x] 10. Digital Crown 횟수 입력

이 화면들은 F-08(폰↔워치 동기화)이 없는 상태에서 만들어졌다. 워치는 자기 로컬 저장소만
읽고 쓸 뿐, 폰의 루틴을 받아올 방법이 아직 없다 — `WatchRootView` 는 여전히 "폰에서 루틴을
만드세요"로 안내한다. 그래서 실기기 검증 대신, 워치 로컬 저장소에 직접 씨드 데이터를 넣어
"시작 → 성공 → 실패(Digital Crown 기본값 + 무게 스테퍼) → 되돌리기 → 성공 → 완료" 전
과정을 워치 시뮬레이터에서 확인했다. `WCSession` 을 통한 실제 폰 ↔ 워치 왕복은 F-08의 몫이다.

**되돌리기는 "주의점"대로 넣었다.** 워치는 실수 탭이 잦다는 이유로 이 문서가 이미
되돌리기 경로를 필수로 요구하고 있어, 세트 목록 전체를 못 보여주는 대신
`SessionRunner.lastRecordedSet`(가장 최근에 기록한 세트 하나)을 추적해
"N세트 되돌리기" 버튼 하나로 노출한다. 되돌리면 그 세트로 초점도 다시 옮겨간다 —
안 그러면 마지막 세트를 되돌렸을 때 화면이 "완료" 상태에 그대로 머무른다.

**M2 범위에서 의도적으로 뺀 것.** 워치 화면은 성공/실패 두 버튼과 직전 기록 한 줄로
압축한다(PRD 화면표의 W3 자체가 P4보다 좁게 정의되어 있다). 그래서 이번 pass 에는
일시정지와 앱 재시작 시 이어받기는 넣지 않았다 — 대신 진행 중 세션을
`navigationBarBackButtonHidden` 으로 감싸 "중단" 버튼으로만 나가게 해서 고아 세션이
생기지 않게 막았다. 필요해지면 별도로 채워 넣는다.

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Session/SessionRunner.swift` | 실행 상태 (`@Observable`) |
| `WoofitCore/Sources/WoofitCore/Session/SessionRestore.swift` | 진행 중 세션 복원 조회 |
| `WoofitCore/Tests/WoofitCoreTests/SessionRunnerTests.swift` | 테스트 |
| `Woofit/Features/Session/SessionRunnerView.swift` | P4 |
| `Woofit/Features/Session/FailureInputSheet.swift` | 실패 횟수 입력 |
| `Woofit/Features/Session/SessionCoordinator.swift` | 루틴 상세의 "시작"과 앱 시작 시 복원, 두 진입점을 `RootView` 의 `fullScreenCover` 로 모으는 화면 상태 |
| `WoofitWatch Watch App/Features/WatchSetView.swift` | W3 |
| `WoofitWatch Watch App/Features/WatchFailureInputView.swift` | 워치 실패 횟수 입력 (Digital Crown) |

## 설계 메모

**`SessionRunner` 는 모델을 감싸는 얇은 상태 객체다.** 비즈니스 로직은 이미
`WorkoutSession` / `SessionSet` 에 있으므로, 여기서는 "지금 어느 세트를 보고 있나"만 다룬다.

```swift
@Observable
public final class SessionRunner: Identifiable {
    public private(set) var session: WorkoutSession
    public var focusedSet: SessionSet?
    public private(set) var lastRecords: [String: LastRecord]   // F-09
    public private(set) var lastRecordedSet: SessionSet?        // 워치 되돌리기용
    public var isPaused: Bool { session.isPaused }              // WorkoutSession.pausedAt 를 그대로 반영

    public func recordSuccess(for set: SessionSet?, at: Date)
    public func recordFailure(for set: SessionSet?, actualReps: Int, actualWeight: Double?, at: Date)
    public func skip(_ set: SessionSet?, at: Date)
    public func undo(_ set: SessionSet)
    public func focus(on set: SessionSet)
    public func pause(at: Date)
    public func resume()
    public func finish(at: Date)
    public func abandon(at: Date)
}
```

**실패 입력을 취소할 수 없게 만든다.** 시트를 내려도 세트가 `pending` 으로 남고,
결과가 기록되지 않는다. 실패로 기록되면서 횟수만 비는 경로를 만들지 않는다 — D1 위반.
`FailureInputSheet` 는 "기록" 버튼을 눌러야만 `onRecord` 콜백을 호출하므로, 취소·스와이프 dismiss 모두 안전하다.

**일시정지는 `WorkoutSession.pausedAt: Date?` 에 저장한다.** `SessionRunner.isPaused` 라는
휘발성 플래그로만 두면 앱을 강제 종료했다가 다시 열었을 때 항상 "재개됨"으로 보인다.
`pausedAt` 이 있을 때만 일시정지 중이고, `stateRaw` 는 여전히 `inProgress` 라서 복원 대상에도 그대로 걸린다.
`SessionRunnerView` 는 `.disabled(runner.isPaused)` 로 기록 버튼 자체를 막는다 — 오버레이는 화면만
가릴 뿐 탭(특히 VoiceOver 같은 접근성 조작)까지 막지는 않기 때문이다.

**세션 복원**은 `SessionRestore.fetchInProgress` 가 `stateRaw == inProgress` 인 세션을 앱 시작 시 조회한다.
`SessionCoordinator`(앱 타겟)가 루틴 상세의 "시작" 버튼과 이 복원 조회, 두 진입점을 모아
`RootView` 의 `fullScreenCover` 로 `SessionRunnerView` 를 띄운다.
휴식 측정 중이었다면 `restStartedAt` 으로 타이머를 되살린다(F-05) — 이 부분은 F-05 화면 통합에서 마저 다룬다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 성공을 기록하면 다음 세트로 초점이 옮겨간다 | 진행 |
| 마지막 세트를 기록하면 종목이 완료된다 | `isComplete` |
| 실패 기록에는 항상 실제 횟수가 있다 | **D1 불변식** |
| 실패 입력을 취소하면 세트가 `pending` 으로 남는다 | D1 우회 차단 |
| 기록을 되돌리면 다시 `pending` 이 된다 | 수정 |
| 되돌려도 측정된 휴식 시간은 남는다 | 실제로 쉰 것은 사실 |
| 진행률이 종목·세트 두 기준으로 계산된다 | 표시 |
| 중단한 세션은 `abandoned` 로 남고 기록에 보인다 | 중단 처리 |
| 앱 재시작 시 진행 중 세션을 찾아 이어받는다 | 복원 |
| 진행 중 세션이 없으면 복원 결과가 `nil` 이다 | 경계 |

## 완료 기준

1. `swift test` 통과
2. 폰에서 루틴 시작 → 전 세트 기록 → 완료까지 한 번에 진행 가능
3. 실패 기록 시 횟수 입력 없이 넘어가는 경로가 **존재하지 않음**
4. 앱을 강제 종료하고 재실행해도 진행 위치가 유지됨
5. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **성공 경로에 확인 대화상자를 넣지 않는다.** 1탭이 수용 기준이다.
- **응답 100ms.** 세트 기록 시 동기화 전송이나 무거운 조회를 같은 흐름에서 하지 않는다.
- 실패 시트의 기본값은 목표 횟수보다 **1 적은 값**으로 둔다. 대부분 한두 개 모자란다.
- 워치에서는 실수 탭이 잦다. 되돌리기 경로를 반드시 노출한다.
