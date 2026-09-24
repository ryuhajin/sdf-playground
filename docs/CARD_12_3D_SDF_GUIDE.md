# `card_12`로 이해하는 3D SDF, 가상 카메라와 볼륨 레이마칭

이 문서는 2D SDF에서 좌표를 역변환해 원과 사각형을 그려 본 사람을 대상으로 한다. 목표는 `card_12.hlsl`에서 다음 값들이 어느 좌표 공간에 있고, 한 픽셀의 색상이 어떤 순서로 계산되는지 설명하는 것이다.

- 2D SDF와 3D SDF는 무엇이 같고 무엇이 다른가?
- 카드의 실제 공간과 PS 내부의 가상 공간은 어떻게 구분되는가?
- `GetRayOrigin`, `GetTarget`, `LookAt`은 카메라의 무엇을 만드는가?
- 2D 회전을 어떻게 3D 축 회전으로 확장하는가?
- `ObjectMarch`와 `VolumeMarch`는 어떻게 협력해 Voronoi 볼륨을 그리는가?

> 핵심 문장: 2D와 3D SDF 모두 **샘플 좌표를 원본 도형의 로컬 공간으로 되돌린 뒤 거리 함수를 평가한다.** 3D에서는 픽셀 하나가 3D 위치 하나가 아니라 광선 하나를 나타내므로, 광선 위의 여러 3D 위치를 만드는 단계가 추가된다.

---

## 1. 2D SDF와 3D SDF

### 1.1 SDF가 답하는 질문

SDF(Signed Distance Function)는 좌표를 입력받아 가장 가까운 표면까지의 부호 있는 거리를 반환한다.

```text
distance < 0 : 도형 내부
distance = 0 : 도형 표면
distance > 0 : 도형 외부
```

2D 원과 3D 구의 공식은 거의 같다.

```hlsl
// 2D 원: p는 float2
float CircleSDF(float2 p, float radius)
{
    return length(p) - radius;
}

// 3D 구: p는 float3
float SphereSDF(float3 p, float radius)
{
    return length(p) - radius;
}
```

차이는 함수가 정의된 공간의 차원이다.

| 구분 | 2D SDF | 3D SDF |
|---|---|---|
| 함수 입력 | `float2` 위치 | `float3` 위치 |
| 픽셀과 샘플의 관계 | 픽셀당 2D 위치 하나 | 픽셀당 레이 하나, 레이 위 3D 위치 여러 개 |
| 표면 찾기 | 현재 좌표의 거리 부호로 즉시 판단 | 레이를 이동하며 표면 위치를 탐색 |
| 일반적인 출력 | fill/stroke 마스크 | 표면 조명 또는 볼륨 누적색 |
| 공통 원리 | 샘플 좌표를 도형 로컬 공간으로 역변환한 뒤 SDF 평가 | 동일 |

### 1.2 2D에서 사용하던 역변환

도형 함수는 보통 원점에 놓인 표준 도형을 정의한다. 화면에 이동·회전·확대된 도형을 보이게 하려면 현재 픽셀을 표준 도형의 로컬 공간으로 되돌린다.

```text
카드의 현재 픽셀 p
→ 이동의 역변환
→ 회전의 역변환
→ 스케일의 역변환
→ 표준 도형 SDF
```

중심이 `center`, 회전이 `angle`, 크기가 `scale`인 2D 도형의 전형적인 형태는 다음과 같다.

```hlsl
float2 localPosition = pixelPosition - center;
localPosition = Rotate2D(localPosition, -angle);
localPosition /= scale;

float distance = CircleSDF(localPosition, 1.0) * scale;
```

- 도형을 `+center`만큼 이동하려면 샘플 좌표에서 `center`를 뺀다.
- 도형을 `+angle`만큼 회전하려면 샘플 좌표를 `-angle`만큼 회전한다.
- 도형을 `scale`배 크게 보이게 하려면 샘플 좌표를 `scale`로 나눈다.
- 정확한 월드 거리까지 보존하려면 마지막 거리 값에 `scale`을 다시 곱한다.

2D 마스크는 거리의 부호만으로도 형태를 그릴 수 있어 거리 스케일 오차가 눈에 덜 띌 수 있다. 하지만 3D sphere tracing은 반환 거리를 다음 이동량으로 사용하므로 올바른 거리 단위가 더 중요하다.

