#include "lib/sdf_cbuffers.hlsli"

struct VSIn {
    float3 pos : POSITION;
    float2 uv  : TEXCOORD;
};

struct VSOut {
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD;
};

VSOut main(VSIn input) {
    VSOut output;
    float4 worldPosition = mul(float4(input.pos, 1.0), uWorld);
    output.pos = mul(worldPosition, uViewProj);
    output.uv  = input.uv;
    return output;
}
