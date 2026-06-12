#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_transform.hlsli"
#include "../lib/sdf_operators.hlsli"

float4 main(PSIn i) : SV_Target {
    // [-1~1] 좌표로 만들기
    float2 cardPos = fitUV(i.uv);
    
    // imGui Transform 반영
    float2 p = applyCardShapeTransform(cardPos);
    
    // 세로 줄 사이 간격
    float spacing = 0.08; 
    
    // x 방향 반복 패턴 생성
    float localX = repeatCentered(p.x, spacing);

    // top, bottom wave : y 범위 곡선으로 만들기
    // x를 넣었으므로 x 위치마다 다른 y 높이 생성
    float t = uCardTime * 0.7;
    float topWave = sin(p.x * 1.7 + t); 
    float bottomWave = sin(p.x * 2.4 - t + 1.2);
    
    float topY = 0.25 + topWave * 0.41;
    float bottomY = -0.25 + bottomWave * 0.28;
    
    // 현재 픽셀이 topY, bottomY 사이에 있는지 거리 계산
    float posY = saturate((p.y - bottomY) / max(topY - bottomY, 0.001));
    
    // 가운데에서 가장 두껍고 양끝으로 갈수록 얇음
    float taper = sin(posY * 3.1415926);
    
    // y 위치별 두께
    float lineWidth = lerp(0.003, 0.022, taper);
    
    // 세로 선 거리
    float taperedLineD = abs(localX) - lineWidth;
    
    // topY ~ bottomY 사이만 남기기
    float insideTop = topY - p.y;
    float insideBottom = p.y - bottomY;
    float bandD = -min(insideTop, insideBottom);
    
    float d = max(taperedLineD, bandD);
    
    return mask(d);
}
