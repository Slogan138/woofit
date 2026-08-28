# CLAUDE.md

Woofit 개발 가이드. 작업 시작 전에 이 문서와 [docs/PRD.md](docs/PRD.md)를 읽는다.

## 프로젝트

미리 짜둔 근력 루틴을 헬스장에서 실행하고, 세트마다 성공·실패와 휴식 시간을 남긴 뒤,
마크다운 표로 뽑아 노트에 붙이는 개인용 iOS · watchOS 앱.
그 마크다운을 다시 붙여넣으면 다음 루틴이 된다.

**기록의 보관소가 아니라 캡처 도구다.** 아카이브는 사용자의 마크다운 노트가 맡는다.
이 전제가 "왜 통계·검색·캘린더를 안 만드는가"의 답이며, 범위를 넓히고 싶을 때 먼저 확인할 기준이다.

사용자는 1인. 서버도 계정도 없다.

---

## 개발 원칙

### 1. 표준을 따른다 — 최우선 원칙

**독자 규격을 만들지 않는다.** 애플과 Swift 생태계가 이미 정한 방식이 있으면 그것을 쓴다.
자체 규격은 표준으로 도저히 안 되는 경우에만, 이유를 남기고 추가한다.

| 영역 | 쓰는 것 | 만들지 않는 것 |
| --- | --- | --- |
| UI | SwiftUI | 자체 뷰 프레임워크·래퍼 |
| 저장 | SwiftData | 자체 ORM·직렬화 계층 |
| 상태 | `@Observable`, `@State`, `@Query` | 자체 Store·Redux류 아키텍처 |
| 비동기 | `async/await`, structured concurrency | 자체 Promise·콜백 규약 |
| 테스트 | Swift Testing (`@Test`, `#expect`) | XCTest 신규 작성 |
| 의존성 | Swift Package Manager | CocoaPods, Carthage, vendored 소스 |
| 프로젝트 | `.xcodeproj` + buildable folder | XcodeGen, Tuist |
| 폰↔워치 | WatchConnectivity | 자체 프로토콜·소켓 |
| 마크다운 | GFM 표준 파이프 표 | 자체 마크업 문법 |
| 오류 | `Error` + `throws`, `Result` | 자체 오류 래퍼 타입 |
| 네이밍 | [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) | 팀 자체 접두사 규칙 |

**서드파티 의존성은 기본적으로 추가하지 않는다.** 표준 라이브러리와 애플 프레임워크로 안 되는
경우에만, 추가 이유를 먼저 논의한 뒤 넣는다.

**추상화를 미리 만들지 않는다.** 구현체가 하나뿐인 프로토콜, 지금 쓰지 않는 제네릭,
"나중에 바꿀 수 있게" 만드는 래퍼는 넣지 않는다. 두 번째 사용처가 생겼을 때 뽑아낸다.

**예외를 둘 때는 반드시 기록한다.** 표준에서 벗어나야 한다면
① 코드에 왜 벗어났는지 한 줄 주석, ② 아래 "표준 예외 기록"에 항목 추가.
기록 없는 예외는 리뷰에서 되돌린다.

#### 표준 예외 기록

| 항목 | 벗어난 내용 | 이유 |
| --- | --- | --- |
| `resultRaw` · `stateRaw` | enum 을 String 원시값으로 저장하고 계산 프로퍼티로 감쌈 | SwiftData 가 enum 저장을 지원하지만, 상태를 추가할 때 기존 저장소가 깨진다. 마이그레이션 비용을 피하려는 의도적 선택(PRD §7) |
| `weekdayMask` | 요일을 배열이 아니라 Int 비트마스크로 저장 | CloudKit 은 배열 관계에 제약이 있고, 워치 전송 payload 도 작아진다(PRD §7) |

### 2. 주석은 핵심만 컴팩트하게

**무엇(what)이 아니라 왜(why)를 쓴다.** 코드를 읽으면 아는 내용은 반복하지 않는다.

```swift
// ✅ 왜 이렇게 했는지가 코드에 없다
/// 실패한 세트는 실제 횟수를 인자로 받는다.
/// 이 API 모양 자체가 PRD D1 의 불변식을 강제한다.
func markFailure(actualReps reps: Int, ...)

// ❌ 코드가 이미 말하는 것을 반복
/// 세트를 실패로 표시하고 실제 횟수를 저장한다.
func markFailure(actualReps reps: Int, ...)
```

