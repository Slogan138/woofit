# 18 · 워치 화면 재설계

> **개선** · 워치 · 새 기능 아님

## 무엇을 하나

[15 · 세션 실행 화면 재설계](15-session-runner-redesign.md)와 [16 · 홈·기록 화면
재배치](16-home-history-redesign.md)가 폰에만 적용한 것 중 **워치에도 옳은 것만** 옮긴다.
15 의 작업 단위 10번(`워치 화면에 같은 원칙 적용 — 별도 작업`)이 가리키던 자리다.

**"폰과 같게 만드는 일"이 아니다.** 15 가 세운 원칙은 "화면을 팔 뻗은 거리에서 땀 손으로
본다"였고, 워치는 그 조건이 더 극단적이면서 화면은 1/10 이다. 배치를 그대로 옮기면
오히려 나빠진다. 아래 **옮기지 않을 것** 절이 이 계획의 절반이다.

## 왜 지금인가

**워치의 `AccentColor` 가 기본 파랑 그대로다.** 15 의 3번이 폰 에셋 카탈로그만 바꿨고,
워치는 자기 카탈로그(`WoofitWatch Watch App/Resources/Assets.xcassets`)를 따로 갖는다.

| | 라이트 | 다크 |
| --- | --- | --- |
| 폰 `AccentColor` | `0.346 / 0.291 / 0.792` (인디고) | `0.444 / 0.376 / 0.916` |
| 워치 `AccentColor` | `0.071 / 0.337 / 0.769` (파랑) | `0.357 / 0.608 / 1.000` |

워치의 `.borderedProminent` "성공" 버튼 — 세션당 가장 많이 누르는 자리 — 이 폰과 다른
브랜드 색으로 칠해지고 있다. 톤앤매너 이전에 그냥 빠뜨린 것이다.

**그리고 판독값의 위계가 뒤집혀 있다.** `WatchSetView` 의 이번 세트 목표는
`Typography.value`(= `.title3`)인데, 같은 앱 `WatchFailureInputView` 의 실패 횟수 입력은
`.system(.largeTitle, design: .rounded).bold()` 다. **주된 판독값이 부수적 입력값보다 작다.**

## 요구사항

새 요구사항을 만들지 않는다. 아래를 **더 잘 전달하는 것**이 목적이다.

- F-3 — 현재 세트를 뚜렷하게. 성공은 1탭
- F-5 — 화면 아무 곳이나 탭하면 휴식 측정이 토글된다
- F-9 — 현재 종목의 직전 기록을 화면에 유지한다
- PRD §9 — Dynamic Type, 색만으로 상태를 구분하지 않음

## 선행 조건

- `LastRecord.weightDelta(toTarget:)` · `WeightFormatter.delta(_:)` — 15 에서 완료
- 워치 `ColorRole` · `Typography` — 12 에서 완료
- `WorkoutSessionController` — 17 에서 완료. 세션 화면을 건드리므로 배선을 깨지 않는다

## 설계

### 옮길 것

| 폰(15·16) | 워치에서 | 왜 |
| --- | --- | --- |
| 인디고 브랜드 색 | 에셋 카탈로그 값을 그대로 맞춘다 | 같은 앱이 두 브랜드 색을 쓰고 있다 |
| 큰 판독값(`heroMetric`) | 워치용 기준 크기로 별도 토큰 | 위계 역전을 푼다 |
| 직전 기록 대비 배지 | `compactSummary` 옆에 증감 | 손목에서 뺄셈을 시키지 않는다 |
| 세트 진행 점 | `"3세트"` 텍스트를 대체 | 좁은 화면에서 글자보다 싸다 |
| 기록 시 햅틱 | `sensoryFeedback` 성공·실패 구분 | 손목에서 없는 게 더 이상하다 |

### 옮기지 않을 것

