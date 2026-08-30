# iOS 개발 표준 준수 현황

[CLAUDE.md](../CLAUDE.md) 가 정한 개발 표준을 이 저장소가 실제로 지키고 있는지 코드·테스트·커밋
기록을 근거로 점검한 문서다. 조사 시점: 2026-08-30, `feature/f14-workout-session`
브랜치(HEAD `9c33897`), `WoofitCore` 테스트 150개 전부 통과.

**결론: CLAUDE.md 의 다섯 원칙 모두 실제로 지켜지고 있다.** 코드 위반 사례는 발견되지
않았고, 유일한 흠은 이미 `main` 에 머지된 `feature/15-session-runner-redesign` 브랜치가
정리 절차(`git branch -d`)를 거치지 않고 로컬에 남아있는 것뿐이다(§5).

---

## 1. 원칙 1 — 표준을 따른다

| 영역 | 판정 | 근거 |
| --- | --- | --- |
| UI | ✅ | `import SwiftUI` 35개 파일. UIKit 은 `UIPasteboard.general`(클립보드, SwiftUI 대응 API 없음) 용도로 3곳만 사용: `Woofit/Features/Export/MarkdownPreviewView.swift`, `Features/Import/MarkdownImportView.swift`, `Features/Migration/LogMigrationView.swift`. 자체 뷰 프레임워크 없음 |
| 저장 | ✅ | `@Model`/`ModelContainer`/`@Query` 34개 파일. 자체 ORM·직렬화 계층 없음 |
| 상태 | ✅ | `@Observable` 2곳(`Woofit/Features/Session/SessionCoordinator.swift:7`, `WoofitCore/Sources/WoofitCore/Session/SessionRunner.swift:32`), `@State` 40회, `@Query` 4곳. `Store`/`Redux`/`Reducer` 클래스 없음 — `SessionCoordinator` 는 action/dispatch 없이 `@Observable` 프로퍼티를 메서드가 직접 바꾸는 표준 패턴 |
| 비동기 | ✅ | `import Combine` 0건, `DispatchQueue` 0건, completion-handler 콜백 0건. `Task { }` + `@MainActor` 로 구조화 동시성 사용(`WoofitCore/Sources/WoofitCore/Sync/WatchSyncService.swift`) — `WCSessionDelegate` 의 `nonisolated` 콜백을 `Task { @MainActor in }` 로 브리지하는 표준 방식 |
| 테스트 | ✅ | `import XCTest` 0건. `@Test(` 150건, 전부 `WoofitCore/Tests/WoofitCoreTests/` 11개 파일 |
| 의존성 | ✅ | `WoofitCore/Package.swift` 에 외부 패키지 없음, `Package.resolved` 자체가 없음(해석할 외부 의존성이 없다는 뜻). `Podfile`/`Cartfile` 없음 |
| 프로젝트 | ✅ | `Woofit.xcodeproj/project.pbxproj` 에 `PBXFileSystemSynchronizedRootGroup` 4건 — buildable folder 구조. `.swift in Sources` 수동 목록 0건. `project.yml`(XcodeGen)·`Project.swift`(Tuist) 없음 |
| 폰↔워치 | ✅ | `WatchSyncService.swift` 가 `import WatchConnectivity`, `WCSession`/`WCSessionDelegate` 표준 API만 사용(`updateApplicationContext`, `transferUserInfo` 등). `URLSession`/소켓 기반 자체 프로토콜 없음 |
| 마크다운 | ✅ | `Markdown/MarkdownTable.swift`(렌더)·`MarkdownTableParser.swift`(파싱) 가 헤더행 + `---` 구분자 + 본문행의 GFM 파이프 표 구조를 그대로 구현. `\|` 이스케이프·복원도 GFM 규칙대로 |
| 오류 | ✅ | `throws` + `Error` 다수. `SessionDeletion.swift:6` `SessionInProgressError: Error` 는 표준 `Error` 를 따르는 구체 타입일 뿐 자체 오류 래퍼가 아님. `Result<>` 사용처 없음(throws 로 충분한 경우만 존재) |
| 네이밍 | ✅ | `SessionRunner.recordSuccess(for:at:)`, `recordFailure(...)`, `skip(_:at:)`, `toggleRest(at:)` 등 동사 기반 메서드명과 인자 라벨이 Swift API 관례를 따름 |

**서드파티 의존성**: `WoofitCore/Package.swift`, `Woofit.xcodeproj` 전체에 외부 의존성 없음.

**추상화 미리 만들지 않기**: 코드베이스 전체에서 protocol 은 두 곳뿐이며 둘 다 `private`
이고 실제로 두 번째 사용처가 생겼을 때만 뽑아낸 것으로 확인됨 — `SyncMerger.swift:154`
`SessionSeedProviding`(`SetResultPayload`/`SessionSnapshotPayload` 두 타입이 conform),
`LastRecordLookup.swift:98` `NormalizedNamedExercise`(`PlannedExercise`/`SessionExercise`
두 타입이 conform). "구현체 하나뿐인 프로토콜"에 해당하는 사례는 없다.

