#include "../lib/sdf_common.hlsli"

// ============================================================
// card_13: 직육면체로 배우는 3D 자전, 공전, 회전 순서
// ------------------------------------------------------------
// X축은 빨강, Y축은 초록, Z축은 파랑이다.
// 이 파일의 모든 각도 단위는 도(degree)가 아니라 라디안(radian)이다.
// 예: 30도 = PI / 6.0, 45도 = PI / 4.0, 90도 = PI / 2.0
// ============================================================

#define ROTATION_ORDER_XYZ 0
#define ROTATION_ORDER_ZYX 1

#define RAY_MARCH_STEPS 96
#define RAY_MARCH_MAX_DISTANCE 10.0
#define RAY_MARCH_EPSILON 0.001

struct SceneSample
{
    float distance;
    float3 color;
    float material;
};

// ============================================================
// 1. 축별 회전
// ============================================================

float3 RotateX(float3 position, float radians)
{
    // X축은 고정하고 YZ 평면을 회전한다.
    float c = cos(radians);
    float s = sin(radians);
    return float3(
        position.x,
        c * position.y - s * position.z,
        s * position.y + c * position.z
    );
}

float3 RotateY(float3 position, float radians)
{
    // Y축은 고정하고 ZX 평면을 회전한다.
    float c = cos(radians);
    float s = sin(radians);
    return float3(
        c * position.x + s * position.z,
        position.y,
        -s * position.x + c * position.z
    );
}

float3 RotateZ(float3 position, float radians)
{
    // Z축은 고정하고 XY 평면을 회전한다.
    float c = cos(radians);
    float s = sin(radians);
    return float3(
        c * position.x - s * position.y,
        s * position.x + c * position.y,
        position.z
    );
}

float3 RotateXYZ(float3 position, float3 radians)
{
    // 함수가 적힌 순서 그대로 X -> Y -> Z축 회전을 적용한다.
    position = RotateX(position, radians.x);
    position = RotateY(position, radians.y);
    position = RotateZ(position, radians.z);
    return position;
}

float3 RotateZYX(float3 position, float3 radians)
{
    // 같은 각도라도 Z -> Y -> X 순서로 적용하면 최종 자세가 달라진다.
    position = RotateZ(position, radians.z);
    position = RotateY(position, radians.y);
    position = RotateX(position, radians.x);
    return position;
}

float3 ApplyForwardRotation(float3 position, float3 radians, int rotationOrder)
{
    return rotationOrder == ROTATION_ORDER_ZYX
        ? RotateZYX(position, radians)
        : RotateXYZ(position, radians);
}

float3 ApplyInverseRotation(float3 position, float3 radians, int rotationOrder)
{
    // SDF에서는 도형을 돌리는 대신 샘플 좌표를 반대 방향으로 되돌린다.
    // 따라서 정방향 회전의 역순으로 음수 각도를 적용해야 한다.
    if (rotationOrder == ROTATION_ORDER_ZYX)
    {
        position = RotateX(position, -radians.x);
        position = RotateY(position, -radians.y);
        position = RotateZ(position, -radians.z);
        return position;
    }

    position = RotateZ(position, -radians.z);
    position = RotateY(position, -radians.y);
    position = RotateX(position, -radians.x);
    return position;
}

// ============================================================
// 2. 자전과 공전
// ============================================================

float3 WorldToBoxLocal(
    float3 worldPosition,
    float3 boxCenter,
    float3 selfRotation,
    int rotationOrder)
{
    // 자전: 직육면체 중심을 원점으로 옮긴 뒤 자세 회전의 역변환을 적용한다.
    float3 localPosition = worldPosition - boxCenter;
    return ApplyInverseRotation(localPosition, selfRotation, rotationOrder);
}

float3 OrbitAroundPivotXYZ(
    float3 startPosition,
    float3 pivot,
    float3 orbitRotation)
{
    // 공전: pivot을 기준으로 위치 벡터를 회전한다.
    // 이 함수는 중심 위치만 바꾸며 직육면체의 자세는 바꾸지 않는다.
    return pivot + RotateXYZ(startPosition - pivot, orbitRotation);
}

