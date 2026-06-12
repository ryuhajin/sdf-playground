# Spec: feat-sdf-mask-color

- **Branch**: feat/sdf-mask-color
- **Started**: 2026-06-05
- **Status**: Complete

## 목적

SDF distance를 fill/stroke/hard/soft 흑백 마스크로 변환하는 단계와 컬러 적용 단계를 분리한다.

## 작업 항목

- [x] `sdf_mask.hlsli` 추가 (`maskFill*`, `maskStroke*`, `cardMask`)
- [x] `sdf_color.hlsli` 추가 (`legacy color wrapper`, `palette`)
- [x] 기존 `mask(d)`를 `cardMask(d)` + `legacy color wrapper()` wrapper로 변경
- [x] README, ADR, changelog 갱신

## 변경 파일

- `shaders/lib/sdf_common.hlsli`
- `shaders/lib/sdf_mask.hlsli`
- `shaders/lib/sdf_color.hlsli`
- `README.md`, `docs/...`

## 검증 (End-to-End)

- 빌드: `cmake --build --preset debug` 통과
- 실행: `out/bin/Debug/SDFs.exe` smoke test 통과 (`Launched=True`, `ExitCode=0`)

## 위험 / 비-범위

- `Edge Softness = 0`일 때도 픽셀 계단 방지를 위해 fwidth AA를 사용한다. 완전한 0/1 hard mask는 `maskFillHard`, `maskStrokeHard`로 제공한다.
- 이번 작업은 `sdf_animation.hlsli` rename 이전에 작성되었다.

