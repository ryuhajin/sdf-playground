# HLSL Card Flow

This document shows the simplest mental model for writing one SDF card.

```text
UV -> card coordinates -> edited SDF coordinates -> signed distance -> mask/color output
```

## 1. Coordinates

Start with card coordinates.

```hlsl
float2 cardPos = fitUV(i.uv);
float2 p = applyCardShapeTransform(cardPos);
```

- `cardPos` is fixed to the card surface.
- `p` includes the shared ImGui transform: center, rotation, and scale.
- Animate or repeat `p` before passing it to SDF shape functions.

## 2. Distance

SDF shape functions return signed distance.

```hlsl
float distance = sdBox(p, float2(0.22, 0.22));
```

- `distance < 0`: inside the shape.
- `distance == 0`: on the contour.
- `distance > 0`: outside the shape.

## 3. Standard Output

For most cards, return through `mask(distance)`.

```hlsl
return mask(distance);
```

That one call applies:

- Fill, Stroke, or Fill + Stroke from ImGui.
- Edge Softness and Stroke Width from ImGui.
- Render Mode.
- Color 0 and Color 1 from ImGui.

## 4. Manual Mask Output

Sometimes you build your own 0..1 mask. In that case, use `colorFromMask`.

```hlsl
float customMask = aa(distance);
return float4(colorFromMask(customMask, distance), 1.0);
```

Use this when a card combines several procedural masks before applying color.

## 5. Helper Choices

- `mask(distance)`: final signed distance -> final `float4` card color. Default choice.
- `aa(distance)`: signed distance -> plain anti-aliased fill mask only. No ImGui style or color.
- `cardMask(distance)`: signed distance -> ImGui Fill/Stroke/Fill+Stroke mask only. No color.
- `colorFromMask(maskValue, distance)`: custom 0..1 mask -> Color 0 / Color 1 color.

## 6. Complete Example

```hlsl
#include "../lib/sdf_common.hlsli"
#include "../lib/sdf_shapes.hlsli"
#include "../lib/sdf_transform.hlsli"

float4 main(PSIn i) : SV_Target {
    float2 cardPos = fitUV(i.uv);
    float2 p = applyCardShapeTransform(cardPos);

    p = rotateAroundOrigin(p, uCardTime * 0.8);

    float distance = sdBox(p, float2(0.22, 0.22));
    return mask(distance);
}
```

If Color 0 / Color 1 do not show up, the card is probably returning a raw `float4` instead of using `mask(distance)` or `colorFromMask(maskValue, distance)`.
