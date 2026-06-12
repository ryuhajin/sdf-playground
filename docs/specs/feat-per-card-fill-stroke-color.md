# feat: Per-card fill/stroke color

## Context

`fill+stroke` 스타일은 fill mask와 stroke mask를 합쳐서 렌더링하지만, 기존 색상 경로는 `PerFrame`의 `uMask1`/`uMask2`를 모든 카드가 공유했다. 그래서 카드별 색을 따로 조정할 수 없고, fill과 stroke를 분리해서 합성하는 의미도 약했다.

## Changes

- `sdf_mask.hlsli`에 `CardMaskParts`와 `cardMaskParts(distance)`를 추가했다.
  - `cardMaskParts`는 fill/stroke mask를 합치지 않고 분리해서 반환한다.
  - `cardMask(distance)`는 기존 호환용으로 style mode에 따른 단일 흑백 mask를 반환한다.
- `sdf_color.hlsli`에 `legacy card color wrapper(parts, distance)`를 추가했다.
  - `mask(distance)` wrapper는 기존 카드 셰이더의 `return mask(d);` 호출을 유지한다.
  - `fill+stroke` 컬러 모드에서는 fill과 stroke를 분리된 mask로 합성한다.
- `PerFrame`에서 `uMask1`/`uMask2`를 제거하고 `PerCard`에 카드별 색상 팔레트를 추가했다.
  - 배경색은 계속 CPU의 `renderer_.BeginFrame(bg_color_)` 클리어 색으로 유지한다.
  - 카드 내부 색은 선택된 카드의 Style UI에서 `Background Color A/B`, `Fill Color A/B`, `Stroke Color A/B`로 조정한다.
  - `uCardBgColorA`는 hard background와 gradient start로 사용한다.
  - `uCardBgColorB`는 background gradient end로 사용한다.
  - `uCardFillColorA`/`uCardStrokeColorA`는 hard color와 gradient start로 사용한다.
  - `uCardFillColorB`/`uCardStrokeColorB`는 gradient end로 사용한다.
- `palette()` 매개변수 이름을 `baseColor`, `amplitude`, `frequency`, `phase`로 바꿔 의도를 명확히 했다.
- Render UI는 체크박스 형태의 상호 배타 모드로 정리했다.
  - `GrayScale / Hard`
  - `GrayScale / Gradient`
  - `Color / Hard Color`
  - `Color / Gradient Color`
- `uCardBgParams.x`를 background mode로 사용한다. `uCardStyle.w`는 reserved로 유지한다.
  - `0 = Solid`
  - `1 = Horizontal Gradient`
  - `2 = Vertical Gradient`
  - `3 = Radial Gradient`
  - `4 = Distance Gradient`
- `old coordinate-aware mask wrapper` overload를 추가했고, 샘플 카드들은 최종 SDF 평가 좌표를 넘기는 `old coordinate-aware mask call` 경로를 사용한다.
- `sdf_color.hlsli`에 카드 셰이더가 직접 재사용할 수 있는 gradient helper를 추가했다.
  - `gradientHorizontal(float2 p)`
  - `gradientVertical(float2 p)`
  - `gradientRadial(float2 p)`
  - `gradientDistance(float distance)`
  - `gradientColor(float t, float3 colorA, float3 colorB)`
- `card_settings.txt` 저장 포맷 뒤에 fill/stroke/background A/B 색상과 `bgParams.x/y/z/w` 값을 추가했다.
  - 기존 색 값이 없는 줄도 읽을 수 있고, 없으면 기본 fill=white, stroke=black을 사용한다.
  - 기존 8개 색상 포맷은 A 슬롯으로 읽고 B 슬롯은 기본값을 사용한다.
  - 기존 16개 색상 포맷은 fill/stroke A/B로 읽고 background A/B는 기본값을 사용한다.

## Compatibility

- 기존 카드 셰이더의 `return mask(d);` 패턴은 유지된다.
- 기존 `card_settings.txt` 줄은 `params`, `transform`, `style`까지만 있어도 로드된다.
- 새로 저장하면 `fillA`, `strokeA`, `fillB`, `strokeB`, `bgA`, `bgB`, `bgParams` 값이 뒤에 붙는다.

## Render Modes

- `GrayScale Hard`: 카드 색상 cbuffer를 사용하지 않고 단일 흑백 mask를 출력한다.
- `GrayScale Gradient`: 카드 색상 cbuffer를 사용하지 않고 SDF distance 기반 흑백 gradient를 출력한다.
- `Color Hard`: background/fill/stroke는 각 A 슬롯을 사용한다.
- `Color Gradient`: background/fill/stroke는 각 A -> B 슬롯을 distance gradient로 보간한다.
- Background는 render mode가 Color 계열일 때 `Background Mode`를 따른다. `mask(distance)` 호환 경로는 좌표가 없으므로 solid/distance 배경만 완전하게 표현되고, 샘플 카드는 `old coordinate-aware mask call`를 사용한다.

