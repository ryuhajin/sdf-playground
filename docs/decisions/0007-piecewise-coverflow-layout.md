# ADR 0007: 비선형 Coverflow 레이아웃 + 가시성 cull

- **Status**: Accepted
- **Date**: 2026-05-15
- **Branch / Commit**: feat/coverflow-polish

## Context
초기 Coverflow는 슬롯 오프셋(`i - 2`)에 단일 `spacing`/`yawRad`/`zStep`/`scaleStep` 을 곱해 선형 배치. 결과:

- 슬롯 ±1 의 카드가 중앙 카드와 X 범위가 겹쳐 occlusion 발생
- 슬롯 ±2 의 카드가 화면 가장자리에 충분히 안 밀려남
- 카드 풀 N=5 일 때 슬라이드 boundary에서 wrap-around 카드가 슬롯 0 (`pos ≈ -2.99`)와 슬롯 4 (`pos = +2`) 사이를 한 프레임에 점프 — 시각적 텔레포트

선형 식으로는 "±1은 적당히 가까이, ±2는 멀리"라는 비선형 요구를 깔끔히 표현 못 함.

## Decision
**Piecewise 선형 보간 + visibility 페이드** 도입.

`Coverflow` 멤버를 길이 2 배열로:
- `spacing[2]` — `[0]` = |pos|=1 거리, `[1]` = |pos|=2 거리
- `yawRad[2]`, `zDepth[2]`, `scaleAt[2]` 동일 구조

GetSlot 내부:
```cpp
auto interp = [](float ax, float vn, float vf) {
    return ax <= 1.0f ? ax * vn : vn + (ax - 1.0f) * (vf - vn);
};
float xDist  = interp(ax, spacing[0], spacing[1]);
float yawMag = interp(ax, yawRad[0],  yawRad[1]);
float zd     = interp(ax, zDepth[0],  zDepth[1]);
// scale은 |pos|=0 일때 1.0 기준:
float sc = (ax <= 1.0f) ? 1.0f + (scaleAt[0]-1.0f)*ax
                         : scaleAt[0] + (scaleAt[1]-scaleAt[0])*(ax-1.0f);
```

기본값 (`Config.h`):
- `kSpacingNear = 1.8`, `kSpacingFar = 3.2`
- `kYawNearRad = 0.65` (~37°), `kYawFarRad = 1.25` (~72°)
- `kZDepthNear = 0.30`, `kZDepthFar = 0.70`
- `kScaleNear = 0.85`, `kScaleFar = 0.65`

**Visibility cull**: `|pos| > cullPos (= 2.5)` 일 때 `Slot.visibility` 를 0으로 fade out. App의 draw loop에서 visibility ≤ 0.01 이면 DrawIndexed skip. 결과: wrap boundary 근처의 텔레포트 카드가 미리 사라져 점프 효과가 줄어듦.

부호 컨벤션은 유지 (`angleY = -sign(pos) * yawMag`) — 안쪽(중앙쪽) edge 가 카메라로 기울어짐 = face-center.

## Consequences
- **긍정**:
  - 중앙 카드와 ±1 카드의 X 범위가 겹치지 않아 occlusion 해소
  - ±2 가 가장자리로 더 밀려나 5장 모두 또렷이 시각 구분
  - cull 덕분에 N=5 환경에서도 wrap 점프가 부드러워짐
  - ImGui 슬라이더로 4쌍 + cullPos + lerpSpeed 실시간 튜닝 가능
- **부정**:
  - 매개변수 수가 늘어 ImGui 패널이 다소 복잡 (`SliderFloat2` 로 정리)
  - cullPos 미만이라도 wrap 텔레포트의 잔상은 N=5 한정 잔존 — 카드 풀이 6장 이상이면 자연 해결
- **후속 작업**:
  - 카드 풀 확장 (사용자 학습 진행 시)
  - 필요해지면 슬롯 ±3 까지 표시(현재는 cull로 잘림)

## Alternatives Considered
- **선형 유지 + spacing 증가**: 중앙 occlusion은 해결되지만 ±2가 너무 멀어짐 또는 ±1이 너무 작아짐. 거부
- **3 슬롯만 표시 (visible=3)**: 좌우 ±1만 보임. 사용자는 5장 유지 원함. 거부
- **카드 풀을 무조건 N≥10 강제**: 사용자가 학습 페이스대로 추가하길 원함. 강제 안 함
- **3차 polynomial 보간**: 두 anchor 만으로 충분, polynomial은 과한 복잡도

## 참고
- 관련 ADR: [0006](0006-per-card-local-time.md), [0008](0008-config-header.md)
- Spec: [docs/specs/feat-coverflow-polish.md](../specs/feat-coverflow-polish.md)
