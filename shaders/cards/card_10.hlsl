#include "../lib/sdf_common.hlsli"

// card 10 · Layered Triangle Dissolve
// 정삼각형 여러 겹을 조금씩 어긋나게 쌓은 흑백 마스크를 만들고,
// simplex noise로 층 경계를 떨리게 한 뒤 흑백 불씨의 dissolve(타들어 가며 사라지는) 효과를 입힌다.
// 이전 버전(동심 삼각형 라인)은 card_10_triangle_backup.hlsl에 보관했다.

float3 Random3(float3 c)
{
    // 3D 좌표 하나를 넣으면 항상 같은 가짜 랜덤 방향을 돌려준다.
    float j = 4096.0 * sin(dot(c, float3(17.0, 59.4, 15.0)));

    float3 r;
    r.z = frac(512.0 * j);
    j *= 0.125;
    r.x = frac(512.0 * j);
    j *= 0.125;
    r.y = frac(512.0 * j);

    return r - 0.5;
}

float SNoise3D(float3 p)
{
    // 3D simplex noise. 결과는 대략 [-1, 1] 범위다.
    // p.xy는 카드 위치, p.z는 시간으로 써서 무늬가 제자리에서 천천히 변하게 한다.
    const float F3 = 0.3333333;
    const float G3 = 0.1666667;

    float3 s = floor(p + dot(p, float3(F3, F3, F3)));
    float3 x = p - s + dot(s, float3(G3, G3, G3));

    float3 e = step(float3(0.0, 0.0, 0.0), x - x.yzx);
    float3 i1 = e * (1.0 - e.zxy);
    float3 i2 = 1.0 - e.zxy * (1.0 - e);

    float3 x1 = x - i1 + G3;
    float3 x2 = x - i2 + 2.0 * G3;
    float3 x3 = x - 1.0 + 3.0 * G3;

    float4 w;
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    w = max(0.6 - w, 0.0);

    float4 d;
    d.x = dot(Random3(s), x);
    d.y = dot(Random3(s + i1), x1);
    d.z = dot(Random3(s + i2), x2);
    d.w = dot(Random3(s + float3(1.0, 1.0, 1.0)), x3);

    w *= w;
    w *= w;
    d *= w;

    return dot(d, float4(52.0, 52.0, 52.0, 52.0));
}

float Fbm3(float3 p)
{
    // simplex noise 3옥타브. 큰 덩어리가 소멸 모양을 정하고 작은 옥타브가 가장자리를 너덜너덜하게 만든다.
    float sum = 0.0;
    float amp = 0.5;
    [unroll]
    for (int k = 0; k < 3; ++k)
    {
        sum += SNoise3D(p) * amp;
        p = p * 2.03 + float3(1.7, 9.2, 0.0);
        amp *= 0.5;
    }
    return sum;
}

float SegmentDistance(float2 p, float2 a, float2 b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float h = saturate(dot(pa, ba) / max(dot(ba, ba), 0.0001));
    return length(pa - ba * h);
}

float Cross2D(float2 a, float2 b)
{
    return a.x * b.y - a.y * b.x;
}

float TriangleSDF(float2 p, float size)
{
    // 정삼각형 SDF. 안쪽은 음수, 바깥은 양수.
    // 꼭짓점: 위 (0, size), 아래 두 점 (±0.866·size, -0.5·size). 무게중심이 원점이다.
    float2 top = float2(0.0, size);
    float2 left = float2(-0.8660254 * size, -0.5 * size);
    float2 right = float2(0.8660254 * size, -0.5 * size);

    float edge = min(SegmentDistance(p, top, left), min(SegmentDistance(p, left, right), SegmentDistance(p, right, top)));
    float s0 = Cross2D(left - top, p - top);
    float s1 = Cross2D(right - left, p - left);
    float s2 = Cross2D(top - right, p - right);
    float inside = step(0.0, min(s0, min(s1, s2)));
    return lerp(edge, -edge, inside);
}