Gradient 값은 `saturate(0.5 + 0.5 * sin(distance * 8.0))`이며, UV 방향이 아니라 도형 경계 거리 기준의 band/contour gradient다.

## Verification

- `cmake --build --preset debug`
- `rg "uMask1|uMask2|mask1_|mask2_|kMask1|kMask2" src shaders` should return no matches.
- `rg "render_mode_|Render Mode|uCardFillColorA|uCardFillColorB|uCardStrokeColorA|uCardStrokeColorB" src shaders` should show the new shader/C++ path.
- `rg "uCardBgColorA|uCardBgColorB|bg_color_a|bg_color_b" src shaders` should show the card background path.
- `rg "gradientHorizontal|gradientVertical|gradientRadial|gradientDistance|gradientColor" shaders` should show the helper functions.
- `rg "Background Mode|Card Background|mask\\(d, p\\)|uCardStyle\\.w" src shaders` should show the background mode path.

## Follow-up

- Runtime visual QA should verify Fill, Stroke, and Fill + Stroke modes in the app.
- Save Card / Load All Cards should be checked after editing per-card fill/stroke colors.

## Background Transform Space

- Background mode now lives in `uCardBgParams.x`; `uCardStyle.w` is reserved again.
- `uCardBgParams.y` is `Follow Shape Transform`: `0` keeps the background fixed to the card, `1` makes it follow the PerCard SDF transform.
- Recommended card shader flow:
  - `cardPos = fitUV(i.uv)`
  - `shapePos = applyCardShapeTransform(cardPos)`
  - build the SDF distance from `shapePos`
  - return `old coordinate-aware mask wrapper`
- Horizontal, Vertical, and Radial background gradients use either `cardPos` or `shapePos` based on the checkbox.
- Distance Gradient still uses SDF distance, so it remains shape-relative by definition.
- New settings writes append `bgParams.x/y/z/w`; old settings migrate `style.w` into `bgParams.x` and default follow to `0`.

## Current Implementation Snapshot

This section is the latest source of truth for the next AI agent. If older text above mentions `uCardStyle.w` as background mode or recommends `old coordinate-aware mask call`, treat this section as the newer implementation.

See also `docs/CURRENT_SHADER_MODEL.md` for the compact handoff document.

- `PerFrame.uRenderFlags.x` stores the exclusive render mode:
  - `0 = GrayScale Hard`
  - `1 = GrayScale Gradient`
  - `2 = Color Hard`
  - `3 = Color Gradient`
- `PerCard.uCardStyle` stores shape mask style only:
  - `x = styleMode` (`0 fill`, `1 stroke`, `2 fill+stroke`)
  - `y = edgeSoftness`
  - `z = strokeWidth`
  - `w = reserved`
- `PerCard.uCardBgParams` stores card background controls:
  - `x = backgroundMode` (`0 solid`, `1 horizontal`, `2 vertical`, `3 radial`, `4 distance`)
  - `y = followShapeTransform` (`0 card-fixed`, `1 follow final SDF coordinate`)
  - `z/w = reserved`
- Per-card palette fields are:
  - `uCardFillColorA/B`
  - `uCardStrokeColorA/B`
  - `uCardBgColorA/B`
- Recommended card shader flow:

```hlsl
float2 cardPos = fitUV(i.uv);
float2 shapePos = applyCardShapeTransform(cardPos);
float2 p = shapePos;

// Apply card-authored local movement, rotation, repetition, animation, etc. to p.
float d = ...;
return old coordinate-aware mask call;
```

- `cardPos` is the card-fixed SDF coordinate used by background gradients when `Follow Shape Transform` is off.
- `p` is the final SDF evaluation coordinate used by background gradients when `Follow Shape Transform` is on.
- `shapePos` is a useful starting point after PerCard transform, but do not pass it to `old coordinate-aware mask call` if the card shader later changes `p`.
- `Distance Gradient` uses signed distance, so it remains shape-relative even when the follow checkbox is off.
- Settings compatibility:
  - old `style.w` background mode is migrated into `bgParams.x` when loading
  - missing `bgParams` defaults to `{0, 0, 0, 0}`
  - new writes append `bgParams.x bgParams.y bgParams.z bgParams.w`

## Current Verification Queries

- `rg "uMask1|uMask2|mask1_|mask2_|kMask1|kMask2" src shaders` should return no matches.
- `rg "uCardBgParams|Follow Shape Transform|mask\\(d, p, cardPos\\)|backgroundGradientT" src shaders` should show the active background path.
- `rg "uCardStyle\\.w" src shaders` should return no matches.

