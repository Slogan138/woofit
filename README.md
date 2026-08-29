# Woofit

미리 짜둔 근력 루틴을 헬스장에서 그대로 실행하고, 세트마다 성공·실패와 휴식 시간을 남긴 뒤,
끝나면 마크다운 표로 뽑아 노트에 붙이는 개인용 iOS · watchOS 앱.
그 마크다운을 다시 붙여넣으면 다음 루틴이 된다.

운동 기록의 보관소가 아니라 **캡처 도구**다. 아카이브는 마크다운 노트가 맡는다.

## 문서

- [개발 가이드 (CLAUDE.md)](CLAUDE.md) — 개발 원칙, 명령어, 핵심 설계 규칙, 완료 기준
- [작업 계획](docs/plans/) — 기능별 구현 계획, 작업 순서
- [제품 요구사항 정의서 (PRD)](docs/PRD.md) — 범위, 기능 요구사항 F-1~F-11, 마크다운 형식, 데이터 모델, 마일스톤

## 환경

| 항목 | 버전 |
| --- | --- |
| Xcode | 26.6 |
| iOS 배포 타겟 | 26.0 |
| watchOS 배포 타겟 | 26.0 |
| Swift | 6.0 (패키지 tools-version 6.2) |

### 실기기 빌드

서명 팀 ID 는 저장소에 넣지 않는다. 실기기에 설치하려면 저장소 루트에
`Signing.local.xcconfig` 를 만들고 자기 팀 ID 를 넣는다([Signing.xcconfig](Signing.xcconfig) 참고).
시뮬레이터 빌드에는 필요 없다.

```sh
echo 'DEVELOPMENT_TEAM = XXXXXXXXXX' > Signing.local.xcconfig
```

## 구조

```
woofit/
├── docs/PRD.md                 제품 요구사항 정의서
├── WoofitCore/                 폰·워치 공용 로직 (로컬 Swift Package)
│   ├── Sources/WoofitCore/
│   │   ├── Model/              SwiftData 모델 · 값 타입
│   │   ├── Query/              직전 기록 조회 (F-9)
│   │   └── Markdown/           표기 포맷터
│   └── Tests/WoofitCoreTests/  도메인 테스트
├── Woofit/                     iOS 앱 타겟
├── WoofitWatch Watch App/      watchOS 앱 타겟
└── Woofit.xcodeproj
```

프로젝트 파일은 Xcode 26의 **buildable folder**(동기화된 폴더)를 쓴다.
`Woofit/` 과 `WoofitWatch Watch App/` 아래에 소스를 추가·삭제·이동해도
`project.pbxproj` 가 바뀌지 않으므로 머지 충돌이 생기지 않는다.

### 도메인 로직은 패키지에

모델과 조회 로직은 전부 `WoofitCore` 에 있고, 앱 타겟은 화면만 갖는다.
덕분에 **시뮬레이터 없이 터미널에서 테스트가 돈다.**

```sh
cd WoofitCore && swift test
```

앱 빌드:

```sh
xcodebuild build -scheme Woofit -destination 'generic/platform=iOS Simulator'
```

## 설계 규칙

- **계획과 실행을 분리한다** — 세션 시작 시 루틴을 복사(스냅샷)한다. 나중에 루틴을 고쳐도 과거 기록이 안 바뀐다.
- **실패는 실제 횟수 없이 기록될 수 없다** — `markFailure(actualReps:)` 가 인자로 강제한다(PRD D1).
- **enum 은 문자열로 저장한다** — `resultRaw`, `stateRaw`. 상태를 추가해도 기존 저장소가 안 깨진다.
- **CloudKit 제약을 미리 지킨다** — 기본값 또는 옵셔널, 관계는 옵셔널, `@Attribute(.unique)` 금지.
  유료 계정 등록 후 `WoofitModelContainer.makeContainer(cloudKitContainerID:)` 에 값만 넘기면 전환된다.
- **종목명은 공백을 제거해 정규화한다** — "벤치프레스"와 "벤치 프레스"가 같은 종목이어야 직전 기록이 이어진다.

## 현재 상태

기능별 진행 상태는 [작업 계획](docs/plans/) 인덱스에 있다.
두 곳에서 같은 상태를 관리하면 반드시 어긋나므로 여기에는 적지 않는다.

## 라이선스

**All rights reserved.** 개인용 프로젝트이며 사용 허가를 부여하지 않는다.
읽고 참고하는 것은 자유지만 복사·수정·재배포는 허용하지 않는다.

외부 의존성이 없어 서드파티 라이선스 고지 의무는 없다. 애플 프레임워크만 쓴다.

## 배포

App Store 배포 없음. 개인 기기 직접 설치.
무료 Apple ID 로는 프로비저닝이 7일마다 만료되어 재빌드가 필요하다(PRD D5).
