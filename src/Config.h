#pragma once
#include <DirectXMath.h>

// SDFs Deck 전역 상수 모음.
// 컴파일 시점 고정값(윈도우 크기, 카메라 파라미터, 색상 기본값, 셰이더 경로 등)을
// 모두 여기에 모은다. 런타임 가변값(ImGui 슬라이더로 조정)은
// `config::kXxxDefault` 를 초기값으로 사용한다.

namespace config {

// ─── 윈도우 ───
constexpr int     kWindowWidth   = 1280;
constexpr int     kWindowHeight  = 720;
constexpr wchar_t kWindowTitle[] = L"SDFs Deck";
constexpr wchar_t kWindowClass[] = L"SDFsWindowClass";

// ─── 색상 (0..1 정규화) ───
constexpr DirectX::XMFLOAT4 kBackgroundColor = {
    70.0f / 255.0f, 70.0f / 255.0f, 70.0f / 255.0f, 1.0f
};
constexpr DirectX::XMFLOAT4 kCardColor0Default = { 0.0f, 0.0f, 0.0f, 1.0f };
constexpr DirectX::XMFLOAT4 kCardColor1Default = { 1.0f, 1.0f, 1.0f, 1.0f };
constexpr int kRenderModeGrayHard = 0;
constexpr int kRenderModeGrayGradient = 1;
constexpr int kRenderModeColorHard = 2;
constexpr int kRenderModeColorGradient = 3;
constexpr int kRenderModeDefault = kRenderModeColorHard;

// ─── 카드 풀 / 슬롯 ───
constexpr int kVisibleSlots = 5;
constexpr int kCenterSlot   = 2;

// ─── Coverflow 레이아웃 (piecewise: near = |pos|=1, far = |pos|=2) ───
// 사용자 튜닝 확정값.
constexpr float kSpacingNear = 2.031f;
constexpr float kSpacingFar  = 3.110f;
constexpr float kYawNearRad  = 1.466f;
constexpr float kYawFarRad   = 1.598f;
constexpr float kZDepthNear  = 0.633f;
constexpr float kZDepthFar   = 0.700f;
constexpr float kScaleNear   = 0.850f;
constexpr float kScaleFar    = 0.629f;
constexpr float kCullPos     = 2.699f;  // |pos| > 이 값이면 fade out
constexpr float kLerpSpeed   = 7.0f;

// ─── 카메라 ───
constexpr float kCameraEyeZ = -3.2f;
constexpr float kFovYRad    = 1.0472f;  // 60°
constexpr float kNearPlane  = 0.1f;
constexpr float kFarPlane   = 100.0f;

// ─── 카드 파라미터 기본값 (uCardParams.xyzw) ───
constexpr float kCardParamDefault[4] = { 0.4f, 0.1f, 0.0f, 0.0f };

// ─── 카드 SDF 좌표 변환 기본값 (uCardTransform.xyzw) ───
// x=shapeCenterX, y=shapeCenterY, z=rotationRadians, w=scale
constexpr float kCardTransformDefault[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

// ─── 카드 렌더 스타일 기본값 (uCardStyle.xyzw) ───
// x=styleMode(0 fill, 1 stroke, 2 fill+stroke), y=edgeSoftness, z=strokeWidth, w=reserved
constexpr float kCardStyleDefault[4] = { 0.0f, 0.0f, 0.035f, 0.0f };

// ─── 슬라이드 / 애니메이션 ───
constexpr float kTimeScaleDefault = 1.0f;

// ─── 셰이더 경로 ───
constexpr wchar_t kQuadVSPath[]     = L"shaders/quad.vs.hlsl";
constexpr char    kCardListPath[]   = "shaders/cards/card_files.txt";
constexpr char    kCardSettingsPath[] = "shaders/cards/card_settings.txt";
constexpr wchar_t kCardDirPath[]    = L"shaders/cards/";
constexpr wchar_t kShaderWatchDir[] = L"shaders";

} // namespace config
