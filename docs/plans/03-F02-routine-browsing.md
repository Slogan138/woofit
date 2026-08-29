# F-02 · 루틴 확인

> **M1**(폰) / **M2**(워치) · [PRD §4 F-2](../PRD.md#f-2--루틴-확인-폰-워치-m1--m2)

## 요구사항

- 폰: 루틴 목록과 상세(전 종목·전 세트). 목록은 요일 순 정렬
- 워치: **오늘 요일에 배정된 루틴을 최우선**. 없으면 최근 사용 루틴 목록
- 워치에서 시작 전 전체 스크롤 확인
- **네트워크나 폰 연결이 필요 없다.** 워치에 이미 내려와 있어야 한다

## 선행 조건

- ✅ `Routine` 모델, `Weekday.today()`
- 워치 부분은 F-08(동기화) 필요

## 작업 단위

**M1 (폰)**
- [x] 1. `RoutineListView` 정렬 — 오늘 → 요일 순 → 미지정
- [x] 2. `RoutineDetailView` — 전 종목·전 세트 표시
- [ ] 3. 목록에서 세션 시작 진입 — **04-F03 로 이동.** 진입 대상인 `SessionRunnerView` 가
      F-03 소관이라 지금은 목적지가 없다. F-03 착수 시 `RoutineListView`/`RoutineDetailView`
      에서 `WorkoutSession.start(from:)` 을 호출하는 버튼을 그때 추가한다.

**M2 (워치)**
- [x] 4. `WatchRootView` — 오늘의 루틴 카드 강조
- [x] 5. `WatchRoutinePreviewView` — 시작 전 훑기 (W2)

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Routine/RoutineOrdering.swift` | 목록 정렬 규칙 |
| `Woofit/Features/Routine/RoutineListView.swift` | P1 (이미 존재, 정렬 보강) |
| `Woofit/Features/Routine/RoutineDetailView.swift` | 루틴 상세 |
| `WoofitWatch Watch App/WatchRootView.swift` | W1 (이미 존재, 보강) |
| `WoofitWatch Watch App/Features/WatchRoutinePreviewView.swift` | W2 |

## 설계 메모

**정렬 규칙을 WoofitCore 로 뺀다.** 화면에서 정렬 조건을 조립하면 테스트가 안 된다.

```swift
public enum RoutineOrdering {
    /// 오늘 배정된 루틴 먼저, 그다음 요일 순, 마지막에 미지정.
    public static func forList(_ routines: [Routine], today: Weekday) -> [Routine]
}
```

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 오늘 배정된 루틴이 맨 앞에 온다 | 우선순위 |
| 오늘 루틴이 없으면 요일 순으로 정렬된다 | 기본 정렬 |
| 미지정 루틴이 맨 뒤로 간다 | `weekdayMask == 0` |
| 여러 요일에 배정된 루틴은 가장 이른 요일 기준으로 정렬된다 | 다중 요일 |

## 완료 기준

1. `swift test` 통과
2. 월요일에 앱을 열면 월요일 루틴이 맨 위에 있다
3. (M2) 워치에서 폰 연결 없이 루틴이 보인다
4. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **워치가 폰 없이 동작해야 한다.** 루틴 조회 경로에 `WCSession` 상태 확인을 넣지 않는다.
  워치의 SwiftData 저장소만 읽는다.
- 요일 계산은 `Calendar.current` 를 쓰되, 테스트에서는 주입 가능해야 한다
  (`Weekday.today(_:now:)` 가 이미 인자를 받는다).
