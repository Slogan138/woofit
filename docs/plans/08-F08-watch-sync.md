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

- [x] 1. Payload 값 타입 — `RoutinePayload`, `SetResultPayload`, `SessionSnapshotPayload`
- [x] 2. `SyncMerger` — payload → SwiftData 반영. **순수하게 테스트 가능하게**
- [x] 3. `WatchSyncService` — `WCSession` 래퍼
- [x] 4. 폰 → 워치 루틴 전송 (`updateApplicationContext`)
- [x] 5. 워치 → 폰 세트 결과 전송 (`transferUserInfo`)
- [x] 6. 세션 종료 스냅샷 전송
- [x] 7. 워치 보관 정리 — 최근 10건만 유지
- [x] 8. 테스트

`WoofitCore` 쪽 구현·테스트는 끝났다. 화면·앱 통합도 끝났다 — 아래 "화면·앱 통합" 참고.
남은 건 완료 기준 2~4번의 실기기 검증뿐이다.

## 화면·앱 통합

전송·수신 로직(`WatchSyncService`)은 방향에 상관없이 같은 클래스를 양쪽 앱이 그대로 쓴다.
차이는 **어느 화면에서 언제 호출하느냐**뿐이다.

| 앱 | 지점 | 호출 |
| --- | --- | --- |
| 폰 · 워치 | `WoofitApp` / `WoofitWatchApp` 시작 | `WatchSyncService` 생성 + `activate()`, `\.watchSyncService` 환경값으로 주입 |
| 폰 | `RootView` 진입 시 | `pushRoutines(in:)` — 앱을 껐다 켠 사이 바뀐 상태도 맞춘다 |
| 폰 | `RoutineListView` 복제·삭제 | `pushRoutines(in:)` |
| 폰 | `RoutineEditorView` 저장(`완료`/`저장`) | `pushRoutines(in:)` |
| 폰 | `MarkdownImportView` 적용 | `pushRoutines(in:)` |
| 폰 | 세션 종료(`RootView.endSession`) | `pushRoutines(in:)` — 직전 기록이 바뀌므로 다시 내려보낸다(F-9) |
| 워치 | `WatchSetView` 세트 기록마다 (`runner.lastRecordedSet` 변화 감지) | `sendSetResult(_:)` |
| 워치 | `WatchSetView` 세션 종료·중단 | `sendSessionSnapshot(_:)` + `WatchRetention.prune(in:)` |

`WatchSyncService.pushRoutines(in:)` 은 로컬 저장소에서 루틴 전체와 직전 기록을 모아
`RoutinePayload` 를 만들고 바로 전송한다 — 화면은 "언제 다시 보낼지"만 정하면 되고
payload 조립은 몰라도 된다.

### 남은 간극 — 세션 이어받기 (알려진 제한)

요구사항의 "폰에서 시작한 세션을 워치가 이어받고, 반대도 된다"는 **워치 → 폰 방향만**
구현했다. `sendInProgressSession` API 는 만들어뒀지만 어느 화면에서도 호출하지 않는다.

이유: 받는 쪽이 그 payload 를 로컬 진행 중 세션으로 받아들여 **화면을 자동으로 전환**해야
의미가 있는데, 워치 쪽에는 그 역할을 할 코디네이터가 없다(폰의 `SessionCoordinator` +
`RootView.fullScreenCover` 에 대응하는 것이 `WatchRootView` 에는 없다). 이 화면 구조를
새로 만드는 일은 전송 배선과 다른 종류의 작업이라 판단해 이번에는 포함하지 않았다 —
"완료되지 않은 구현을 반쯤 남기지 않는다" 원칙에 따라 API 자리만 마련해두고 화면 작업은
별도로 진행한다.

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

**`activate()` 완료를 기다리지 않고 보낸 첫 `pushRoutines` 는 유실될 수 있다.**
`WCSession.activate()` 는 비동기라, 앱 시작 직후 호출한 `pushRoutines` 가 활성화보다
먼저 실행되면 조용히 실패한다. `activationDidCompleteWith` 에서 `activationState == .activated`
이면(iOS 쪽만, 루틴은 폰 → 워치 방향이라) 최신 루틴을 한 번 더 내려보내 재시도한다.
전송 결과는 `lastSendError` 에 남고 실패는 `os.Logger`(`WatchSync` 카테고리)로도 남아,
실기기에서 `try?` 로 버려지는 오류를 진단할 수 있다.

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

---

## 후속 · 세션 이어받기가 절반만 구현돼 있었다 (2026-09-02)

실사용에서 발견. **폰에서 시작한 세션이 워치에 안 뜨고, 그 반대도 같다.**

### 무엇이 빠져 있었나

`sendInProgressSession(_:)` 은 처음부터 있었다. 그런데

- **부르는 곳이 없었다.** 폰도 워치도 세션을 시작할 때 이 함수를 호출하지 않았다
- **받는 쪽도 꺼내지 않았다.** delegate 가 `routines` 키만 읽고 `inProgressSession` 은
  버렸다. 주석은 "이어받기 화면이 직접 디코드해 쓴다" 고 말했지만 그런 화면이 없었다

