# Changelog

날짜는 ISO 8601 (`YYYY-MM-DD`). 최신 항목이 위. 항목은 Conventional Commits 형식.

## [Unreleased]
- fix(shaders): make card background follow final SDF shape position when enabled (specs/feat-per-card-fill-stroke-color)
- feat(shaders/ui): split card background gradient space from shape transform (specs/feat-per-card-fill-stroke-color)
- feat(shaders/ui): add per-card background palette and gradient helpers (specs/feat-per-card-fill-stroke-color)
- feat(shaders/ui): add render color modes and per-card gradient palette (specs/feat-per-card-fill-stroke-color)
- feat(shaders/ui): add per-card fill and stroke colors (specs/feat-per-card-fill-stroke-color)
- chore(shaders): split `PerFrame`/`PerCard` constant buffers into `sdf_cbuffers.hlsli` (specs/chore-hlsl-cbuffer-split)
- chore(shaders): rename `sdf_anim.hlsli` to `sdf_animation.hlsli` and `sdf_ops.hlsli` to `sdf_operators.hlsli`
- feat(ui): persist per-card params/transform/style defaults from ImGui (specs/feat-card-settings-persistence)
- feat(shaders): split SDF mask/color libraries for card style rendering (specs/feat-sdf-mask-color, ADR 0010)
- feat(shaders): per-card SDF transform/style cbuffer controls (specs/feat-card-transform-style-cbuffer)
- chore(build): CMake presets and isolated build output (specs/chore-build-output, ADR 0009)

## 2026-05-15
- feat(ui): Cards 패널 자동 center 동기화 + Coverflow tuning 라벨을 ±1/±2 단일 슬라이더로 분리 + painter's order 안내문 (specs/feat-ui-clarify)
- feat(coverflow): piecewise near/far 레이아웃 + visibility cull — ±1 occlusion 해소, ±2 가장자리로, wrap 점프 완화 (ADR 0007)
- feat(cards): 카드별 로컬 시간(`uCardTime`) — 중앙 슬롯에서만 누적, 도착 시 애니메이션 시작 (ADR 0006)
- feat(ui): ImGui Background color picker + Coverflow tuning near/far 슬라이더 재구성
- chore: `src/Config.h` 도입, 매직 넘버/인라인 산술을 `namespace config` 로 이주 (ADR 0008)
- fix(shaders): PSIn 공용 구조체로 VS/PS 시그니처 정렬 — D3D11 ERROR #343 + 깜빡임 제거 (specs/fix-vs-ps-linkage, ADR 0005)
- fix(shaders): custom ID3DInclude handler — hlsli끼리 `#include` 가능하게 (specs/fix-shader-include, ADR 0004)
- docs: docs/ 골격 (WORKFLOW, CHANGELOG, decisions/, templates/, specs/)
- docs: 초기 ADR backfill (0001 CMake, 0002 HLSLI 구조, 0003 ImGui)
- docs: README 7-섹션 재작성 (개요/미리보기/기능/빌드/구조/워크플로우/참고)

## 2026-05-14
- feat: 초기 SDF Deck (DX11 + Coverflow + HLSLI 라이브러리 + ImGui + 핫리로드 + 데모 카드 5장)
- chore: CMake 빌드 시스템, ImGui 벤더링
- chore: VS_STARTUP_PROJECT 자동 설정으로 F5 실행 흐름 정리
