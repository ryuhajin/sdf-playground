#include "../lib/sdf_common.hlsli"

float ShapeN(float2 st, float sideCount)
{
    // st는 0..1 범위의 작은 공간이다.
    // 먼저 중심이 (0, 0)이 되도록 -1..1 좌표로 바꾼다.
    st = st * 2.0 - 1.0;

    // 보통 각도는 atan2(st.y, st.x)로 구하지만,
    // 여기서는 x/y를 일부러 바꿔 넣어서 각도 0의 기준을 +x 오른쪽이 아니라 +y 위쪽으로 둠
    // +PI는 atan2의 -PI..PI 범위를 0..TWO_PI 범위로 옮겨,
    // 아래에서 각도를 변 개수로 나누기 쉽게 만든다

    // 각도 a는 현재 픽셀이 중심에서 어느 방향에 있는지를 뜻함
    float a = atan2(st.x, st.y) + PI;

    // r은 한 변이 차지하는 각도 폭
    // sideCount가 4면 360도를 4등분하므로 사각형 기준 각도
    float r = TWO_PI / sideCount;

    // floor(0.5 + a / r)는 현재 각도 a가 어느 변 방향에 가장 가까운지 고름
    // cos(...) * length(st)는 "N각형 중심에서 현재 점까지의 거리장"처럼 쓸 수 있음
    return cos(floor(0.5 + a / r) * r - a) * length(st);
}

float BoxShape(float2 st, float2 size)
{
    // 사각형은 ShapeN에 sideCount 4를 넣음
    // size를 곱해 셀 내부에서 사각형이 차지하는 폭을 조절
    return ShapeN(st * size, 4.0);
}

float PatternBit(float pattern, float bitIndex)
{
    // pattern은 0..63 사이의 숫자다.
    // 2진수로 보면 6개의 on/off 스위치를 담을 수 있다.
    //
    // 예: 13 = 001101
    // bit 0 = 1, bit 1 = 0, bit 2 = 1, bit 3 = 1 ...
    float shifted = floor(pattern / exp2(bitIndex));
    return fmod(shifted, 2.0);
}

float PatternBox(float2 fpos, float enabled)
{
    // enabled가 1이면 조금 더 크고 오른쪽으로 민 사각형을 쓴다.
    // enabled가 0이면 폭이 조금 좁은 사각형을 쓴다.
    //
    // 이 차이 때문에 시간이 바뀔 때 각 줄의 사각형 상태가 바뀌는 것처럼 보인다.
    if (enabled > 0.5)
    {
        return BoxShape(fpos - float2(0.03, 0.0), float2(1.0, 1.0));
    }

    return BoxShape(fpos, float2(0.84, 1.0));
}

float HexPattern(float2 st, float pattern)
{
    // 육각형을 그리는 함수라기보다, 0..63 숫자 하나를 6개의 줄 on/off 패턴으로 해석하는 함수
    // x는 2칸, y는 6칸으로 나눔
    // 각 y줄마다 하나의 사각형 거리장을 만들고, pattern의 bit가 그 상태를 정함
    st *= float2(1.0, 1.0);

    float2 fpos = frac(st);  // 현재 칸 내부의 0..1 좌표
    float2 ipos = floor(st); // 현재 칸 번호

    // 오른쪽 열은 x를 뒤집어서 좌우가 마주보는 패턴처럼 만들기
    // if (ipos.x == 1.0)
    // {
    //     fpos.x = 1.0 - fpos.x;
    // }

    // y줄은 0..5만 사용
    // 화면 밖으로 넘어간 값은 가장자리 줄로 고정
    float row = clamp(ipos.y, 0.0, 5.0);
    float enabled = PatternBit(floor(fmod(pattern, 64.0)), row);

    return PatternBox(fpos, enabled);
}

float3 Random3(float3 c)
{
    // 3D 좌표 하나를 넣으면 항상 같은 랜덤 방향을 돌려줌
    float j = 4096.0 * sin(dot(c, float3(17.0, 59.4, 15.0)));

    float3 r;
    r.z = frac(512.0 * j);
    j *= 0.125;
    r.x = frac(512.0 * j);
    j *= 0.125;
    r.y = frac(512.0 * j);

    // 0..1 값을 -0.5..0.5 근처의 방향값으로 바꿈
    return r - 0.5;
}

