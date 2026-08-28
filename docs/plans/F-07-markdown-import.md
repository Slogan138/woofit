# F-07 · 마크다운 가져오기

> **M1** · 폰 · [PRD §4 F-7](../PRD.md#f-7--마크다운-가져오기-폰-m1) · 파싱 규칙 [§6.5](../PRD.md#65-가져오기-파싱-규칙)

## 요구사항

- 내보낸 것과 **같은 형식**의 마크다운을 붙여넣으면 루틴이 된다
- 세션 기록 형식(A·B)과 루틴 형식 셋 다 받는다
- 결과 표시·휴식·`지난 기록` 열은 무시한다. 계획이 아니라 실행 결과이기 때문
- **파싱 결과를 미리보기로 확인한 뒤 적용**
- 새 루틴 생성 / 기존 루틴 덮어쓰기 선택
- 파싱 실패한 줄은 표시하고 건너뛴다. 전체를 거부하지 않는다

**수용 기준** — 지난주 세션 마크다운을 무게만 고쳐 붙여넣으면 추가 편집 없이 이번 주 루틴이 된다.

## 선행 조건

- **F-06 완료.** 내보내기 출력이 가져오기의 입력이므로, 왕복 테스트를 쓰려면 먼저 있어야 한다.

## 작업 단위

- [ ] 1. `ParsedRoutine` · `ParsedExercise` — SwiftData 가 아닌 값 타입. 미리보기용
- [ ] 2. `ParseIssue` — 건너뛴 줄과 이유
- [ ] 3. `MarkdownTableParser` — 파이프 표를 행·셀로 분해
- [ ] 4. 형식 판별 — 헤더 행을 보고 A / B / 루틴 구분
- [ ] 5. 메타데이터 파싱 — 제목, `- 부위:`, `- 반복:`, 제목에서 요일 추론
- [ ] 6. `목표` 열 파싱 — `80kg × 5`, `맨몸 × 15`, `22.5kg × 5`
- [ ] 7. 세트 수 판정 — 형식별 규칙
- [ ] 8. 테스트 (왕복 테스트 포함)
- [ ] 9. 폰 UI — 붙여넣기 → 미리보기 → 적용

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Markdown/ParsedRoutine.swift` | 파싱 결과 값 타입 |
| `WoofitCore/Sources/WoofitCore/Markdown/MarkdownTableParser.swift` | 표 → 행·셀 |
| `WoofitCore/Sources/WoofitCore/Markdown/RoutineMarkdownImporter.swift` | 텍스트 → `ParsedRoutine` |
| `WoofitCore/Sources/WoofitCore/Markdown/ParsedRoutine+Apply.swift` | `ParsedRoutine` → SwiftData 반영 |
| `WoofitCore/Tests/WoofitCoreTests/MarkdownImportTests.swift` | 테스트 |
| `Woofit/Features/Import/MarkdownImportView.swift` | 붙여넣기·미리보기·적용 (P3) |

## 설계 메모

**파싱과 반영을 분리한다.** 파싱은 `ModelContext` 없이 순수 함수로 돌고,
결과는 `ParsedRoutine` 값 타입이다. 미리보기가 이 값을 그대로 보여주고,
사용자가 확인한 뒤에야 `apply(to:)` 가 SwiftData 에 쓴다.

```swift
public struct ParseResult: Sendable {
    public let routine: ParsedRoutine
    public let issues: [ParseIssue]      // 건너뛴 줄
}

public enum RoutineMarkdownImporter {
    public static func parse(_ text: String) -> ParseResult
}
```

**세트 수 판정**(PRD §6.5)

| 형식 | 규칙 |
| --- | --- |
| A (세트 가로) | 숫자 헤더 열 중 **값이 있는 칸의 개수** |
| B (세트 세로) | 같은 종목의 **행 수** |
| 루틴 | `세트` 열의 숫자 |

**형식 판별**은 헤더 행으로 한다. `세트` 열이 있고 결과 열이 없으면 루틴 형식,
`결과` 열이 있으면 B, 숫자 헤더(`1`, `2`, …)가 있으면 A.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| **왕복 — 루틴을 내보내고 다시 가져오면 같은 루틴이다** | F-06 ↔ F-07 대칭성. **가장 중요한 테스트** |
| **왕복 — 세션을 내보내고 가져오면 그 세션의 계획이 나온다** | 결과를 무시하고 계획만 읽음 |
| 형식 A 를 읽고 세트 수를 값 있는 칸 수로 센다 | 빈 칸이 세트로 세지지 않음 |
| 형식 B 를 읽고 같은 종목 행을 하나로 묶는다 | 세로 배치 |
| 루틴 형식의 `세트` 열을 읽는다 | 명시적 세트 수 |
| `지난 기록` 열이 있어도 무시한다 | 내보내기 전용 열(A7) |
| `- 반복: 월, 목` 을 마스크 18 로 읽는다 | 요일 파싱 |
| 제목 `## 2026-08-31 (월) · 가슴` 에서 요일과 이름을 뽑는다 | 요일 추론 |
| `- 부위:` 가 없으면 카테고리가 비어 미리보기에서 지정 대상이 된다 | 누락 처리 |
| `맨몸 × 15` 를 무게 0 으로 읽는다 | 맨몸 표기 |
| `22.5kg × 5` 소수 무게를 읽는다 | 소수점 |
| 깨진 행 하나가 있어도 나머지는 읽힌다 | **전체 거부 금지** |
| 깨진 행이 `issues` 에 담긴다 | 미리보기 표시용 |
| 표가 아예 없으면 종목 0개 + issue 를 돌려준다 | 빈 입력 |
| 덮어쓰기 시 기존 종목·세트가 교체된다 | `apply(to:)` |

## 완료 기준

1. `swift test` 통과, **왕복 테스트 2개가 반드시 포함**
2. 폰에서 실제 노트 텍스트를 붙여넣어 루틴 생성 성공
3. 깨진 텍스트를 넣어도 앱이 죽지 않고 issue 로 표시
4. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **관대하게 파싱한다.** 사용자가 노트에서 손으로 고친 텍스트가 들어온다.
  공백 개수, 구분자 길이(`---` vs `-----`), 앞뒤 빈 줄, 표 앞뒤의 다른 문단을 전부 허용한다.
- **파싱 실패가 앱을 멈추면 안 된다.** 오타 한 줄 때문에 전부 막히면 이 기능을 안 쓰게 된다.
- **덮어쓰기는 되돌릴 수 없다.** 미리보기에서 무엇이 바뀌는지 명확히 보여준 뒤 적용한다.
- 종목명 정규화는 `ExerciseName.normalize` 를 거쳐야 직전 기록이 이어진다.
