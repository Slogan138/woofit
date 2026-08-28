# F-01 · 루틴 작성

> **M1** · 폰 · [PRD §4 F-1](../PRD.md#f-1--루틴-작성-폰-m1)

## 요구사항

- 루틴에 **이름 · 카테고리(부위) · 반복 요일**
- 카테고리는 자유 입력 + 프리셋 제안 (가슴 · 등 · 하체 · 어깨 · 팔 · 코어 · 전신)
- 반복은 요일 단위, 한 루틴에 여러 요일 가능
- **같은 요일에는 루틴 하나만**. 다른 루틴에 주면 기존 배정 해제(A1)
- 종목 자유 입력 + 이전 종목명 자동완성
- 세트마다 목표 무게·횟수, **세트 복제**, 피라미드 세트 지원
- 순서 변경·삭제, 루틴 복제
- 각 종목 옆에 직전 기록 표시(F-09)

**수용 기준** — 5종목 × 4세트 루틴을 2분 안에 작성.

## 선행 조건

- ✅ `Routine` · `PlannedExercise` · `PlannedSet` 모델과 조작 메서드
- F-09 (직전 기록 표시) — 병행 가능. 없어도 편집기는 동작한다

## 작업 단위

- [ ] 1. `RoutineScheduler` — 요일 배타 배정 로직 (WoofitCore)
- [ ] 2. `ExerciseNameSuggester` — 과거 종목명 수집·정렬 (WoofitCore)
- [ ] 3. `Routine.duplicate()` — 루틴 복제 (WoofitCore)
- [ ] 4. 테스트 (1~3)
- [ ] 5. `RoutineEditorView` — 이름·카테고리·요일
- [ ] 6. 종목 목록 — 추가·순서 변경·삭제
- [ ] 7. 세트 편집 — 무게/횟수 입력, 세트 복제
- [ ] 8. 자동완성 연결
- [ ] 9. 루틴 목록에서 편집·복제·삭제 진입

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Routine/RoutineScheduler.swift` | 요일 배타 배정 |
| `WoofitCore/Sources/WoofitCore/Routine/ExerciseNameSuggester.swift` | 종목명 자동완성 후보 |
| `WoofitCore/Sources/WoofitCore/Model/Routine+Duplicate.swift` | 루틴 복제 |
| `WoofitCore/Tests/WoofitCoreTests/RoutineAuthoringTests.swift` | 테스트 |
| `Woofit/Features/Routine/RoutineEditorView.swift` | P2 편집기 |
| `Woofit/Features/Routine/ExerciseEditorRow.swift` | 종목 + 세트 편집 |
| `Woofit/Features/Routine/WeekdayPicker.swift` | 요일 선택 |
| `Woofit/Features/Routine/CategoryField.swift` | 카테고리 입력 + 프리셋 |

## 설계 메모

**요일 배타 배정은 로직이므로 WoofitCore 에 둔다.** 화면에서 처리하면 테스트가 안 된다.

```swift
public enum RoutineScheduler {
    /// `routine` 에 요일을 배정하고, 같은 요일을 쓰던 다른 루틴에서 해제한다(A1).
    public static func assign(_ weekdays: [Weekday], to routine: Routine, in context: ModelContext) throws
}
```

**자동완성 후보**는 과거 `PlannedExercise` 와 `SessionExercise` 의 이름을
`normalizedName` 으로 묶고 사용 빈도·최근순으로 정렬한다.

**세트 복제**는 `PlannedExercise.appendSets(count:weight:reps:)` 가 이미 있다.
UI 는 "세트 수" 스테퍼로 노출해 5×5 를 한 번에 만들 수 있게 한다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 요일을 배정하면 같은 요일을 쓰던 다른 루틴에서 해제된다 | A1 배타성 |
| 여러 요일을 한 루틴에 배정할 수 있다 | 월·목 = 마스크 18 |
| 요일을 비우면 미지정 루틴이 된다 | `weekdayMask == 0` |
| 자동완성 후보가 최근·빈도 순으로 나온다 | 정렬 |
| 자동완성이 공백 표기 차이를 하나로 묶는다 | `normalizedName` |
| 루틴을 복제하면 종목·세트가 전부 복사된다 | 깊은 복사 |
| 복제본은 요일 배정을 물려받지 않는다 | 배타성 충돌 방지 |
| 종목 삭제 후 `order` 가 빈틈없이 재정렬된다 | `reindexExercises` |
| 세트 복제로 5세트를 한 번에 만든다 | `appendSets` |

## 완료 기준

1. `swift test` 통과
2. 5종목 × 4세트 루틴을 실제로 2분 안에 작성 가능
3. 요일 배정 시 다른 루틴에서 해제되는 것을 화면에서 확인
4. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **종목명은 `rename(to:)` 로 바꾼다.** `name` 에 직접 대입하면 `normalizedName` 이
  갱신되지 않아 직전 기록이 조용히 끊긴다.
- **복제본에 요일을 물려주면 안 된다.** 물려주면 원본의 배정이 즉시 해제된다.
- 순서 변경·삭제 뒤에는 `reindexExercises()` / `reindexSets()` 를 호출한다.
- 편집기는 F-07(가져오기)의 대안 경로일 뿐이다. **여기에 과하게 투자하지 않는다.**
  실사용에서는 마크다운 붙여넣기가 주 경로가 될 가능성이 높다.
