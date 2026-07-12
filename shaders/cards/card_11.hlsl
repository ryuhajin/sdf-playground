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

float4 main(PSIn i) : SV_Target
{
    // GLSL의 gl_FragCoord.xy / u_resolution.xy에 해당한다.
    // 이 프로젝트에서는 pixel shader 입력 i.uv가 이미 0..1 화면 좌표다.
    float2 st = i.uv;

    // 화면이 가로로 넓거나 세로로 길어도 noise가 늘어나 보이지 않도록
    // 원문처럼 x축에 화면 비율을 곱한다.
    float aspect = uTimeRes.z / max(uTimeRes.w, 1.0);
    st.x *= aspect;

    // baseScale은 첫 octave의 전체 무늬 크기다.
    // 값이 작으면 큰 덩어리가 보이고, 값이 크면 더 촘촘한 무늬부터 시작한다.
    float baseScale = 3.0;

    // 2D FBM은 화면의 각 픽셀 위치마다 Fbm2D(st)를 계산해서 밝기로 사용한다.
    // 1D 그래프에서는 y = noise(x)였지만,
    // 여기서는 color = noise(float2(x, y))라서 화면 전체가 질감으로 채워진다.
    float n = Fbm2D(st * baseScale);

    float3 color = float3(n, n, n);
    return float4(saturate(color), 1.0);
}