**표준 예외 기록 표의 정확성**: `resultRaw`/`stateRaw`(`WorkoutSession.swift:17`,
`SessionSet.swift:11`)와 `weekdayMask`(`Routine.swift:15`) 모두 표에 적힌 그대로 구현돼
있고, 코드베이스를 통틀어 이 두 항목 외에 표에 없는 표준 이탈 사례는 발견되지 않았다 —
표는 정확하고 빠진 항목이 없다.

---

## 2. 원칙 2 — 주석은 핵심만 컴팩트하게

| 점검 항목 | 판정 | 근거 |
| --- | --- | --- |
| PRD/F-번호 식별자 인용 | ✅ | `F-[0-9]` 패턴 인용 111건(Core 64 + 앱 타겟 47), `PRD` 인용 43건(Core 30 + 앱 타겟 13). 예: `WorkoutSession.swift:135` `"진행 중인 세션은 지울 수 없다 — 먼저 abandon() 으로 중단해야 한다(F-12, D7)."` |
| 왜(why) 중심 | ✅ | `ExerciseName.swift` 가 대표적 — "공백을 제거한다"(무엇)가 아니라 "표기 차이가 F-9 를 조용히 망가뜨린다"(왜)를 설명 |
| 한 줄 우선 | ✅ | 대부분 한 줄. 문단 주석은 판단 근거가 필요한 곳(`RoutineOrdering.swift` 정렬 안정성 설명 등)에만 등장 |
| 한국어 주석 / 영어 식별자 | ✅ | 영어 문장형 주석 검색 결과 없음(프레임워크 고유명사 제외). 변수·함수명은 전부 영어 |
| 죽은 코드 주석 없음 | ✅ | `// let/var/func/if/for/return/guard/import/class/struct` 패턴 전체 검색 결과 0건 |
| 공개 API doc comment | ✅ | 대부분의 `public` 타입·함수에 `///` 짧은 설명 존재 |

---

## 3. 원칙 3 — 기능 검증 테스트는 반드시 작성한다

- **위치**: 테스트는 `WoofitCore/Tests/WoofitCoreTests/` 한 곳에만 존재(11개 파일, 150개
  `@Test`). 앱 타겟(`Woofit`, `WoofitWatch Watch App`)에는 테스트 디렉터리 자체가 없다 —
  도메인 로직이 Core 에 몰려 있다는 뜻과 일치.
- **프레임워크**: `import XCTest` 0건. `#expect` 314회, `#require` 29회, 전부 Swift Testing.
- **실행 결과**: `cd WoofitCore && swift test` → `Test run with 150 tests in 0 suites passed
  after 0.164 seconds.` 실패 0건.
- **테스트 이름**: 거의 전부 한국어 동작 서술 문장. 예 — `"실패는 실제 횟수 없이 기록될 수
  없다"`, `"세션은 루틴을 복사하므로 이후 루틴 수정에 영향받지 않는다"`, `"직전 기록이 없는
  종목은 지난 기록 칸이 빈 칸이다"`.
- **불변식 테스트**: `markFailure(actualReps:)` 가 필수 인자로 설계되어 있고
  (`SessionSet.swift:69`), `ModelTests.swift` 의 `"실패는 실제 횟수 없이 기록될 수 없다"` 와
  `SyncMergerTests.swift` 의 병합 시 `actualReps` 보존 테스트로 이중 검증됨.
- **경계 조건 테스트**: 빈 루틴/빈 세션(`"세트가 0개인 종목은 완료로 간주된다"`,
  `"빈 세션은 진행률이 전부 0이다"`), 첫 수행(`"처음 하는 종목이면 직전 기록이 없다"`),
  중단된 세션(`"남은 세트가 있는 채로 끝내면 중단으로 기록된다"`, `"중단된 세션도 삭제할 수
  있다"`) 모두 실제 테스트로 존재.
- **화면 전용 로직 없음**: `RoutineListView.swift`, `SessionRunnerView.swift` 등은
  `WeightFormatter`, `RoutineMarkdownImporter.parse`, `LegacyLogParser.parse` 등 Core 의
  순수 함수를 호출하는 얇은 글루 코드 수준이며, 시뮬레이터 없이는 검증 불가능한 계산·파싱
  로직은 발견되지 않았다.

---

## 4. 핵심 설계 규칙 (PRD §7)