- **한 줄로 끝낼 수 있으면 한 줄.** 문단은 판단 근거가 정말 필요할 때만.
- **PRD 근거가 있는 결정은 식별자로 연결한다.** `(F-9)`, `(PRD D1)`, `(PRD §7)`.
  나중에 "이거 왜 이렇게 했지"를 문서에서 되찾을 수 있게.
- **공개 API 에는 짧은 doc comment.** 내부 구현 세부는 대부분 주석이 필요 없다.
- **조용히 망가지는 코드에는 반드시 주석.** 실패가 오류로 드러나지 않고 빈 값·기본값으로
  보이는 자리(예: 종목명 정규화)는 왜 이렇게 처리하는지 남긴다.
- **주석 처리된 죽은 코드를 남기지 않는다.** git 이 기억한다.
- 주석과 문서는 한국어로 쓴다. 코드 식별자는 영어.

### 3. 기능 검증 테스트는 반드시 작성한다

**기능을 추가하거나 고치면 테스트를 함께 쓴다. 예외 없다.**
"돌려보니 되더라"는 검증이 아니다.

- **도메인 로직은 `WoofitCore` 에 둔다.** 시뮬레이터 없이 `swift test` 로 도는 것이
  기본값이어야 한다. 화면에서만 검증 가능한 로직은 잘못 배치된 것이다.
- **Swift Testing 을 쓴다.** `@Test`, `#expect`, `#require`. XCTest 는 신규 작성하지 않는다.
- **테스트 이름은 동작을 한국어 문장으로 서술한다.**
  `@Test("실패는 실제 횟수 없이 기록될 수 없다")` — 무엇을 보장하는지가 이름에서 읽혀야 한다.
- **무엇을 테스트하나**
  - PRD 요구사항의 **수용 기준** — 각 F-번호가 약속한 동작
  - **불변식** — 실패 세트는 반드시 `actualReps` 를 갖는다 등
  - **경계 조건** — 빈 루틴, 첫 수행이라 직전 기록이 없는 경우, 중단된 세션
  - **회귀** — 버그를 고칠 때는 그 버그를 재현하는 테스트를 먼저 쓴다
- **작업을 끝내기 전 `swift test` 가 통과해야 한다.** 실패한 채로 완료 보고하지 않는다.
- 테스트가 명세의 오류를 잡으면 **코드가 아니라 문서를 고칠 수도 있다.**
  실제로 요일 비트마스크 계산과 종목명 정규화 규칙 두 건이 이렇게 수정됐다.

---

## 명령어

```sh
# 도메인 테스트 — 시뮬레이터 불필요, 가장 자주 쓰는 명령
cd WoofitCore && swift test

# 패키지 빌드만
cd WoofitCore && swift build

# iOS 앱 빌드 (워치 앱도 의존성으로 함께 빌드·임베드된다)
xcodebuild build -project Woofit.xcodeproj -scheme Woofit \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# 타겟·스킴 확인
xcodebuild -list -project Woofit.xcodeproj
```

첫 빌드는 SwiftData 매크로 컴파일 때문에 몇 분 걸린다. `-derivedDataPath` 를 고정해두면 이후가 빠르다.

---

## 구조

```
woofit/
├── CLAUDE.md                   이 문서
├── docs/PRD.md                 제품 요구사항 정의서 — 기능 정의의 단일 출처
├── WoofitCore/                 폰·워치 공용 로직 (로컬 Swift Package)
│   ├── Sources/WoofitCore/
│   │   ├── Model/              SwiftData 모델 · 값 타입
│   │   ├── Query/              직전 기록 조회 (F-9)
│   │   └── Markdown/           표기 포맷터
│   └── Tests/WoofitCoreTests/
├── Woofit/                     iOS 앱 타겟 — 화면만
├── WoofitWatch Watch App/      watchOS 앱 타겟 — 화면만
└── Woofit.xcodeproj
```

**앱 타겟에는 화면만 둔다.** 모델·계산·파싱은 전부 `WoofitCore` 로 간다.
이 경계가 무너지면 테스트가 시뮬레이터를 요구하게 되고, 원칙 3이 지켜지지 않는다.

프로젝트는 Xcode 26 **buildable folder** 를 쓴다. 소스를 추가·삭제·이동해도
`project.pbxproj` 가 바뀌지 않으므로, 파일 목록을 손으로 관리할 필요가 없다.

---

## 핵심 설계 규칙

PRD §7 에서 온 것들. 어기면 조용히 데이터가 망가지므로 먼저 확인한다.

