# ADR 0002: HLSLI 라이브러리 5-모듈 분리

- **Status**: Accepted
- **Date**: 2026-05-14
- **Branch / Commit**: 초기 셋업

## Context
PixelSpiritDeck 스타일로 SDF 카드를 학습하려면 재사용 함수가 필요. 라이브러리 구성 방식 선택지:

- 모든 함수를 한 hlsli에 모음
- 카드마다 필요한 함수를 인라인
- 도메인별 hlsli로 분리

학습 목표가 "SDF 개념을 익히고 함수 조합에 집중"이므로, 함수가 어디서 오는지 명확해야 함.

## Decision
5개 도메인으로 hlsli 분리:

| 파일 | 책임 |
|---|---|
| `sdf_cbuffers.hlsli` | `PerFrame`/`PerCard` constant buffer declarations |
| `sdf_common.hlsli` | `PSIn`, `fitUV`, `cardUVToShapePos`, `applyCardShapeTransform`, `aa`, `mask` helpers |
| `sdf_operators.hlsli` | Boolean ops: `opUnion`/`opSub`/`opInter`, `opSMin`/`opSMax`, `opOnion`/`opRound` |
| `sdf_shapes.hlsli` | 도형: `sdCircle`/`sdBox`/`sdTriEq`/`sdStar`/`sdNgon`/`sdGrid`/`sdCross`/`sdHeart` 등 |
| `sdf_transform.hlsli` | 변환: `moveCenterTo`/`rotateAroundOrigin`/`scaleAroundCenter`/`repeat`/`mirror`/`polar`/`kaleido`/`pixelate` |
| `sdf_animation.hlsli` | 애니메이션: `pulse`/`wave`/`ease01`/`bounce`/`oscillate`/`animDispatch` |

각 hlsli는 자체 헤더 가드. 카드는 필요한 도메인만 `#include`.

## Consequences
- **긍정**: 함수의 출처가 include 줄에서 즉시 보임. 학습 단위가 파일과 일치(오늘은 transforms 익히기, 내일은 ops). LYGIA·iq SDF 자료와 도메인 매핑 명확
- **부정**: hlsli끼리 cross-include 필요한 경우(예: `sdf_animation.hlsli`가 `sdf_common.hlsli`의 `uRenderFlags`를 씀)에서 include 핸들러 경로 해석 문제 발생 → [ADR 0004](0004-custom-shader-include-handler.md)로 별도 해결
- **후속 작업**: 카드 작성 시 include 누락에 대한 친절한 에러 메시지 (이미 컴파일 에러 패널로 처리)

## Alternatives Considered
- **단일 hlsli**: 카드가 `#include "sdf.hlsli"` 한 줄로 끝나 편하지만, 학습 효과(함수가 어느 도메인 소속인지 인지)가 낮아짐. 거부
- **카드별 인라인**: 학습 초반엔 명시적이지만 재사용 0%, 카드 추가할수록 부담. 거부

## 참고
- iq의 SDF 함수 페이지 (https://iquilezles.org/articles/distfunctions2d/) — 함수 정의 출처
- ADR 0004 — cross-include 처리
