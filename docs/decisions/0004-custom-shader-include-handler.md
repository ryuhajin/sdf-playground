# ADR 0004: 커스텀 ID3DInclude 핸들러

- **Status**: Accepted
- **Date**: 2026-05-15
- **Branch / Commit**: fix/shader-include (specs/fix-shader-include.md)

## Context
HLSL 라이브러리를 5개 hlsli로 분리 ([ADR 0002](0002-hlsli-library-structure.md))한 결과, hlsli끼리 cross-include가 필요해졌다. 예: `sdf_animation.hlsli`가 `uRenderFlags` 상수를 쓰려고 `sdf_common.hlsli`를 include.

그런데 `D3DCompileFromFile`에 `D3D_COMPILE_STANDARD_FILE_INCLUDE`(표준 핸들러)를 넘기면 `D3D_INCLUDE_LOCAL` 경로를 **원본 컴파일 파일** 디렉토리 기준으로 해석한다.

- `shaders/cards/card_NN.hlsl` 컴파일 시
  - `#include "../lib/sdf_animation.hlsli"` → `shaders/cards/../lib/sdf_animation.hlsli` ✓
  - 그 내부의 `#include "sdf_common.hlsli"` → `shaders/cards/sdf_common.hlsli` ✗ 실패

에러: `error X1507: failed to open source file: 'sdf_common.hlsli'`.

표준 핸들러로는 라이브러리 구조를 유지할 수 없다.

## Decision
`ID3DInclude`를 직접 구현해 **다중 검색 경로**를 갖는 핸들러를 사용한다.

```cpp
class ShaderIncludeHandler : public ID3DInclude {
public:
    HRESULT __stdcall Open(D3D_INCLUDE_TYPE, LPCSTR file_name, LPCVOID,
                           LPCVOID* out_data, UINT* out_bytes) override;
    HRESULT __stdcall Close(LPCVOID data) override;
};
```

`Open`은 다음 순서로 파일을 찾는다:
1. `shaders/lib/<file>`  (대부분의 hlsli가 여기)
2. `shaders/<file>`
3. `shaders/cards/<file>`
4. `<file>` (그대로)

첫 번째로 열리는 파일을 읽어 메모리 버퍼로 반환. `Close`에서 `delete[]`.

`CompileVS`/`CompilePS`에서 `D3D_COMPILE_STANDARD_FILE_INCLUDE` 대신 이 핸들러 인스턴스 사용.

## Consequences
- **긍정**:
  - hlsli끼리 자유롭게 `#include "filename.hlsli"` 가능
  - 카드 작성자는 `#include "../lib/sdf_xxx.hlsli"` 한 줄로 끝, 내부 의존성을 신경 안 써도 됨
  - 검색 경로는 한곳에 모여 있어 새 폴더 추가 시 한 줄 추가
- **부정**:
  - 같은 파일명이 두 경로에 있으면 첫 번째가 우선되어 혼동 가능 (현재 라이브러리엔 없음)
  - 매 컴파일마다 inc 파일을 새로 읽음 (캐시 없음). 핫리로드용으로 OK, 카드 한 장 컴파일이 수 ms.
  - `new[]` / `delete[]` 페어를 D3DCompile 컨벤션에 맞춰 직접 관리 (RAII 아님). 누수 위험은 작지만 코드 점검 시 주의
- **후속 작업**: 필요해지면 캐싱 또는 메모리 풀로 최적화 (지금은 불필요)

## Alternatives Considered
- **표준 핸들러 유지 + 모든 cross-include에 상대 경로 적기**: `sdf_animation.hlsli` 안에 `#include "../lib/sdf_common.hlsli"`처럼 작성. 동작은 하지만, 의미상 자기 자신의 경로를 자신이 알아야 한다는 게 어색하고 파일 이동 시 깨짐. 거부
- **인라인 (cross-include 없애기)**: `sdf_animation.hlsli`에서 `uRenderFlags`를 안 쓰게 만들고 카드에서 처리. 라이브러리 책임 분리가 무너짐. 거부
- **모든 라이브러리를 하나의 거대한 hlsli로 통합**: [ADR 0002](0002-hlsli-library-structure.md)의 분리 결정과 충돌. 거부
- **D3DPreprocess + 직접 텍스트 합성**: 너무 큰 변경, 디버그 정보 손실. 거부

## 참고
- 관련 ADR: [0002](0002-hlsli-library-structure.md)
- Spec: [docs/specs/fix-shader-include.md](../specs/fix-shader-include.md)
- D3DCompile / ID3DInclude Microsoft Learn docs
