# Architecture Decision Records

큰 기술 결정의 기록 모음. 새 ADR은 `../templates/adr.md`를 복사해 `NNNN-<slug>.md`로 만든다.

## Index

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-cmake-build-system.md) | CMake 빌드 시스템 채택 | Accepted | 2026-05-14 |
| [0002](0002-hlsli-library-structure.md) | HLSLI 라이브러리 5-모듈 분리 | Accepted | 2026-05-14 |
| [0003](0003-imgui-for-runtime-controls.md) | 런타임 컨트롤에 Dear ImGui 채택 | Accepted | 2026-05-14 |
| [0004](0004-custom-shader-include-handler.md) | 커스텀 ID3DInclude 핸들러 | Accepted | 2026-05-15 |
| [0005](0005-shared-psin-struct.md) | 카드 PS 공용 `PSIn` 구조체 | Accepted | 2026-05-15 |
| [0006](0006-per-card-local-time.md) | 카드별 로컬 시간 (중앙에서만 누적) | Accepted | 2026-05-15 |
| [0007](0007-piecewise-coverflow-layout.md) | 비선형 Coverflow 레이아웃 + cull | Accepted | 2026-05-15 |
| [0008](0008-config-header.md) | `src/Config.h` 상수 중앙 관리 | Accepted | 2026-05-15 |
| [0009](0009-vs-presets-isolated-output.md) | VS Presets와 격리된 빌드 출력 | Accepted | 2026-06-05 |
| [0010](0010-mask-color-library-split.md) | SDF Mask와 Color 라이브러리 분리 | Accepted | 2026-06-05 |

## 작성 규칙

- 번호는 4자리 영구 발급, 재사용 금지
- 한 ADR = 한 결정
- 결정 시점의 컨텍스트를 남기는 게 목적이므로, 결정이 뒤집혀도 ADR을 삭제하지 않고 `Superseded by NNNN`으로 표시
- 코드 수정 PR과 ADR PR을 같이 머지 (하나의 변화로 묶음)
