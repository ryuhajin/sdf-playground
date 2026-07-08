#ifndef SDF_CBUFFERS_HLSLI
#define SDF_CBUFFERS_HLSLI

// ============================================================
// PerFrame
// ------------------------------------------------------------
// 한 프레임 동안 모든 카드가 함께 쓰는 값
// 카드마다 달라지는 값이 아니라, 앱 전체에서 한 번 정해져 모든 셰이더에 전달
// ============================================================
cbuffer PerFrame : register(b0) {
    // uTimeRes.x = sim_time: 앱이 시작된 뒤 흐른 시뮬레이션 시간(초)입니다. 일시정지 중에는 멈춤
    // uTimeRes.y = dt: delta time입니다. 바로 전 프레임에서 이번 프레임까지 걸린 시간(초)
    // uTimeRes.z = width: swapchain/backbuffer의 가로 픽셀 수
    // uTimeRes.w = height: swapchain/backbuffer의 세로 픽셀 수
    float4 uTimeRes;
    float4 uMouse;       // xy=mouse, zw=clicks
    int4   uRenderFlags; // x=renderMode, y=animMode, z=paused, w=reserved
    row_major float4x4 uViewProj;
};

// ============================================================
// PerCard
// ------------------------------------------------------------
// 카드 한 장을 그릴 때마다 갱신되는 값
// 같은 셰이더를 쓰더라도 카드별 위치, 시간, 변형, 색상 등을 다르게 줄 수 있음
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