| 규칙 | 판정 | 근거 |
| --- | --- | --- |
| 계획/실행 분리 — `WorkoutSession.start(from:)` 이 루틴을 복사 | ✅ | `WorkoutSession.swift:47-75` — `routine.sortedExercises`/`sortedSets` 를 순회해 `SessionExercise`/`SessionSet` 을 새로 생성, 원본 `PlannedExercise`/`PlannedSet` 참조를 저장하지 않음. `ModelTests.swift` 의 `"세션은 루틴을 복사하므로 이후 루틴 수정에 영향받지 않는다"` 로 검증 |
| 실패는 `actualReps` 없이 기록 불가 | ✅ | `SessionSet.swift:69` `markFailure(actualReps reps: Int, actualWeight weight: Double? = nil, at date: Date = Date())` — `actualReps` 만 기본값 없는 필수 인자. 호출부 13곳 전부 명시적으로 전달 |
| enum → String raw + 계산 프로퍼티 | ✅ | `stateRaw`(`WorkoutSession.swift`), `resultRaw`(`SessionSet.swift`) 두 곳뿐이며 표준 예외 기록 표와 정확히 일치. fallback(`?? .inProgress`, `?? .pending`) 도 있음 |
| CloudKit 제약(기본값/옵셔널, `.unique` 금지) | ✅ | `Routine`/`PlannedExercise`/`PlannedSet`/`WorkoutSession`/`SessionExercise`/`SessionSet` 6개 `@Model` 전수 확인 — 저장 프로퍼티 전부 기본값 또는 옵셔널, 관계 전부 옵셔널. `@Attribute` 자체가 코드베이스에 없음(`.unique` 미사용) |
| `WoofitModelContainer.makeContainer(cloudKitContainerID:)` + `schema` 등록 | ✅ | `WoofitModelContainer.swift:26-37` 존재, `nil` → 로컬 / 값 있음 → `cloudKitDatabase: .private(...)`. `schema` 배열에 6개 모델 전부 등록, 누락 없음 |
| `sorted*` 로만 관계 배열 읽기 | ✅ | `Routine.sortedExercises`, `PlannedExercise.sortedSets`, `WorkoutSession.sortedExercises`, `SessionExercise.sortedSets` 존재. `.exercises`/`.sets` 직접 참조는 전부 `ParsedRoutine`/`RoutinePayload` 같은 순수 struct(SwiftData 모델 아님) 이거나 SwiftData 모델에 대한 **쓰기**(관계 교체)뿐 — 읽기는 전부 `sorted*` 경유 |
| `ExerciseName.normalize` 공백 제거 + `rename(to:)` | ✅ | `ExerciseName.swift:11-16` — `CharacterSet.whitespacesAndNewlines` 제거(축약 아님) 후 소문자화. `PlannedExercise.rename(to:)`(`PlannedExercise.swift:35-39`) 가 `name`/`normalizedName` 을 함께 갱신하는 유일한 경로 |
| `weekdayMask` Int 비트마스크 | ✅ | `Routine.swift:15` `var weekdayMask: Int = 0`. `Weekday.swift` 의 `bit`/`from(mask:)`/`mask(of:)` 로 비트 연산 왕복 |

---

## 5. 작업 방식

- **브랜치 네이밍**: `feature/f01~f14-*`, `fix/*` 가 병합 커밋 로그 전반에서 일관되게
  사용됨(`Merge branch 'feature/f13-log-migration'`, `Merge branch 'fix/session-complete-tokens'`
  등). `chore/signing-xcconfig` 하나는 CLAUDE.md 에 정의되지 않은 카테고리지만, 서명 설정처럼
  기능/버그 어디에도 속하지 않는 작업에 대한 합리적인 확장으로 보인다.
- **⚠️ 정리 누락 1건**: `feature/15-session-runner-redesign` 브랜치가 이미 `main` 에
  머지됐음에도(`git merge-base --is-ancestor` 확인, 머지 커밋 `85241bd`) 로컬에 여전히
  남아있다. CLAUDE.md 의 "머지 뒤 `git branch -d` 로 지운다" 절차가 누락됐다. 사소하지만
  다음에 `main` 을 다룰 때 `git branch -d feature/15-session-runner-redesign` 로 정리할 것.
- **계획 문서**: `docs/plans/` 에 17개 계획 문서 + `README.md` 인덱스가 `NN-F##-슬러그.md`
  형식으로 정리돼 있고, `docs/PRD.md`·`docs/TECH_SPEC.md` 모두 존재.
- **완료 기준 이행 흔적**: `docs/PRD.md` 히스토리에서 F-12(D7)·F-13(D8)·F-14(D9) 각각의
  커밋이 요구사항·수용 기준·결정 근거를 함께 추가한 것을 확인(예: F-14 커밋 `7a0de8b` 가
  PRD 에 31줄을 추가하며 D9 결정 근거를 남김). `docs/plans/README.md` 의 진행 상태 표시도
  낙관적으로 부풀리지 않고 정직하게 관리되고 있다(F-14 는 코드 없이 문서만 추가된 상태라
  `⬜`, F-08/F-05/F-12 등 실기기 검증이 남은 항목은 `🟡`).
- **커밋 메시지**: 전부 한국어, "무엇"이 아니라 "왜"를 설명하는 문체로 CLAUDE.md 의 주석
  원칙과 같은 톤을 유지하고 있다.

---

## 종합

11개 표준 항목, 8개 핵심 설계 규칙, 주석 원칙, 테스트 원칙 — 조사한 전 영역에서 코드 수준의
위반 사례는 발견되지 않았다. 표준 예외 기록 표(`resultRaw`/`stateRaw`, `weekdayMask`)도
정확하고 누락이 없다. 유일하게 걸리는 것은 이미 머지된 브랜치 하나가 정리되지 않은 것으로,
기능 완료 기준과는 무관한 저장소 위생 문제다.