float SNoise3D(float3 p)
{
    // 3D simplex noise
    // p.xy는 화면 위치, p.z는 시간으로 쓰면 2D 무늬가 시간축을 따라 천천히 변함
    const float F3 = 0.3333333;
    const float G3 = 0.1666667;

    // 1) 현재 점 p가 들어 있는 simplex 격자 칸을 찾는다.
    // 3D simplex의 기본 셀은 정육면체가 아니라 사면체에 가깝다.
    float3 s = floor(p + dot(p, float3(F3, F3, F3)));

    // 2) 현재 점에서 첫 번째 꼭짓점까지의 상대 좌표를 구한다.
    float3 x = p - s + dot(s, float3(G3, G3, G3));

    // 3) x/y/z 크기 비교로 나머지 세 꼭짓점의 순서를 정한다.
    // 큰 축부터 이동해야 현재 점이 들어 있는 사면체의 꼭짓점들을 고를 수 있다.
    float3 e = step(float3(0.0, 0.0, 0.0), x - x.yzx);
    float3 i1 = e * (1.0 - e.zxy);
    float3 i2 = 1.0 - e.zxy * (1.0 - e);

    // 4) 네 꼭짓점에서 현재 점까지의 상대 좌표다.
    float3 x1 = x - i1 + G3;
    float3 x2 = x - i2 + 2.0 * G3;
    float3 x3 = x - 1.0 + 3.0 * G3;

    // 5) 각 꼭짓점의 영향력이다.
    // 가까운 꼭짓점은 크게, 먼 꼭짓점은 0에 가깝게 만든다.
    float4 w;
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    w = max(0.6 - w, 0.0);

    // 6) 각 꼭짓점에 붙은 가짜 랜덤 방향과 현재 점 방향을 dot으로 비교한다.
    // 방향이 비슷하면 양수, 반대면 음수, 직각에 가까우면 0에 가까워진다.
    float4 d;
    d.x = dot(Random3(s), x);
    d.y = dot(Random3(s + i1), x1);
    d.z = dot(Random3(s + i2), x2);
    d.w = dot(Random3(s + float3(1.0, 1.0, 1.0)), x3);

    // 7) 영향력을 여러 번 곱하면 가장자리가 부드럽게 사라진다.
    // 그래서 셀 경계에서 값이 갑자기 끊기지 않는다.
    w *= w;
    w *= w;
    d *= w;

    // 8) 네 꼭짓점의 기여도를 합쳐 최종 노이즈 값 하나를 만든다.
    return dot(d, float4(52.0, 52.0, 52.0, 52.0));
}

float4 main(PSIn i) : SV_Target
{
    float2 st = i.uv;

    // 시간은 카드마다 따로 흐르는 uCardTime을 쓴다.
    float t = uCardTime * 0.5;

    // 0..63 패턴이 한 칸씩 바뀌면 너무 딱딱하므로,
    // 현재 패턴과 다음 패턴을 frac(t)만큼 섞어서 부드럽게 넘어가게 한다.
    float currentPattern = floor(t);
    float nextPattern = currentPattern + 1.0;
    float df = lerp(
        HexPattern(st, currentPattern),
        HexPattern(st, nextPattern),
        frac(t)
    );

    // 거리장에 더할 작은 simplex noise
    // st * n : 요철이 얼마나 촘촘한지 정함
    // t * n: 시간축을 천천히 움직여 외곽이 살아 있는 듯 변하게 함
    // 0.37: 외곽을 밀고 당기는 힘. 크게 하면 더 찢어진 듯 보임
    float edgeNoise = SNoise3D(float3(st * 60.0, t * 0.1)) * 0.37;
    float noisyDf = df + edgeNoise;

    // 반듯한 외곽은 step(0.7, df)처럼 같은 기준선으로 자를 때 생김
    // 오돌토돌한 외곽은 step(0.7, df + edgeNoise)처럼 거리장에 작은 노이즈를 더해 만들기
    // 어떤 곳은 기준선을 넘고, 어떤 곳은 못 넘어서 경계가 밀리고 당겨짐
    float threshold = 0.62;
    float finalMask = step(threshold, noisyDf);

    // 아래 줄들을 하나씩 주석 해제해서 화면에 그려지는 절차를 확인

    // return float4(df.xxx, 1.0); // 거리장 확인
    // return float4((SNoise3D(float3(st * 75.0, t * 2.0)) * 0.5 + 0.5).xxx, 1.0); // 노이즈 확인
    // return float4(noisyDf.xxx, 1.0); // 노이즈가 더해진 거리장 확인

    return float4(finalMask.xxx, 1.0);  //최종 오돌토돌한 외곽
}
