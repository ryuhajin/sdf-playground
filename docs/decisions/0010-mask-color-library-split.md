# ADR 0010: SDF Mask와 Color 라이브러리 분리

- **Status**: Accepted
- **Date**: 2026-06-05
- **Branch / Commit**: feat/sdf-mask-color

## Context

기존 `sdf_common.hlsli`의 `mask(d)`는 distance field를 anti-aliased 흑백 값으로 바꾸는 일과 색상 적용을 한 함수에서 처리했다. 카드별 `uCardStyle`이 추가되면서 fill/stroke, hard/soft edge, color mapping을 명확히 나누는 구조가 필요해졌다.

## Decision

SDF 도형 함수는 signed distance만 반환하고, distance를 렌더 가능한 값으로 바꾸는 단계를 두 라이브러리로 분리한다.

- `sdf_mask.hlsli`: `maskFill*`, `maskStroke*`, `cardMask`
- `sdf_color.hlsli`: `legacy color wrapper`, `palette`
- `sdf_cbuffers.hlsli`: `PerFrame`/`PerCard` cbuffer 선언
- `sdf_common.hlsli`: 입력 구조체/좌표 helper와 기존 카드 호환용 `mask(d)` wrapper 유지

`cardMask(d)`는 `uCardStyle.x/y/z`를 사용해 fill, stroke, fill+stroke와 edge softness를 결정한다.

## Consequences

- **긍정**: 카드 작성자는 도형 distance 생성과 스타일 변환을 분리해서 생각할 수 있다.
- **긍정**: 기존 카드의 `return mask(d);`는 계속 동작한다.
- **부정**: `sdf_common.hlsli`가 `sdf_mask.hlsli`, `sdf_color.hlsli`를 include하므로 include 관계가 한 단계 늘어난다.
- **후속 작업**: `sdf_animation.hlsli` rename은 완료되었고, easing 함수 분리는 별도 작업으로 진행한다.

## Alternatives Considered

- **`sdf_common.hlsli`에 계속 유지**: 파일이 빠르게 비대해지고 hard/soft/fill/stroke 책임이 섞인다. 거부.
- **카드마다 직접 fill/stroke 구현**: 학습에는 즉각적이지만 일관된 UI 스타일 제어가 어렵다. 거부.

## 참고

- 관련 ADR: [0002](0002-hlsli-library-structure.md)

