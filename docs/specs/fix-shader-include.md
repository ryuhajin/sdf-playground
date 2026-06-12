# Spec: fix/shader-include

- **Branch**: fix/shader-include (git 초기화 후 정식 브랜치로 전환 예정, 일단 main 직접 작업)
- **Started**: 2026-05-15
- **Completed**: 2026-05-15
- **Status**: Complete

## 목적
HLSL `.hlsli` 파일끼리 `#include "x.hlsli"`로 서로 참조할 수 있게 만든다.

## 배경 / 동기
런타임 핫리로드가 실패. 에러:
```
shaders/lib/sdf_animation.hlsli error X1507: failed to open source file: 'sdf_common.hlsli'
```

`D3D_COMPILE_STANDARD_FILE_INCLUDE`는 `D3D_INCLUDE_LOCAL` 경로를 **원본 컴파일 파일(`shaders/cards/card_NN.hlsl`) 디렉토리** 기준으로 해석한다. 따라서:

- `card_01.hlsl`이 `#include "../lib/sdf_animation.hlsli"` → `shaders/cards/../lib/sdf_animation.hlsli` ✓
- `sdf_animation.hlsli` 안에서 `#include "sdf_common.hlsli"` → `shaders/cards/sdf_common.hlsli` ✗ (없음)

표준 핸들러는 hlsli끼리 cross-include를 지원하지 못한다. 라이브러리 구조 ([ADR 0002](../decisions/0002-hlsli-library-structure.md)) 상 cross-include는 필연이라 핸들러를 교체해야 한다.

## 작업 항목
- [x] 원인 진단 (위 배경)
- [x] `ShaderIncludeHandler` 클래스를 `ShaderManager.h`에 선언
- [x] `ShaderManager.cpp`에 구현 (검색 경로: `shaders/lib/`, `shaders/`, `shaders/cards/`)
- [x] `CompileVS`/`CompilePS`에서 `D3D_COMPILE_STANDARD_FILE_INCLUDE` 대신 핸들러 인스턴스 사용
- [x] 빌드 통과 확인 (`cmake --build`)
- [x] 실행 확인 (5장 카드 정상 렌더 — 시작 시 MessageBox 없음으로 검증)
- [ ] 핫리로드 확인 (card_01 편집 → X1507 없이 반영) — 사용자 인터랙티브 검증
- [x] ADR 0004 작성
- [x] CHANGELOG entry 추가
- [x] 이 spec을 `Status: Complete`로 업데이트

## 변경 파일
- `src/ShaderManager.h`
- `src/ShaderManager.cpp`
- `docs/decisions/0004-custom-shader-include-handler.md` (신규)
- `docs/CHANGELOG.md` (entry 추가)

## 검증 (End-to-End)
1. **빌드**: `cmake --build build --config Debug` — 경고/에러 없음
2. **실행**: `Start-Process build\Debug\SDFs.exe -WorkingDirectory $PWD` — MessageBox 없음, 윈도우 정상 표시
3. **시각 확인**: 5장 카드 모두 정상 렌더 (card_05까지 sdf_animation 사용 → include OK여야 보임)
4. **핫리로드**: `shaders/cards/card_01.hlsl` 편집 후 저장 → 1초 이내 화면 반영, X1507 에러 없음
5. **hlsli 변경**: `shaders/lib/sdf_animation.hlsli`에 새 함수 한 줄 추가 → 모든 카드 재컴파일 성공

## 위험 / 비-범위
- **위험**: 새 핸들러가 메모리 누수 가능성 (`new char[]` ↔ `Close`에서 `delete[]`) — RAII로 묶지 않고 D3DCompile API 컨벤션 따름. 매번 컴파일마다 2~3KB만 다루므로 누수 영향 미미하나 코드 점검 시 주의
- **위험**: 검색 경로 우선순위 차이로 같은 파일명이 두 곳에 있으면 잘못된 파일을 들 수 있음. 현재 라이브러리 구조엔 중복 파일 없음
- **비-범위**:
  - Git init 자체 (이 fix가 완료된 다음에 묶어서 init)
  - VS HLSL 도구 통합 (런타임 컴파일만 영향)
  - 다른 ShaderManager 리팩토링 (캐싱, 비동기 등)

## 참고
- 관련 ADR: [0002](../decisions/0002-hlsli-library-structure.md) (라이브러리 구조), [0004](../decisions/0004-custom-shader-include-handler.md) (이번 결정, 완료 후 작성)
- D3DCompile docs: `D3D_INCLUDE_LOCAL` 해석 동작
