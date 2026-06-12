#ifndef SDF_COLOR_HLSLI
#define SDF_COLOR_HLSLI

#include "sdf_cbuffers.hlsli"

float3 palette(float t, float3 baseColor, float3 amplitude, float3 frequency, float3 phase) {
    return baseColor + amplitude * cos(6.2831853 * (frequency * t + phase));
}

float gradientHorizontal(float2 p) {
    return saturate(p.x * 0.5 + 0.5);
}

float gradientVertical(float2 p) {
    return saturate(p.y * 0.5 + 0.5);
}

float gradientRadial(float2 p) {
    return saturate(length(p));
}

float gradientDistance(float distance) {
    return saturate(0.5 + 0.5 * sin(distance * 8.0));
}

float3 gradientColor(float t, float3 colorA, float3 colorB) {
    return lerp(colorA, colorB, saturate(t));
}

// 이미 계산된 0..1 마스크 값을 최종 RGB 색으로 바꾸기
//
// maskValue:
//   0이면 uCardColor0, 1이면 uCardColor1에 해당
//   0과 1 사이 값은 안티앨리어싱이나 soft edge 전환 구간
//
// distance:
//   원래 signed distance 값
//   Gradient render mode에서만 거리 기반 Color0 -> Color1 ramp를 만들기 위해 사용
//
// 여러 SDF나 procedural mask를 직접 조합해서 이미 maskValue를 만든 뒤,
// 마지막에 ImGui Color 0 / Color 1을 입히고 싶을 때 사용
float3 colorFromMask(float maskValue, float distance) {
    float m = saturate(maskValue);
    int renderMode = uRenderFlags.x;

    if (renderMode == 0) {
        return float3(m, m, m);
    }
    if (renderMode == 1) {
        float g = gradientDistance(distance);
        return float3(g * m, g * m, g * m);
    }
    if (renderMode == 2) {
        return lerp(uCardColor0.rgb, uCardColor1.rgb, m);
    }

    float g = gradientDistance(distance);
    float3 ramp = gradientColor(g, uCardColor0.rgb, uCardColor1.rgb);
    return lerp(uCardColor0.rgb, ramp, m);
}

#endif
