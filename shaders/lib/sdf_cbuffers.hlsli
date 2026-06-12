#ifndef SDF_CBUFFERS_HLSLI
#define SDF_CBUFFERS_HLSLI

// ============================================================
// PerFrame
// ------------------------------------------------------------
// 한 프레임 동안 모든 SDF 카드가 공유하는 값
// 시간, 해상도, 마우스, 렌더링 모드, ViewProjection처럼
// 카드마다 달라지지 않는 전역 상태
// ============================================================
cbuffer PerFrame : register(b0) {
    float4 uTimeRes;     // x=time, y=dt, z=resX, w=resY
    float4 uMouse;       // xy=mouse, zw=clicks
    int4   uRenderFlags; // x=renderMode, y=animMode, z=paused, w=reserved
    row_major float4x4 uViewProj;
};

// ============================================================
// PerCard
// ------------------------------------------------------------
// 카드 하나를 그릴 때마다 갱신되는 값
// 같은 SDF 셰이더를 쓰더라도 카드별 위치, 색, 스타일,
// 도형 transform, 파라미터를 다르게 줄 수 있다.
// ============================================================
cbuffer PerCard : register(b1) {
    row_major float4x4 uWorld;
    float4 uCardMeta;      // x=cardIndex, y=isCenter, z=slotOffset, w=cardLocalTime
    float4 uCardParams;    // ImGui Param.x/y/z/w; interpreted freely by card shaders.
    float4 uCardTransform; // xy=shape center in card coordinates, z=rotation radians, w=shape scale.
    float4 uCardStyle;     // x=0 fill, 1 stroke, 2 fill+stroke, y=edgeSoftness, z=strokeWidth, w=reserved.
    float4 uCardColor0;    // rgb=color for mask value 0.
    float4 uCardColor1;    // rgb=color for mask value 1.
};

#endif
