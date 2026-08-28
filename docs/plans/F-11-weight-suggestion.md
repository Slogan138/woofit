# F-11 · 다음 무게 제안

> **M3** · 폰 · [PRD §4 F-11](../PRD.md#f-11--다음-무게-제안-폰-m3) · 결정 근거 [D6](../PRD.md#11-확정-사항)

> ⚠️ **이 계획은 개요 수준이다.** 증량 규칙을 정하려면 본인의 성공·실패 패턴이 먼저 쌓여야 한다.
> 남의 프로그램 기본값을 그대로 박아두면 제안이 신뢰를 잃고 결국 아무도 안 쓴다.
> **착수 시점에 실제 기록을 보고 이 문서를 다시 쓴다.**

## 요구사항

- 직전 기록을 근거로 다음 세션의 목표 무게 제안
- 기본 규칙 — 전 세트 성공이면 증량, 절반 이상 실패면 유지 또는 감량
- 증량 폭은 설정에서 조정. 기본 2.5kg
- **제안은 제안일 뿐이다.** 루틴 편집기에서 한 번에 적용하거나 무시한다. 자동으로 바꾸지 않는다

## 선행 조건

- ✅ `LastRecord` (F-09) — 이미 완료. 판단에 필요한 입력은 갖춰져 있다
- **본인의 성공·실패 패턴 데이터** — 규칙을 정하려면 필요
- F-10 과 함께 진행하면 자연스럽다

## 착수 전 확인할 것

실제 기록을 보고 답한다.

- 전 세트 성공했을 때 실제로 얼마나 올렸나? (2.5kg 고정? 종목마다 다른가?)
- 실패했을 때 유지했나 내렸나? 몇 번 실패하면 내렸나?
- 종목별로 증량 폭이 달라야 하나? (스쿼트와 사이드 레터럴은 다르다)
- 며칠 쉬었다 온 경우를 다르게 취급해야 하나?

## 개략 작업 단위

- [ ] 0. **이 문서를 다시 쓴다** — 실제 증량 패턴을 보고
- [ ] 1. `ProgressionRule` — 직전 기록 → 제안 무게 (WoofitCore, 순수 함수)
- [ ] 2. 증량 폭 설정
- [ ] 3. 테스트
- [ ] 4. 루틴 편집기에 제안 표시 + 일괄 적용

## 파일 (예상)

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Progression/ProgressionRule.swift` | 제안 계산 |
| `WoofitCore/Tests/WoofitCoreTests/ProgressionRuleTests.swift` | 테스트 |
| `Woofit/Features/Routine/SuggestionBanner.swift` | 제안 표시·적용 |

## 설계 메모 (예상)

순수 함수여야 한다. 입력은 `LastRecord` 와 설정, 출력은 제안 무게.

```swift
public struct ProgressionSuggestion: Sendable {
    public let suggestedWeight: Double
    public let reason: String        // "전 세트 성공 · +2.5kg"
}

public enum ProgressionRule {
    public static func suggest(from record: LastRecord, increment: Double) -> ProgressionSuggestion?
}
```

**이유를 함께 돌려준다.** 근거 없는 숫자는 신뢰받지 못한다.

## 테스트 계획 (예상)

- 전 세트 성공이면 증량 폭만큼 오른다
- 절반 이상 실패면 유지된다
- 전부 실패면 감량된다
- 직전 기록이 없으면 제안이 없다
- 건너뛴 세트가 섞이면 어떻게 판단하는지 (착수 시 규칙 확정 필요)

## 주의점

- **자동으로 무게를 바꾸지 않는다.** 제안이 틀렸을 때 사용자가 모르는 채로 루틴이 바뀌면
  이 기능 전체를 못 믿게 된다.
- 컨디션·수면·식사는 앱이 모른다. 제안은 참고값 이상이 될 수 없다.
- 종목별 증량 폭 차이를 처음부터 만들지 않는다. 단일 규칙으로 써보고 불편하면 그때 나눈다.