### 1.3 3D에도 같은 역변환이 있다

3D에서는 픽셀에서 바로 도형 로컬 좌표가 나오지 않는다. 먼저 카메라 레이를 만들고, 레이 위의 한 점을 구한 뒤, 그 점을 도형 로컬 공간으로 역변환한다.

```text
픽셀 UV
→ 카메라 로컬 광선
→ 가상 월드 광선
→ 레이 위의 3D 월드 위치
→ 물체 역변환
→ 3D 물체 로컬 좌표
→ 3D SDF 평가
```

전형적인 코드는 다음 형태다.

```hlsl
float3 worldPosition = rayOrigin + rayDirection * rayDistance;
float3 localPosition = InverseObjectTransform(worldPosition);
float distance = ObjectSDF(localPosition);
```

`card_12`의 `Transform3D()`는 현재 입력을 그대로 반환한다.

```hlsl
float3 Transform3D(float3 position)
{
    return position;
}
```

따라서 현재는 가상 SDF 월드 공간과 구의 로컬 공간이 일치한다. 역변환 방식이 사라진 것이 아니라 **항등변환이라 보이지 않는 것**이다.

---

## 2. 실제 카드 공간과 PS 내부의 가상 공간

### 2.1 실제로 존재하는 모델

애플리케이션이 실제로 그리는 지오메트리는 버텍스 4개와 인덱스 6개로 만든 카드 한 장이다.

```text
(-1, 1) ┌──────────┐ (1, 1)
        │        ／│
        │      ／  │  삼각형 2개
        │    ／    │
(-1,-1) └──────────┘ (1,-1)
```

공통 vertex shader는 카드 버텍스에 `uWorld`와 `uViewProj`를 적용한다.

```text
카드 로컬 버텍스
→ uWorld
→ 애플리케이션 월드
→ uViewProj
→ 클립 공간
→ 래스터라이저
→ 화면 픽셀과 보간된 UV
```

PS 한 번의 실행에는 카드 모델 전체가 전달되지 않는다. 현재 fragment의 `SV_Position`과 보간된 UV 등이 전달된다. `card_12`는 실제 화면 위치인 `i.pos` 대신 카드 표면에 고정된 `i.uv`를 사용한다.

### 2.2 가상 공간은 실제 월드를 역투영한 결과가 아니다

`card_12`는 실제 애플리케이션의 `uViewProj` 역행렬로 월드 위치를 복원하지 않는다. 카드 UV를 새 가상 카메라의 이미지 평면 좌표로 해석하고, PS 안에서 독립적인 3D 공간을 정의한다.

```text
[실제 카드 렌더링 공간]
카드 quad
→ quad VS에서 uWorld, uViewProj 적용
→ 래스터라이저
→ 픽셀별 보간 UV

[PS 내부 가상 SDF 공간]
픽셀별 보간 UV
→ fitUV로 이미지 평면 좌표 -1..1 생성
→ cameraRay로 카메라 로컬 광선 생성
→ LookAt으로 가상 월드 방향 변환
→ P(t)로 가상 월드 위치 계산
→ Transform3D로 오브젝트 로컬 위치 변환
→ SphereSDF로 구의 경계 검사

가상 월드 위치
→ 좌표에 1.4를 곱해 Voronoi 좌표 생성
→ 밀도 누적
→ 카드 픽셀 RGB 출력
```

두 공간은 UV와 최종 RGB를 통해서만 연결된다.

```text
외부 실제 카메라: 카드가 화면 어디에 놓이는가?
내부 가상 카메라: 카드 안의 가상 볼륨이 어떻게 보이는가?
```

카드를 Coverflow에서 회전하면 가상 구가 실제 월드에서 회전하는 것이 아니다. 가상 장면을 계산한 RGB 이미지가 카드 UV에 붙어 있으므로 카드와 함께 돌아가는 디스플레이처럼 보인다.

### 2.3 구는 볼륨을 담는 경계다

`card_12`의 구에는 메시도 없고, 구 표면을 위한 normal/lighting도 없다. 구 SDF는 광선이 Voronoi 볼륨을 샘플링할 입구와 출구를 제한하는 용기 역할을 한다.

