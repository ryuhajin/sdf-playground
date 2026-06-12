# Spec: feat-card-transform-style-cbuffer

- **Branch**: feat/card-transform-style-cbuffer
- **Started**: 2026-06-05
- **Status**: Complete

## 목적

카드별 SDF 좌표 이동과 렌더 스타일 값을 ImGui에서 조절하고, 같은 값을 C++/HLSLI cbuffer에 명시적인 주석과 함께 노출한다.

## 작업 항목

- [x] `PerCardCB`와 HLSLI `PerCard`에 `uCardTransform`, `uCardStyle` 추가
- [x] C++ `CardEntry`에 `transform[4]`, `style[4]` 기본값 추가
- [x] `sdf_common.hlsli`에 `applyCardShapeTransform()`과 `cardUVToShapePos()` helper 추가
- [x] 샘플 카드 5장의 공통 SDF transform 진입점을 `applyCardShapeTransform()` 기준으로 정리
- [x] ImGui Cards 패널에 Transform/Style 컨트롤 추가
- [x] 카드 풀 핫리로드 시 `params`, `transform`, `style` 값 보존

## 변경 파일

- `src/App.h`, `src/App.cpp`, `src/Config.h`
- `shaders/lib/sdf_common.hlsli`
- `shaders/cards/card_01.hlsl` ~ `card_05.hlsl`

## 검증 (End-to-End)

- 빌드: `cmake --build --preset debug` 통과
- 실행: `out/bin/Debug/SDFs.exe` smoke test 통과 (`Launched=True`, `ExitCode=0`)

## 위험 / 비-범위

- `uCardStyle`은 이번 단계에서 cbuffer/UI까지 추가한다. 실제 fill/stroke/soft mask 함수 분리는 다음 SDF mask 라이브러리 작업에서 진행한다.
- 마우스 입력은 연결하지 않는다.
