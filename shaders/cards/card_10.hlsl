#include "../lib/sdf_common.hlsli"

float2 Skew(float2 st)
{
    float2 r = float2(0.0, 0.0);

    // 원래 화면 좌표는 네모 칸이 반복되는 사각 격자
    // 하지만 2D simplex noise는 네모보다 더 단순한 모양인 삼각형을 씀

    // 1.1547은 거의 2 / sqrt(3)
    // 정삼각형의 높이는 한 변보다 작기 때문에, x 방향을 이 비율로 늘려 주면
    // 사각형을 대각선으로 나눈 이등변 삼각형이 정삼각형 비율에 가까워짐
    r.x = 1.1547 * st.x;

    // y에 x의 절반을 더하면 격자가 오른쪽으로 갈수록 비스듬히 밀림
    // 이렇게 기울이면 네모 칸 안의 두 삼각형이 정삼각형처럼 배치된다
    r.x = 1.1547 * st.x;
    r.y = st.y + 0.5 * r.x;

    return r;
}

float3 SimplexGrid(float2 st)
{
    float3 xyz = float3(0.0, 0.0, 0.0);

    // Skew로 사각 격자를 비스듬히 민 다음, frac으로 현재 칸 안의 위치 보기
    float2 p = frac(Skew(st));

    // 기울어진 네모 칸은 대각선 하나로 두 삼각형으로 나눌 수 있음
    // p.x > p.y이면 대각선 아래쪽 삼각형, 아니면 위쪽 삼각형에 있는 것
    // 이 비교 하나만으로 "지금 픽셀이 어느 삼각형 안에 있는지" 빠르게 알 수 있다
    if (p.x > p.y)
    {
        // RGB 세 채널을 삼각형의 세 꼭짓점까지의 비율처럼 사용
        // 한 삼각형 안에서 세 꼭짓점의 영향이 섞임
        xyz.xy = 1.0 - float2(p.x, p.y - p.x);
        xyz.z = p.y;
    }
    else
    {
        // 위쪽 삼각형도 같은 원리
        // 정삼각형 격자를 쓰면 2D에서 세 꼭짓점 보간
        xyz.yz = 1.0 - float2(p.x - p.y, p.y);
        xyz.x = p.x;
    }

    return frac(xyz);
}

float3 Mod289(float3 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float2 Mod289(float2 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float3 Permute(float3 x)
{
    return Mod289(((x * 34.0) + 1.0) * x);
}

float SNoise(float2 v)
{
    // 이 함수는 simplex grid를 실제 noise 값으로 바꾸는 예제
    // 사각형 칸 4꼭짓점을 쓰는 대신, 정삼각형 칸 3꼭짓점만 사용

    // C에는 정삼각형 격자로 좌표를 기울이고 다시 펴는 데 필요한 숫자가 들어 있음
    // C.y는 좌표를 먼저 비스듬히 밀어 현재 정삼각형 칸을 찾을 때 쓴다
    // C.x와 C.z는 기울어진 좌표를 원래 거리 계산용 좌표로 되돌릴 때 쓴다
    const float4 C = float4(
        0.211324865405187,
        0.366025403784439,
        -0.577350269189626,
        0.024390243902439
    );

    float2 i = floor(v + dot(v, C.yy));

    // x0는 현재 픽셀에서 첫 번째 꼭짓점까지 가는 상대 좌표
    // simplex 삼각형 안에서의 거리 벡터
    float2 x0 = v - i + dot(i, C.xx);

    // x0.x와 x0.y를 비교하면 현재 점이 삼각형의 어느 절반에 있는지 알 수 있다
    // 이 한 번의 비교로 두 번째 꼭짓점이 오른쪽인지 위쪽인지 고른다
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);

    // x1, x2는 현재 픽셀에서 나머지 두 꼭짓점까지 가는 상대 좌표
    // 결국 simplex noise는 x0, x1, x2 세 꼭짓점의 영향을 합쳐서 만들어진다
    float2 x1 = x0.xy + C.xx - i1;
    float2 x2 = x0.xy + C.zz;

    // 칸 번호가 너무 커지면 숫자 계산이 지저분해질 수 있어서 289 안에서 반복되게 만든다
    i = Mod289(i);

    // Permute는 각 꼭짓점마다 사용할 gradient 번호를 뽑는 과정
    // 진짜 랜덤은 아니지만, 좌표마다 섞인 번호가 나오므로 자연스러운 무늬처럼 보임
    float3 p = Permute(
        Permute(i.y + float3(0.0, i1.y, 1.0))
        + i.x + float3(0.0, i1.x, 1.0)
    );

    // m은 세 꼭짓점의 영향력
    // 현재 픽셀에서 가까운 꼭짓점은 영향이 크고, 멀리 있는 꼭짓점은 0에 가까워짐
    float3 m = max(
        0.5 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2)),
        float3(0.0, 0.0, 0.0)
    );

    // 두 번 제곱해서 영향력이 부드럽게 줄어들게 만든다
    // 덕분에 삼각형 경계에서 값이 갑자기 끊기지 않음
    m = m * m;
    m = m * m;

    // p에서 나온 번호를 -1~1 근처의 방향 값으로 바꿈
    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;

    // gradient 화살표의 길이를 대략 맞춤
    // 정확한 정규화보다 빠른 근사식을 써서 shader에서 계산을 줄임
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    // 각 꼭짓점의 gradient 방향과, 픽셀까지의 상대 좌표를 dot으로 비교
    // 방향이 픽셀 쪽을 향할수록 더 큰 값, 반대쪽이면 더 작은 값
    float3 g = float3(0.0, 0.0, 0.0);
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * float2(x1.x, x2.x) + h.yz * float2(x1.y, x2.y);

    // 마지막으로 세 꼭짓점의 방향 기여도 g를 영향력 m만큼 섞기
    // 130은 결과가 보기 좋은 -1~1 범위 근처로 오도록 키워 주는 값
    return 130.0 * dot(m, g);
}

float4 main(PSIn i) : SV_Target
{
    float2 st = i.uv;

    st *= 10.0;

    float3 color = float3(0.0, 0.0, 0.0);

    // 1단계: 그냥 사각 격자
    //color.rg = frac(st);

    // 2단계: 사각 격자를 비스듬히 민 모습
    //color.rg = frac(Skew(st));

    // 3단계: 기울어진 사각 격자를 두 정삼각형으로 나눈 simplex grid
    //color = SimplexGrid(st);

    // 4단계: simplex grid의 세 꼭짓점 방향값을 섞어 실제 simplex noise 출력
    // SNoise는 대략 -1~1 값을 내므로, 화면에 보이게 0~1 회색 값으로 바꿈
    float n = SNoise(st);
    color = float3(n * 0.5 + 0.5, n * 0.5 + 0.5, n * 0.5 + 0.5);

    return float4(color, 1.0);
}
