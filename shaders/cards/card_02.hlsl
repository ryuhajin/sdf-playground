#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_operators.hlsli"
#include "../lib/sdf_animation.hlsli"

// 나중에 할것 - card.params에 center에 곱할 float 값 설정하기

float4 main(PSIn i) : SV_Target {
    // [-1~1] 좌표로 만들기
    float2 cardPos = fitUV(i.uv);
    
    // imGui Transform 적용
    float2 p = applyCardShapeTransform(cardPos);

    float2 center = float2(sin(uCardTime * 0.8) * 0.15, cos(uCardTime * 0.6) * 1.2);

    // 거리 초기 값 (아주 먼 거리로 설정)
    float d = 10.0;

    // 움직이는 중심 원 생성
    float centerCircle = sdCircle(p - center, 0.07);
    d = opUnion(d, centerCircle); //min

    // 중심 원이 주변 점에 영향을 주는 거리 범위
    float innerRadius = 0.10;
    float outerRadius = 0.75;

    // 격자 점 생성
    // y: -4 ~ 4, x = -3 ~ 3
    [unroll]
    for (int y = -4; y <= 4; ++y)
    {
        [unroll]
        for (int x = -2; x <= 2; ++x)
        {
            // 현재 격자 점 위치 (x,y는 정수)
            float2 pointPos = float2(x, y) * 0.28;

            //  현재 격자 점이 중심 원과 얼마나 가까운지 계산
            float distToCenter = length(pointPos - center);

            // 거리 기반 영향력 만들기 : 중앙에 가까울수록 1, 멀수록 0
            float influence = 1.0 - smoothstep(innerRadius, outerRadius, distToCenter);

            // 영향력에 따라 점 크기 수정 : 멀면 작고, 가까우면 커짐
            float dotRadius = lerp(0.017, 0.038, influence);
            float dotD = sdCircle(p - pointPos, dotRadius);

            d = opUnion(d, dotD);

            // 일정 거리 안에 있는 점만 선으로 연결하기
            float connect = step(distToCenter, outerRadius);

            // 0.006 = 선 두께
            float lineD = sdSegment(p, center, pointPos) - 0.006;

            // 그리지 않을 라인은 아주 먼 거리로 보내서 union에 영향을 못 주게 만든다
            lineD = lerp(10.0, lineD, connect);

            d = opUnion(d, lineD);
        }
    }

    float m = aa(d);
    return float4(colorFromMask(m, d), 1.0);
}