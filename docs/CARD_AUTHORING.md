# Card Authoring Guide

This guide explains the current card shader authoring flow.

## Minimal Card

Create a pixel shader under `shaders/cards/`.

```hlsl
#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"

float4 main(PSIn i) : SV_Target {
    float2 p = cardUVToShapePos(i.uv);
    float distance = sdCircle(p, 0.55);
    return mask(distance);
}
```

The important line is:

```hlsl
return mask(distance);
```

Use it when `distance` is your final signed distance. It applies the selected ImGui Style Mode, edge softness, stroke width, Render Mode, and Color 0 / Color 1.

## Coordinates

Use this flow when you need to animate, repeat, rotate, or otherwise edit coordinates yourself.

```hlsl
float2 cardPos = fitUV(i.uv);
float2 p = applyCardShapeTransform(cardPos);

// Card-local edits happen after the shared transform.
p = rotateAroundOrigin(p, uCardTime * 0.8);

float distance = sdStar(p, 0.55, 5, 3.0);
return mask(distance);
```

- `fitUV(i.uv)` converts screen UV to centered card coordinates.
- `applyCardShapeTransform(cardPos)` applies ImGui Transform X/Y, Rotation, and Scale.
- `p` is the coordinate you pass to SDF shape functions.

## Mask And Color Helpers

Use one of these four helpers depending on what value you have.

```hlsl
return mask(distance);
```

Use this for normal final output when you have a signed distance.

```hlsl
float m = aa(distance);
```

Use this when you only want a plain anti-aliased fill mask. It does not apply ImGui Style Mode or Color 0 / Color 1.

```hlsl
float m = cardMask(distance);
```

Use this when you want ImGui Fill, Stroke, or Fill + Stroke as a 0..1 mask, but want to color it yourself.

```hlsl
float customMask = ...;
float3 color = colorFromMask(customMask, distance);
return float4(color, 1.0);
```

Use this when you already built a custom 0..1 mask and only want to apply Render Mode plus Color 0 / Color 1.

## Settings

Register new cards in `shaders/cards/card_files.txt`.

Per-card defaults live in `shaders/cards/card_settings.txt`:

```text
card params.x params.y params.z params.w transform.x transform.y transform.z transform.w style.x style.y style.z style.w color0.r color0.g color0.b color0.a color1.r color1.g color1.b color1.a
```

## Encoding

Save HLSL files without a UTF-8 BOM. `D3DCompileFromFile` can report
`(1,1) illegal character in shader file` when a card starts with BOM bytes
before the first `#include`.

Avoid Windows PowerShell `Set-Content -Encoding UTF8` for shader files because
older PowerShell versions write UTF-8 with BOM. Prefer editor settings that
explicitly say `UTF-8 without BOM`, or verify the first bytes before testing a
shader.

Quick check in PowerShell:

```powershell
Get-Content -Path shaders\cards\card_03.hlsl -Encoding Byte -TotalCount 3
```

If the output is `239`, `187`, `191`, the file has a UTF-8 BOM and should be
resaved without BOM.

## Troubleshooting

- If a card is invisible, check the filename in `card_files.txt`.
- If a compile error appears, use the overlay filename and line number first.
- If a shader reports `(1,1) illegal character`, check for a UTF-8 BOM before
  debugging the HLSL code itself.
- If Color 0 / Color 1 do not seem to apply, check whether the card returns a raw `float4(...)` instead of `mask(distance)` or `colorFromMask(...)`.
- If Style Mode does not seem to apply, check whether the card uses `aa(distance)` directly. `aa` is fill-only and ignores ImGui Style Mode.
