#include "../lib/sdf_common.hlsli"

// 2D 랜덤 함수
//
// 셰이더에서는 매 프레임 진짜 난수를 새로 뽑기보다,
// 입력 좌표를 항상 같은 0~1 값으로 바꾸는 해시 함수를 자주 사용
// 같은 p를 넣으면 같은 값이 나오고, 다른 p를 넣으면 다른 값처럼 보임
float random2d(float2 p)
{
    // dot으로 2D 좌표를 하나의 숫자로 접고,
    // sin으로 값을 크게 흔든 뒤 frac으로 소수 부분만 남김
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// 셀 안에서 중심 기준 직사각형을 만드는 마스크
// rectSize.x는 가로 폭, rectSize.y는 세로 높이
float rectangleMaskInCell(float2 localUV, float2 rectSize)
{
    float xDistance = abs(localUV.x - 0.5) * 2.0;
    float yDistance = abs(localUV.y - 0.5) * 2.0;
    float xSoftness = max(fwidth(xDistance), 0.001);
    float ySoftness = max(fwidth(yDistance), 0.001);

    float xMask = 1.0 - smoothstep(rectSize.x, rectSize.x + xSoftness, xDistance);
    float yMask = 1.0 - smoothstep(rectSize.y, rectSize.y + ySoftness, yDistance);

    return xMask * yMask;
}

// RGB 채널을 살짝 다른 x 위치에서 샘플링하기 위한 런(run) 마스크 함수
float glitchRunMask(float2 uv, float movedX, float rowCount, float baseColCount, float timeBlock, float rowVisible)
{
    float2 gridUV = float2(movedX, uv.y) * float2(baseColCount, rowCount);
    float rowId = floor(gridUV.y);

    // segmentSpan은 여러 x 셀을 하나의 런 단위로 묶는 크기다.
    float spanSeed = floor(gridUV.x / 12.0);
    float segmentSpan = floor(lerp(2.0, 18.0, random2d(float2(rowId + timeBlock * 13.0, spanSeed))));

    float2 segmentUV = float2(gridUV.x / segmentSpan, gridUV.y);
    float2 segmentId = floor(segmentUV);
    float2 segmentLocalUV = frac(segmentUV);

    float stateRandom = random2d(segmentId + float2(timeBlock, timeBlock * 3.17));
    float notEmpty = step(0.50, stateRandom);
    float longState = step(0.75, stateRandom);

    float shortWidth = lerp(0.08, 1.0, random2d(segmentId + float2(7.1, 19.3)));
    float longWidth = lerp(0.45, 1.0, random2d(segmentId + float2(23.7, 5.9)));
    float width = lerp(shortWidth, longWidth, longState);
    float rowFillHeight = 0.58;

    float run = rectangleMaskInCell(segmentLocalUV, float2(width, rowFillHeight));

    return rowVisible * notEmpty * run;
}

float4 main(PSIn i) : SV_Target
{
    float2 uv = i.uv;

    // 화면을 여러 줄(row)로 나누기
    float rowCount = 50.0;
    float baseColCount = 100.0;

    // row ID: 현재 픽셀이 몇 번째 줄에 있는지 나타내는 정수 번호
    // 같은 줄 안의 모든 픽셀은 같은 rowId를 공유
    float rowId = floor(uv.y * rowCount);

    // 짝수 row = 오른쪽, 홀수 row = 왼쪽
    // fmod(rowId, 2.0)는 0, 1, 0, 1...로 반복되므로 방향을 번갈아 만들기 좋음
    float direction = lerp(1.0, -1.0, fmod(rowId, 2.0));

    // timeBlock은 패턴 상태를 일정 시간마다 새로 뽑기 위한 시간 인덱스
    float timeBlock = floor(uCardTime * 0.75);

    // floor를 사용해 시간 계단처럼 만들기 (뚝뚝 끊기게)
    float tickRate = 8.0;
    float tick = floor(uCardTime * tickRate);

    // 속도도 매 순간 계속 바꾸지 않고, 느린 시간 구간마다 새 랜덤값을 뽑기
    // 그래서 행의 움직임이 일정하게 흐르다가 어느 순간 다른 속도로 바뀌는 것처럼 보임
    float speedChange = floor(uCardTime * 1.25);
    float rowRandom = random2d(float2(rowId, speedChange + 13.7));
    float rowSpeed = lerp(0.35, 2.4, rowRandom);

    // tick 자체도 행마다 조금씩 엇갈리게 해서 모든 줄이 동시에 딱딱 바뀌지 않게 만들기
    float rowPhase = floor(random2d(float2(rowId, 29.0)) * 4.0);
    float steppedTime = tick + rowPhase;

    // 최종 시간 오프셋
    // baseColCount로 나누는 이유 = uv 좌표 이동량으로 바꾸기 위함
    // tick을 썼기 때문에 오프셋은 연속값이 아니라 계단식으로 바뀜
    float xOffset = steppedTime * rowSpeed * direction / baseColCount;
    float movedX = uv.x + xOffset;

    // 행 자체를 가끔 비워서 고밀도 패턴 안에 큰 여백 만들기
    float rowVisible = step(0.12, random2d(float2(rowId, timeBlock + 91.3)));

    // 크로마 오프셋도 행마다 랜덤하게 약해지거나 사라지게
    float chromaVisible = step(0.55, random2d(float2(rowId, timeBlock + 137.0)));
    float chroma = 0.0012 * chromaVisible;
    float redMask = glitchRunMask(uv, movedX - chroma, rowCount, baseColCount, timeBlock, rowVisible);
    float greenMask = glitchRunMask(uv, movedX, rowCount, baseColCount, timeBlock, rowVisible);
    float blueMask = glitchRunMask(uv, movedX + chroma, rowCount, baseColCount, timeBlock, rowVisible);

    float3 color = float3(redMask, greenMask, blueMask);

    return float4(color, 1.0);
}
