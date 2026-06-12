#pragma once
#include <Windows.h>
#include <d3d11.h>
#include <wrl/client.h>
#include <DirectXMath.h>
#include <string>
#include <vector>

#include "Config.h"
#include "Renderer.h"
#include "ShaderManager.h"
#include "Coverflow.h"
#include "FileWatcher.h"

struct CardEntry {
    std::wstring path;
    std::string  name;
    Microsoft::WRL::ComPtr<ID3D11PixelShader> ps;
    bool ok = false;
    std::string error;
    float params[4] = {
        config::kCardParamDefault[0], config::kCardParamDefault[1],
        config::kCardParamDefault[2], config::kCardParamDefault[3]
    };
    // x=shapeCenterX, y=shapeCenterY, z=rotationRadians, w=scale
    float transform[4] = {
        config::kCardTransformDefault[0], config::kCardTransformDefault[1],
        config::kCardTransformDefault[2], config::kCardTransformDefault[3]
    };
    // x=styleMode(0 fill, 1 stroke, 2 fill+stroke), y=edgeSoftness, z=strokeWidth, w=reserved
    float style[4] = {
        config::kCardStyleDefault[0], config::kCardStyleDefault[1],
        config::kCardStyleDefault[2], config::kCardStyleDefault[3]
    };
    float color0[4] = {
        config::kCardColor0Default.x, config::kCardColor0Default.y,
        config::kCardColor0Default.z, config::kCardColor0Default.w
    };
    float color1[4] = {
        config::kCardColor1Default.x, config::kCardColor1Default.y,
        config::kCardColor1Default.z, config::kCardColor1Default.w
    };
};

struct PerFrameCB {
    float uTimeRes[4];
    float uMouse[4];
    int   uRenderFlags[4];
    DirectX::XMFLOAT4X4 uViewProj;
};

struct PerCardCB {
    DirectX::XMFLOAT4X4 uWorld;
    float uCardMeta[4];   // x=cardIndex, y=isCenter, z=slotOffset, w=cardLocalTime
    float uCardParams[4]; // x/y/z/w=card-authored free parameters from ImGui
    float uCardTransform[4]; // x=shapeCenterX, y=shapeCenterY, z=rotationRadians, w=scale
    float uCardStyle[4]; // x=styleMode(0 fill, 1 stroke, 2 fill+stroke), y=edgeSoftness, z=strokeWidth, w=reserved
    float uCardColor0[4]; // mask value 0
    float uCardColor1[4]; // mask value 1
};

class App {
public:
    int Run(HINSTANCE hInstance, int nCmdShow);
    static LRESULT CALLBACK WndProcStatic(HWND, UINT, WPARAM, LPARAM);

private:
    bool InitWindow(HINSTANCE hInstance, int nCmdShow);
    bool InitPipeline();
    bool InitImGui();
    bool LoadCardPool();
    void Frame(float t, float dt);
    void DrawUi();
    void UpdateViewProj();
    void UpdateCardTimers(float dt);
    void Shutdown();
    LRESULT WndProc(HWND, UINT, WPARAM, LPARAM);

    void ProcessFileEvents(const std::vector<std::wstring>& events);
    void RecompileCard(CardEntry& c);
    void RecompileVS();
    void ReloadCardPool();
    void LoadCardSettings();
    bool SaveCardSettings() const;
    bool SaveCurrentCardSettings(const CardEntry& selected) const;
    void ResetCardDefaults(CardEntry& card);
    void SetCardSettingsStatus(const std::string& message, bool ok);

    HWND hwnd_ = nullptr;
    int  width_  = config::kWindowWidth;
    int  height_ = config::kWindowHeight;
    bool running_ = true;

    Renderer      renderer_;
    ShaderManager shaders_;

    Microsoft::WRL::ComPtr<ID3D11Buffer>          vb_;
    Microsoft::WRL::ComPtr<ID3D11Buffer>          ib_;
    Microsoft::WRL::ComPtr<ID3D11VertexShader>    vs_;
    Microsoft::WRL::ComPtr<ID3D11InputLayout>     layout_;
    Microsoft::WRL::ComPtr<ID3D11RasterizerState> rs_;
    Microsoft::WRL::ComPtr<ID3D11SamplerState>    sampler_;
    Microsoft::WRL::ComPtr<ID3D11Buffer>          cb_per_frame_;
    Microsoft::WRL::ComPtr<ID3D11Buffer>          cb_per_card_;

    std::vector<CardEntry> cards_;
    Coverflow coverflow_;

    // 카드별 로컬 시간 — 중앙 슬롯에 있는 동안만 누적, 다른 슬롯으로 가면 0으로 리셋
    std::vector<float> card_local_time_;
    int                prev_center_idx_ = -1;

    // Global UI state
    float bg_color_[4] = {
        config::kBackgroundColor.x, config::kBackgroundColor.y,
        config::kBackgroundColor.z, config::kBackgroundColor.w
    };
    int   render_mode_   = config::kRenderModeDefault;
    int   anim_mode_     = 0;
    int   paused_        = 0;
    float time_scale_    = config::kTimeScaleDefault;
    float sim_time_      = 0.0f;
    int   ui_selected_card_ = 0;

    DirectX::XMFLOAT4X4 view_proj_{};
    bool imgui_initialized_ = false;

    FileWatcher              file_watcher_;
    std::vector<std::wstring> watcher_events_;
    std::string              last_compile_error_;
    std::string              last_compile_file_;
    std::string              card_settings_status_;
    bool                     card_settings_status_ok_ = true;
};
