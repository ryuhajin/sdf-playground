#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_operators.hlsli"
#include "../lib/sdf_animation.hlsli"

float4 main(PSIn i) : SV_Target
{
    float2 cardPos = fitUV(i.uv);
    float2 shapePos = applyCardShapeTransform(cardPos);
    float2 p = shapePos;

    float t = uCardTime;
    float ox = 0.35 * sin(t * 1.2);
    float oy = 0.20 * cos(t * 1.7);

    float a = sdCircle(p - float2(-ox, -oy), 0.30);
    float b = sdCircle(p - float2(ox, oy), 0.30);

    float k = max(0.05, uCardParams.x * 0.5 + 0.10);
    float d = opSMin(a, b, k);
    return mask(d);
}
