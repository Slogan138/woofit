# F-06 · 마크다운 내보내기

> **M1** · 폰 · [PRD §4 F-6](../PRD.md#f-6--마크다운-내보내기-폰-m1) · 형식 명세 [§6](../PRD.md#6-마크다운-형식)

## 요구사항

- 세션 완료 화면과 지난 세션 상세에서 **마크다운 복사**
- 복사 전 미리보기
- **루틴도 내보낼 수 있고, 이때 `지난 기록` 열이 포함된다**(F-9 의 주 전달 경로)
- 형식 A(세트 가로, 기본) / 형식 B(세트 세로) / 루틴 형식
- 워치에는 두지 않는다

**수용 기준** — 붙여넣은 결과가 손대지 않고 그대로 노트에 들어간다.

## 선행 조건

- ✅ `WorkoutSession` · `Routine` 모델
- ✅ `LastRecord` · `LastRecordLookup`
- ✅ `WeightFormatter`

없음. 바로 시작 가능하다.

## 작업 단위

- [ ] 1. `MarkdownStyle` — 형식 A/B 선택, 이모지/텍스트 표기 전환
- [ ] 2. `MarkdownTable` — 파이프 표 조립 유틸. 셀 이스케이프를 여기서 한 곳으로 모은다
- [ ] 3. `SessionMarkdownExporter` — 형식 A
- [ ] 4. 형식 B
- [ ] 5. `RoutineMarkdownExporter` — 루틴 형식 + `지난 기록` 열
- [ ] 6. 테스트
- [ ] 7. 폰 UI — 미리보기 + `UIPasteboard` 복사

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Markdown/MarkdownStyle.swift` | 형식·기호 옵션 |
| `WoofitCore/Sources/WoofitCore/Markdown/MarkdownTable.swift` | 파이프 표 조립, 셀 이스케이프 |
| `WoofitCore/Sources/WoofitCore/Markdown/SessionMarkdownExporter.swift` | 세션 → 마크다운 |
| `WoofitCore/Sources/WoofitCore/Markdown/RoutineMarkdownExporter.swift` | 루틴 → 마크다운 |
| `WoofitCore/Tests/WoofitCoreTests/MarkdownExportTests.swift` | 테스트 |
| `Woofit/Features/Export/MarkdownPreviewView.swift` | 미리보기 + 복사 (P5) |

## 설계 메모

**순수 함수로 만든다.** 입력은 모델, 출력은 `String`. `ModelContext` 를 받지 않는다.
`지난 기록` 은 호출하는 쪽에서 `LastRecordLookup.fetchAll` 로 조회해 넘긴다.
그래야 화면 없이 테스트가 완결된다.

```swift
public enum SessionMarkdownExporter {
    public static func export(_ session: WorkoutSession, style: MarkdownStyle = .default) -> String
}

public enum RoutineMarkdownExporter {
    public static func export(_ routine: Routine,
                              lastRecords: [String: LastRecord] = [:],
                              style: MarkdownStyle = .default) -> String
}
```

**형식 A 의 열 개수**는 그 세션에서 가장 세트가 많은 종목에 맞춘다. 모자란 칸은 빈 문자열.

**`목표` 열**은 `SessionExercise.uniformTarget` 이 있으면 `80kg × 5`,
피라미드 세트라 `nil` 이면 범위 표기(`70~80kg × 5`)로 대체한다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 형식 A 전체 출력이 PRD §6.1 예시와 일치한다 | 헤더·구분자·셀 배치 |
| 형식 B 전체 출력이 PRD §6.2 예시와 일치한다 | 세로 배치 |
| 루틴 형식이 PRD §6.3 예시와 일치한다 | `세트` 열 + `지난 기록` 열 |
| 세트 수가 다른 종목이 섞이면 빈 칸으로 채운다 | 열 개수 = 최대 세트 수 |
| 중단된 세션의 `pending` 세트는 빈 칸이다 | 미수행 표기 |
| 실패 세트는 `❌ 3`, 무게를 바꿨으면 `❌ 70kg 3` | 실패 표기 |
| 종목명에 `\|` 가 있으면 이스케이프된다 | **표가 깨지지 않음** |
| 이모지 대신 텍스트 표기 옵션이 동작한다 | `MarkdownStyle` |
| 직전 기록이 없는 종목은 `지난 기록` 이 빈 칸이다 | 첫 수행 |
| 휴식을 측정하지 않은 종목은 휴식 칸이 빈 칸이다 | 옵셔널 처리 |

## 완료 기준

1. `swift test` 통과, 위 테스트 전부 존재
2. PRD §6.1~6.3 예시와 **문자 단위로 일치**하는 출력
3. 폰에서 미리보기 → 복사 → 노트 붙여넣기가 편집 없이 동작
4. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **파이프 이스케이프.** 종목명은 자유 입력이라 `|` 가 들어올 수 있다. 들어오면 표 전체가
  깨지는데 붙여넣기 전까지 모른다. `MarkdownTable` 한 곳에서 처리하고 테스트로 고정한다.
- **줄바꿈.** 종목명·메모에 개행이 들어가면 표가 깨진다. 공백으로 치환한다.
- 형식 A/B 예시는 PRD 에 있으므로 **문서를 정답으로 두고 테스트를 쓴다.**
  출력이 다르면 어느 쪽이 맞는지 먼저 판단한다. 문서가 틀렸으면 문서를 고친다.
