# F-08 · 폰 ↔ 워치 동기화

> **M2** · 기반 · [PRD §4 F-8](../PRD.md#f-8--폰--워치-동기화-기반-m2) · 전송 규칙 [§8](../PRD.md#8-동기화-규칙)

## 요구사항

- 루틴은 폰 → 워치. **최신 상태만** 있으면 된다
- 세션 결과는 워치 → 폰. **한 건도 잃으면 안 된다.** 그날 운동이 통째로 사라지기 때문
- 폰이 꺼져 있거나 멀어도 **워치 단독으로 세션 완주**. 연결 회복 시 자동 전송
- 폰에서 시작한 세션을 워치가 이어받고, 반대도 된다
- 루틴을 내릴 때 **직전 기록을 함께 실어 보낸다**(F-09)
- 병합은 **세션 id + 세트 id** 기준, `recordedAt` 이 나중인 쪽이 이긴다
- 전송은 **멱등**. 같은 payload 가 두 번 와도 결과가 같다

## 선행 조건

- F-03 (세션 실행) 폰·워치 양쪽
- F-09 (직전 기록 조회) — payload 에 포함

## 작업 단위

- [ ] 1. Payload 값 타입 — `RoutinePayload`, `SetResultPayload`, `SessionSnapshotPayload`
- [ ] 2. `SyncMerger` — payload → SwiftData 반영. **순수하게 테스트 가능하게**
- [ ] 3. `WatchSyncService` — `WCSession` 래퍼
- [ ] 4. 폰 → 워치 루틴 전송 (`updateApplicationContext`)
- [ ] 5. 워치 → 폰 세트 결과 전송 (`transferUserInfo`)
- [ ] 6. 세션 종료 스냅샷 전송
- [ ] 7. 워치 보관 정리 — 최근 10건만 유지
- [ ] 8. 테스트

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/Sources/WoofitCore/Sync/SyncPayload.swift` | `Codable` 값 타입 |
| `WoofitCore/Sources/WoofitCore/Sync/SyncMerger.swift` | 병합 로직 (순수) |
| `WoofitCore/Sources/WoofitCore/Sync/WatchSyncService.swift` | `WCSession` 래퍼 |
| `WoofitCore/Sources/WoofitCore/Sync/WatchRetention.swift` | 워치 세션 정리 |
| `WoofitCore/Tests/WoofitCoreTests/SyncMergerTests.swift` | 테스트 |

## 설계 메모

**전송과 병합을 분리한다.** `WCSession` 은 테스트하기 어렵지만, 병합 로직은 순수 함수로
만들 수 있다. `SyncMerger` 가 payload 와 `ModelContext` 만 받으면
`WCSession` 없이 병합을 전부 테스트할 수 있다.

```swift
public enum SyncMerger {
    /// 멱등. 같은 payload 를 두 번 넣어도 결과가 같다.
    public static func merge(_ payload: SetResultPayload, into context: ModelContext) throws
    public static func merge(_ payload: SessionSnapshotPayload, into context: ModelContext) throws
    public static func replaceRoutines(with payload: [RoutinePayload], in context: ModelContext) throws
}
```

**전송 방식을 방향별로 나눈다**(PRD §8)

| 데이터 | 방향 | 방식 | 이유 |
| --- | --- | --- | --- |
| 루틴 + 직전 기록 | 폰 → 워치 | `updateApplicationContext` | 덮어쓰기. 마지막 것만 도착하면 충분 |
| 세트 결과 | 워치 → 폰 | `transferUserInfo` | 큐잉 보장 전달 |
| 세션 종료 스냅샷 | 워치 → 폰 | `transferUserInfo` | 세트별 전송이 새면 여기서 복구 |
| 진행 중 세션 | 폰 → 워치 | `updateApplicationContext` | 워치가 이어받기 |

**세션 종료 스냅샷이 최종 보루다.** 세트별 전송이 하나라도 유실되면 여기서 복구된다.
따라서 종료 스냅샷 병합은 세트별 병합과 **같은 결과**를 내야 한다.

## 테스트 계획

| 테스트 | 검증하는 것 |
| --- | --- |
| 같은 세트 payload 를 두 번 병합해도 결과가 같다 | **멱등성** |
| `recordedAt` 이 나중인 payload 가 이긴다 | 충돌 해결 |
| `recordedAt` 이 이전인 payload 는 무시된다 | 역순 도착 |
| 없는 세션의 세트 payload 가 오면 세션을 만든다 | 순서 뒤바뀜 |
| 종료 스냅샷 병합 결과가 세트별 병합 결과와 같다 | **복구 경로 일치** |
| 루틴 전송은 전체를 교체한다 | 덮어쓰기 |
| 루틴 payload 에 직전 기록이 포함된다 | F-09 |
| 워치 보관 정리가 최근 10건과 진행 중 세션을 남긴다 | 보관 정책 |
| 진행 중 세션은 10건 밖이어도 지워지지 않는다 | **데이터 유실 방지** |

## 완료 기준

1. `swift test` 통과, **멱등성 테스트 반드시 포함**
2. 실제 기기 2대에서 루틴이 워치로 내려간다
3. 워치에서 세션을 완주하고 폰에 결과가 도착한다
4. **폰을 비행기 모드로 두고 워치에서 완주 → 연결 복구 후 결과 도착**
5. [CLAUDE.md 완료 기준](../../CLAUDE.md#완료-기준) 충족

## 주의점

- **`sendMessage` 를 쓰지 않는다.** 상대가 도달 가능해야만 동작해서 헬스장에서 유실된다.
- **세트 기록 흐름에서 전송을 기다리지 않는다.** F-03 의 100ms 수용 기준을 깬다.
  기록은 로컬에 즉시 쓰고, 전송은 뒤에서 큐에 넣는다.
- **워치 정리에서 진행 중 세션을 지우면 안 된다.** 운동 도중 기록이 통째로 날아간다.
- `applicationContext` 는 크기 제한이 있다. 루틴이 많아지면 payload 를 줄이거나
  `transferUserInfo` 로 옮겨야 한다. 실제 크기를 측정해보고 판단한다.
- 시뮬레이터 페어링으로도 어느 정도 검증되지만, **실기기 확인이 필요하다.**