```text
레이가 구를 놓침 → BackgroundColor
레이가 구를 통과 → entry부터 exit까지 Voronoi 밀도 누적
```

---

## 3. 가상 카메라 이해하기

### 3.1 이 셰이더의 카메라 구성요소

| 요소 | 코드 | 의미 |
|---|---|---|
| 위치 | `rayOrigin` | 모든 픽셀 광선이 출발하는 가상 월드 위치 |
| 응시점 | `target` | 카메라가 바라보는 가상 월드의 점 |
| 정면축 | `forward` | `normalize(target - eye)` |
| 오른쪽축 | `right` | 화면에서 오른쪽이 향할 월드 방향 |
| 위쪽축 | `up` | 화면에서 위쪽이 향할 월드 방향 |
| roll | `0.0` | 이 구현에서 XY 평면의 위쪽 기준 벡터를 돌리는 값 |
| 이미지 평면 | `float3(screenPosition, 2.0)` | 각 픽셀의 카메라 로컬 방향과 FOV 결정 |

`screenPosition`은 카드 UV를 `-1..1`로 바꾼 가상 이미지 평면 좌표다. 여기서 이미지 평면은 메시나 quad처럼 실제로 렌더링되는 지오메트리가 아니다. 카메라 로컬 공간에서 `Z=2`, `X/Y=-1..1`에 놓여 있다고 가정한 수학적 평면이며, 픽셀마다 광선 방향을 계산하기 위한 기준으로만 사용한다.

```hlsl
float2 screenPosition = fitUV(i.uv);
float3 cameraRay = float3(screenPosition, 2.0);
```

이미지 평면은 다음 세 역할을 한다.

1. 각 픽셀에 서로 다른 카메라 로컬 광선 방향을 부여한다.
2. 2D 화면의 가로·세로 위치를 3D 광선 방향의 X·Y 성분으로 연결한다.
3. 이미지 평면 크기와 카메라 원점에서 평면까지의 Z 거리 비율로 FOV를 결정한다.

가로 중앙선 위의 대표 픽셀을 정규화 전 `cameraRay`로 비교하면 다음과 같다.

| 픽셀 위치 | `screenPosition` | `cameraRay` | 의미 |
|---|---|---|---|
| 왼쪽 | `(-1, 0)` | `(-1, 0, 2)` | 정면보다 왼쪽을 향함 |
| 중앙 | `(0, 0)` | `(0, 0, 2)` | 카메라 로컬 `+Z`, 즉 정면을 향함 |
| 오른쪽 | `(1, 0)` | `(1, 0, 2)` | 정면보다 오른쪽을 향함 |

```text

```

이 벡터들은 이후 `LookAt`으로 가상 월드 방향으로 회전되고 `normalize`된다. 따라서 위 값의 길이보다 X:Y:Z 비율, 즉 어느 방향을 가리키는지가 중요하다.

가로 화면 반너비를 `halfWidth`, 이미지 평면 거리를 `Z`라고 하면 정면에서 화면 한쪽 끝까지의 반각과 전체 가로 FOV는 다음 관계를 가진다.

```text
angle = atan(halfWidth / Z)
FOV = 2 × angle
```

현재처럼 X 범위가 `-1..1`이면 `halfWidth=1`이다.

| `Z` | `angle = atan(1 / Z)` | 가로 `FOV = 2 × angle` |
|---:|---:|---:|
| 1 | 45.00° | 90.00° |
| 2 | 26.565° | 약 53.13° |
| 4 | 약 14.036° | 약 28.07° |

Z를 키우면 가장자리 광선이 정면에 가까워져 FOV가 좁아지고, Z를 줄이면 광선이 더 퍼져 FOV가 넓어진다. 단, **Z 자체가 아니라 이미지 평면 크기와 Z의 비율이 중요하다.** 예를 들어 `halfWidth=1, Z=2`와 `halfWidth=2, Z=4`는 비율이 같으므로 동일한 가로 FOV를 만든다.

마지막으로 `target`과 이미지 평면의 역할은 다르다. `target`은 중앙 픽셀의 시선인 `forward` 방향을 정하고, 이미지 평면은 그 중앙 시선 주변에서 왼쪽·오른쪽·위·아래 픽셀이 얼마나 벌어진 광선 방향을 가질지 정한다.