float4 main(PSIn i) : SV_Target
{
    float2 p = applyCardShapeTransform(fitUV(i.uv));
    float t = uCardTime;

    // 1단계: 바깥 정삼각형 SDF. 중심을 -0.23 내리면 삼각형의 외접 박스가 카드 중앙에 온다.
    // simplex noise로 경계를 살짝 떨리게 한다. 모든 줄이 같은 노이즈를 쓰므로 줄끼리 붙거나 끊기지 않는다.
    const float OUTER_SIZE = 0.92;
    const int BANDS = 6;          // 흰 줄 + 검은 줄을 합친 겹 수 (흰-검-흰-검-흰-검)
    const float BAND_WIDTH = 0.05;
    float2 q = p - float2(0.0, -0.23);
    float wobble = SNoise3D(float3(p * 5.0, t * 0.25)) * 0.004;
    float outerD = TriangleSDF(q, OUTER_SIZE) + wobble;

    // 2단계: 삼각형 안쪽으로 들어간 거리를 같은 폭의 구간으로 나눈다.
    // 정삼각형 안에서 "세 변까지의 최소 거리"가 같은 점들은 다시 정삼각형을 이루므로,
    // 이 거리를 일정 폭으로 자르면 세 변 모두 같은 두께의 동심 삼각형 줄이 된다.
    float inward = -outerD;
    float bandPos = inward / BAND_WIDTH;          // 0~6 구간이 줄 영역
    float bandPx = max(fwidth(bandPos), 1e-4);

    // 짝수 구간 = 흰색, 홀수 구간 = 검은색. 구간 경계는 한 픽셀 폭으로 부드럽게 자른다.
    float stripe = frac(bandPos * 0.5);           // 0~0.5 흰 구간, 0.5~1 검은 구간
    float white = smoothstep(0.5 + bandPx * 0.5, 0.5 - bandPx * 0.5, stripe) * smoothstep(0.0, bandPx * 0.5, stripe);

    // 줄 영역(0 < inward < 6구간) 밖은 모두 검은색. 가운데는 뚫린 구멍이다.
    float inBands = aa(outerD) * aa(inward - BANDS * BAND_WIDTH);
    // 흰 줄은 마지막 검은 줄 전까지만 존재한다. 구멍 경계에서 흰색이 새어 나와 회색 선이 생기는 것을 막는다.
    white *= aa(inward - (BANDS - 1) * BAND_WIDTH);
    float3 col = float3(0.94, 0.94, 0.94) * white * inBands;
    float shapeMask = inBands;

    // 3단계: dissolve 임계값. 10초 주기로 "채워짐 → 타들어 감 → 사라짐 → 다시 채워짐"을 왕복한다.
    float tri = abs(frac(t / 10.0) * 2.0 - 1.0);
    float sweep = smoothstep(0.15, 0.85, 1.0 - tri);
    float threshold = lerp(0.1, 0.9, sweep);

    // 4단계: 소멸 순서. fBm 대비를 키워 0~1에 고르게 퍼뜨리고 아래→위 기울기를 섞는다.
    float n = Fbm3(float3(p * 2.2, t * 0.15));
    float order = saturate(0.5 + n * 0.85 + p.y * 0.3);

    // 5단계: 남은 영역과 불씨 띠
    float diff = order - threshold;
    float px = max(fwidth(diff), 1e-4);
    float alive = smoothstep(-px, px, diff);

    float edgeWidth = 0.075;
    float burn = saturate(1.0 + diff / edgeWidth) * (1.0 - alive);
    // 불씨 색(흑백): 식은 쪽은 짙은 회색, 경계에 가까울수록 밝은 회색 → 흰빛
    float3 ember = lerp(float3(0.12, 0.12, 0.12), float3(0.55, 0.55, 0.55), smoothstep(0.0, 0.6, burn));
    ember = lerp(ember, float3(1.0, 1.0, 1.0), smoothstep(0.75, 1.0, burn));

    // 6단계: 합성. 층 그림은 남은 영역에만, 불씨는 도형 안쪽에만 보인다.
    float3 finalCol = col * alive + ember * burn * 1.6 * shapeMask;

    // 아래 return 줄을 하나씩 주석 해제하면 단계별 결과를 볼 수 있다.
    // return float4(col, 1.0);                        // 2단계: 쌓인 삼각형 층
    // return float4(order.xxx, 1.0);                  // 4단계: 소멸 순서(노이즈 + 기울기)
    // return float4(burn.xxx * shapeMask, 1.0);       // 5단계: 불씨 띠

    return float4(finalCol, 1.0);
}
