#ifndef SDF_SHAPES_HLSLI
#define SDF_SHAPES_HLSLI

// ==== shape: 좌표를 받아 거리 d를 계산 ===============

// 모든 sd* 함수는 signed distance를 반환
// d < 0 도형 내부
// d = 0 경계
// d > 0 도형 외부

float sdCircle(float2 samplePos, float radius) {
    // 원점 중심 원에서 반지름 radius
    // 원점(0,0)을 중심으로 하는 원의 signed distance를 계산
    // samplePos는 도형 중심 기준 좌표
    // length(samplePos)는 현재 픽셀이 원 중심에서 얼마나 떨어져 있는지 뜻함
    return length(samplePos) - radius;
}

// 원점 중심 축 사각형 signed distance
// halfSize = 중심에서 x,y 경계까지의 거리 (사각형 크기의 절반)
float sdBox(float2 samplePos, float2 halfSize) {
    // 현재 좌표가 사각형 경계 기준으로 얼마나 바깥(+)/안쪽(-)인지 계산
    float2 edgeOffset = abs(samplePos) - halfSize;
    // edgeOffset > 0이면 해당 축에서 박스 밖, < 0이면 박스 안
    
    // 박스 밖에서는 면/모서리까지의 실제 거리, 박스 안에서는 0
    float outsideDistance = length(max(edgeOffset, 0.0));

    // 박스 안에서는 가장 가까운 경계까지의 음수 거리, 박스 밖에서는 0
    float insideDistance = min(max(edgeOffset.x, edgeOffset.y), 0.0);

    // 사각형은 x축 범위와 y축 범위의 교집합
    // 바깥: outside + 0, 안쪽: 0 + inside, 경계: 0 + 0
    return outsideDistance + insideDistance;
}

// 모서리를 r만큼 둥글게 깎은 사각형
float sdRoundBox(float2 samplePos, float2 halfSize, float radius) {
    // 먼저 halfSize - radius 크기의 작은 박스 생성
    // 그 후 radius를 빼서 작은 박스를 바깥으로 radius만큼 확장
    return sdBox(samplePos, halfSize - radius) - radius;
}

// 위쪽을 향한 정삼각형(equilateral triangle)
float sdTriangleEq(float2 p, float size) {
    // 정삼각형의 변은 60도 방향으로 기울어져 있음
    // 60도 직각삼각형에서 tan(60도) = 높이 / 밑변 = sqrt(3)이므로,
    // 이 값은 60도 변의 기울기와 좌표 접기 계산에 쓰임
    // sqrt는 제곱근 = sqrt(3) ~= 1.732
    const float k = sqrt(3.0);

    // x를 abs로 접어서 오른쪽 반쪽만 계산 후 size를 빼서 x 기준을 삼각형 오른쪽 경계 쪽으로 옮김
    p.x = abs(p.x) - size;
    // 정삼각형의 높이 관계에 맞게 y좌표를 보정한다
    p.y = p.y + size / k;

    // 점이 60도 기울어진 변 바깥쪽 영역에 있는지 if문으로 판별
    if (p.x + k * p.y > 0.0) p = float2(p.x - k * p.y, -k * p.x - p.y) / 2.0;

    //  p.x를 실제 삼각형 변의 선분 범위(-2*size ~ 0)로 제한
    // clamp(value, minValue, maxValue) = value를 minValue 이상, maxValue 이하로 제한
    p.x -= clamp(p.x, -2.0 * size, 0.0);

    //  좌표 p에서 가장 가까운 삼각형 경계까지의 거리 구하기. sign으로 안쪽/바깥 판단
    //  sign(x) = x<0이면 -1, x=0이면 0, x>0이면 1을 반환
    return -length(p) * sign(p.y);
}

