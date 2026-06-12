# ADR 0005: 카드 PS 공용 `PSIn` 구조체

- **Status**: Accepted
- **Date**: 2026-05-15
- **Branch / Commit**: fix/vs-ps-linkage (specs/fix-vs-ps-linkage.md)

## Context
`quad.vs.hlsl`은 VS 출력으로 `{SV_Position pos, float2 uv : TEXCOORD}` 두 슬롯을 내보낸다. 카드 PS는 처음에 `float2 uv : TEXCOORD` 한 슬롯만 받았다.

`fxc`가 두 단계에서 TEXCOORD를 다른 hardware register index에 배치 → 시맨틱 매칭은 성공하지만 D3D11 debug layer가 매 `DrawIndexed`마다 다음을 보고:

```
EXECUTION ERROR #343: DEVICE_SHADER_LINKAGE_REGISTERINDEX
Semantic 'TEXCOORD' is defined for mismatched hardware registers
```

화면에서는 일부 카드가 깜빡거렸다 (드라이버에 따라 미정의 데이터 읽음).

## Decision
`sdf_common.hlsli`에 공용 `PSIn` 구조체 정의하고 모든 카드 PS는 이 구조체를 받는다.

```hlsl
struct PSIn {
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD;
};

// 카드:
float4 main(PSIn i) : SV_Target {
    float2 p = fitUV(i.uv);
    ...
}
```

VS 출력 시그니처(`{SV_Position, TEXCOORD}`)와 PS 입력 시그니처가 정확히 일치 → debug layer 통과 + 안정적인 렌더.

## Consequences
- **긍정**:
  - debug layer ERROR #343 소거
  - 깜빡임 사라짐
  - 미래에 PS 입력을 확장(예: normal, world position)하려면 `PSIn`에 필드만 추가
  - 카드 작성자는 그냥 `i.uv` 또는 추가 필드 접근 — 시그니처 일관성
- **부정**:
  - 카드 PS 시그니처가 약간 더 verbose (`float2 uv` → `PSIn i`)
  - 5장 데모 카드 + 향후 사용자 카드 모두 영향. README/docs에 명시 필요
- **후속 작업**:
  - README의 카드 예제 코드를 새 시그니처로 동기화 (이미 완료)
  - 추후 새 입력(예: world space normal) 추가하려면 quad.vs.hlsl과 `PSIn` 둘 다 동기 갱신

## Alternatives Considered
- **PS에 `noperspective float4 pos : SV_Position` 만 추가하고 uv는 그대로**: 효과는 같지만 매번 카드마다 두 줄을 적어야 함. 구조체로 묶는 게 깔끔. 거부
- **VS 출력에서 SV_Position을 분리 / 더미 처리**: HLSL은 VS가 SV_Position을 반드시 내보내야 함. 불가능
- **D3DCOMPILE_SIGNATURE_INDEX_ORDER 같은 플래그**: 그런 플래그 없음. fxc의 register 패킹 동작은 제어 불가
- **debug layer 메시지 억제 (`ID3D11InfoQueue` 필터링)**: 증상만 가리고 실제 깜빡임은 해결 안 됨. 거부

## 참고
- 관련 ADR: [0002](0002-hlsli-library-structure.md) (라이브러리 구조)
- Spec: [docs/specs/fix-vs-ps-linkage.md](../specs/fix-vs-ps-linkage.md)
- D3D11 debug layer DEVICE_SHADER_LINKAGE_REGISTERINDEX
