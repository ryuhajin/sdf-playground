#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_transform.hlsli"
#include "../lib/sdf_animation.hlsli"

float movingArcMask(float theta, float startAngle, float arcWidth, float edgeWidth)
{
    // theta를 startAngle 기준의 지역 각도로 바꾼다.
    // localAngle이 0이면 파동 구간의 시작이고, arcWidth이면 파동 구간의 끝이다.
    float localAngle = frac((theta - startAngle) / TWO_PI) * TWO_PI;

    // 파동 구간 바깥은 원형으로 남겨야 하므로 마스크를 0으로 만든다.
    if (localAngle > arcWidth) return 0.0;

    // 구간 양끝 중 더 가까운 경계까지의 거리.
    // 이 값이 작을수록 원형 구간과 만나는 가장자리다.
    float edgeDistance = min(localAngle, arcWidth - localAngle);

    // 경계에서 안쪽으로 edgeWidth만큼 들어온 정도를 0..1로 만든다.
    float x = saturate(edgeDistance / max(edgeWidth, 0.0001));

    // raised cosine fade.
    // 경계에서는 0, 구간 안쪽에서는 1로 부드럽게 올라간다.
    return 0.5 - 0.5 * cos(x * PI);
}

float indexedWaveMask(
    float theta,
    float movingOffset,
    float slotCount,
    float startIndex,
    float slotLength,
    float edgeRatio)
{
    // 원 전체 TWO_PI를 slotCount개로 나눈다.
    // 예: slotCount = 16이면 한 칸은 TWO_PI / 16 라디안이다.
    float slotWidth = TWO_PI / slotCount;

    // startIndex번 칸부터 파동 구간을 시작한다.
    // movingOffset이 시간에 따라 증가하므로 이 인덱스 구간 전체가 원 둘레를 따라 이동한다.
    float startAngle = movingOffset + startIndex * slotWidth;

    // slotLength는 몇 칸을 이어서 파동 구간으로 쓸지 뜻한다.
    // 예: startIndex = 5, slotLength = 3이면 5, 6, 7번 칸이 이어진 파동 구간이다.
    // 예: startIndex = 13, slotLength = 4이면 13, 14, 15, 0번 칸으로 자연스럽게 감긴다.
    float arcWidth = slotLength * slotWidth;

    // 각 파동 구간 폭에 비례해서 fade 폭을 잡는다.
    // edgeRatio가 클수록 원형 구간과 파동 구간이 더 길게 섞인다.
    float edgeWidth = arcWidth * edgeRatio;

    return movingArcMask(theta, startAngle, arcWidth, edgeWidth);
}

float4 main(PSIn i) : SV_Target
{
    float2 cardPos = fitUV(i.uv);
    float2 p = applyCardShapeTransform(cardPos);

    float r = length(p);
    float theta = atan2(p.y, p.x);
    float t = uCardTime;

    float d = 10.0;
    float lineWidth = 0.004;

    // 파동 구간 묶음 전체가 원 둘레를 따라 앞으로 이동한다.
    float waveOffset = t * 0.55;

    // 원을 16등분해서 각도 구간을 인덱스로 다룬다.
    float slotCount = 16.0;

    // 현재 theta가 어느 칸에 있는지 확인하고 싶을 때 쓰는 계산식.
    // 셰이더 출력에는 쓰지 않지만, 머릿속 모델은 아래와 같다:
    // 0번 칸: 0/16 지점, 5번 칸: 5/16 지점, 15번 칸: 15/16 지점.
    float theta01 = frac((theta - waveOffset) / TWO_PI);
    float thetaSlotIndex = floor(theta01 * slotCount);

    // 예제 구간:
    // - 0번 인덱스: 짧은 파동 1칸
    // - 5~7번 인덱스: 이어진 파동 3칸
    // - 13~16번 인덱스: 13,14,15,0으로 이어지는 파동 4칸
    float waveMask0 = indexedWaveMask(theta, waveOffset, slotCount, 0.0, 15.0, 0.76);
    float waveMask5to7 = indexedWaveMask(theta, waveOffset, slotCount, 12.0, 1.0, 0.45);
    float waveMask13to16 = indexedWaveMask(theta, waveOffset, slotCount, 14.0, 2.0, 0.85);

    // 여러 인덱스 구간을 하나의 파동 마스크로 합친다.
    // max는 "어느 한 구간이라도 파동이면 파동으로 본다"는 뜻이다.
    float waveMask = max(waveMask0, max(waveMask5to7, waveMask13to16));

    // 마스크를 한 번 더 부드럽게 만든다.
    // 원형 부분과 파동 부분의 연결부에서 기울기가 덜 튀게 한다.
    float softWaveMask = waveMask * waveMask * (3.0 - 2.0 * waveMask);

    // 파동 모양은 이동 중인 인덱스 기준의 지역 각도로 만든다.
    // 지금은 간단한 예제라 모든 파동 구간이 같은 파동 패턴을 공유한다.
    float localWaveTheta = frac((theta - waveOffset) / TWO_PI) * TWO_PI;

    [unroll]
    for (int ringIndex = 0; ringIndex < 42; ++ringIndex)
    {
        float ring01 = float(ringIndex) / 41.0;

        float spread = pow(ring01, 3);
        float baseRadius = 0.02 + spread * 0.77;

        float ringPhase = ring01 * 5.7;

        float wobble =
            sin(localWaveTheta * 8.0 + t * 1.2 + ringPhase) * 0.020 +
            sin(localWaveTheta * 17.0 - t * 2.0 + ringPhase * 1.4) * 0.013 +
            sin(localWaveTheta * 31.0 + t * 3.1 + ringPhase * 2.0) * 0.007;

        float uneven =
            sin(localWaveTheta * 5.0 + t * 1.5 + ringPhase * 2.0) * 0.030 +
            sin(localWaveTheta * 13.0 - t * 2.4 + ringPhase * 0.7) * 0.018;

        // 바깥쪽 링일수록 파동 변화량을 크게 받고, 링마다 약간의 랜덤 차이를 둔다.
        float outwardAmp = lerp(0.12, 2.0, pow(ring01, 1.8));
        float ringRandom = lerp(0.75, 1.25, hash11(float(ringIndex) + 4.7));
        float ringAmp = outwardAmp * ringRandom;

        float targetRadius = baseRadius + (wobble + uneven) * softWaveMask * ringAmp;
        targetRadius = max(targetRadius, baseRadius - 0.09);

        float ringD = abs(r - targetRadius) - lineWidth;
        d = min(d, ringD);
    }

    return mask(d);
}