// 점 a와 b를 잇는 선분까지의 거리. stroke와 함께 쓰면 선을 그릴 수 있음
// 현재 점에서 startPos-endPos 선분까지의 최단 거리를 구함
// 선분은 안/밖 영역이 없으므로 결과는 항상 0 이상
float sdSegment(float2 p, float2 startPos, float2 endPos) {
    // startPos에서 현재 점으로 향하는 벡터
    float2 startToPoint = p - startPos;

    // startPos에서 endPos로 향하는 선분 방향 벡터
    float2 startToEnd = endPos - startPos;

    // 현재 점을 선분 위로 내렸을 때, 선분의 몇 퍼센트 지점에 떨어지는지 구하기
    float t = saturate(dot(startToPoint, startToEnd) / dot(startToEnd, startToEnd));

    // startToEnd * t는 시작점에서 선분 위 가장 가까운 점까지의 벡터
    // startToPoint 기준으로 쓰면 p - closestPoint = startToPoint - startToEnd * t
    return length(startToPoint - startToEnd * t);
}

// n각형. n은 3 이상을 권장하고, r은 중심에서 변까지의 거리처럼 동작한다.
float sdNgon(float2 p, float r, int n) {
    float an = 6.2831853 / float(n);
    float a = atan2(p.x, p.y);
    float i = floor(a / an + 0.5);
    float ang = i * an;
    float2 dir = float2(sin(ang), cos(ang));
    return dot(p, dir) - r;
}

// 별. n은 꼭짓점 수, m은 안쪽 파임 정도를 조절한다.
float sdStar(float2 p, float r, int n, float m) {
    float an = 3.1415926 / float(n);
    float en = 3.1415926 / m;
    float2 acs = float2(cos(an), sin(an));
    float2 ecs = float2(cos(en), sin(en));
    float bn = fmod(atan2(p.x, p.y), 2.0 * an) - an;
    p = length(p) * float2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}

// 반복 격자선. cell은 반복 간격, thick은 선 두께 기준 거리다.
float sdGrid(float2 p, float2 cell, float thick) {
    float2 q = abs(fmod(p + cell * 0.5, cell) - cell * 0.5);
    float dx = q.x - thick;
    float dy = q.y - thick;
    return min(dx, dy);
}

// 십자 도형. b는 팔의 폭과 길이를 조절하는 반크기 값이다.
float sdCross(float2 p, float2 b) {
    p = abs(p);
    p = (p.y > p.x) ? p.yx : p.xy;
    float2 q = p - b;
    float k = max(q.y, q.x);
    float2 w = (k > 0.0) ? q : float2(b.y - p.x, -k);
    return sign(k) * length(max(w, 0.0));
}

// 하트 도형. s는 전체 크기 스케일이다.
float sdHeart(float2 p, float s) {
    p /= s;
    p.x = abs(p.x);
    if (p.y + p.x > 1.0)
        return (sqrt(dot(p - float2(0.25, 0.75), p - float2(0.25, 0.75))) - sqrt(2.0) / 4.0) * s;
    float2 q = p - float2(0.0, 1.0);
    float2 r = p - 0.5 * max(p.x + p.y, 0.0);
    return sqrt(min(dot(q, q), dot(r, r))) * sign(p.x - p.y) * s;
}


/*
float cross2(float2 a, float2 b) {
    return a.x * b.y - a.y * b.x;
}

float sdEquilateralTriangleEasy(float2 localPos, float halfWidth) {
    float height = sqrt(3.0) * halfWidth;

    // 중심이 원점 근처에 오도록 정삼각형 꼭짓점 3개를 배치
    float2 top         = float2(0.0,  2.0 * height / 3.0);
    float2 bottomLeft  = float2(-halfWidth, -height / 3.0);
    float2 bottomRight = float2( halfWidth, -height / 3.0);

    // 각 변까지의 거리 중 가장 가까운 거리를 구한다
    float distanceToEdges = min(
        sdSegment(localPos, top, bottomLeft),
        min(
            sdSegment(localPos, bottomLeft, bottomRight),
            sdSegment(localPos, bottomRight, top)
        )
    );

    // 세 변의 같은 쪽에 있으면 삼각형 안쪽
    bool inside =
        cross2(bottomLeft - top, localPos - top) >= 0.0 &&
        cross2(bottomRight - bottomLeft, localPos - bottomLeft) >= 0.0 &&
        cross2(top - bottomRight, localPos - bottomRight) >= 0.0;

    return inside ? -distanceToEdges : distanceToEdges;
}
*/
#endif
