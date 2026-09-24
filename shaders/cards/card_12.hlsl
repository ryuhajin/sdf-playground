#include "../lib/sdf_common.hlsli"

// ============================================================
// 3D 해시와 회전
// ============================================================

float Hash11(float value)
{
    return frac(sin(value) * 43237.5324);
}

float Hash21(float2 value)
{
    return frac(sin(dot(value, float2(12.9898, 78.233))) * 43237.5324);
}

float3 Hash33(float3 value)
{
    // 셀 ID 하나에서 항상 같은 0..1 범위의 3D 특징점 위치를 만든다.
    float3 projected = float3(
        dot(value, float3(1.0, 57.0, 113.0)),
        dot(value, float3(57.0, 113.0, 1.0)),
        dot(value, float3(113.0, 1.0, 57.0))
    );
    return frac(sin(projected) * 43758.5453);
}

float2x2 Rotation2D(float radians)
{
    float c = cos(radians);
    float s = sin(radians);
    return float2x2(c, -s, s, c);
}

float2 Rotate2D(float2 position, float radians)
{
    // HLSL에서는 행렬과 열 벡터의 곱 순서를 명시한다.
    return mul(Rotation2D(radians), position);
}

float3 Rotate3D(float3 position, float3 radians)
{
    // 원문처럼 Z축(xy), X축(yz), Y축(zx) 순서로 회전한다.
    position.xy = Rotate2D(position.xy, radians.z);
    position.yz = Rotate2D(position.yz, radians.x);

    float2 rotatedZX = Rotate2D(position.zx, radians.y);
    position.z = rotatedZX.x;
    position.x = rotatedZX.y;
    return position;
}

// ============================================================
// 3D 보로노이: x=F1, y=F2, z=최근접 셀 ID
// ============================================================

float3 Voronoi3D(float3 samplePosition)
{
    float3 cellId = floor(samplePosition);
    float3 cellUV = frac(samplePosition);

    float nearestDistanceSquared = 100.0;
    float secondDistanceSquared = 100.0;
    float nearestCellIdentifier = 0.0;

    // 현재 셀과 주변 26개 셀의 특징점을 검사한다.
    [unroll]
    for (int z = -1; z <= 1; ++z)
    {
        [unroll]
        for (int y = -1; y <= 1; ++y)
        {
            [unroll]
            for (int x = -1; x <= 1; ++x)
            {
                float3 neighbor = float3((float)x, (float)y, (float)z);
                float3 candidateCellId = cellId + neighbor;
                float3 vectorToPoint =
                    neighbor - cellUV + Hash33(candidateCellId);
                float distanceSquared = dot(vectorToPoint, vectorToPoint);

                // 원문의 branchless cond 대신 F1/F2 갱신 의도를 직접 표현한다.
                if (distanceSquared < nearestDistanceSquared)
                {
                    secondDistanceSquared = nearestDistanceSquared;
                    nearestDistanceSquared = distanceSquared;
                    nearestCellIdentifier = dot(
                        candidateCellId,
                        float3(1.0, 57.0, 113.0)
                    );
                }
                else if (distanceSquared < secondDistanceSquared)
                {
                    secondDistanceSquared = distanceSquared;
                }
            }
        }
    }

    // 후보마다 sqrt하지 않고 마지막 F1/F2에만 적용한다.
    return float3(
        sqrt(nearestDistanceSquared),
        sqrt(secondDistanceSquared),
        abs(nearestCellIdentifier)
    );
}

// ============================================================
// 볼륨을 담을 구 SDF
// ============================================================

float3 Transform3D(float3 position)
{
    // 아래 줄을 하나씩 해제하면 공간 접기와 회전을 실험할 수 있다.
    // position = abs(position);
    // position = Rotate3D(position, uCardTime * 0.04.xxx);
    return position;
}

float SphereSDF(float3 position, float radius)
{
    return length(position) - radius;
}

float ObjectSDF(float3 position)
{
    position = Transform3D(position);
    return SphereSDF(position, 5.0);
}

// ============================================================
// 구의 입구와 출구를 찾는 sphere tracing
// ============================================================

#define OBJECT_MARCH_ITERATIONS 64
#define OBJECT_MARCH_THRESHOLD 0.0001

