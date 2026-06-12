#ifndef SDF_ANIMATION_HLSLI
#define SDF_ANIMATION_HLSLI

#include "sdf_common.hlsli"

// 0..1 사이를 sin으로 왕복하는 기본 펄스. speed는 시간 배율이다.
float pulse(float t, float speed) {
    return 0.5 + 0.5 * sin(t * speed);
}

// 위치 x와 시간 t를 섞은 0..1 파동. f가 클수록 공간 주기가 촘촘해진다.
float wave(float x, float t, float f) {
    return 0.5 + 0.5 * sin(x * f + t);
}

// 0..1 입력을 부드러운 시작/끝 곡선으로 바꾼다.
float ease01(float t) {
    t = saturate(t);
    return t * t * (3.0 - 2.0 * t);
}

// ease01보다 더 강한 cubic ease-in-out.
float easeInOutCubic(float t) {
    t = saturate(t);
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5;
}

// 0..1..0으로 튀는 값. 간단한 크기 변화나 깜빡임에 쓴다.
float bounce(float t) {
    return abs(sin(t * 3.1415926));
}

// lo와 hi 사이를 pulse로 왕복한다.
float oscillate(float lo, float hi, float t, float speed) {
    return lerp(lo, hi, pulse(t, speed));
}

// 전역 ImGui Animation mode를 카드에서 간단히 재사용하기 위한 dispatch 함수.
float animDispatch(float t) {
    int mode = uRenderFlags.y;
    if (mode == 0) return pulse(t, 2.0);
    if (mode == 1) return 0.5 + 0.5 * sin(t * 1.5);
    if (mode == 2) return bounce(t * 0.5);
    return oscillate(0.0, 1.0, t, 1.0);
}

#endif
