# 13 · F-12 세션 기록 삭제

> **개선** · 폰 · [PRD §4 F-12](../PRD.md) · 결정 근거 [D7](../PRD.md#11-확정-사항)

## 요구사항

- 기록 **목록과 상세 양쪽**에서 삭제
- **삭제 전 확인**을 받는다
- **진행 중 세션은 중단한 뒤에만** 삭제 가능
- 일괄 삭제는 만들지 않는다

**수용 기준** — 잘못 시작한 세션을 두 번의 조작(삭제 → 확인)으로 없앨 수 있다.

## 왜 뒤늦게 생겼나

PRD D3 이 "세션 기록 전체 보관, 개수 제한 없음"으로 정해져 있었는데, 그건 **앱이 자동으로
지우지 않는다**는 결정이었다. 그 과정에서 **사용자가 직접 지우는 경우**를 아무도 짚지
않았고, "다 보관한다"와 "지울 수 없다"가 같은 말처럼 넘어갔다.

실기기 테스트 중 시험용 세션이 쌓이면서 드러났다. 루틴은 삭제되는데 세션만 안 되는
비대칭도 그때까지 눈에 띄지 않았다.

## 선행 조건

- ✅ `SessionHistoryView`(목록) · `SessionDetailView`(상세) — 삭제를 붙일 자리
- ✅ `WorkoutSession.abandon()` — 중단
- ✅ `SessionState.isFinished` — 진행 중 여부 판정

새로 만들 도메인 로직은 거의 없다.

## 작업 단위

- [x] 1. `WorkoutSession.isDeletable` — 진행 중이면 `false` (WoofitCore)
- [x] 2. 삭제 로직 — 컨텍스트에서 지우고 관계를 정리한다 (WoofitCore)
- [x] 3. 테스트 (1~2)
- [x] 4. 목록에서 스와이프 삭제 + 확인
- [x] 5. 상세에서 삭제 + 확인
- [x] 6. 진행 중 세션에는 삭제를 노출하지 않거나 비활성화

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Model/WorkoutSession.swift` | `isDeletable` |
| `WoofitCore/Sources/WoofitCore/Session/SessionDeletion.swift` | 삭제 로직 |
| `WoofitCore/Tests/WoofitCoreTests/SessionDeletionTests.swift` | 테스트 |
| `Woofit/Features/Session/SessionHistoryView.swift` | 목록 삭제 |
| `Woofit/Features/Session/SessionDetailView.swift` | 상세 삭제 |

## 설계 메모

**삭제 가능 여부를 모델이 판정한다.** 화면 두 곳이 같은 조건을 각자 쓰면 어긋난다.
`isDeletable` 하나를 두고 목록·상세가 함께 읽는다.

**관계를 함께 지운다.** `SessionExercise` · `SessionSet` 은 `deleteRule: .cascade` 라
세션만 지우면 따라간다. 다만 편집기에서 배열만 비워 고아가 남았던 전례가 있으므로
(`fix/editor-orphans-and-cancel`) 테스트로 확인한다.

**확인 UI 는 루틴 삭제와 같은 방식으로.** 목록 스와이프는 `allowsFullSwipe: false` 를
써서 끝까지 밀어도 바로 지워지지 않게 한다 — 루틴 목록이 이미 그렇게 되어 있다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 완료된 세션은 삭제할 수 있다 | `isDeletable` |
| 중단된 세션도 삭제할 수 있다 | 중단 후 삭제(D7) |
| 진행 중 세션은 삭제할 수 없다 | 중단이 선행되어야 함 |
| 중단하면 삭제할 수 있게 된다 | 두 단계 전이 |
| 세션을 지우면 종목·세트도 저장소에서 사라진다 | cascade · 고아 없음 |
| 세션을 지워도 루틴은 남는다 | 스냅샷이라 원본과 무관 |
| 세션을 지워도 다른 세션의 직전 기록에 영향이 없다 | F-9 조회 |

## 완료 기준

1. `swift test` 통과, 위 테스트 존재
2. `xcodebuild build` 통과
3. 목록·상세 양쪽에서 확인 후 삭제 동작
4. 진행 중 세션에 삭제가 노출되지 않음
5. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

**되돌릴 수 없다.** 마크다운으로 옮기지 않은 세션을 지우면 그 운동이 사라진다.
확인 문구에 그 사실을 담는다 — "삭제하시겠습니까?" 보다 무엇을 잃는지 알려야 한다.

**직전 기록(F-9)이 바뀔 수 있다.** 가장 최근 세션을 지우면 그 종목의 직전 기록이
그 이전 세션으로 바뀐다. 정상 동작이지만, 지운 뒤 루틴의 `지난 기록` 열이 달라지는 것을
사용자가 이상하게 느낄 수 있다. 테스트로 동작을 고정해둔다.

---

## 후속 · 삭제 애니메이션이 끊긴다 (fix/delete-animation)

실사용에서 발견. 스와이프 → 삭제 버튼 → 확인 팝업 → 삭제 사이가 매끄럽지 않다.
동작은 맞고 데이터도 정확하다. **표현만 문제다.**

원인이 겹쳐 있다. 위에서부터 영향이 크다.

### ① 삭제가 다이얼로그 닫힘과 같은 프레임에서 일어난다

```swift
Button("삭제", role: .destructive) {
    if let session = pendingDeletion { delete(session) }   // 목록이 여기서 바뀐다
    pendingDeletion = nil                                   // 다이얼로그가 여기서 닫힌다
}
```

다이얼로그가 닫히는 애니메이션, 스와이프 행이 닫히는 애니메이션, 행이 목록에서
빠지는 변화가 한 프레임에 겹친다. **사용자가 보는 "끊김"의 주 원인이다.**

### ② 삭제에 애니메이션 트랜잭션이 없다

`SessionDeletion.delete` 는 컨텍스트만 바꾸고 `@Query` 가 갱신된다. `withAnimation`
밖이라 List 가 부드럽게 줄지 않고 툭 끊긴다. 월 마지막 세션을 지우면 Section 이
통째로 사라져 더 크게 튄다.

### ③ 자체 Binding 을 만들었다 — 표준 API 가 있다

```swift
isPresented: Binding(get: { pendingDeletion != nil }, set: { ... })
```

`confirmationDialog(_:isPresented:presenting:)` 가 바로 이 용도다. 매 렌더마다 새
Binding 이 만들어져 불필요한 무효화도 생긴다. **원칙 1 위반이기도 하다**(독자 규격).

### ④ `byMonth` 가 매 렌더 재계산된다

`@Query(sort: \.startedAt, order: .reverse)` 가 이미 내림차순으로 주는데 `byMonth`
안에서 `sorted(by:)` 를 또 돈다. F-13 으로 73세션이 들어와 100건에 가까워졌고,
애니메이션이 도는 매 프레임마다 이 비용을 낸다.

### ⑤ 상세 화면은 순서가 반대다 — 더 위험하다

```swift
try? SessionDeletion.delete(session, in: modelContext)
dismiss()
```

지운 뒤에 화면을 닫는다. 그 사이 뷰가 **이미 삭제된 SwiftData 객체를 렌더**할 수
있다. 지금은 눈에 띄지 않지만 조용히 깨지는 자리다. `dismiss()` 가 먼저여야 한다.

## 작업 단위

- [x] 1. 목록 — 다이얼로그를 먼저 닫고, 닫힘이 끝난 뒤 삭제한다
- [x] 2. 삭제를 `withAnimation` 안에서 한다
- [x] 3. `confirmationDialog(_:isPresented:presenting:)` 로 바꾼다 (자체 Binding 제거)
- [x] 4. `byMonth` 재계산을 줄인다. `@Query` 가 이미 정렬해 주므로 안쪽 `sorted` 는 뺀다
      — **정렬 보장이 호출자에게 넘어가므로 주석으로 남긴다**
- [x] 5. 상세 — `dismiss()` 를 먼저, 삭제를 나중에
- [x] 6. `SessionHistoryGrouping` 테스트가 여전히 통과하는지 확인 (4번이 Core 를 건드린다)

1·5 는 같은 문제라 `DeferredSessionDeletion` 하나로 처리했다. SwiftUI 가 전환 완료
콜백을 주지 않으므로 **표준 애니메이션 길이만큼 기다렸다가** `withAnimation` 안에서
지운다. 뷰가 사라진 뒤에도 삭제는 끝나야 하므로 구조화되지 않은 `Task` 를 쓴다.

**6 은 "그대로 통과"가 아니었다.** 4번이 정렬 계약을 호출자에게 넘기므로, 뒤섞인
입력을 넣고 정렬된 출력을 기대하던 기존 테스트의 전제가 사라진다. 입력을 최신순으로
바꾸고, 바뀐 계약(`묶음 순서는 입력 순서를 그대로 따른다`)을 고정하는 테스트를 더했다.

## 검증

**`swift test` 로는 확인되지 않는다.** 화면 표현이라 도메인 테스트가 닿지 않는다.
4번만 Core 라 기존 `SessionHistoryGroupingTests` 로 회귀를 막는다.

나머지는 실기기·시뮬레이터에서 눈으로 본다.

1. 스와이프 → 삭제 → 팝업 → 삭제 가 한 흐름으로 이어질 것
2. 월의 마지막 세션을 지워 Section 이 사라질 때도 튀지 않을 것
3. 상세에서 삭제하면 화면이 먼저 닫히고 목록에서 사라질 것
4. 취소를 눌렀을 때 스와이프가 제자리로 돌아올 것
