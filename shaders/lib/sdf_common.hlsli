#ifndef SDF_COMMON_HLSLI
#define SDF_COMMON_HLSLI

#include "sdf_cbuffers.hlsli"
#include "sdf_transform.hlsli"

#define PI 3.14159265359
#define TWO_PI 6.28318530718
#define HALF_PI 1.57079632679
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

// 카드별 로컬 시간. 카드가 중앙 카드가 될 때 0으로 리셋된다.
#define uCardTime (uCardMeta.w)

// 카드 셰이더가 공통으로 사용하는 pixel shader 입력.
struct PSIn {
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD;
};

// 화면 UV를 카드 SDF 좌표로 바꾼다.
// 반환 좌표는 카드 중앙이 원점이고, x/y는 대략 [-1, 1] 범위이며 +y가 위쪽이다.
float2 fitUV(float2 uv) {
    return float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
}

// 카드 좌표에 공통 ImGui 도형 transform을 적용한다.
// uCardTransform.xy는 도형 중심, z는 회전, w는 scale이다.
float2 applyCardShapeTransform(float2 cardPos) {
    return applyCenterRotationScale(
        cardPos,
        uCardTransform.xy,
        uCardTransform.z,
        uCardTransform.w
    );
}

// UV -> 카드 좌표 -> 도형 좌표 흐름을 한 번에 처리하는 편의 함수.
float2 cardUVToShapePos(float2 uv) {
    return applyCardShapeTransform(fitUV(uv));
}

float hash11(float n) {
    return frac(sin(n) * 43758.5453123);
}

float hash21(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// value를 [rangeStart, rangeEnd] 범위 기준의 0..1 값으로 바꾼다.
float inverseLerp01(float rangeStart, float rangeEnd, float value) {
    float rangeSize = max(rangeEnd - rangeStart, 0.0001);
    return saturate((value - rangeStart) / rangeSize);
}

// 양 끝은 0, 가운데는 1이 되는 값. taper band나 pulse에 자주 쓴다.
float middleTaper01(float position01) {
    return sin(saturate(position01) * PI);
}

#include "sdf_mask.hlsli"
#include "sdf_color.hlsli"

// signed distance를 단순 anti-aliased fill mask로 바꾸기
// ImGui Style Mode나 Color 0 / Color 1은 적용하지 않음
// 직접 mask를 조합하고 싶을 때 사용
float aa(float distance) {
    return maskFillAA(distance);
}

// 카드의 표준 출력 경로
// d가 최종 signed distance라면 `return mask(d);` 형태로 사용
// 이 함수는 아래 설정을 모두 적용:
// - ImGui Style Mode: Fill, Stroke, Fill + Stroke
// - ImGui Edge Softness와 Stroke Width
// - Render Mode
// - ImGui Color 0 / Color 1
float4 mask(float distance) {
    float maskValue = cardMask(distance);
    return float4(colorFromMask(maskValue, distance), 1.0);
}

#endif