- **하단 고정 액션 바.** 폰에서 옳았던 이유는 화면이 커서 바를 고정해도 콘텐츠가 안
  죽어서다. 41mm 에서는 화면의 1/3 을 먹는다. 워치의 답은 고정이 아니라 **순서 재배치** —
  판독값 바로 아래에 버튼을 두고 진행률·되돌리기를 그 밑으로 밀어, 버튼이 첫 화면 안에
  들어오게 한다
- **`ColorRole.cardSurface`.** OLED 검정 배경 자체가 워치의 디자인이다. 카드를 얹으면
  대비만 떨어진다
- **`ColorRole.progress` 그라디언트.** 15 는 "브랜드 색이 그라디언트로 드러나는 자리를
  하나로 묶는다"고 정했다. 워치에는 그릴 면적이 없다. 단색 `accent` 만 쓴다

### 워치에만 두는 것

`.handGestureShortcut(.primaryAction)` 을 "성공" 버튼에 붙인다. 더블 탭으로 기록된다 —
바를 잡은 손·땀 손이라는 이 앱의 실제 사용 맥락에 정확히 맞고, 애플이 정한 표준이라
원칙 1 에 부합한다(watchOS 11+, 배포 타깃 26.0).

### 토큰을 `WoofitCore` 로 올리지 않는다

워치 `ColorRole` 의 주석은 *"지금은 값이 같아 [공유할] 필요가 없다"* 인데, 15 이후로
**이미 값이 다르다**(폰만 `accent`·`cardSurface`·`progress` 를 갖는다). 주석이 낡았으니
고친다. 그러나 **타입을 합치지는 않는다** — 두 타겟이 실제로 공유해야 하는 것은 브랜드
색 하나뿐이고, 그건 에셋 카탈로그 두 벌의 값을 맞추면 끝난다. 지금 `WoofitCore` 로
올리면 사용처가 갈라지는 추상화를 미리 만드는 것이다(원칙 1).

## 작업 단위

### 1단계 · 계산 (WoofitCore)

- [ ] 1. `LastRecord.compactSummary` 의 기준 무게를 `topWeight` 로 맞춘다.
      지금은 `entries.first` 의 무게를 보여주는데 `weightDelta(toTarget:)` 는 `topWeight`
      기준이라, 피라미드 세트에서 **화면의 두 값이 서로 다른 무게를 가리킨다**

### 2단계 · 토큰

- [ ] 2. 워치 `AccentColor` 를 인디고로 — 폰 카탈로그와 같은 값
- [ ] 3. 워치 `Typography` 에 `heroMetricSize`·`heroMetric(_:)` 추가.
      폰의 56pt 를 그대로 쓰지 않는다. 36pt 안팎에서 시작해 41mm 실기기로 정한다.
      **반드시 `@ScaledMetric(relativeTo: .largeTitle)` 로 감싼다**(PRD §9)
- [ ] 4. 워치 `ColorRole` 의 낡은 주석 정정 — 값이 같다는 전제가 이미 깨졌다

### 3단계 · 화면 (`WatchSetView`)

- [ ] 5. 판독값을 화면의 주인공으로 — 목표 무게·횟수에 `heroMetric` 적용
- [ ] 6. 세트 진행 점 — `"3세트"` 텍스트 대체. 기호·형태로도 구분되게 한다(PRD §9)
- [ ] 7. 직전 기록 줄에 증감 배지 — `WeightFormatter.delta(_:)`
- [ ] 8. 순서 재배치 — 판독값 → 버튼 → 진행률 → 되돌리기. 버튼이 첫 화면 안에
- [ ] 9. "성공"에 `.handGestureShortcut(.primaryAction)`
- [ ] 10. 기록 햅틱 — `sensoryFeedback`. 성공은 `.success`, 실패는 `.warning`
- [ ] 11. `WatchFailureInputView` 의 큰 숫자도 같은 토큰 경유로 바꾼다 — 지금은
      화면이 직접 폰트를 지정한다
- [ ] 12. 실기기에서 확인 — 41mm, 손목 각도, Always-On 상태

## 파일