// ============================================================
// 3. 장면을 구성하는 기본 SDF
// ============================================================

float BoxSDF(float3 position, float3 halfSize)
{
    float3 q = abs(position) - halfSize;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float CapsuleSDF(float3 position, float3 start, float3 end, float radius)
{
    float3 startToPoint = position - start;
    float3 startToEnd = end - start;
    float segmentLengthSquared = max(dot(startToEnd, startToEnd), 0.0001);
    float h = saturate(dot(startToPoint, startToEnd) / segmentLengthSquared);
    return length(startToPoint - startToEnd * h) - radius;
}

float SphereSDF(float3 position, float3 center, float radius)
{
    return length(position - center) - radius;
}

SceneSample EmptySceneSample()
{
    SceneSample sample;
    sample.distance = 1000.0;
    sample.color = 0.0.xxx;
    sample.material = 0.0;
    return sample;
}

void AddToScene(
    inout SceneSample scene,
    float distance,
    float3 color,
    float material)
{
    if (distance < scene.distance)
    {
        scene.distance = distance;
        scene.color = color;
        scene.material = material;
    }
}

void AddAxis(
    inout SceneSample scene,
    float3 position,
    float3 start,
    float3 direction,
    float length,
    float radius,
    float3 color,
    float material)
{
    float3 end = start + direction * length;

    // 가느다란 캡슐이 축 선이고, 끝의 큰 구가 양의 축 방향을 알려 준다.
    AddToScene(
        scene,
        CapsuleSDF(position, start, end, radius),
        color,
        material
    );
    AddToScene(
        scene,
        SphereSDF(position, end, radius * 2.0),
        color,
        material
    );
}

SceneSample SceneSDF(
    float3 position,
    float3 boxCenter,
    float3 selfRotation,
    int rotationOrder)
{
    SceneSample scene = EmptySceneSample();

    const float3 xColor = float3(0.95, 0.08, 0.06);
    const float3 yColor = float3(0.08, 0.88, 0.18);
    const float3 zColor = float3(0.08, 0.32, 1.00);

    // 원점의 긴 월드축은 물체가 자전하거나 공전해도 절대 움직이지 않는다.
    float worldAxisLength = 1.18;
    AddAxis(scene, position, 0.0.xxx, float3(1.0, 0.0, 0.0), worldAxisLength, 0.022, xColor, 1.0);
    AddAxis(scene, position, 0.0.xxx, float3(0.0, 1.0, 0.0), worldAxisLength, 0.022, yColor, 1.0);
    AddAxis(scene, position, 0.0.xxx, float3(0.0, 0.0, 1.0), worldAxisLength, 0.022, zColor, 1.0);

    // 흰 구는 월드 피벗, 노란 구는 직육면체의 자전 피벗이다.
    AddToScene(scene, SphereSDF(position, 0.0.xxx, 0.055), float3(1.0, 1.0, 1.0), 1.0);
    AddToScene(scene, SphereSDF(position, boxCenter, 0.045), float3(1.0, 0.88, 0.12), 1.0);

    // 직육면체는 X 방향으로 가장 길어서 회전 결과를 쉽게 구분할 수 있다.
    float3 boxLocal = WorldToBoxLocal(
        position,
        boxCenter,
        selfRotation,
        rotationOrder
    );
    float boxDistance = BoxSDF(boxLocal, float3(0.38, 0.19, 0.26));
    AddToScene(scene, boxDistance, float3(0.92, 0.58, 0.16), 2.0);

    // 짧은 로컬축은 직육면체 중심에서 시작하고 자전 자세를 그대로 따른다.
    float3 localX = ApplyForwardRotation(float3(1.0, 0.0, 0.0), selfRotation, rotationOrder);
    float3 localY = ApplyForwardRotation(float3(0.0, 1.0, 0.0), selfRotation, rotationOrder);
    float3 localZ = ApplyForwardRotation(float3(0.0, 0.0, 1.0), selfRotation, rotationOrder);
    float localAxisLength = 0.56;
    AddAxis(scene, position, boxCenter, localX, localAxisLength, 0.014, float3(1.0, 0.34, 0.32), 1.0);
    AddAxis(scene, position, boxCenter, localY, localAxisLength, 0.014, float3(0.34, 1.0, 0.42), 1.0);
    AddAxis(scene, position, boxCenter, localZ, localAxisLength, 0.014, float3(0.34, 0.55, 1.0), 1.0);

    return scene;
}

// ============================================================
// 4. 고정된 사선 카메라와 ray marching
// ============================================================

float3x3 LookAt(float3 eye, float3 target)
{
    float3 forward = normalize(target - eye);
    float3 right = normalize(cross(forward, float3(0.0, 1.0, 0.0)));
    float3 up = normalize(cross(right, forward));

    return float3x3(
        right.x, up.x, forward.x,
        right.y, up.y, forward.y,
        right.z, up.z, forward.z
    );
}

float MarchScene(
    float3 rayOrigin,
    float3 rayDirection,
    float3 boxCenter,
    float3 selfRotation,
    int rotationOrder)
{
    float rayDistance = 0.0;

    [loop]
    for (int stepIndex = 0; stepIndex < RAY_MARCH_STEPS; ++stepIndex)
    {
        float3 position = rayOrigin + rayDirection * rayDistance;
        float distance = SceneSDF(
            position,
            boxCenter,
            selfRotation,
            rotationOrder
        ).distance;

        if (distance < RAY_MARCH_EPSILON)
        {
            return rayDistance;
        }

        rayDistance += max(distance * 0.8, RAY_MARCH_EPSILON * 0.5);
        if (rayDistance > RAY_MARCH_MAX_DISTANCE)
        {
            break;
        }
    }

    return -1.0;
}

float3 SceneNormal(
    float3 position,
    float3 boxCenter,
    float3 selfRotation,
    int rotationOrder)
{
    float epsilon = 0.002;
    float centerDistance = SceneSDF(position, boxCenter, selfRotation, rotationOrder).distance;
    float3 normal = float3(
        SceneSDF(position + float3(epsilon, 0.0, 0.0), boxCenter, selfRotation, rotationOrder).distance - centerDistance,
        SceneSDF(position + float3(0.0, epsilon, 0.0), boxCenter, selfRotation, rotationOrder).distance - centerDistance,
        SceneSDF(position + float3(0.0, 0.0, epsilon), boxCenter, selfRotation, rotationOrder).distance - centerDistance
    );
    return normalize(normal);
}

float3 BackgroundColor(float3 rayDirection)
{
    float vertical = saturate(rayDirection.y * 0.5 + 0.5);
    return lerp(float3(0.025, 0.032, 0.055), float3(0.11, 0.14, 0.20), vertical);
}

float4 RenderRotationStage(
    float2 uv,
    float3 boxCenter,
    float3 selfRotation,
    int rotationOrder)
{
    // 카드 자체는 정사각형이므로 별도의 화면 종횡비 보정을 하지 않는다.
    float2 screenPosition = fitUV(uv);

    float3 rayOrigin = float3(2.65, 2.05, -3.45);
    float3 target = float3(0.18, 0.10, 0.05);
    float3 cameraRay = float3(screenPosition, 2.15);
    float3 rayDirection = normalize(mul(LookAt(rayOrigin, target), cameraRay));

    float rayDistance = MarchScene(
        rayOrigin,
        rayDirection,
        boxCenter,
        selfRotation,
        rotationOrder
    );

    float3 color = BackgroundColor(rayDirection);

    if (rayDistance >= 0.0)
    {
        float3 hitPosition = rayOrigin + rayDirection * rayDistance;
        SceneSample hit = SceneSDF(
            hitPosition,
            boxCenter,
            selfRotation,
            rotationOrder
        );
        float3 normal = SceneNormal(
            hitPosition,
            boxCenter,
            selfRotation,
            rotationOrder
        );

        float3 lightDirection = normalize(float3(-0.45, 0.80, -0.60));
        float diffuse = saturate(dot(normal, lightDirection));
        float rim = pow(1.0 - saturate(dot(normal, -rayDirection)), 3.0);

        // 축은 선명하게, 직육면체는 면 방향이 드러나도록 조금 더 강하게 음영 처리한다.
        float light = hit.material > 1.5
            ? (0.30 + 0.70 * diffuse + 0.18 * rim)
            : (0.58 + 0.42 * diffuse + 0.10 * rim);
        color = hit.color * light;
    }

    color = pow(saturate(color), 0.4545.xxx);
    return float4(color, 1.0);
}

// ============================================================
// 5. 단계별 출력
// ------------------------------------------------------------
// 아래 return 중 반드시 하나만 주석 해제한다.
// 고정값의 PI 비율을 직접 바꿔 본 뒤, 바로 아래 uCardTime 예제도 실험한다.
// ============================================================

float4 main(PSIn i) : SV_Target
{
    float3 worldPivot = float3(0.0, 0.0, 0.0);
    float3 startCenter = float3(0.50, 0.12, 0.0);

    // 1단계: 회전 없음. 긴 축은 월드축, 직육면체 중심의 짧은 축은 로컬축이다.
    return RenderRotationStage(i.uv, startCenter, float3(0.0, 0.0, 0.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, startCenter, float3(0.0, 0.0, 0.0) * uCardTime, ROTATION_ORDER_XYZ);

    // 2단계: 직육면체 중심을 기준으로 X축 자전한다.
    // return RenderRotationStage(i.uv, startCenter, float3(PI / 4.0, 0.0, 0.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, startCenter, float3(uCardTime * 0.7, 0.0, 0.0), ROTATION_ORDER_XYZ);

    // 3단계: X축 회전 결과에 이어서 Y축 회전을 적용한다.
    // return RenderRotationStage(i.uv, startCenter, float3(PI / 4.0, PI / 5.0, 0.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, startCenter, float3(uCardTime * 0.7, uCardTime * 0.5, 0.0), ROTATION_ORDER_XYZ);

    // 4단계: X -> Y -> Z 순서로 세 축 자전을 모두 적용한다.
    // return RenderRotationStage(i.uv, startCenter, float3(PI / 4.0, PI / 5.0, PI / 6.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, startCenter, uCardTime * float3(0.7, 0.5, 0.3), ROTATION_ORDER_XYZ);

    // 5단계: 4단계와 각도는 같고 순서만 Z -> Y -> X로 바꾼다. 최종 자세를 비교한다.
    // return RenderRotationStage(i.uv, startCenter, float3(PI / 4.0, PI / 5.0, PI / 6.0), ROTATION_ORDER_ZYX);
    // return RenderRotationStage(i.uv, startCenter, uCardTime * float3(0.7, 0.5, 0.3), ROTATION_ORDER_ZYX);

    // 6단계: 원점 기준 공전. 중심 위치만 회전하고 직육면체의 자세는 회전하지 않는다.
    // return RenderRotationStage(i.uv, OrbitAroundPivotXYZ(startCenter, worldPivot, float3(0.0, PI / 2.5, 0.0)), float3(0.0, 0.0, 0.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, OrbitAroundPivotXYZ(startCenter, worldPivot, float3(0.0, uCardTime * 0.6, 0.0)), float3(0.0, 0.0, 0.0), ROTATION_ORDER_XYZ);

    // 7단계: 중심은 원점을 공전하고, 직육면체와 로컬축은 자기 중심을 기준으로 자전한다.
    // return RenderRotationStage(i.uv, OrbitAroundPivotXYZ(startCenter, worldPivot, float3(0.0, PI / 2.5, 0.0)), float3(PI / 4.0, PI / 5.0, PI / 6.0), ROTATION_ORDER_XYZ);
    // return RenderRotationStage(i.uv, OrbitAroundPivotXYZ(startCenter, worldPivot, float3(0.0, uCardTime * 0.6, 0.0)), uCardTime * float3(0.9, 0.5, 0.3), ROTATION_ORDER_XYZ);
}
