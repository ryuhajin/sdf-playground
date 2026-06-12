# ADR 0008: `src/Config.h` 상수 중앙 관리 헤더

- **Status**: Accepted
- **Date**: 2026-05-15
- **Branch / Commit**: feat/coverflow-polish

## Context
초기 코드에 매직 넘버가 흩어져 있었다:
- `App::WndProc` 의 `width_=1280; height_=720;`
- `Renderer::Init` 의 fov `1.0472f`, near `0.1f`, far `100.0f`
- `App::Frame` 의 clear color `{0.04f, 0.04f, 0.05f, 1.0f}` 인라인
- 셰이더 경로 리터럴 `L"shaders/quad.vs.hlsl"` 여러 곳
- `Coverflow` 멤버 디폴트(`spacing=1.15f` 등) 클래스 내부 고정

문제:
1. 같은 종류의 값(예: 카메라 파라미터)이 여러 파일에 분산되어 한눈에 안 들어옴
2. `70.0f/255.0f` 같은 인라인 계산이 매번 등장 — 사용자 명시 피드백
3. 다른 AI/협업자가 들어왔을 때 튜닝 포인트를 찾기 어려움

## Decision
**`src/Config.h` 단일 헤더에 `namespace config` 로 모든 초기/디폴트 값 모음**.

분류:
- 윈도우 (크기, 타이틀, 클래스명)
- 색상 (배경, mask1/mask2 디폴트)
- 카드 풀/슬롯 (visible slots, center slot)
- Coverflow 레이아웃 (near/far 쌍)
- 카메라 (eye Z, fov, near/far plane)
- 카드 파라미터 기본값
- 셰이더 경로

사용 원칙:
- 컴파일 시점 고정값(윈도우 크기, 카메라 파라미터, 셰이더 경로 등)은 `config::kXxx` 직접 참조
- 런타임 변경 가능 값(mask1, coverflow 슬라이더 등)은 멤버를 두고 `config::kXxxDefault` 로 초기화
- 매직 넘버를 새로 도입할 일이 생기면 일단 Config.h에 등록부터

## Consequences
- **긍정**:
  - 튜닝 포인트 한눈에 파악 (헤더 한 파일)
  - `70.0f/255.0f` 같은 인라인 산술 제거
  - 신규 협업자/AI가 빠르게 환경 변경 가능 — 매크로 시그널로 "여기를 만져라"
  - ADR 0007(piecewise 레이아웃)의 디폴트 값과 클래스 멤버 분리가 자연스러움
- **부정**:
  - 헤더 의존성 한 단계 추가 (`App.h`, `Coverflow.h` 가 `Config.h` include)
  - 단순 한 곳에서만 쓰는 상수도 Config.h에 두면 헤더가 비대해질 수 있음 → 사용자 가시성 있는 값만 등록, 내부 임시값은 함수/파일 내 `constexpr` 로 두기
- **후속 작업**:
  - 향후 추가되는 튜닝 값(예: 새 효과 강도, 새 카메라 모드 등)은 Config.h에 등록

## Alternatives Considered
- **클래스 멤버 디폴트로만 처리**: 한 곳에서 못 보고 분산됨. 거부
- **INI/JSON 외부 설정 파일**: 학습 프로젝트에 오버엔지니어링. 거부 — 컴파일 시 고정으로 충분
- **CMake `target_compile_definitions` 로 매크로 전달**: 빌드 시점만 결정, 가독성/IntelliSense 면에서 헤더가 우월. 거부

## 참고
- 사용자 피드백 메모리: `feedback-centralized-constants`
- Spec: [docs/specs/feat-coverflow-polish.md](../specs/feat-coverflow-polish.md)
