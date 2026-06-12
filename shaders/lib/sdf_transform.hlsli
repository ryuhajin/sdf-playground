#ifndef SDF_TRANSFORM_HLSLI
#define SDF_TRANSFORM_HLSLI

// =============== transform: 거리 계산 전에 좌표 바꾸기 ===============

// uv를 변환한 카드 좌표에서 도형 중심으로 쓸 좌표(centerPos)를 정한다.
// SDF 도형 함수는 보통 원점(0,0)을 중심으로 계산하므로,
// samplePos - centerPos로 현재 픽셀을 "도형 중심 기준 좌표"로 바꾼다
float2 moveCenterTo(float2 samplePos, float2 centerPos) {
    // centerPos를 도형 중심으로 사용
    return samplePos - centerPos;
}

// 원점 기준으로 좌표를 radians만큼 회전
// 좌표 자체는 반시계 방향으로 회전
// 다만 이 값을 SDF 입력으로 쓰면 샘플 좌표계를 돌리는 것이므로, 화면의 도형은 반대 (시계 방향)으로 돔
float2 rotateAroundOrigin(float2 localPos, float radians) {
    float cosAngle = cos(radians);
    float sinAngle = sin(radians);
    return float2(
        cosAngle * localPos.x - sinAngle * localPos.y,
        sinAngle * localPos.x + cosAngle * localPos.y
    );
}

// 도형 중심 기준으로 스케일 적용
// SDF 좌표에서는 좌표를 scale로 나누면 화면의 도형은 scale배 커짐
float2 scaleAroundCenter(float2 localPos, float scale) {
    return localPos / max(abs(scale), 0.0001);
}

// 카드 좌표를 도형 로컬 좌표로 되돌리는 공통 STR 변환
// 도형 자체를 SRT로 움직이는 것이 아니라, SDF에 넣을 샘플 좌표를 역변환하므로
// 이동 보정 -> 회전 보정 -> 스케일 보정 순서로 적용
float2 applyCenterRotationScale(float2 samplePos, float2 centerPos, float radians, float scale) {
    float2 localPos = moveCenterTo(samplePos, centerPos);
    localPos = rotateAroundOrigin(localPos, radians);
    return scaleAroundCenter(localPos, scale);
}

// fmod 기반 좌표 반복 (cell 간격 반복)
// ***** 음수 좌표에서는 셀 중심 범위 밖 값이 나올 수 있다
float2 repeatFmod(float2 samplePos, float2 cellSize) {
    // fmod(a, b) = a를 b로 나눴을 때 남는 나머지 = cellSize마다 반복되는 범위로 접기

    // +0.5*cellSize 후 fmod를 하고 다시 -0.5*cellSize를 빼면,
    // 각 셀의 좌표 범위가 0~cellSize가 아니라 -cellSize/2~+cellSize/2가 됨
    // = 원점 중심 SDF 도형 하나가 각 셀 중심에 반복되어 보임
    return fmod(samplePos + 0.5 * cellSize, cellSize) - 0.5 * cellSize;
}

// frac 기반 중심 반복
// 음수/양수 좌표 모두 각 셀 안의 -cellSize/2 ~ +cellSize/2 범위로 접음
float2 repeatCentered(float2 samplePos, float2 cellSize)
{
    return (frac(samplePos / cellSize + 0.5) - 0.5) * cellSize;
}

// 좌표를 1사분면으로 접어 대칭 도형을 쉽게 만들기
float2 mirror(float2 samplePos) {
    return abs(samplePos);
}

// 직교 좌표를 polar 형태로 변환. x=반지름, y=각도(radians)
float2 polar(float2 samplePos) {
    return float2(length(samplePos), atan2(samplePos.y, samplePos.x));
}

// samplePos의 방향(angle)을 segmentCount개 각도 조각 안으로 접기
// 거리(radius)는 유지되므로, 도형 하나가 원형 만화경처럼 반복되어 보임
float2 kaleido(float2 samplePos, float segmentCount) {
    float2 polarPos = polar(samplePos);
    float radius = polarPos.x;
    float angle = polarPos.y;
    float segmentAngle = 6.2831853 / segmentCount;

    // 각도를 중심 기준으로 맞추기 [-segmentAngle/2 ~ +segmentAngle/2]
    // 그 후 abs로 대칭 접기
    angle = abs(fmod(angle + segmentAngle * 0.5, segmentAngle) - segmentAngle * 0.5);
    
    // 접힌 angle + 원래 radius를 사용해서 다시 x,y 좌표로 변환해 리턴
    return float2(cos(angle), sin(angle)) * radius;
}

// 좌표를 항상 아래쪽 격자 위치로 붙여서 여러 픽셀이 같은 좌표를 공유하게 만든다 (= 도형이 블록처럼 보임)
// gridSteps = 좌표 1.0 길이당 몇 단계로 나눌지
// 카드 [-1~1] 폭 기준이므로 전체 블록 수 = gridSteps * 2
float2 pixelate(float2 samplePos, float gridSteps) {
    // floor = 수직선에서 더 아래 방향으로 내림 (더 작은 정수로 감)
    // 주의 : floor(-0.1) = -1, floor(0.1) = 0

    // samplePos * gridSteps로 현재 좌표가 몇 번째 그리드에 있는지 계산
    // floor로 아래쪽 그리드 번호를 고른 뒤, 그 번호를 gridSteps로 나눠 실제 좌표 위치로 바꿈
    // 예: gridSteps=5이면 1번 그리드는 1/5 = 0.2
    return floor(samplePos * gridSteps) / gridSteps;
}

#endif
