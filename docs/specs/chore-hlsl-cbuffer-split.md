# Spec: chore-hlsl-cbuffer-split

- **Started**: 2026-06-05
- **Status**: Complete

## Goal

Keep vertex buffers limited to geometry data and make the HLSL constant-buffer boundary explicit.

## Changes

- Added `shaders/lib/sdf_cbuffers.hlsli` for `PerFrame : register(b0)` and `PerCard : register(b1)`.
- Updated `sdf_common.hlsli` to include cbuffer declarations instead of owning them.
- Updated `quad.vs.hlsl` to include only `sdf_cbuffers.hlsli` and fixed UV forwarding.

## Validation

- `cmake --build --preset debug`
- Runtime smoke test for VS/PS compile and five-card rendering.
- `rg "cbuffer PerFrame|cbuffer PerCard" shaders` should point only to `sdf_cbuffers.hlsli`.
