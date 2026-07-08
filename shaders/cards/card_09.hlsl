#include "../lib/sdf_common.hlsli"

float Random2D(float2 st)
{
    // dot: x,y 좌표를 숫자 하나처럼 섞기
    // sin: 섞인 숫자를 크게 흔들기
    // frac: 소수점 아래만 남겨서 0~1 사이 값처럼 만든다
    return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

float ValueNoise2D(float2 st)
{
    float2 i = floor(st);
    float2 f = frac(st);

    // 현재 칸의 네 모서리에 각각 랜덤 밝기값을 붙임
    // a: 왼쪽 아래, b: 오른쪽 아래, c: 왼쪽 위, d: 오른쪽 위
    float a = Random2D(i);
    float b = Random2D(i + float2(1.0, 0.0));
    float c = Random2D(i + float2(0.0, 1.0));
    float d = Random2D(i + float2(1.0, 1.0));

    // smoothstep(0, 1, f)와 같음
    float2 u = f * f * (3.0 - 2.0 * f);

    // 아래쪽 두 모서리 a,b를 x 방향으로 섞고,
    // 위쪽 두 모서리 c,d도 x 방향으로 섞은 다음,
    // 그 두 줄을 y 방향으로 다시 섞는다
    float bottom = lerp(a, b, u.x);
    float top = lerp(c, d, u.x);
    return lerp(bottom, top, u.y);
}

// gradient noise는 모서리에 "방향 화살표"를 붙임
// 이 함수는 각 격자 모서리마다 -1~1 범위의 float2를 만들어서
// 왼쪽/오른쪽/위/아래를 가리키는 랜덤 방향처럼 사용
float2 RandomGradient2D(float2 st)
{
    st = float2(
        dot(st, float2(127.1, 311.7)),
        dot(st, float2(269.5, 183.3))
    );

    return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
}

// 2D gradient noise
float GradientNoise2D(float2 st)
{
    float2 i = floor(st);
    float2 f = frac(st);

    // value noise와 똑같이 부드러운 S자 곡선으로 섞기
    float2 u = f * f * (3.0 - 2.0 * f);

    //  현재 픽셀이 그 모서리에서 어느 방향으로 떨어져 있는지 거리 벡터를 만든다
    //  dot(랜덤 방향 백터, 거리 벡터)를 하면 화살표가 픽셀 쪽을 얼마나 바라보는지 값 도출
    // 따라서 gradient noise는 단순 밝기값을 섞는 것보다 흐름과 결이 더 자연스러움
    float bottomLeft = dot(
        RandomGradient2D(i + float2(0.0, 0.0)),
        f - float2(0.0, 0.0)
    );

    float bottomRight = dot(
        RandomGradient2D(i + float2(1.0, 0.0)),
        f - float2(1.0, 0.0)
    );

    float topLeft = dot(
        RandomGradient2D(i + float2(0.0, 1.0)),
        f - float2(0.0, 1.0)
    );

    float topRight = dot(
        RandomGradient2D(i + float2(1.0, 1.0)),
        f - float2(1.0, 1.0)
    );

    // 네 모서리에서 만든 dot 값을 value noise처럼 x 방향, y 방향 순서로 섞는다.
    float bottom = lerp(bottomLeft, bottomRight, u.x);
    float top = lerp(topLeft, topRight, u.x);
    return lerp(bottom, top, u.y);
}

// noise 값을 색으로 바로 쓰지 않고, 현재 좌표 pos를 얼마나 회전시킬지 정하는 각도로 사용
float2 Rotate2D(float2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);

    return float2(
        c * p.x - s * p.y,
        s * p.x + c * p.y
    );
}

// pos.x 방향으로 sin 줄무늬를 만들고, smoothstep으로 줄의 경계를 부드럽게 만든다
float Lines(float2 pos, float b)
{
    float scale = 10.0;
    pos *= scale;

    return smoothstep(
        0.0,
        0.5 + b * 0.5,
        abs((sin(pos.x * 3.1415) + b * 2.0)) * 0.5
    );
}


// ------------------------------------------------------------
// 4. Animated Noise Splatter
// ------------------------------------------------------------
// 임계값은 "어떤 noise 높이를 도형으로 뽑을지"를 정한다.
// 그래서 임계값만 바꾸면 얼룩의 크기와 경계는 달라지지만, 무늬가 살아 움직이지는 않는다.
//
// 움직임은 noise를 읽는 좌표에 시간을 더해서 만든다.
// 같은 noise 함수라도 st + time 위치를 읽으면 시간이 지나며 다른 부분을 천천히 훑는 것처럼 보인다.
// 큰 noise는 전체 얼룩의 흐름을 만들고, 작은 noise는 표면의 튐 자국과 구멍 디테일을 만든다.
float4 main(PSIn i) : SV_Target
{
    float2 st = i.uv;

    float t = uCardTime * 0.12;

    // 큰 흐름용 좌표 왜곡
    // 화면의 픽셀을 직접 옮기는 것이 아니라, 이후 noise를 읽을 좌표를 살짝 밀어 줌
    st += GradientNoise2D(st * 7.0 + float2(t, -t)) * 0.35;

    // 큰 검은 얼룩
    // smoothstep의 두 숫자는 threshold 문턱값이다
    float bigDrops = smoothstep(
        0.01,
        0.3,
        GradientNoise2D(st + float2(t * 2.2, -t * 0.3))
    );

    // 작은 튐 자국
    // st * 10.0은 noise를 더 촘촘한 스케일로 읽어서 작은 디테일을 만든다.
    float splatter = smoothstep(
        0.15,
        0.2,
        GradientNoise2D(st * 10.0 + float2(-t, t * 0.7))
    );

    // 튐 자국 안의 구멍
    // 같은 작은 noise의 더 높은 구간을 빼서 빈 영역처럼 보이게 함
    float holes = smoothstep(
        0.35,
        0.4,
        GradientNoise2D(st * 28.0 + float2(t * 0.6, -t))
    );

    float3 color = float3(1.0, 1.0, 1.0) * bigDrops;
    color += splatter;
    color -= holes;

    return float4(1.0 - color, 1.0);
}
