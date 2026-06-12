# ADR 0006: 카드별 로컬 시간 (중앙에서만 누적)

- **Status**: Accepted
- **Date**: 2026-05-15
- **Branch / Commit**: feat/coverflow-polish (specs/feat-coverflow-polish.md)

## Context
초기 데모 카드는 `uTimeRes.x`(전역 sim_time)을 직접 써서 모든 카드가 항상 애니메이션을 진행했다. 사용자는 "중앙에 도달한 카드만 애니메이션이 시작되도록" 연출을 원함 — 양옆 카드는 정지된 상태로, 슬라이드해 중앙에 오면 0에서부터 동작 시작.

선택지:
- A. 모든 카드를 전역 시간으로 진행 + 카드 PS에서 `isCenter` 분기로 정지
- B. 앱이 카드별 로컬 시간을 관리하고 셰이더는 그것만 받음
- C. 카드 PS가 자체 fade-in 로직 구현

A는 카드 PS에 분기 코드 강요(매번 작성자가 처리), 정지 상태도 카드 정의 시 신경 써야 함.
C는 카드마다 패턴 다름 → 일관성 없음.

## Decision
**App이 카드별 로컬 시간을 관리, 카드 셰이더는 `uCardTime` 매크로로 받음**.

구현:
- `App::card_local_time_ : std::vector<float>` — `cards_`와 평행하게 카드 수만큼 유지
- `App::UpdateCardTimers(dt)` 가 매 프레임:
  - 현재 중앙 카드(`coverflow_.CenterCardIndex()`)에만 `dt * time_scale_` 누적 (paused가 아닐 때)
  - 다른 모든 카드는 0으로 강제 리셋
  - 중앙이 바뀌면 이전 중앙도 0으로 리셋 — 떠나는 즉시 정지
- PerCard 상수 버퍼의 `uCardMeta.w` 필드에 해당 카드의 로컬 시간을 채움
- `sdf_common.hlsli` 에 `#define uCardTime (uCardMeta.w)` 매크로 정의
- 데모 카드 5장의 모든 시간 사용 위치를 `uTimeRes.x` → `uCardTime` 로 교체

## Consequences
- **긍정**:
  - 카드 셰이더는 분기 없이 그냥 `uCardTime` 만 쓰면 됨 — 작성 단순화
  - "중앙 진입 → 0부터 시작"이 자동으로 적용되어 연출 일관성 확보
  - 카드별 독립 시간이라 추후 효과(예: 진입 시 fade-in, "처음 본 시간" 같은 효과) 확장 용이
- **부정**:
  - 글로벌 시간이 필요한 카드(예: 항상 도는 배경 효과)는 여전히 `uTimeRes.x` 를 직접 써야 함 — 컨벤션 분기 발생. 향후 필요해지면 `uGlobalTime` 별도 매크로 추가
  - App이 카드별 상태를 들고 있어야 함(`card_local_time_`) — `LoadCardPool`/`ReloadCardPool` 마다 사이즈 동기화 필요. 이미 처리.
- **후속 작업**:
  - 사용자 카드 추가 시 `uCardTime` 사용 컨벤션 README 안내(이미 작성)

## Alternatives Considered
- **A. 전역 시간 + PS 분기**: 카드 PS마다 `if (uCardMeta.y > 0.99) animate else freeze` 같은 분기. 거부 — 작성자에게 부담, 실수로 빼먹기 쉬움
- **C. PS 자체 fade-in**: smoothstep으로 첫 0.3s 동안 강도 0→1 등. 거부 — 카드마다 형태 다름, 일관성 없음
- **D. CPU에서 매 카드의 sim_time 변형값 전달**: 동일한 효과지만 매크로 없이 `uCardMeta.w` 직접 접근 → 가독성 낮음. `#define uCardTime` 로 의도 명확화

## 참고
- 관련 ADR: [0007](0007-piecewise-coverflow-layout.md) — Coverflow 레이아웃
- Spec: [docs/specs/feat-coverflow-polish.md](../specs/feat-coverflow-polish.md)
