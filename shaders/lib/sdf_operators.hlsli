#ifndef SDF_OPERATORS_HLSLI
#define SDF_OPERATORS_HLSLI

// SDF boolean 조합. 더 작은 distance가 더 안쪽인 도형을 의미한다.

// 두 도형을 합친다.
float opUnion(float a, float b)  { return min(a, b); }

// a에서 b를 뺀다.
float opSub(float a, float b)    { return max(a, -b); }

// 두 도형이 겹치는 영역만 남긴다.
float opInter(float a, float b)  { return max(a, b); }

// 부드러운 union. k가 클수록 두 도형 사이가 더 넓게 섞인다.
float opSMin(float a, float b, float k) {
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// 부드러운 intersection/subtraction 계열을 만들 때 쓰는 smooth max.
float opSMax(float a, float b, float k) {
    float h = saturate(0.5 - 0.5 * (b - a) / k);
    return lerp(b, a, h) + k * h * (1.0 - h);
}

// 도형 경계를 중심으로 껍질을 만든다. stroke와 비슷하지만 distance 자체를 바꾼다.
float opOnion(float d, float r) { return abs(d) - r; }

// 도형을 r만큼 둥글게 확장한다. 양수 r은 바깥으로 부풀린다.
float opRound(float d, float r) { return d - r; }

#endif
