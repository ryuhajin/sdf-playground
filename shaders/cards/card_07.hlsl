#include "../lib/sdf_common.hlsli"

float2 tileFract(float2 uv, float2 scale, out float2 cell)
{
    float2 scaled = uv * scale;
    cell = floor(scaled);
    return frac(scaled);
}

float gridLine(float2 localUv, float width)
{
    float2 edgeDist = min(localUv, 1.0 - localUv);
    float nearest = min(edgeDist.x, edgeDist.y);
    return 1.0 - smoothstep(width, width * 1.8, nearest);
}

float panelMask(float2 p, float2 center, float2 halfSize)
{
    float2 edge = halfSize - abs(p - center);
    return step(0.0, min(edge.x, edge.y));
}

float panelBorder(float2 p, float2 center, float2 halfSize)
{
    float2 q = abs(p - center) - halfSize;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    float w = max(fwidth(d), 0.002);
    return 1.0 - smoothstep(0.0, w * 2.0, abs(d));
}

float2 panelUv(float2 p, float2 center, float2 halfSize)
{
    return (p - center) / (halfSize * 2.0) + 0.5;
}

float3 sectionFract(float2 uv)
{
    float2 cell;
    float2 localUv = tileFract(uv, float2(4.0, 4.0), cell);

    float checker = frac(cell.x + cell.y * 0.5) * 0.08;
    float3 color = float3(localUv.x, localUv.y, 0.22 + checker);

    float grid = gridLine(localUv, 0.025);
    color = lerp(color, float3(1.0, 1.0, 1.0), grid * 0.85);

    float2 centerLine = abs(localUv - 0.5);
    float cross = 1.0 - smoothstep(0.012, 0.024, min(centerLine.x, centerLine.y));
    color = lerp(color, float3(0.05, 0.08, 0.12), cross * 0.45);

    return color;
}

float4 main(PSIn i) : SV_Target
{
    float2 cardPos = fitUV(i.uv);
    float2 p = applyCardShapeTransform(cardPos);

    float3 color = float3(0.035, 0.040, 0.052);

    float2 panel1Center = float2(-0.58, 0.48);
    float2 panelHalf = float2(0.34, 0.34);

    float mask1 = panelMask(p, panel1Center, panelHalf);
    float3 section1 = sectionFract(panelUv(p, panel1Center, panelHalf));
    color = lerp(color, section1, mask1);

    float border1 = panelBorder(p, panel1Center, panelHalf);
    color = lerp(color, float3(0.80, 0.88, 1.0), border1);

    return float4(color, 1.0);
}
