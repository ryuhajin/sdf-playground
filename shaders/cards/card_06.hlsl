#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_operators.hlsli"

// 이동: 도형을 offset 방향으로 보이게 하려면, SDF에 넣는 좌표는 반대로 offset만큼 빼준다.
// 이유: SDF는 "지금 샘플 좌표가 도형 중심에서 얼마나 떨어졌는가"를 묻기 때문이다.
float2 move2d(float2 p, float2 offset)
{
    return p - offset;
}

// 스케일: SDF 좌표에서는 좌표를 scale로 나누면 화면의 도형은 scale만큼 커진다.
// 예를 들어 p / 2.0은 같은 도형 거리장을 더 천천히 지나가게 만들어서 도형이 2배 커져 보인다.
float2 scale2d(float2 p, float2 scale)
{
    float2 safeScale = max(abs(scale), float2(0.0001, 0.0001));
    return p / safeScale;
}

// 회전: 이 함수는 원점(0,0)을 기준으로 좌표계를 돌린다.
// 특정 위치의 도형을 돌리고 싶으면 먼저 move2d로 그 위치를 원점처럼 만든 뒤 회전한다.
float2 Rotate2D(float2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);

    return float2(
        c * p.x - s * p.y,
        s * p.x + c * p.y
    );
}

// --------------------------------------------------
// 현재 화면 픽셀 p를
// "worldPivot을 기준으로 angle만큼 회전해 보이는 도형"의
// 로컬 좌표로 되돌린다.
//
// worldPivot : 화면에서 고정되는 회전 기준점
// localPivot : 도형 로컬 좌표계에서의 회전 기준점
// angle      : 화면에서 보이는 회전 각도
// --------------------------------------------------
float2 ToLocalFromPivot(float2 p, float2 scenePivot, float2 localPivot, float angle)
{
    // 1. 현재 화면 픽셀을 scenePivot 기준 상대좌표로 바꿈
    float2 q = p - scenePivot;

    // 2. 화면에서 +angle만큼 회전해 보이게 하려면
    //    픽셀 좌표에는 역회전(-angle)을 적용
    q = Rotate2D(q, -angle);

    // 3. 십자가 SDF는 중심 (0,0)을 기대하므로
    //    pivot이 로컬 좌표에서 어디였는지(localPivot)를 다시 더해
    //    상대좌표를 localPivot 중심 기준으로 맞춘다
    q += localPivot;

    return q;
}

