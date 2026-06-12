# Current Shader Model

This document is the latest handoff summary for the current SDF card rendering model.

## Render Modes

- `GrayScale / Hard`: outputs the final mask as grayscale. Card colors are not used.
- `GrayScale / Gradient`: outputs a distance gradient multiplied by the final mask. Card colors are not used.
- `Color / Hard Color`: maps the final mask from `uCardColor0` to `uCardColor1`.
- `Color / Gradient Color`: keeps `mask == 0` at `uCardColor0`, and maps visible mask areas through a distance-based `uCardColor0 -> uCardColor1` ramp.

`PerFrame.uRenderFlags.x` stores this mode:

- `0 = GrayScale Hard`
- `1 = GrayScale Gradient`
- `2 = Color Hard`
- `3 = Color Gradient`

## Style And Palette

`PerCard.uCardStyle` stores mask style only:

- `x = styleMode` (`0 fill`, `1 stroke`, `2 fill+stroke`)
- `y = edgeSoftness`
- `z = strokeWidth`
- `w = reserved`

Per-card palette fields:

- `uCardColor0`: color for mask value `0`
- `uCardColor1`: color for mask value `1`

Background is not a separate material. It is the `mask == 0` region and uses `uCardColor0`.

## Public Helpers

- `return mask(distance);`
  Use this for normal card output when `distance` is the final signed distance. It applies ImGui Style, Render Mode, and Color 0 / Color 1.
- `float m = aa(distance);`
  Use this when you only want a plain anti-aliased fill mask. It does not apply ImGui Style or colors.
- `float m = cardMask(distance);`
  Use this when you want ImGui Fill/Stroke/Fill+Stroke as a 0..1 mask, but want to color it yourself.
- `float3 c = colorFromMask(maskValue, distance);`
  Use this when you already built a custom 0..1 mask and want to apply Render Mode plus Color 0 / Color 1.

Recommended card flow:

```hlsl
float2 cardPos = fitUV(i.uv);
float2 p = applyCardShapeTransform(cardPos);

// Apply card-authored local movement, rotation, repetition, animation, etc.
float distance = ...;
return mask(distance);
```

## Settings Format

`card_settings.txt` is saved as one line per card:

```text
card params.x params.y params.z params.w transform.x transform.y transform.z transform.w style.x style.y style.z style.w color0.r color0.g color0.b color0.a color1.r color1.g color1.b color1.a
```

Compatibility:

- Older settings with fill/stroke/background color slots are still loaded.
- On load, old `bgA` becomes `Color 0`.
- On load, old `fillA` becomes `Color 1`.
- New saves always write the compact `Color 0` / `Color 1` format.

## Verification

- `rg "uCardFillColor|uCardStrokeColor|uCardBgColor|uCardBgParams" src shaders` should return no matches.
- `rg "legacy color wrapper|legacy card color wrapper" shaders docs` should return no matches.
- `rg "uCardColor0|uCardColor1|colorFromMask|cardMask\\(|aa\\(" src shaders docs` should show the active palette and mask path.