### 3.2 `GetTarget(time)`

target은 near/far가 아니라 카메라가 바라볼 점이다.

```hlsl
float3 forward = normalize(target - eye);
```

함수는 두 응시점 중 하나를 선택한다.

```hlsl
float3 movingTarget = 0.4 * sin(
    time * float3(0.17, 0.11, 0.13)
);
float3 fixedTarget = float3(0.0, 0.5, 0.0);
```

- `movingTarget`: 각 축이 서로 다른 속도로 `-0.4..0.4`를 움직여 원점 근처를 떠돈다.
- `fixedTarget`: 구 중심보다 Y축으로 0.5 위인 고정점이다.

```hlsl
float cameraMode = step(0.5, frac(time * 0.1));
```

`frac(time*0.1)`은 10초마다 `0..1`을 반복한다.

| 시간 구간 | `cameraMode` | 선택되는 target |
|---|---:|---|
| 0~5초 | 0 | `movingTarget` |
| 5~10초 | 1 | `fixedTarget` |
| 10~15초 | 0 | `movingTarget` |

`cameraMode`가 0 또는 1이므로 `lerp`는 부드러운 보간이 아니라 즉시 선택으로 동작한다.

### 3.3 `GetRayOrigin(time)`

`rayOrigin`은 가상 SDF 공간의 카메라 위치이며, 두 위치 애니메이션 중 하나를 선택한다.

#### Orbit 모드

```hlsl
float3(cos(time * PI * 0.3), 0.0, sin(time * PI * 0.3))
```

`x=cos(angle)`, `z=sin(angle)`은 XZ 평면의 반지름 1인 원을 만든다. 여기에 `Rotate3D(..., z=PI/6)`을 적용해 궤도면을 Z축으로 30도 기울이고, 마지막에 2를 곱해 궤도 반지름을 2로 만든다.

```hlsl
float3 orbitCamera = 2.0 * Rotate3D(
    float3(cos(time * PI * 0.3), 0.0, sin(time * PI * 0.3)),
    float3(0.0, 0.0, PI / 6.0)
);
```

구 반지름은 5이므로 이 카메라는 구 내부에 있다.

#### Forward 모드

```hlsl
float3 forwardCamera = float3(
    0.0,
    0.0,
    5.0 - sin(time * 0.37)
);
```

X/Y는 고정되고 Z만 4~6 사이를 왕복한다. 구 반지름이 5이므로 시간에 따라 구 안과 밖을 오갈 수 있다.

`GetTarget`과 같은 `cameraMode`를 사용하므로 카메라 쌍은 다음처럼 바뀐다.

```text
0~5초  : orbitCamera + movingTarget
5~10초 : forwardCamera + fixedTarget
```

### 3.4 카메라 이동과 target 이동의 차이

```text
[카메라 위치가 움직일 때]
eye 변경
→ 광선 출발점 변경
→ 시차와 관측 위치 변경

[target이 움직일 때]
eye 고정
→ forward 방향 변경
→ 같은 자리에서 고개를 돌린 것처럼 보임
```

| 상황 | 카메라 위치 | target | 결과 |
|---|---|---|---|
| 카메라만 이동 | 변경 | 고정 | 물체 주위를 돌거나 가까워짐, 시차 발생 |
| target만 이동 | 고정 | 변경 | 제자리에서 pan/tilt하듯 시선만 변경 |
| 둘 다 같은 양만큼 이동 | 변경 | 변경 | 바라보는 방향은 같지만 장면 속 관측 위치는 변경 |

### 3.5 `LookAt`과 카메라 basis

`cameraRay`는 카메라 로컬 좌표다.

```text
+X: 카메라 화면 오른쪽
+Y: 카메라 화면 위쪽
+Z: 카메라 정면
```

이 벡터를 SDF가 정의된 가상 월드 방향으로 바꾸려면 월드에서 카메라의 세 축이 어느 방향인지 알아야 한다.

```hlsl
float3 forward = normalize(target - eye);
float3 right = normalize(cross(forward, referenceUp));
float3 up = normalize(cross(right, forward));
```

세 벡터는 서로 수직인 카메라 좌표계, 즉 basis를 만든다.

