#include "../lib/sdf_common.hlsli"

// Author @patriciogv - 2015
// http://patriciogonzalezvivo.com
//
// The Book of Shaders 13장 FBM 예제를 DirectX11 HLSL로 옮긴 학습용 카드.

#define OCTAVES 6

float Random2D(float2 st)
{
    // random은 완성된 noise가 아니다.
    // 2D 좌표 하나를 넣으면 0..1 사이의 "고정된 랜덤값" 하나를 돌려주는 재료 함수다.
    //
    // dot(st, float2(...))는 2D 좌표를 하나의 숫자로 섞고,
    // sin과 큰 곱셈값은 그 숫자를 불규칙하게 흔든다.
    // 마지막 frac은 소수 부분만 남겨 0..1 범위로 만든다.
    return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

float Noise2D(float2 st)
{
    // 1D noise는 noise(x)처럼 x 하나를 넣고 선의 높이를 만든다.
    // 2D noise는 noise(float2(x, y))처럼 화면의 가로/세로 위치를 둘 다 넣고
    // 그 위치의 밝기 또는 높이값을 만든다.

    // st가 들어 있는 정수 격자 칸을 찾는다.
    // i는 현재 칸의 왼쪽 아래 정수 좌표, f는 칸 안에서의 0..1 지역 좌표다.
    float2 i = floor(st);
    float2 f = frac(st);

    // 현재 칸의 네 모서리에 랜덤값을 붙인다.
    // 완전 랜덤을 픽셀마다 바로 쓰면 TV 잡음처럼 거칠지만,
    // 모서리 값만 랜덤으로 두고 그 사이를 부드럽게 섞으면 덩어리진 흐름이 생긴다.
    float a = Random2D(i);
    float b = Random2D(i + float2(1.0, 0.0));
    float c = Random2D(i + float2(0.0, 1.0));
    float d = Random2D(i + float2(1.0, 1.0));

    // f를 그대로 보간값으로 쓰면 격자 경계에서 변화가 딱딱하게 느껴진다.
    // S자 곡선으로 바꿔서 각 칸의 시작과 끝이 부드럽게 이어지게 한다.
    float2 u = f * f * (3.0 - 2.0 * f);

    // GLSL 원문의 mix는 HLSL의 lerp와 같다.
    // 아래 식은 네 모서리 값을 x/y 방향으로 부드럽게 섞는 bilinear interpolation이다.
    return lerp(a, b, u.x)
        + (c - a) * u.y * (1.0 - u.x)
        + (d - b) * u.x * u.y;
}

float Fbm2D(float2 st)
{
    // FBM(fractal Brownian motion)은 noise를 여러 층(octave)으로 더하는 방식이다.
    // 큰 흐름을 만드는 낮은 주파수 noise 위에,
    // 더 촘촘한 작은 디테일을 만드는 높은 주파수 noise를 계속 얹는다.

    float value = 0.0;

    // amplitude는 현재 octave가 최종 결과에 얼마나 세게 더해지는지 정한다.
    // 첫 octave는 큰 흐름이므로 비교적 크게 시작한다.
    float amplitude = 0.5;

    // lacunarity는 octave가 올라갈 때 좌표 스케일이 얼마나 커지는지 정한다.
    // 2.0이면 다음 층은 이전 층보다 noise를 두 배 촘촘하게 읽는다.
    float lacunarity = 2.0;

    // gain은 octave가 올라갈 때 amplitude가 얼마나 남는지 정한다.
    // 값이 작으면 높은 octave의 촘촘한 디테일이 빨리 약해져 부드러워지고,
    // 값이 크면 촘촘한 디테일이 강하게 남아서 더 빽빽하고 거칠게 보인다.
    float gain = 0.5;

    [unroll]
    for (int octave = 0; octave < OCTAVES; ++octave)
    {
        value += amplitude * Noise2D(st);

        // 다음 octave에서는 같은 noise 함수를 더 작은 크기로 다시 읽는다.
        // 좌표를 키우면 화면 안에서 noise 패턴이 더 자주 반복되므로 주파수가 올라간다.
        st *= lacunarity;

        // 높은 octave의 디테일은 보통 점점 약하게 더한다.
        amplitude *= gain;
    }

    return value;
}

// ---------------------------------------------------------------------------
// card 11 · Topographic Map (기본) / Heightmap Terrain (CARD11_MODE 0)
// fBm 값을 "높이"로 읽는다.
// - Topographic Map: 같은 높이를 잇는 등고선만 그리고 지형을 천천히 흘려보낸다.
// - Heightmap Terrain: 이웃 위치와의 높이 차이로 노멀을 구해 방향광으로 셰이딩한다.
// 이전 버전(fBm 밝기 그대로 출력)은 card_11_fbm_backup.hlsl에 보관했다.
// ---------------------------------------------------------------------------

// 0 = 흑백 라이팅, 1 = 높이별 색(물·모래·풀·바위·눈)
#define TERRAIN_COLOR 1

float TerrainHeight(float2 p)
{
    // 카드 좌표 p를 fBm 좌표로 바꿔 0..1 높이를 얻는다.
    return Fbm2D(p * 1.4 + float2(3.7, 1.3));
}

float3 TerrainNormal(float2 p, float heightScale)
{
    // 전방 차분(finite difference): x, y로 아주 조금 옮긴 위치의 높이와 비교해 기울기를 구한다.
    // 기울기가 크면 노멀이 옆으로 눕고, 평평하면 위(z)를 향한다.
    // e가 너무 작으면 가장 촘촘한 옥타브까지 그대로 잡혀 표면이 자글거린다.
    const float e = 0.008;
    float h = TerrainHeight(p);
    float hx = TerrainHeight(p + float2(e, 0.0));
    float hy = TerrainHeight(p + float2(0.0, e));
    return normalize(float3(-(hx - h) * heightScale, -(hy - h) * heightScale, e));
}

// 0 = Heightmap Terrain, 1 = Topographic Map
#define CARD11_MODE 1

float4 TopographicMap(float2 p, float t)
{
    // fBm 높이의 등고선(같은 높이를 잇는 선)만 그린다.
    // 좌표를 천천히 흘려보내 지형이 한 방향으로 흘러가듯 움직인다.
    // 등고선은 촘촘한 옥타브까지 쓰면 작은 고리가 너무 많이 생긴다.
    // 그래서 앞의 4옥타브만 더해 큰 지형 흐름만 남긴다.
    float2 q = (p + float2(t * 0.035, t * 0.02)) * 1.4 + float2(3.7, 1.3);
    float h = 0.0;
    float amp = 0.5;
    [unroll]
    for (int o = 0; o < 4; ++o)
    {
        h += amp * Noise2D(q);
        q *= 2.0;
        amp *= 0.5;
    }
    h /= 0.9375; // 4옥타브 진폭 합(0.5+0.25+0.125+0.0625)으로 나눠 0..1로 맞춘다

    // 높이를 LEVELS 단계로 나누고, 각 단계 경계(정수 값)에 선을 긋는다.
    // fwidth로 화면 픽셀 크기에 맞춘 두께를 써서 어디서든 선 굵기가 일정하다.
    const float LEVELS = 20.0;
    float v = h * LEVELS;
    float dv = max(fwidth(v), 1e-4);
    float dist = abs(frac(v + 0.5) - 0.5);          // 가장 가까운 등고선까지의 거리(단계 단위)

    // 5단계마다 굵은 주곡선(index contour), 나머지는 얇은 계곡선
    float major = step(abs(fmod(floor(v + 0.5), 5.0)), 0.5);
    float width = lerp(0.9, 1.8, major);
    float contour = 1.0 - smoothstep(width * 0.5 * dv, (width * 0.5 + 1.0) * dv, dist);

    // 높을수록 선을 밝게 해서 봉우리가 도드라져 보이게 한다.
    float bright = lerp(0.45, 1.0, smoothstep(0.35, 0.75, h));
    float lineCol = contour * bright * lerp(0.75, 1.0, major);

    // 아주 옅은 높이 톤을 깔아 선 사이의 기복을 느끼게 한다.
    float tint = smoothstep(0.30, 0.80, h) * 0.08;
    return float4(saturate(lineCol + tint).xxx, 1.0);
}

float4 main(PSIn i) : SV_Target
{
    float2 p = fitUV(i.uv);
    float t = uCardTime;

#if CARD11_MODE == 1
    return TopographicMap(p, t);
#endif

    // 1단계: 높이. 물 높이(waterLevel) 아래는 평평한 수면으로 자른다.
    const float waterLevel = 0.47;
    float h = TerrainHeight(p);
    bool water = h < waterLevel;

    // 2단계: 노멀. heightScale이 클수록 지형이 가파르게 보인다. 수면은 위를 향하는 평면이다.
    float3 n = water ? float3(0.0, 0.0, 1.0) : TerrainNormal(p, 0.7);

    // 3단계: 방향광. 태양이 8초에 한 바퀴 돌며 비스듬히 비춰 명암이 바뀐다.
    float a = t * TWO_PI / 8.0;
    float3 L = normalize(float3(cos(a), sin(a), 0.75));
    float diffuse = saturate(dot(n, L));

#if TERRAIN_COLOR
    // 높이별 색 램프
    float3 albedo = lerp(float3(0.78, 0.72, 0.52), float3(0.30, 0.52, 0.22), smoothstep(0.48, 0.52, h)); // 모래 → 풀
    albedo = lerp(albedo, float3(0.45, 0.40, 0.36), smoothstep(0.58, 0.63, h));                          // 바위
    albedo = lerp(albedo, float3(0.95, 0.95, 0.97), smoothstep(0.66, 0.70, h));                          // 눈
    float3 waterCol = lerp(float3(0.05, 0.16, 0.30), float3(0.15, 0.40, 0.55), smoothstep(0.30, waterLevel, h));
    float3 col = water ? waterCol * (0.6 + 0.4 * diffuse) : albedo * (0.18 + 0.82 * diffuse);
#else
    // 흑백: 수면은 어두운 회색, 지형은 라이팅 명암 + 높이에 따라 조금 밝게
    float lit = 0.10 + 0.90 * diffuse;
    float3 col = water ? (0.10 + 0.10 * smoothstep(0.30, waterLevel, h)).xxx
                       : (lit * lerp(0.75, 1.0, smoothstep(waterLevel, 0.7, h))).xxx;
#endif

    // 4단계: 해안선. 물 경계를 한 픽셀 폭으로 부드럽게 잇는다.
    float shore = 1.0 - smoothstep(0.0, fwidth(h) * 1.5, abs(h - waterLevel));
    col = lerp(col, col * 0.6, shore);

    // 아래 return 줄을 하나씩 주석 해제하면 단계별 결과를 볼 수 있다.
    // return float4(h.xxx, 1.0);                 // 1단계: 높이(fBm 원본)
    // return float4(n * 0.5 + 0.5, 1.0);         // 2단계: 노멀 (노멀맵처럼 보인다)
    // return float4(diffuse.xxx, 1.0);           // 3단계: 방향광 명암

    return float4(saturate(col), 1.0);
}