float2 ObjectMarch(float3 rayOrigin, float3 rayDirection, float2 distanceRange)
{
    // x=-1이면 구를 만나지 못했다. 성공하면 x=입구, y=출구 거리다.
    float2 result = float2(-1.0, -1.0);

    // 첫 번째 마칭: 구 외부에서 SDF만큼 전진해 입구 표면을 찾는다.
    float rayDistance = distanceRange.x;
    [loop]
    for (int entryIteration = 0; entryIteration < OBJECT_MARCH_ITERATIONS; ++entryIteration)
    {
        float distanceToSurface = ObjectSDF(
            rayOrigin + rayDirection * rayDistance
        );

        if (distanceToSurface < OBJECT_MARCH_THRESHOLD
            || rayDistance > distanceRange.y)
        {
            break;
        }

        rayDistance += distanceToSurface;
    }

    if (rayDistance > distanceRange.y)
    {
        return result;
    }
    result.x = rayDistance;

    // 입구를 다시 감지하지 않도록 구 내부로 조금 이동한다.
    rayDistance += 0.05;

    // 두 번째 마칭: 구 내부의 음수 SDF를 뒤집어 출구까지 전진한다.
    [loop]
    for (int exitIteration = 0; exitIteration < OBJECT_MARCH_ITERATIONS; ++exitIteration)
    {
        float distanceToSurface = -ObjectSDF(
            rayOrigin + rayDirection * rayDistance
        );

        if (distanceToSurface < OBJECT_MARCH_THRESHOLD
            || rayDistance > distanceRange.y)
        {
            break;
        }

        rayDistance += distanceToSurface;
    }

    result.y = min(rayDistance, distanceRange.y);
    return result;
}

// ============================================================
// 3D 보로노이 값을 볼륨 밀도로 변환하고 광선 위에서 누적
// ============================================================

float VolumeDensity(float3 position)
{
    position = Transform3D(position);
    position *= 1.4;

    // F2를 세제곱해 대비를 높이고 역수를 취해 작은 값 주변을 밝게 만든다.
    float secondDistance = Voronoi3D(position).y;
    float shapedDistance = pow(secondDistance, 3.0);

    // 보로노이 값이 0에 가까울 때 0으로 나누지 않도록 하한을 둔다.
    return 1.0 / max(shapedDistance, 0.0001);
}

#define VOLUME_MARCH_ITERATIONS 24

float3 VolumeMarch(
    float3 rayOrigin,
    float3 rayDirection,
    float2 distanceRange,
    float time
)
{
    float3 color = float3(0.0, 0.0, 0.0);
    float rayDistance = distanceRange.x;
    float stepDistance =
        (distanceRange.y - distanceRange.x) / (float)VOLUME_MARCH_ITERATIONS;

    float3 volumeColor = float3(0.8, 0.8, 0.8);
    float historyWeight = 0.988 + 0.003 * sin(time * 0.4);

    // 구의 입구부터 출구까지 같은 간격으로 24번 밀도를 샘플링한다.
    [loop]
    for (int iteration = 0; iteration < VOLUME_MARCH_ITERATIONS; ++iteration)
    {
        float density = VolumeDensity(
            rayOrigin + rayDirection * rayDistance
        );

        // 기존 누적색은 약 99% 유지하고 새 밀도를 약 1%씩 더한다.
        color = lerp(density * volumeColor, color, historyWeight);
        rayDistance += stepDistance;
    }

    // 낮은 누적값을 어둡게 눌러 밝은 보로노이 구조의 대비를 높인다.
    return pow(max(color, 0.0), 3.0);
}

float3 BackgroundColor(float3 direction)
{
    // 광선 방향을 3D 보로노이 좌표로 사용해 환경 맵 같은 배경을 만든다.
    float value = saturate(Voronoi3D(direction * 8.0).y);
    value = pow(value, 6.0);
    return value * float3(0.06, 0.07, 0.08);
}

// ============================================================
// 카메라
// ============================================================

float3x3 LookAt(float3 eye, float3 target, float roll)
{
    // eye는 가상 SDF 공간의 카메라 위치이고 target은 카메라가 바라볼 점이다.
    // 둘의 차이를 정규화하면 카메라 로컬 +Z축에 해당하는 정면 방향이 된다.
    float3 forward = normalize(target - eye);

    // 이 구현의 roll은 XY 평면에서 위쪽 기준 벡터를 돌리는 값이다. roll=0이면
    // 가상 월드의 +Y축을 기준으로 사용하며, forward가 Z축에 가까울 때 일반적인
    // 카메라 roll처럼 보인다. forward와 이 위쪽 기준을 외적해 right를 만든다.
    float3 right = normalize(cross(
        forward,
        float3(sin(roll), cos(roll), 0.0)
    ));

    // 이미 구한 right와 forward 모두에 수직인 축을 만들어 직교 카메라 basis를 완성한다.
    float3 up = normalize(cross(right, forward));

    // 위치 이동은 rayOrigin이 따로 담당하므로 방향 회전만 담는 3x3이면 충분하다.
    // 열에 right/up/forward를 배치해 카메라 로컬 벡터 (x,y,z)를
    // right*x + up*y + forward*z 형태의 가상 월드 방향으로 바꾼다.
    return float3x3(
        right.x, up.x, forward.x,
        right.y, up.y, forward.y,
        right.z, up.z, forward.z
    );
}