상태표에 `🟡 세션 이어받기 대기` 로 적혀 있던 그 항목이다. **테스트가 없어서 조용했다** —
빌드도 통과하고 화면도 멀쩡해 보이는데 기능만 없는 상태였다.

### 자동 반영으로 정했다

두 기기에서 동시에 시작하는 일은 없다는 사용자 판단에 따라, 받으면 **바로 반영한다.**
이어받기 버튼을 거치지 않는다.

**다만 남아 있던 다른 진행 중 세션은 지우지 않고 중단으로 돌린다.** 전제가 어긋났을 때
기록이 조용히 사라지는 것이 이 앱에서 가장 나쁜 결과다. 중단으로 남겨두면 기록 목록에서
확인하고 지울 수 있다(F-12).

### 고친 것

| | |
| --- | --- |
| `SyncMerger.mergeInProgress` | 반영 + 다른 진행 중 세션 중단 |
| `WatchSyncService` | 수신에서 두 키를 **독립적으로** 처리. 워치가 보내는 컨텍스트에는 루틴이 없어 먼저 빠져나오면 세션을 놓친다 |
| `SessionCoordinator.start` | 폰에서 시작할 때 전송 |
| `RootView.endSession` | 폰에서 끝낼 때 최종 상태 전송 |
| `WatchRoutinePreviewView.start` | 워치에서 시작할 때 전송 |
| `WatchSetView.finishSession` | 워치에서 끝낼 때 이어받기 채널도 갱신 |

### 남은 검증

전송 자체는 실기기에서만 확인된다. 병합 규칙은 `SessionHandoffTests` 로 고정했다.

1. 폰에서 시작 → 워치를 보면 그 세션이 떠 있을 것
2. 워치에서 시작 → 폰을 보면 그 세션이 떠 있을 것
3. 한쪽에서 끝내면 다른 쪽도 진행 중으로 남지 않을 것

### 그래도 안 됐다 — `receivedApplicationContext` 를 안 읽고 있었다

위 수정을 넣고 실기기에 올렸는데 여전히 릴레이가 안 됐다. 기록은 남는데 세션만 안 넘어왔다.

**`didReceiveApplicationContext` 는 받는 앱이 실행 중일 때만 호출된다.** 폰에서 세션을
시작할 때 워치 앱은 대개 꺼져 있다. 그동안 도착한 컨텍스트는 `receivedApplicationContext`
에 담겨 있는데, 이 앱은 **그것을 어디에서도 읽지 않았다.**

세트 결과가 멀쩡히 도착한 것이 오히려 진단을 늦췄다. 그쪽은 `transferUserInfo` 라
큐잉이 보장되고 앱이 꺼져 있어도 나중에 전달된다. **두 채널의 성질이 다르다는 것이
이 버그의 핵심이다.**

| 채널 | 앱이 꺼져 있을 때 |
| --- | --- |
| `transferUserInfo` (세트 결과) | 큐에 쌓였다가 전달된다 |
| `updateApplicationContext` (루틴·세션) | **직접 읽어야 한다** |

**고친 것** — `consumeReceivedContext()` 를 만들어 두 시점에 부른다.

- 활성화 직후(`activationDidComplete`)
- 앱이 앞으로 나올 때(`scenePhase == .active`) — 백그라운드에 있는 동안 온 것도 잡는다

여러 번 불러도 안전하다. 루틴은 전체 교체이고 세션 병합은 같은 `sessionID` 를 갱신할 뿐이다.

### 데이터만 넘어가고 화면은 안 열렸다

수신을 고쳤더니 세션이 저장소에는 들어왔는데 **워치 화면은 그대로였다.**
워치 홈은 루틴만 보고 있었고, 진행 중 세션을 열어주는 경로가 아예 없었다 —
계획 17 에 "현재 워치 앱에는 복원 경로 자체가 없다" 고 적어둔 그것이다.

**세션 소유를 루트로 옮겼다.** `WatchSessionCoordinator` 를 만들어 폰의
`SessionCoordinator` 와 같은 구조로 뒀다. 루틴 미리보기가 세션을 들고 있으면
폰에서 넘어온 세션을 열어줄 자리가 없다.

### 반대 방향도 자동으로 되지 않았다

폰은 앱 시작 시 `restoreIfNeeded` 를 부르지만, **이미 앱이 떠 있는 동안 워치 세션이
도착하면 다시 확인하지 않는다.** 앱을 새로 켜도 복원이 컨텍스트 수신보다 먼저 돌면
놓친다.

양쪽 루트가 세 시점에 다시 확인한다.

| 시점 | 잡는 경우 |
| --- | --- |
| `.task` (앱 시작) | 꺼져 있는 동안 도착한 것 |
| `scenePhase == .active` | 백그라운드에 있는 동안 도착한 것 |
| `latestInProgressSession` 변화 | **앱이 떠 있는 동안** 도착한 것 |

