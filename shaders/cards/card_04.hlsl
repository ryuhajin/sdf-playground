#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_operators.hlsli"

float2 repeatCentered_(float2 p, float2 cellSize)
{
    float2 wrapped = fmod(fmod(p + cellSize * 0.5, cellSize) + cellSize, cellSize);
    return wrapped - cellSize * 0.5;
}

float easeInOut(float x)
{
    x = saturate(x);
    return x * x * (3.0 - 2.0 * x);
}

float4 main(PSIn i) : SV_Target
{
    float2 cardPos = fitUV(i.uv);
    float2 p = applyCardShapeTransform(cardPos);

    // 타일 하나 안에 gridCount x gridCount 원을 만든다
    const int gridCount = 6;
    // 원 중심 사이 거리
    const float spacing = 0.2;
    const float radius = 0.05;
    const float gridHalfIndex = (float(gridCount) - 1.0) * 0.5;

    float d = 10.0;

    // 반복되는 타일 한 장의 크기.
    float totalSize = spacing * float(gridCount);

    // 앞 절반은 아래 이동, 뒤 절반은 오른쪽 이동
    float cycle = frac(uCardTime / 4.0);
    bool isVerticalStep = cycle < 0.5;
    float verticalMove = easeInOut(saturate(cycle / 0.5));
    float horizontalMove = easeInOut(saturate((cycle - 0.5) / 0.5));

    // p를 타일 하나 안으로 접어서 경계선 위치 구하기
    float2 tileLocal = repeatCentered_(p, float2(totalSize, totalSize));

    float lineWidth = 0.005;
    float distToVerticalTileLine = abs(abs(tileLocal.x) - totalSize * 0.5);
    float distToHorizontalTileLine = abs(abs(tileLocal.y) - totalSize * 0.5);
    float tileLineD = min(distToVerticalTileLine, distToHorizontalTileLine) - lineWidth;

    // 중심 타일 주변에 복사 타일을 배치
    for (int tileY = -1; tileY <= 1; ++tileY)
    {
        for (int tileX = -1; tileX <= 1; ++tileX)
        {
            float2 tileOffset = float2(
                float(tileX) * totalSize,
                float(tileY) * totalSize
            );

            // row/col = 타일 안의 원 인덱스
            for (int row = 0; row < gridCount; ++row)
            {
                for (int col = 0; col < gridCount; ++col)
                {
                    // row/col 인덱스를 중심 기준 좌표로 바꾼다.
                    float2 center = float2(
                        (float(col) - gridHalfIndex) * spacing,
                        (float(row) - gridHalfIndex) * spacing
                    );

                    // 예시: 0, 3번 열/행은 고정한다.
                    bool fixedColumn = (col % 2) == 0;
                    bool fixedRow = (row % 2) == 0;

                    // 원을 그리기 전에 center를 먼저 움직인다.
                    if (isVerticalStep)
                    {
                        // 고정이 아닌 열은 아래로 한 칸 이동한다.
                        if (!fixedColumn)
                        {
                            center.y -= spacing * verticalMove;
                        }
                    }
                    else
                    {
                        // 고정이 아닌 행은 오른쪽으로 한 칸 이동한다.
                        if (!fixedRow)
                        {
                            center.x += spacing * horizontalMove;
                        }
                    }

                    // 인덱스 이동 후 타일 복사 위치를 더한다.
                    center += tileOffset;

                    float boxD = sdBox(p - center, float2(radius, radius));
                    d = opUnion(d, boxD);
                }
            }
        }
    }

    d = opUnion(d, tileLineD);

    return mask(d);
}