// --------------------------------------------------
// 원점 중심 축 정렬 박스 SDF
// p        : 박스 중심 기준 로컬 좌표
// halfSize : 박스의 가로/세로 반길이
// --------------------------------------------------
float SdBox(float2 p, float2 halfSize)
{
    float2 d = abs(p) - halfSize;

    // 박스 바깥에서는 실제 거리를,
    // 내부에서는 가장 가까운 변까지의 음수 거리를 반환
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// --------------------------------------------------
// 원점 중심 원 SDF
// --------------------------------------------------
float SdCircle(float2 p, float radius)
{
    return length(p) - radius;
}

// q는 반드시 "십자가 중심 기준 로컬 좌표"여야 한다
float sdCross(float2 p)
{
    float verticalBar = sdBox(p, float2(0.045, 0.18));
    float horizontalBar = sdBox(p, float2(0.18, 0.045));
    return opUnion(verticalBar, horizontalBar);
}

// SDF 내부를 1, 외부를 0으로 만든다.
float FillFromSDF(float d)
{
    float aa = max(fwidth(d), 0.0001);
    return 1.0 - smoothstep(0.0, aa, d);
}

// 화면 좌표계에 고정된 그리드
float Grid(float2 p, float density)
{
    float2 cell = p * density;
    float2 width = fwidth(cell);

    // 격자선까지의 거리 비슷한 값
    float2 g = abs(frac(cell) - 0.5);

    float2 lineMask = smoothstep(0.5 - width * 1.2, 0.5, g);

    return max(lineMask.x, lineMask.y);
}

// 화면 원점 축 표시
float AxisLine(float value)
{
    float width = max(fwidth(value) * 2.0, 0.002);
    return 1.0 - smoothstep(0.0, width, abs(value));
}

float4 main(PSIn i) : SV_Target
{
    // pixelPosition을 -1~1 기준으로 맞추기
    float2 p = i.uv * 2.0 - 1.0;
    p.y *= -1.0; // +y를 위쪽으로

    // 화면에 고정된 배경 = pixelPosition으로 계산
    // 십자가가 돌아도 배경 회전 x
    float2 pColor = p * 0.5 + 0.5;

    float3 color = float3(
        0.08 + pColor.x * 0.10,
        0.08 + pColor.y * 0.10,
        0.12
    );

    float grid = Grid(p, 8.0);
    color = lerp(color, float3(0.30, 0.33, 0.38), grid * 0.45);

    float axes = max(AxisLine(p.x), AxisLine(p.y));
    color = lerp(color, float3(0.75, 0.18, 0.18), axes);

    // --------------------------------------------------
    // 3. A십자가의 화면상 중심 = 회전 pivot (0,0) 화면 중심
    // --------------------------------------------------
    float2 aWorldPivot = float2(0.0, 0.0);
    float2 aLocalPivot = float2(0.0, 0.0);
    float aAngle = uCardTime * 0.2;

    // 픽셀 p를 a십자가 기준 로컬 좌표 q로 바꾸기
    float2 qA = ToLocalFromPivot(p, aWorldPivot, aLocalPivot, aAngle);

    float aCrossD = sdCross(qA);
    float aCrossMask = FillFromSDF(aCrossD);

    // a십자가 확인용 표식
    // 표식 또한 q 기준이므로 십자가와 같이 회전
    float aMarkerD = SdCircle(qA - float2(0.23, 0.0), 0.028);
    float aMarkerMask = FillFromSDF(aMarkerD);

    // --------------------------------------------------
    // 4. B십자가 = 로컬 좌하단 pivot 회전
    // --------------------------------------------------
    
    float2 bWorldPivot = float2(-1.0, -1.0);
    float2 bLocalPivot = float2(0.63, 0.63);

    float bAngle = uCardTime * 1.4;

    float2 qB = ToLocalFromPivot(p, bWorldPivot, bLocalPivot, bAngle);


    float bScale = 0.77;
    float2 qBShape = qB / bScale;

    float bCrossD = sdCross(qBShape);
    float bCrossMask = FillFromSDF(bCrossD);

    // b십자가 확인용 표식
    float bMarkerD    = SdCircle(qB - float2(0.23, 0.0), 0.028);
    float bMarkerMask = FillFromSDF(bMarkerD);

    // B의 고정 pivot 위치를 화면에 표시
    // 이 점은 회전하지 않고 화면에 고정됨
    float bPivotDotD    = SdCircle(p - bWorldPivot, 0.024);
    float bPivotDotMask = FillFromSDF(bPivotDotD);

    // ==================================================
    // D 십자가
    // A 원점을 기준으로 공전 + 자기 중심 기준 자전
    // ==================================================

    // A의 원점 = D의 공전 pivot
    float2 dOrbitPivot = aWorldPivot;

    // A 원점에서 D 중심까지의 기본 거리(공전 반지름 역할)
    float2 dOffset = float2(0.55, 0.0);

    // 공전 각도
    float dOrbitAngle = uCardTime * 0.5;

    // 자전 각도
    float dSelfAngle = uCardTime * 1.2;

    // ----------------------------------------
    // 1. 현재 화면 픽셀을 공전 전 장면 좌표로 되돌린다.
    // ----------------------------------------
    float2 qD = p;

    qD -= dOrbitPivot; // pivot 원점으로 옮기기
    qD = Rotate2D(qD, -dOrbitAngle); // 공전 역회전
    qD -= dOffset; // D offset 빼서 D center 기준 로컬 좌표로
    qD = Rotate2D(qD, -dSelfAngle); // 자전 역회전

    float dScale = 0.45;
    float2 qDShape = qD / dScale;

    // D 십자가 판정
    float dCrossDMaskSDF = sdCross(qDShape);
    float dCrossMask = FillFromSDF(dCrossDMaskSDF);

    // D 회전 확인용 오른팔 표식
    float dMarkerD = SdCircle(qD - float2(0.23, 0.0), 0.028);
    float dMarkerMask = FillFromSDF(dMarkerD);

    // D의 공전 경로를 보기 위한 작은 점선 느낌의 가이드
    float orbitGuideD = abs(length(p - dOrbitPivot) - length(dOffset));
    float orbitGuideMask = 1.0 - smoothstep(0.0, 0.01, orbitGuideD);


    // --------------------------------------------------
    // 3. 색 합성
    // --------------------------------------------------

    // A
    color = lerp(color, float3(0.95, 0.95, 0.98), aCrossMask);
    color = lerp(color, float3(1.00, 0.75, 0.10), aMarkerMask);

    // B
    color = lerp(color, float3(0.80, 0.96, 1.00), bCrossMask);
    color = lerp(color, float3(1.00, 0.55, 0.20), bMarkerMask);

    // B의 고정 pivot 점
    color = lerp(color, float3(0.20, 1.00, 0.35), bPivotDotMask);

    // D의 공전 가이드 원
    color = lerp(color, float3(0.45, 0.35, 0.85), orbitGuideMask * 0.25);

    // D 십자가
    color = lerp(color, float3(0.92, 0.78, 1.00), dCrossMask);

    // D 오른팔 회전 표식
    color = lerp(color, float3(1.00, 0.35, 0.85), dMarkerMask);

    return float4(color, 1.0);
}
