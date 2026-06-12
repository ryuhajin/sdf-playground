#ifndef SDF_MASK_HLSLI
#define SDF_MASK_HLSLI

#include "sdf_cbuffers.hlsli"

// fill mask와 stroke mask를 따로 들고 있는 구조체
struct CardMaskParts {
    float fill;   // SDF 도형 안쪽이면 1, 바깥쪽이면 0
    float stroke; // SDF 경계선 근처면 1, 경계선에서 멀면 0
};

// SDF 경계에 사용할 pixel derivative 기반 anti-aliasing 폭
// 화면 공간에서 distance 변화가 클수록 더 넓은 전환 구간이 필요하다
float sdfAAWidth(float distance) {
    return max(fwidth(distance) * 1.5, 0.0001);
}

// signed distance를 hard fill mask로 바꿈
// distance <= 0이면 도형 안쪽
float maskFillHard(float distance) {
    return step(distance, 0.0);
}

// signed distance를 anti-aliased fill mask로 바꿈
// ImGui color 없이 단순한 0..1 fill 값만 필요할 때 사용
float maskFillAA(float distance) {
    float w = sdfAAWidth(distance);
    return 1.0 - smoothstep(-w, w, distance);
}

// 사용자가 지정한 폭으로 soft fill mask 만들기
float maskFillSoft(float distance, float softness) {
    float w = max(softness, sdfAAWidth(distance));
    return 1.0 - smoothstep(-w, w, distance);
}

//  SDF 경계선 주변의 hard stroke mask 만들기
// width는 distance == 0을 기준으로 한쪽 방향의 반쪽 두께
float maskStrokeHard(float distance, float width) {
    return step(abs(distance), max(width, 0.0));
}

// SDF 경계선 주변의 anti-aliased stroke mask 만들기
// width는 distance == 0을 기준으로 한쪽 방향의 반쪽 두께
float maskStrokeAA(float distance, float width) {
    float w = sdfAAWidth(distance);
    float halfWidth = max(width, 0.0);
    return 1.0 - smoothstep(halfWidth - w, halfWidth + w, abs(distance));
}

// 사용자가 지정한 폭으로 soft stroke mask 만들기
float maskStrokeSoft(float distance, float width, float softness) {
    float w = max(softness, sdfAAWidth(distance));
    float halfWidth = max(width, 0.0);
    return 1.0 - smoothstep(halfWidth - w, halfWidth + w, abs(distance));
}

// ImGui style 값을 사용해서 fill과 stroke mask를 따로 계산
// fill/stroke를 직접 다른 방식으로 합성하거나 색칠하고 싶을 때만 사용
// 표준 최종 카드 색을 원하면 mask(distance)를 사용
CardMaskParts cardMaskParts(float distance) {
    float softness = max(uCardStyle.y, 0.0);
    float strokeWidth = max(uCardStyle.z, 0.0);

    CardMaskParts parts;
    parts.fill = softness <= 0.0 ? maskFillAA(distance) : maskFillSoft(distance, softness);
    parts.stroke = softness <= 0.0 ? maskStrokeAA(distance, strokeWidth)
                                   : maskStrokeSoft(distance, strokeWidth, softness);
    return parts;
}

// ImGui style만 반영한 단일 0..1 mask를 반환한다. 색은 적용하지 않음
// Fill/Stroke/Fill+Stroke 동작은 쓰되 색칠은 직접 하고 싶을 때 사용
// 일반적인 카드 출력에는 mask(distance)를 사용
float cardMask(float distance) {
    int styleMode = (int)round(uCardStyle.x);
    CardMaskParts parts = cardMaskParts(distance);

    if (styleMode == 1) return parts.stroke;
    if (styleMode == 2) return saturate(max(parts.fill, parts.stroke));
    return parts.fill;
}

#endif