- **계획과 실행을 분리한다.** 세션 시작 시 `WorkoutSession.start(from:)` 이 루틴을 **복사**한다.
  참조만 하면 다음 주에 무게를 올리려고 루틴을 고쳤을 때 지난달 기록까지 바뀐다.
- **실패는 실제 횟수 없이 기록될 수 없다.** `markFailure(actualReps:)` 가 인자로 강제한다(PRD D1).
  이 불변식을 우회하는 경로를 만들지 않는다.
- **enum 은 String 원시값으로 저장한다.** `resultRaw`, `stateRaw`. 계산 프로퍼티로 감싸 접근한다.
- **CloudKit 제약을 미리 지킨다.** 모든 저장 프로퍼티에 기본값 또는 옵셔널, 관계는 옵셔널,
  `@Attribute(.unique)` 금지. 유료 계정 등록 후
  `WoofitModelContainer.makeContainer(cloudKitContainerID:)` 에 값만 넘기면 전환된다(PRD D5).
- **관계 배열은 옵셔널이므로 `sorted*` 프로퍼티로 읽는다.** `exercises` 를 직접 쓰지 않는다.
- **종목명은 공백을 제거해 정규화한다.** `ExerciseName.normalize`.
  축약이 아니라 제거여야 "벤치프레스"와 "벤치 프레스"가 같은 종목이 된다.
  이름을 바꿀 때는 `rename(to:)` 를 써서 `normalizedName` 을 함께 갱신한다.
- **모델을 추가하면 `WoofitModelContainer.schema` 에도 넣는다.**

---

## 작업 방식

**계획 문서를 보고 시작한다.** 기능별 구현 계획이 [docs/plans/](docs/plans/) 에 있다.
작업 단위·파일·테스트 계획·완료 기준이 적혀 있으므로, 무엇부터 할지는 거기서 확인한다.
계획이 틀린 걸 발견하면 계획 문서를 고친 뒤 진행한다.

**PRD 가 먼저다.** 기능의 정의는 [docs/PRD.md](docs/PRD.md) 가 단일 출처다.
동작을 바꾸는 결정을 하면 코드보다 PRD 를 먼저 고치고, 요구사항 번호로 연결한다.
PRD 에 없는 기능을 임의로 추가하지 않는다.

**마일스톤 순서를 지킨다.** 현재 M1. 뒤 마일스톤의 기능을 앞당겨 만들지 않는다.
특히 추이 그래프(F-10)와 무게 제안(F-11)은 데이터가 6~10주 쌓여야 의미가 생기므로 M3 이다.

### 완료 기준

작업을 끝냈다고 보고하기 전에 전부 만족해야 한다.

1. `cd WoofitCore && swift test` 통과
2. 추가·변경한 기능에 대응하는 테스트 존재
3. `xcodebuild build -scheme Woofit` 통과 (앱 타겟을 건드린 경우)
4. 표준에서 벗어난 부분이 있으면 "표준 예외 기록"에 추가
5. 동작이 PRD 와 달라졌으면 PRD 갱신

---

## 현재 상태

- ✅ `WoofitCore` 모델 · 직전 기록 조회 · 표기 포맷터 (테스트 18개)
- ✅ Xcode 프로젝트 (iOS + watchOS 2타겟, 로컬 패키지 연결, 빌드 통과)
- ⬜ **M1** — [F-06 내보내기](docs/plans/F-06-markdown-export.md) → [F-07 가져오기](docs/plans/F-07-markdown-import.md) → [F-01 루틴 작성](docs/plans/F-01-routine-authoring.md) · [F-09 직전 기록](docs/plans/F-09-last-record.md) → [F-03 세션 실행](docs/plans/F-03-session-execution.md) · [F-04 다음 종목](docs/plans/F-04-next-exercise.md)
- ⬜ M2 — 워치, 휴식 측정(F-5), 폰↔워치 동기화(F-8)
- ⬜ M3 — 추이 그래프(F-10), 다음 무게 제안(F-11)

M1 은 마크다운 왕복부터 시작한다. 순수 함수라 테스트가 잘 붙고,
먼저 만들어두면 이후 화면 작업에 실제 데이터를 꽂아 넣을 수 있다.

## 환경

Xcode 26.6 · iOS/watchOS 배포 타겟 26.0 · Swift 6.0 (패키지 tools-version 6.2)

App Store 배포 없음. 개인 기기 직접 설치이며, 무료 Apple ID 는 프로비저닝이
7일마다 만료되어 재빌드가 필요하다(PRD D5).