```text
                  up
                  ↑
                  │
                  ●────→ right
                 ╱
            forward
```

현재 구현의 `float3(sin(roll), cos(roll), 0)`은 월드 XY 평면에서 기준 up을 회전시킨다. 카메라의 forward가 Z축에 가까울 때는 일반적인 “정면축 주위로 기울이는 roll”처럼 동작하지만, 임의의 forward에 대한 완전한 축 회전 공식은 아니다. 현재 호출은 `roll=0`이므로 월드 `+Y`를 위쪽 기준으로 사용하는 것으로 이해하면 충분하다.

행렬의 열에 세 축을 배치하면 행렬 곱은 개념적으로 다음과 같다.

```hlsl
worldRay =
      right   * cameraRay.x
    + up      * cameraRay.y
    + forward * cameraRay.z;
```

위치 이동은 `rayOrigin`이 별도로 담당하므로 방향 회전에는 4×4가 아닌 3×3 행렬이면 충분하다. 이 프로젝트의 `LookAt`은 일반적인 `world → view` 행렬이라기보다 `camera local direction → virtual world direction` basis 행렬이다.

---

## 4. 2D 회전에서 3D 회전으로

### 4.1 2D 원점 회전

2D 점 `p=(x,y)`를 원점 기준으로 각도 θ만큼 회전하는 행렬은 다음과 같다.

```text
x' = cosθ·x - sinθ·y
y' = sinθ·x + cosθ·y
```

```hlsl
float2x2 Rotation2D(float radians)
{
    float c = cos(radians);
    float s = sin(radians);
    return float2x2(c, -s, s, c);
}

float2 Rotate2D(float2 position, float radians)
{
    return mul(Rotation2D(radians), position);
}
```

임의 중심 `C` 주위로 점을 회전하려면 중심을 원점으로 옮기고, 회전한 뒤, 중심을 되돌린다.

```hlsl
float2 rotatedPoint =
    center + Rotate2D(point - center, angle);
```

이 공식은 점이나 카메라 위치를 실제로 회전시키는 forward transform이다. 반대로 SDF 도형을 `+angle` 회전해 보이게 만들려면 샘플 좌표에 역변환을 적용한다.

```hlsl
float2 localPosition =
    Rotate2D(worldPosition - center, -angle);
```

### 4.2 3D 축 회전은 2D 평면 회전이다

3D에서도 한 축을 고정하면 나머지 두 좌표가 2D 평면을 만든다.

| 회전축 | 고정 좌표 | 회전하는 2D 평면 | 코드 |
|---|---|---|---|
| Z축 | z | xy | `position.xy = Rotate2D(position.xy, zAngle)` |
| X축 | x | yz | `position.yz = Rotate2D(position.yz, xAngle)` |
| Y축 | y | zx | `Rotate2D(position.zx, yAngle)` |

즉 “3D 회전”을 처음에는 “선택한 축에 수직인 평면에서 하는 2D 회전”으로 이해할 수 있다.

### 4.3 `Rotate3D`의 적용 순서

```hlsl
float3 Rotate3D(float3 position, float3 radians)
{
    position.xy = Rotate2D(position.xy, radians.z); // Z축
    position.yz = Rotate2D(position.yz, radians.x); // X축

    float2 rotatedZX = Rotate2D(position.zx, radians.y); // Y축
    position.z = rotatedZX.x;
    position.x = rotatedZX.y;
    return position;
}
```

현재 순서는 Z → X → Y다. 첫 회전이 좌표를 바꾸므로 그다음 회전이 받는 입력도 달라진다. 따라서 3D Euler 회전은 일반적으로 순서를 바꾸면 결과도 바뀐다.

```text
RotateZ → RotateX ≠ RotateX → RotateZ
```

Euler 각은 직관적이지만 특정 자세에서 두 회전축이 겹쳐 자유도 하나를 잃는 gimbal lock이 생길 수 있다. 현재처럼 짧은 시각 효과와 작은 회전을 만드는 코드에서는 Euler 방식이 이해하고 조절하기 쉽다. 복잡한 카메라 자세 누적에는 quaternion이 더 적합할 수 있다.

### 4.4 `orbitCamera`에서 실제로 회전하는 것