| 경로 | 내용 |
| --- | --- |
| `WoofitCore/.../Query/LastRecord.swift` | `compactSummary` 기준 통일 (1번) |
| `WoofitCore/Tests/.../ModelTests.swift` | 회귀 테스트 (1번) |
| `WoofitWatch Watch App/Resources/Assets.xcassets/AccentColor.colorset` | 인디고 (2번) |
| `WoofitWatch Watch App/DesignSystem/Typography.swift` | 워치용 hero 토큰 (3번) |
| `WoofitWatch Watch App/DesignSystem/ColorRole.swift` | 주석 정정 (4번) |
| `WoofitWatch Watch App/Features/WatchSetView.swift` | 5~10번 |
| `WoofitWatch Watch App/Features/WatchFailureInputView.swift` | 11번 |

`BrandViolet` 은 워치 카탈로그에 추가하지 않는다 — 그라디언트를 쓰지 않으므로 쓸 자리가 없다.

## 테스트 계획

| 무엇 | 어디 |
| --- | --- |
| 피라미드 세트에서 `compactSummary` 와 `weightDelta` 가 같은 무게를 기준으로 삼는다 | `ModelTests` |
| 균일 세트에서는 표기가 바뀌지 않는다 (회귀) | `ModelTests` |

**이 작업이 건드리는 계산은 1번 하나뿐이다.** 나머지는 기존 `SessionRunnerTests` 가 이미
보장하는 동작을 다르게 그리는 것이라 화면 테스트를 새로 쓰지 않는다. 15 와 같은 판단이다.

## 완료 기준

1. `swift test` 통과
2. `xcodebuild build -scheme Woofit` 통과 (워치 앱이 의존성으로 함께 빌드된다)
3. **동작이 하나도 바뀌지 않을 것** — 되돌리기 · 휴식 토글 · 실패 입력 · 중단 경로가 전부 남아 있을 것
4. 폰과 워치의 "성공" 버튼이 같은 색일 것
5. 색·폰트를 화면에서 직접 지정하는 곳이 없을 것 (토큰 경유)
6. 실기기에서 확인 (12번)

## 주의점

**휴식 토글이 조용히 깨진다.** F-5 는 "화면 아무 곳이나 탭"이고, `WatchSetView` 는
`.contentShape(Rectangle()).onTapGesture` 로 그걸 받는다. 진행 점·배지처럼 새 뷰를 넣을
때마다 그 영역이 화면 전체 탭에서 빠져나갈 수 있다. 15 에서 폰이 겪은 것과 같은 함정이다.

**햅틱이 두 번 울린다.** `WatchNextExerciseView` 가 `onAppear` 에서
`WKInterfaceDevice.play(.notification)` 을 친다. 10번의 기록 햅틱을 그냥 붙이면 종목의
마지막 세트에서 **기록 햅틱과 전환 햅틱이 겹친다.** 겹치면 두 신호를 구분할 수 없게 되어
"종목이 끝났다"는 F-4 의 알림이 뜻을 잃는다.

**운동 세션 배선을 건드리지 않는다.** `WatchSetView.finishSession()` 은 완료·중단 두 경로가
합류하는 지점이고, 거기서 `workoutSessionController.end()` 를 부른다(계획 17). 8번의 순서
재배치가 이 함수나 `.onChange(of: runner.phase)` 를 건드리면 **종료가 빠져 배터리를 먹는다.**
화면에는 아무 문제가 없어 보이므로 며칠 뒤에야 드러난다.

**고정 포인트 크기를 넣고 싶어진다.** 15 와 같은 함정이고 워치에서 더 세다 — 화면이 좁아
"이 정도면 되겠지" 하고 숫자를 박게 된다. `@ScaledMetric` 없이는 Dynamic Type 이 죽는다.

**실기기에서 봐야 한다.** 시뮬레이터의 워치 화면은 실제 크기가 아니고, Always-On
디스플레이 상태는 시뮬레이터로 재현되지 않는다. 12 의 주의점이 그대로 유효하다.