// 가상 SDF 공간에서 모든 픽셀 광선이 출발할 카메라 위치를 구한다.
float3 GetRayOrigin(float time)
{
    // cos/sin으로 XZ 평면의 원 궤도를 만들고, Z축으로 30도 회전해
    // 궤도면을 기울인 뒤 반지름을 2로 만든다. 이 위치는 구 반지름 5보다 안쪽이다.
    float3 orbitCamera = 2.0 * Rotate3D(
        float3(cos(time * PI * 0.3), 0.0, sin(time * PI * 0.3)),
        float3(0.0, 0.0, PI / 6.0)
    );

    // X/Y는 고정하고 Z만 4..6 사이에서 왕복하는 두 번째 카메라 위치다.
    float3 forwardCamera = float3(0.0, 0.0, 5.0 - sin(time * 0.37));

    // frac(time*0.1)은 10초마다 0..1을 반복한다. 앞 5초에는 0, 뒤 5초에는 1이다.
    // cameraMode가 0이면 orbitCamera, 1이면 forwardCamera를 즉시 선택한다.
    float cameraMode = step(0.5, frac(time * 0.1));
    return lerp(orbitCamera, forwardCamera, cameraMode);
}

// 가상 SDF 공간에서 카메라가 바라볼 한 점을 구한다. target은 near/far가 아니라
// forward = normalize(target - eye)를 만들기 위한 응시점이다.
float3 GetTarget(float time)
{
    // 각 축이 서로 다른 속도로 -0.4..0.4 사이를 움직여 원점 근처를 떠돈다.
    float3 movingTarget = 0.4 * sin(
        time * float3(0.17, 0.11, 0.13)
    );

    // 구 중심 (0,0,0)보다 Y축으로 0.5 위에 있는 고정 응시점이다.
    float3 fixedTarget = float3(0.0, 0.5, 0.0);

    // GetRayOrigin과 같은 스위치를 사용해 앞 5초에는 movingTarget,
    // 뒤 5초에는 fixedTarget을 선택한다. 0/1 선택이므로 부드러운 보간은 아니다.
    float cameraMode = step(0.5, frac(time * 0.1));
    return lerp(movingTarget, fixedTarget, cameraMode);
}

float4 main(PSIn i) : SV_Target
{
    // 카드 UV를 실제 월드로 역투영하지 않고, 별도 가상 카메라의 이미지 평면
    // 좌표(-1..1)로 사용한다. 여기부터 카드 바깥의 실제 월드와는 독립된 공간이다.
    float2 screenPosition = fitUV(i.uv);
    float time = uCardTime;

    // 가상 SDF 월드에서 광선 출발점과 카메라가 바라볼 응시점을 구한다.
    float3 rayOrigin = GetRayOrigin(time);
    float3 target = GetTarget(time);

    // 카메라 로컬 공간에서 현재 픽셀 방향을 만든다. 중앙 픽셀은 (0,0,2)이며,
    // z=2는 이미지 평면 거리라서 가상 카메라의 FOV에 대응한다.
    float3 cameraRay = float3(screenPosition, 2.0);

    // LookAt basis로 카메라 로컬 방향을 가상 SDF 월드 방향으로 회전한다.
    // normalize한 뒤에는 rayDistance가 가상 월드의 실제 거리 단위로 동작한다.
    float3 rayDirection = normalize(
        mul(LookAt(rayOrigin, target, 0.0), cameraRay)
    );

    // 구와 만나는 입구/출구 거리를 구한다.
    float2 objectRange = ObjectMarch(
        rayOrigin,
        rayDirection,
        float2(0.0, 10.0)
    );
    float hitMask = step(0.0, objectRange.x);

    float3 color;

    if (objectRange.x < 0.0)
    {
        // 구를 만나지 않음
        color = BackgroundColor(rayDirection);
    }
    else
    {
        // 4단계 확인: 구 내부 중간점에서 밀도를 한 번만 샘플링한다.
        float middleDistance = 0.5 * (objectRange.x + objectRange.y);
        float middleDensity = VolumeDensity(
            rayOrigin + rayDirection * middleDistance
        );
        float densityPreview = middleDensity / (1.0 + middleDensity);
        // return float4(densityPreview.xxx, 1.0);

        // 5단계: 입구부터 출구까지 24개 밀도를 누적한 최종 볼륨이다.
        color = VolumeMarch(rayOrigin, rayDirection, objectRange, time);
    }

    // 출력 범위를 제한한 뒤 선형 색을 화면 감마에 맞게 밝힌다.
    color = saturate(color);
    color = pow(color, 0.4545.xxx);
    return float4(color, 1.0);
}