세 번째는 처음에 콜백으로 만들었다가 `@Observable` 로 바꿨다. "`WCSessionDelegate`
때문에 `NSObject` 를 상속해야 해서 관찰 매크로를 못 쓴다"고 판단했는데 **확인해보니
그냥 된다.** 콜백은 대입 슬롯이 하나뿐이라 두 곳에서 설정하면 조용히 덮어쓰는 문제도
있었다. 상태 관찰은 `@Observable` 이 표준이다(원칙 1).

### 남겨두는 것

**이어받은 세션은 워치에서 운동 세션(F-14)을 시작하지 않는다.** 며칠 전 중단된 세션이
복원될 수도 있어 유령 운동을 만들지 않으려는 규칙이다(계획 17). 다만 폰에서 시작하고
워치로 이어받아 계속 운동하는 흐름에서는 워치 앱이 휴식 중에 정지한다. **실기기에서
그 불편이 실제로 드러나면 "방금 시작된 세션만 운동 세션도 시작" 규칙을 검토한다.**

**한쪽에서 끝내도 다른 쪽의 열린 화면은 자동으로 닫히지 않는다.** 상태는 따라오지만
화면은 사용자가 완료·중단을 눌러야 닫힌다. 우선 이대로 두고 실사용에서 판단한다.

### 세션은 넘어가는데 기록이 안 넘어갔다

세션 이어받기가 동작한 뒤 남은 증상. 원인이 둘이었다.

**① 폰에는 세트를 보내는 경로가 아예 없었다.** 워치는 세트마다 `sendSetResult` 를
보내지만 폰 세션 화면(`SessionRunnerView`)에는 전송 코드가 한 줄도 없었다. 폰은
시작과 종료 두 시점에만 보내고 있었다. 양쪽 모두 세트를 기록할 때마다 진행 상태를
보내도록 했다 — `updateApplicationContext` 는 최신 것만 도착하면 되는 채널이라
매 세트가 부담이 아니다.

워치도 `sendSetResult` 와 함께 진행 상태를 보낸다. 세트 하나만 보내면 상대가 그
세션을 아직 모를 때 붙일 곳이 없다.

**② 병합을 화면과 다른 컨텍스트에 하고 있었다.** 수신 처리가 `ModelContext(container)`
를 새로 만들어 저장했다. 그러면 열려 있는 세션 화면이 **이미 들고 있는 객체**가 즉시
갱신되지 않아, 도착한 세트가 화면에 안 나타난다. `WatchSyncService` 는 `@MainActor`
라 `mainContext` 를 그대로 써도 안전하다.

②는 세션 이어받기가 동작하는 것만으로는 드러나지 않았다 — 그때는 화면을 새로 열어
저장소를 처음 읽는 경로라 최신 값이 보였기 때문이다.

### 같은 종목은 되는데 종목 전환이 안 넘어갔다

데이터는 다 넘어가는데 **상대가 다음 종목으로 넘어가면 이쪽은 이전 종목에 머물렀다.**

`SessionRunner.refreshPhase` 는 로컬 조작(기록·되돌리기·이동)에서만 불린다. 세트 결과가
병합돼도 러너의 `phase` 와 `focusedSet` 은 그대로라, 같은 종목 안에서는 세트 표시가
바뀌는데 종목 경계를 넘지 못한다.

`refreshFromRemoteChange()` 를 열어 양쪽 루트가 수신 시 부른다. 로컬 조작과 달리
"방금 어느 세트를 눌렀는지"가 없으므로 **남은 첫 세트를 초점으로 삼는다.** 상대가 이미
넘어갔으니 전환 화면을 거치지 않고 바로 그 종목을 기록 중으로 둔다.

**이번 건은 Core 로직이라 테스트로 고정했다**(`RemoteChangeTests`). 앞의 동기화
문제들이 화면·플랫폼 경계라 테스트가 닿지 않았던 것과 다르다.

### 세션 종료가 릴레이되지 않았다 — 중단이 되살아나고 있었다

원인이 둘이었다.

**① 도착한 중단·완료를 러너가 되돌렸다.** `refreshPhase` 는 남은 세트가 있으면
`session.reopen()` 을 부른다. 로컬에서 마지막 세트를 되돌린 경우를 위한 경로인데,
**상대가 세트를 남긴 채 중단한 상태가 도착했을 때도 그 경로를 탔다.**

```
폰에서 중단 → 워치가 abandoned 로 병합 → 남은 세트가 있으니 reopen()
          → 다시 inProgress → 그 상태를 폰으로 되돌려 보냄 → 중단이 풀린다
```

`refreshFromRemoteChange` 가 세션 상태를 먼저 보고, 진행 중이 아니면 그대로
`.finished` 로 둔다. **로컬 되돌리기 경로는 건드리지 않았다** — 그건 계속 `reopen`
되어야 한다(F-3). 세 테스트로 두 경로를 갈라 고정했다.

**② 끝나도 상대 화면이 열린 채 남았다.** 상태는 따라오는데 화면이 안 닫혀
"릴레이가 안 되는" 것처럼 보였다. 원격 변경으로 세션이 진행 중이 아니게 되면 이쪽
화면을 닫는다. 요약은 **끝낸 기기가** 보여준다 — 양쪽에서 같은 완료 화면을 띄울
이유가 없다.
