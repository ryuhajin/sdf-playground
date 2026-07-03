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

float2 rotate2(float2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float oddRow(float row)
{
    return step(1.0, fmod(row, 2.0));
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

float3 sectionMatrix(float2 uv)
{
    float2 cell;
    float2 localUv = tileFract(uv, float2(4.0, 4.0), cell);
    float2 local = localUv * 2.0 - 1.0;

    float angle = (cell.x + cell.y) * 0.35 + 0.7;
    float2 q = rotate2(local, angle);

    float barA = 1.0 - smoothstep(0.035, 0.055, abs(q.x));
    float barB = 1.0 - smoothstep(0.035, 0.055, abs(q.y));
    float diamond = 1.0 - smoothstep(0.48, 0.52, abs(q.x) + abs(q.y));
    float motif = max(max(barA, barB) * 0.75, diamond);

    float3 color = lerp(float3(0.08, 0.09, 0.12), float3(0.95, 0.70, 0.20), motif);
    color += float3(localUv.x, localUv.y, 0.0) * 0.15;

    float grid = gridLine(localUv, 0.020);
    color = lerp(color, float3(0.92, 0.94, 1.0), grid * 0.65);

    return color;
}

float3 sectionAnimation(float2 uv, float t)
{
    float2 cell;
    float2 localUv = tileFract(uv, float2(5.0, 5.0), cell);
    float2 local = localUv * 2.0 - 1.0;

    float phase = dot(cell, float2(0.7, 1.1));
    float spin = t * 1.3 + phase;
    float2 q = rotate2(local, spin);

    float pulse = 0.5 + 0.5 * sin(t * 2.2 + phase);
    float radius = lerp(0.18, 0.42, pulse);
    float ring = 1.0 - smoothstep(0.025, 0.045, abs(length(q) - radius));
    float slash = 1.0 - smoothstep(0.025, 0.050, abs(q.x + q.y));
    float motif = max(ring, slash * 0.65);

    float3 low = float3(0.04, 0.08, 0.12);
    float3 high = lerp(float3(0.25, 0.82, 1.0), float3(1.0, 0.34, 0.42), pulse);
    float3 color = lerp(low, high, motif);

    float grid = gridLine(localUv, 0.018);
    color = lerp(color, float3(0.86, 0.94, 1.0), grid * 0.50);

    return color;
}

float3 sectionOffset(float2 uv)
{
    float2 scale = float2(5.0, 4.0);
    float row = floor(uv.y * scale.y);
    float rowOdd = oddRow(row);

    float2 shifted = uv * scale;
    shifted.x += rowOdd * 0.5;

    float2 localUv = frac(shifted);
    float2 local = localUv * 2.0 - 1.0;

    float brickBody = 1.0 - smoothstep(0.50, 0.56, max(abs(local.x), abs(local.y)));
    float mortar = gridLine(localUv, 0.030);

    float3 evenColor = float3(0.48, 0.12, 0.08);
    float3 oddColor = float3(0.72, 0.20, 0.10);
    float3 color = lerp(evenColor, oddColor, rowOdd) * brickBody;
    color += float3(0.10, 0.08, 0.07);

    float halfShiftMark = 1.0 - smoothstep(0.020, 0.040, abs(localUv.x - 0.5));
    color = lerp(color, float3(1.0, 0.78, 0.35), halfShiftMark * rowOdd * 0.45);
    color = lerp(color, float3(0.92, 0.88, 0.78), mortar * 0.85);

    return color;
}

float truchetArc(float2 localUv)
{
    float dA = abs(length(localUv - float2(0.0, 0.0)) - 0.50) - 0.040;
    float dB = abs(length(localUv - float2(1.0, 1.0)) - 0.50) - 0.040;
    float d = min(dA, dB);
    return 1.0 - smoothstep(0.0, 0.018, d);
}

float2 rotateTilePattern(float2 localUv, float index)
{
    float2 q = localUv - 0.5;

    if (index < 0.5)
    {
        q = q;
    }
    else if (index < 1.5)
    {
        q = rotate2(q, HALF_PI);
    }
    else if (index < 2.5)
    {
        q = rotate2(q, PI);
    }
    else
    {
        q = rotate2(q, -HALF_PI);
    }

    return q + 0.5;
}

float3 sectionTruchet(float2 uv)
{
    float2 cell;
    float2 localUv = tileFract(uv, float2(5.0, 5.0), cell);

    float index = fmod(cell.x + cell.y * 2.0, 4.0);
    float2 rotatedUv = rotateTilePattern(localUv, index);

    float arc = truchetArc(rotatedUv);
    float dotMark = 1.0 - smoothstep(0.050, 0.075, length(localUv - 0.5));

    float tileTint = hash21(cell) * 0.10;
    float3 color = float3(0.055 + tileTint, 0.070 + tileTint, 0.085 + tileTint);
    color = lerp(color, float3(0.88, 0.88, 0.78), arc);
    color = lerp(color, float3(0.28, 0.92, 0.62), dotMark * 0.55);

    float grid = gridLine(localUv, 0.018);
    color = lerp(color, float3(0.36, 0.42, 0.48), grid * 0.65);

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

    float2 panel2Center = float2(0.0, 0.48);
    float mask2 = panelMask(p, panel2Center, panelHalf);
    float3 section2 = sectionMatrix(panelUv(p, panel2Center, panelHalf));
    color = lerp(color, section2, mask2);

    float border2 = panelBorder(p, panel2Center, panelHalf);
    color = lerp(color, float3(1.0, 0.76, 0.32), border2);

    float2 panel3Center = float2(0.58, 0.48);
    float mask3 = panelMask(p, panel3Center, panelHalf);
    float3 section3 = sectionAnimation(panelUv(p, panel3Center, panelHalf), uCardTime);
    color = lerp(color, section3, mask3);

    float border3 = panelBorder(p, panel3Center, panelHalf);
    color = lerp(color, float3(0.42, 0.92, 1.0), border3);

    float2 panel4Center = float2(-0.29, -0.34);
    float mask4 = panelMask(p, panel4Center, panelHalf);
    float3 section4 = sectionOffset(panelUv(p, panel4Center, panelHalf));
    color = lerp(color, section4, mask4);

    float border4 = panelBorder(p, panel4Center, panelHalf);
    color = lerp(color, float3(1.0, 0.42, 0.28), border4);

    float2 panel5Center = float2(0.29, -0.34);
    float mask5 = panelMask(p, panel5Center, panelHalf);
    float3 section5 = sectionTruchet(panelUv(p, panel5Center, panelHalf));
    color = lerp(color, section5, mask5);

    float border5 = panelBorder(p, panel5Center, panelHalf);
    color = lerp(color, float3(0.52, 1.0, 0.68), border5);

    return float4(color, 1.0);
}