`orbitCamera`에서는 두 작업을 구분해야 한다.

1. `cos/sin`이 시간에 따라 XZ 원 위의 카메라 위치를 만든다.
2. `Rotate3D(..., z=PI/6)`이 그 위치 벡터를 회전해 원의 궤도면을 기울인다.

즉 시간에 따른 주 회전 궤도는 이미 `cos/sin`이 만들며, `Rotate3D`는 그 궤도를 30도 기울인다.

임의의 중심 `C` 주위를 돌고 싶다면 다음 패턴을 사용한다.

```hlsl
float3 offset = float3(0.0, 0.0, -radius);
float3 eye = center + Rotate3D(offset, orbitAngles);
```

이것은 카메라 위치를 움직이는 orbit이다. 카메라를 제자리에서 회전하려면 eye는 유지하고 시선 방향을 회전한다.

```hlsl
float3 viewDirection = target - eye;
float3 rotatedDirection = Rotate3D(viewDirection, lookAngles);
float3 rotatedTarget = eye + rotatedDirection;
```

```text
orbit: eye가 움직이고 대개 target은 중심 근처에 유지
제자리 회전: eye는 고정하고 target-eye 방향을 회전
```

---

## 5. `card_12`의 픽셀당 실행 흐름

```text
PS 입력 i.uv
→ fitUV로 screenPosition 생성
→ GetRayOrigin으로 rayOrigin 계산
→ GetTarget으로 target 계산
→ LookAt으로 카메라 basis 생성
→ cameraRay = (screen.x, screen.y, 2) 생성
→ rayDirection = normalize(LookAt × cameraRay)
→ ObjectMarch로 구의 entry/exit 탐색

구를 hit하지 않음
→ BackgroundColor
→ 감마 보정 후 RGB 출력

구를 hit함
→ VolumeMarch로 밀도 24회 샘플링
→ 감마 보정 후 RGB 출력
```

한 픽셀의 핵심 수식은 다음이다.

```hlsl
float3 samplePosition =
    rayOrigin + rayDirection * rayDistance;
```

모든 값은 `rayDirection`을 만든 뒤부터 같은 가상 SDF 월드 좌표계를 사용한다.

---

## 6. `ObjectMarch`: 구의 입구와 출구 찾기

### 6.1 목적

`ObjectMarch`는 Voronoi 밀도를 계산하지 않는다. 광선이 볼륨의 경계 구를 통과하는 구간만 찾는다.

```text
result.x = entry까지의 rayDistance
result.y = exit까지의 rayDistance
result.x = -1이면 miss
```

```text
rayOrigin ●────────│════════════════│────────→
                   entry            exit
                   objectRange.x    objectRange.y
```

### 6.2 입구 탐색

```hlsl
float rayDistance = distanceRange.x;

float distanceToSurface = ObjectSDF(
    rayOrigin + rayDirection * rayDistance
);

rayDistance += distanceToSurface;
```

`rayDirection`이 정규화되어 있으므로 `rayDistance`는 가상 월드 거리 단위로 해석할 수 있다. SDF가 반환한 안전한 거리만큼 전진하며 `distanceToSurface < 0.0001`이 되면 표면에 도착했다고 판단한다. 최대 64번 반복하고 거리가 10을 넘으면 miss를 반환한다.

### 6.3 카메라가 이미 구 안에 있을 때

구 내부의 SDF는 음수다. 현재 입구 루프의 종료 조건은 다음과 같다.

```hlsl
if (distanceToSurface < OBJECT_MARCH_THRESHOLD)
    break;
```

따라서 orbit 모드처럼 카메라가 반지름 5인 구 내부에 있으면 첫 샘플에서 바로 종료하고 entry를 시작 거리 0으로 취급한다. 이 경우 entry는 실제 외부 표면이 아니라 “현재 카메라 위치부터 볼륨을 샘플링한다”는 의미다.

### 6.4 출구 탐색

입구를 다시 감지하지 않도록 0.05만큼 안으로 들어간 뒤, 내부에서 음수인 SDF의 부호를 뒤집는다.

```hlsl
rayDistance += 0.05;

float distanceToSurface = -ObjectSDF(
    rayOrigin + rayDirection * rayDistance
);

rayDistance += distanceToSurface;
```

