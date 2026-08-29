# F-04 · 다음 운동 안내

> **M1**(폰) / **M2**(워치) · [PRD §4 F-4](../PRD.md#f-4--다음-운동-안내-폰-워치-m1--m2)

## 요구사항

- 한 종목의 모든 세트가 처리되면(성공·실패·건너뜀 무관) **자동으로** 전환 화면
- 전환 화면에 다음 종목명 · 세트 수 · 목표 무게 × 횟수
- 워치는 **햅틱으로 알린다**. 화면을 안 보고 있어도 안다
- 마지막 종목이면 전환 대신 세션 완료 화면
- **순서를 무시하고 아무 종목으로나 이동 가능** (기구가 사용 중일 때)

## 선행 조건

- ✅ `SessionExercise.isComplete`, `WorkoutSession.exercise(after:)`, `currentExercise`
- F-03 (세션 실행 화면)

**판정 로직은 이미 완료.** 남은 것은 전환 연출과 이동 UI다.

## 작업 단위

- [x] 1. `SessionRunner` 에 종목 완료 감지 → 전환 상태 추가
- [x] 2. `NextExerciseView` — 다음 종목 안내 (폰)
- [x] 3. 종목 목록 시트 — 순서 무시하고 이동
- [x] 4. 세션 완료 화면 진입 (마지막 종목)
- [x] 5. 테스트
- [x] 6. (M2) `WatchNextExerciseView` + `WKInterfaceDevice.play(.notification)` 햅틱

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Session/SessionRunner.swift` | 전환 상태 (F-03 과 같은 파일) |
| `WoofitCore/Sources/WoofitCore/Model/WorkoutSession.swift` | `reopen()` — 자동 완료를 되돌리기용으로 대칭 추가 |
| `Woofit/Features/Session/NextExerciseView.swift` | 전환 화면 |
| `Woofit/Features/Session/ExercisePickerSheet.swift` | 종목 이동 |
| `Woofit/Features/Session/SessionCompleteView.swift` | 세션 완료 화면(P5). 계획에는 없었지만 F-6 의 `MarkdownPreviewView`/`SessionMarkdownExporter` 를 그대로 재사용해 추가 |
| `WoofitWatch Watch App/Features/WatchNextExerciseView.swift` | W5 — 전환 화면 + 햅틱 |
| `WoofitWatch Watch App/Features/WatchSetView.swift` | `phase` 로 기록/전환/완료 세 화면을 전환하도록 재구성 |

## 설계 메모

전환은 **상태로 표현한다.** 화면 전환을 명령형으로 밀지 않는다.

```swift
public enum RunnerPhase: Equatable {
    case recording(SessionExercise)
    case transition(from: SessionExercise, to: SessionExercise)
    case finished
}
```

`SessionExercise` 가 `Sendable` 이 아니라(SwiftData `@Model` 참조 타입) `RunnerPhase` 도
`Sendable` 을 뺐다 — `SessionRunner` 자체도 원래부터 `Sendable` 이 아니었으므로 일관된다.

`recordSuccess()` 등 모든 기록·되돌리기·초점 이동 메서드가 끝에서 `refreshPhase(around:)`
단일 진입점을 거쳐 `phase` 를 갱신한다. `focusedSet` 은 종목 경계를 넘어 미리 전진하지만,
`phase` 는 사용자가 전환 화면에서 "시작"을 누르기 전까지 `transition` 에 머문다.

마지막 종목까지 끝나면 `refreshPhase` 가 `session.finish()` 를 자동 호출한다(더 이상
수동 "완료" 버튼에 의존하지 않는다). 이 자동 완료 뒤 마지막 세트를 되돌리면 대칭으로
`session.reopen()` 을 호출해 `state`·`endedAt` 을 되돌린다 — 안 그러면 세션이 여전히
`.completed` 로 남아 앱을 재시작해도 복원 대상에서 빠진다.

**건너뛴 세트도 처리된 것으로 센다.** `SetResult.isRecorded` 가 이미 그렇게 정의돼 있다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 마지막 세트를 기록하면 `phase` 가 `transition` 이 된다 | 자동 전환 |
| 건너뛴 세트만 남아도 종목은 완료로 친다 | `isRecorded` 정의 |
| 마지막 종목을 끝내면 `phase` 가 `finished` 가 된다 | 세션 완료 |
| 전환 상태가 다음 종목의 세트 수와 목표를 담는다 | 표시 데이터 |
| 순서를 건너뛰어 3번째 종목으로 이동할 수 있다 | 임의 이동 |
| 이동 후 미완료 종목으로 돌아올 수 있다 | 왕복 |
| 마지막 세트를 기록하면 세션이 자동으로 완료 처리된다 | 자동 완료 |
| 자동 완료 뒤 마지막 세트를 되돌리면 세션이 다시 진행 중이 된다 | 완료 되돌리기 |

## 완료 기준

1. `swift test` 통과
2. 폰에서 종목이 끝나면 다음 종목 화면이 자동으로 뜬다
3. 종목 목록에서 임의 이동이 동작한다
4. (M2) 워치에서 화면을 안 보고 있어도 햅틱으로 종목 완료를 안다
5. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **자동 전환이 기록을 가로채면 안 된다.** 마지막 세트를 잘못 눌러 되돌리려는데
  화면이 이미 넘어가 있으면 곤란하다. 전환 화면에서 이전 종목으로 돌아가는 경로를 남긴다.
- 햅틱은 `.notification` 을 쓴다. `.success` 는 세트 기록 피드백과 헷갈린다.
