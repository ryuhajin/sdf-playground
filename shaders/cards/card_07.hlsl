#include "../lib/sdf_common.hlsli"

// cellId 같은 2D 번호를 넣으면 0~1 사이의 가짜 랜덤값
// 같은 cellId는 항상 같은 값을 반환하므로 타일 패턴이 프레임마다 흔들리지 않음
float Hash21(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// 타일 내부에 대각선 삼각형 마스크를 만든다.
// uv는 0~1 범위의 타일 내부 좌표.
// uv.x > uv.y 쪽을 1
float TriangleMask(float2 uv)
{
    float d = uv.x - uv.y;

    // 대각선 경계 주변을 살짝 부드럽게 처리한다.
    return smoothstep(-0.01, 0.01, d);
}

// 타일 경계선을 보여주는 마스크.
// localUV가 0 또는 1에 가까우면 타일 가장자리다.
float GridMask(float2 uv)
{
    float2 edgeDist = min(uv, 1.0 - uv);
    float d = min(edgeDist.x, edgeDist.y);

    return 1.0 - smoothstep(0.01, 0.02, d);
}

float4 main(PSIn i) : SV_Target
{
    float2 uv = i.uv;

    // 전체 화면 10 x 10 타일
    float2 tile = float2(10.0, 10.0);
    float2 tiledUV = uv * tile;

    // cellId는 현재 픽셀이 속한 타일의 정수 번호
    // 예: (0,0), (1,0), (2,0), ...
    float2 cellId = floor(tiledUV);

    // localUV는 각 타일 안의 0~1 좌표
    // 모든 타일이 같은 작은 uv 공간을 가짐
    float2 localUV = frac(tiledUV);

    // cellId를 기반으로 0~1 사이 랜덤값 생성
    // 타일마다 다른 값이 나오지만, 같은 타일 안에서는 같은 값
    float random01 = Hash21(cellId);

    // 0~1 랜덤값을 0,1,2,3 네 가지 type으로 바꾸기
    //
    // random01 * 4.0 : 0~4 범위
    // floor(...)     : 0,1,2,3 중 하나
    float type = floor(random01 * 4.0);

    // type 0,1,2,3을 x/y 뒤집기 스위치로 분해
    //
    // type | flipX | flipY
    //  0   |   0   |   0
    //  1   |   1   |   0
    //  2   |   0   |   1
    //  3   |   1   |   1
    //
    // flipX는 0,1,0,1로 반복
    float flipX = fmod(type, 2.0);

    // flipY는 0,0,1,1로 반복
    float flipY = floor(type / 2.0);

    // if 없이 lerp로 x 좌표를 선택
    // flipX가 0이면 localUV.x,
    // flipX가 1이면 1.0 - localUV.x를 선택
    float x = lerp(localUV.x, 1.0 - localUV.x, flipX);

    // if 없이 lerp로 y 좌표를 선택
    // flipY가 0이면 localUV.y,
    // flipY가 1이면 1.0 - localUV.y를 선택
    float y = lerp(localUV.y, 1.0 - localUV.y, flipY);

    float2 tileUV = float2(x, y);

    // 변형된 tileUV에 같은 삼각형 마스크 하나만 적용
    // tileUV가 뒤집혔기 때문에 타일마다 삼각형 방향이 달라 보인다
    float tri = TriangleMask(tileUV);

    float3 white = float3(1.0, 1.0, 1.0);
    float3 black = float3(0.0, 0.0, 0.0);

    float3 color = lerp(white, black, tri);

    // 타일 경계 그리기
    float grid = GridMask(localUV);
    color = lerp(color, float3(0.15, 0.15, 0.15), grid);

    return float4(color, 1.0);
}