그러면 구 내부에서도 양의 이동 거리를 얻어 출구 표면까지 sphere tracing할 수 있다.

---

## 7. `VolumeMarch`: 구 내부 Voronoi 밀도 누적

### 7.1 목적

`VolumeMarch`는 `ObjectMarch`가 찾은 entry~exit 구간을 같은 간격으로 24등분한다.

```hlsl
float rayDistance = distanceRange.x;
float stepDistance =
    (distanceRange.y - distanceRange.x)
    / VOLUME_MARCH_ITERATIONS;
```

각 반복에서 가상 월드의 샘플 위치를 구한다.

```hlsl
float3 samplePosition =
    rayOrigin + rayDirection * rayDistance;
```

### 7.2 가상 월드 좌표에서 노이즈 좌표로

`VolumeDensity`는 샘플 위치를 볼륨 로컬 좌표로 바꾼 뒤 1.4를 곱한다.

```hlsl
position = Transform3D(position);
position *= 1.4;
```

현재 `Transform3D`는 항등변환이다. `position *= 1.4`는 같은 구 안에서 더 넓은 Voronoi 좌표 범위를 읽게 하므로 패턴을 더 촘촘하게 만든다.

`Voronoi3D`는 3D 텍스처를 읽는 함수가 아니다. 입력 좌표 주변의 셀과 특징점 위치를 hash로 생성해 그 위치의 F1/F2를 절차적으로 계산한다.

```hlsl
float secondDistance = Voronoi3D(position).y;
float shapedDistance = pow(secondDistance, 3.0);
float density = 1.0 / max(shapedDistance, 0.0001);
```

### 7.3 색상 누적

24개 위치의 밀도를 순서대로 누적한다.

```hlsl
color = lerp(
    density * volumeColor,
    color,
    historyWeight
);
```

이 식은 엄밀한 물리 기반 흡수·산란 적분이라기보다 밝은 Voronoi 구조의 대비를 만들기 위한 스타일화된 누적이다.

### 7.4 두 march 함수의 관계

```text
픽셀 레이
→ ObjectMarch
→ SDF가 반환한 거리만큼 가변 전진
→ 구의 entry / exit 획득
→ VolumeMarch
→ entry~exit 구간을 24등분
→ 각 P(t)의 Voronoi 밀도 계산
→ 밀도 색상 누적
→ 픽셀 RGB 출력
```

| 함수 | 이동 간격 | 평가 함수 | 결과 |
|---|---|---|---|
| `ObjectMarch` | SDF가 반환한 가변 거리 | `ObjectSDF` | 구의 entry/exit |
| `VolumeMarch` | `(exit-entry)/24` 고정 거리 | `VolumeDensity` | 누적 볼륨 색상 |

---

## 8. 한 픽셀의 좌표 공간 추적

| 단계 | 값 | 좌표 공간 또는 의미 |
|---:|---|---|
| 1 | `i.uv` | 실제 카드 표면의 UV |
| 2 | `screenPosition` | 가상 카메라 이미지 평면 `-1..1` |
| 3 | `cameraRay` | 가상 카메라 로컬 방향 |
| 4 | `rayDirection` | 가상 SDF 월드 방향 |
| 5 | `rayOrigin + rayDirection * rayDistance` | 가상 SDF 월드 위치 |
| 6 | `Transform3D(position)` | 볼륨/구의 오브젝트 로컬 위치, 현재는 동일 |
| 7 | `SphereSDF(position, 5)` | 구 표면까지의 부호 있는 거리 |
| 8 | `position * 1.4` | Voronoi 노이즈 좌표 |
| 9 | `VolumeDensity` | 해당 3D 위치의 절차적 밀도 |
| 10 | 누적 `color` | 실제 카드 픽셀에 출력할 RGB |

마지막으로 전체를 한 문장으로 정리하면 다음과 같다.

> 카드의 실제 quad가 PS를 실행할 픽셀과 UV를 제공하면, 각 픽셀은 UV로부터 가상 카메라 레이를 만들고, 그 레이를 가상 SDF 월드에서 전진시켜 구의 통과 구간을 찾은 뒤, 구간 내부의 3D Voronoi 밀도를 24번 누적해 자신의 RGB를 결정한다.
