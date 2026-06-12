#include "App.h"
#include <chrono>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <set>
#include <unordered_map>
#include <array>
#include <algorithm>
#include <iomanip>

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND, UINT, WPARAM, LPARAM);

using Microsoft::WRL::ComPtr;
using namespace DirectX;

namespace {
struct Vertex { float pos[3]; float uv[2]; };

Vertex kQuadVerts[4] = {
    { {-1.0f, -1.0f, 0}, {0, 1} },
    { { 1.0f, -1.0f, 0}, {1, 1} },
    { { 1.0f,  1.0f, 0}, {1, 0} },
    { {-1.0f,  1.0f, 0}, {0, 0} },
};
uint16_t kQuadIdx[6] = { 0, 2, 1, 0, 3, 2 };

std::wstring Widen(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
    std::wstring w(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), w.data(), n);
    return w;
}

std::string Trim(const std::string& s) {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a == std::string::npos) return {};
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
}

struct SavedCardState {
    std::array<float, 4> params{};
    std::array<float, 4> transform{};
    std::array<float, 4> style{};
    std::array<float, 4> color0{};
    std::array<float, 4> color1{};
};

SavedCardState DefaultSavedCardState() {
    SavedCardState state{};
    for (int i = 0; i < 4; ++i) {
        state.params[i] = config::kCardParamDefault[i];
        state.transform[i] = config::kCardTransformDefault[i];
        state.style[i] = config::kCardStyleDefault[i];
    }
    state.color0 = {
        config::kCardColor0Default.x, config::kCardColor0Default.y,
        config::kCardColor0Default.z, config::kCardColor0Default.w
    };
    state.color1 = {
        config::kCardColor1Default.x, config::kCardColor1Default.y,
        config::kCardColor1Default.z, config::kCardColor1Default.w
    };
    return state;
}

void CopyStateToCard(const SavedCardState& state, CardEntry& card) {
    for (int i = 0; i < 4; ++i) {
        card.params[i] = state.params[i];
        card.transform[i] = state.transform[i];
        card.style[i] = state.style[i];
        card.color0[i] = state.color0[i];
        card.color1[i] = state.color1[i];
    }
}

SavedCardState CardToState(const CardEntry& card) {
    SavedCardState state{};
    for (int i = 0; i < 4; ++i) {
        state.params[i] = card.params[i];
        state.transform[i] = card.transform[i];
        state.style[i] = card.style[i];
        state.color0[i] = card.color0[i];
        state.color1[i] = card.color1[i];
    }
    return state;
}

void RenderModeCheckbox(const char* label, int mode, int& current) {
    bool selected = (current == mode);
    if (ImGui::Checkbox(label, &selected) && selected) current = mode;
}

bool ReadCardSettingsFile(std::unordered_map<std::string, SavedCardState>& out) {
    out.clear();
    std::ifstream f(config::kCardSettingsPath);
    if (!f.is_open()) return false;

    std::string line;
    while (std::getline(f, line)) {
        line = Trim(line);
        if (line.empty() || line[0] == '#') continue;

        std::istringstream iss(line);
        std::string name;
        SavedCardState state = DefaultSavedCardState();
        if (!(iss >> name)) continue;

        bool ok = true;
        for (int i = 0; i < 4; ++i) ok = ok && (iss >> state.params[i]);
        for (int i = 0; i < 4; ++i) ok = ok && (iss >> state.transform[i]);
        for (int i = 0; i < 4; ++i) ok = ok && (iss >> state.style[i]);
        state.style[3] = config::kCardStyleDefault[3];
        std::vector<float> colorValues;
        float colorValue = 0.0f;
        while (iss >> colorValue) colorValues.push_back(colorValue);
        if (colorValues.size() >= 24) {
            for (int i = 0; i < 4; ++i) {
                state.color1[i] = colorValues[i];      // legacy fillA
                state.color0[i] = colorValues[16 + i]; // legacy bgA
            }
        } else if (colorValues.size() >= 8) {
            for (int i = 0; i < 4; ++i) {
                state.color0[i] = colorValues[i];
                state.color1[i] = colorValues[4 + i];
            }
        }
        if (ok) out[name] = state;
    }
    return true;
}

bool WriteCardSettingsFile(const std::vector<CardEntry>& cards,
                           const std::unordered_map<std::string, SavedCardState>* overrides = nullptr) {
    std::ofstream f(config::kCardSettingsPath, std::ios::trunc);
    if (!f.is_open()) return false;

    f << "# SDFs Deck card defaults\n";
    f << "# card params.x params.y params.z params.w "
      << "transform.x transform.y transform.z transform.w "
      << "style.x style.y style.z style.w "
      << "color0.r color0.g color0.b color0.a "
      << "color1.r color1.g color1.b color1.a\n";
    f << std::setprecision(6);

    for (const auto& card : cards) {
        SavedCardState state = CardToState(card);
        if (overrides) {
            auto it = overrides->find(card.name);
            if (it != overrides->end()) state = it->second;
        }

        f << card.name;
        for (float v : state.params) f << ' ' << v;
        for (float v : state.transform) f << ' ' << v;
        for (float v : state.style) f << ' ' << v;
        for (float v : state.color0) f << ' ' << v;
        for (float v : state.color1) f << ' ' << v;
        f << '\n';
    }
    return true;
}
}

LRESULT CALLBACK App::WndProcStatic(HWND h, UINT m, WPARAM w, LPARAM l) {
    App* self = nullptr;
    if (m == WM_NCCREATE) {
        auto cs = reinterpret_cast<CREATESTRUCT*>(l);
        self = reinterpret_cast<App*>(cs->lpCreateParams);
        SetWindowLongPtr(h, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    } else {
        self = reinterpret_cast<App*>(GetWindowLongPtr(h, GWLP_USERDATA));
    }
    if (self) return self->WndProc(h, m, w, l);
    return DefWindowProc(h, m, w, l);
}

LRESULT App::WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (imgui_initialized_ && ImGui_ImplWin32_WndProcHandler(h, m, w, l)) return 1;
    if (imgui_initialized_) {
        ImGuiIO& io = ImGui::GetIO();
        if (io.WantCaptureKeyboard && (m == WM_KEYDOWN || m == WM_KEYUP || m == WM_CHAR))
            return DefWindowProc(h, m, w, l);
        if (io.WantCaptureMouse && (m == WM_LBUTTONDOWN || m == WM_LBUTTONUP ||
                                     m == WM_RBUTTONDOWN || m == WM_RBUTTONUP ||
                                     m == WM_MBUTTONDOWN || m == WM_MBUTTONUP ||
                                     m == WM_MOUSEMOVE   || m == WM_MOUSEWHEEL))
            return DefWindowProc(h, m, w, l);
    }
    switch (m) {
        case WM_SIZE:
            if (w != SIZE_MINIMIZED) {
                width_  = LOWORD(l);
                height_ = HIWORD(l);
                renderer_.Resize(width_, height_);
                UpdateViewProj();
            }
            return 0;
        case WM_KEYDOWN:
            switch (w) {
                case VK_ESCAPE: running_ = false; PostQuitMessage(0); break;
                case VK_LEFT:   coverflow_.Shift(-1); break;
                case VK_RIGHT:  coverflow_.Shift(+1); break;
                case VK_SPACE:  paused_ = !paused_; break;
            }
            return 0;
        case WM_CLOSE: running_ = false; PostQuitMessage(0); return 0;
        case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProc(h, m, w, l);
}

bool App::InitWindow(HINSTANCE hInstance, int nCmdShow) {
    WNDCLASSEX wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = &App::WndProcStatic;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = config::kWindowClass;
    if (!RegisterClassEx(&wc)) return false;

    RECT r{ 0, 0, width_, height_ };
    AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);

    hwnd_ = CreateWindowEx(
        0, config::kWindowClass, config::kWindowTitle, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        r.right - r.left, r.bottom - r.top,
        nullptr, nullptr, hInstance, this);
    if (!hwnd_) return false;

    ShowWindow(hwnd_, nCmdShow);
    UpdateWindow(hwnd_);
    return true;
}

bool App::InitPipeline() {
    auto* device = renderer_.Device();
    shaders_.Init(device);

    D3D11_BUFFER_DESC vbd{};
    vbd.ByteWidth = sizeof(kQuadVerts);
    vbd.Usage = D3D11_USAGE_IMMUTABLE;
    vbd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    D3D11_SUBRESOURCE_DATA vinit{ kQuadVerts, 0, 0 };
    if (FAILED(device->CreateBuffer(&vbd, &vinit, vb_.GetAddressOf()))) return false;

    D3D11_BUFFER_DESC ibd{};
    ibd.ByteWidth = sizeof(kQuadIdx);
    ibd.Usage = D3D11_USAGE_IMMUTABLE;
    ibd.BindFlags = D3D11_BIND_INDEX_BUFFER;
    D3D11_SUBRESOURCE_DATA iinit{ kQuadIdx, 0, 0 };
    if (FAILED(device->CreateBuffer(&ibd, &iinit, ib_.GetAddressOf()))) return false;

    D3D11_INPUT_ELEMENT_DESC layout_desc[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,                            D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT,    0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };

    std::string vs_err;
    auto vs = shaders_.CompileVS(config::kQuadVSPath, "main",
                                  layout_desc, _countof(layout_desc), &vs_err);
    if (!vs.ok) {
        MessageBoxA(hwnd_, vs_err.empty() ? "VS compile failed" : vs_err.c_str(),
                    "Shader error", MB_OK | MB_ICONERROR);
        return false;
    }
    vs_ = vs.shader;
    layout_ = vs.layout;

    D3D11_RASTERIZER_DESC rsd{};
    rsd.FillMode = D3D11_FILL_SOLID;
    rsd.CullMode = D3D11_CULL_NONE;
    rsd.DepthClipEnable = TRUE;
    if (FAILED(device->CreateRasterizerState(&rsd, rs_.GetAddressOf()))) return false;

    D3D11_SAMPLER_DESC sd{};
    sd.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sd.AddressU = sd.AddressV = sd.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sd.MaxLOD = D3D11_FLOAT32_MAX;
    if (FAILED(device->CreateSamplerState(&sd, sampler_.GetAddressOf()))) return false;

    D3D11_BUFFER_DESC cbd{};
    cbd.Usage = D3D11_USAGE_DYNAMIC;
    cbd.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    cbd.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    cbd.ByteWidth = (sizeof(PerFrameCB) + 15) & ~15;
    if (FAILED(device->CreateBuffer(&cbd, nullptr, cb_per_frame_.GetAddressOf()))) return false;
    cbd.ByteWidth = (sizeof(PerCardCB) + 15) & ~15;
    if (FAILED(device->CreateBuffer(&cbd, nullptr, cb_per_card_.GetAddressOf()))) return false;

    if (!LoadCardPool()) {
        MessageBoxA(hwnd_, "No cards loaded. Check shaders/cards/card_files.txt",
                    "Card pool", MB_OK | MB_ICONWARNING);
    }

    UpdateViewProj();
    coverflow_.SetCardCount((int)cards_.size());

    file_watcher_.Init(config::kShaderWatchDir);
    return true;
}

bool App::InitImGui() {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui::StyleColorsDark();
    if (!ImGui_ImplWin32_Init(hwnd_)) return false;
    if (!ImGui_ImplDX11_Init(renderer_.Device(), renderer_.Context())) return false;
    imgui_initialized_ = true;
    return true;
}

void App::DrawUi() {
    ImGui::SetNextWindowPos(ImVec2(10, 10), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(360, 540), ImGuiCond_FirstUseEver);
    ImGui::Begin("SDFs Deck");

    if (ImGui::CollapsingHeader("Render", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::TextUnformatted("GrayScale:");
        ImGui::SameLine();
        RenderModeCheckbox("Hard##GrayScale", config::kRenderModeGrayHard, render_mode_);
        ImGui::SameLine();
        RenderModeCheckbox("Gradient##GrayScale", config::kRenderModeGrayGradient, render_mode_);
        ImGui::SameLine();
        ImGui::TextUnformatted("| Color:");
        ImGui::SameLine();
        RenderModeCheckbox("Hard Color", config::kRenderModeColorHard, render_mode_);
        ImGui::SameLine();
        RenderModeCheckbox("Gradient Color", config::kRenderModeColorGradient, render_mode_);
        ImGui::ColorEdit3("Background", bg_color_);
    }

    if (ImGui::CollapsingHeader("Cards", ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::Text("Pool: %d cards", (int)cards_.size());
        if (ImGui::Button("<<")) coverflow_.Shift(-1);
        ImGui::SameLine();
        if (ImGui::Button(">>")) coverflow_.Shift(+1);

        if (!cards_.empty()) {
            ui_selected_card_ = coverflow_.CenterCardIndex();
            ui_selected_card_ = std::clamp(ui_selected_card_, 0, (int)cards_.size() - 1);

            CardEntry& sel = cards_[ui_selected_card_];
            ImGui::Text("Editing: %s  (center)", sel.name.c_str());

            ImGui::SameLine();
            ImGui::TextDisabled("(?)");
            if (ImGui::IsItemHovered()) {
                ImGui::BeginTooltip();
                ImGui::PushTextWrapPos(ImGui::GetFontSize() * 28);
                ImGui::TextUnformatted(
                    "아래 Param.x/y/z/w 4값은 카드 셰이더의 uCardParams.xyzw 에 "
                    "1:1 매핑됩니다. 카드 작성자가 자유롭게 의미 부여 "
                    "(예: card_02 의 Param.x = baseR / Param.y = pulseAmp). "
                    "셰이더 재컴파일 없이 실시간 튜닝 용도.");
                ImGui::PopTextWrapPos();
                ImGui::EndTooltip();
            }

            if (!sel.ok) {
                ImGui::TextColored(ImVec4(1, 0.4f, 0.4f, 1), "compile failed");
                if (!sel.error.empty()) ImGui::TextWrapped("%s", sel.error.c_str());
            }

            ImGui::SliderFloat("Param.x", &sel.params[0], -1.0f, 1.0f);
            ImGui::SliderFloat("Param.y", &sel.params[1], -1.0f, 1.0f);
            ImGui::SliderFloat("Param.z", &sel.params[2], -1.0f, 1.0f);
            ImGui::SliderFloat("Param.w", &sel.params[3], -1.0f, 1.0f);

            ImGui::Spacing();
            ImGui::TextUnformatted("Transform");
            ImGui::SliderFloat("Transform X", &sel.transform[0], -1.5f, 1.5f, "%.3f");
            ImGui::SliderFloat("Transform Y", &sel.transform[1], -1.5f, 1.5f, "%.3f");
            ImGui::SliderFloat("Rotation", &sel.transform[2], -3.14159f, 3.14159f, "%.3f rad");
            ImGui::SliderFloat("Scale", &sel.transform[3], 0.1f, 3.0f, "%.3f");

            ImGui::Spacing();
            ImGui::TextUnformatted("Style");
            const char* style_modes[] = { "Fill", "Stroke", "Fill + Stroke" };
            int style_mode = std::clamp((int)sel.style[0], 0, (int)IM_ARRAYSIZE(style_modes) - 1);
            if (ImGui::Combo("Style Mode", &style_mode, style_modes, IM_ARRAYSIZE(style_modes))) {
                sel.style[0] = (float)style_mode;
            }
            ImGui::SliderFloat("Edge Softness", &sel.style[1], 0.0f, 0.2f, "%.4f");
            ImGui::SliderFloat("Stroke Width", &sel.style[2], 0.0f, 0.3f, "%.4f");
            ImGui::ColorEdit3("Color 0", sel.color0);
            ImGui::ColorEdit3("Color 1", sel.color1);

            ImGui::Spacing();
            if (ImGui::Button("Save Card")) {
                bool ok = SaveCurrentCardSettings(sel);
                SetCardSettingsStatus(ok ? "Saved current card defaults."
                                         : "Failed to save current card defaults.", ok);
            }
            ImGui::SameLine();
            if (ImGui::Button("Save All Cards")) {
                bool ok = SaveCardSettings();
                SetCardSettingsStatus(ok ? "Saved all card defaults."
                                         : "Failed to save card defaults.", ok);
            }
            if (ImGui::Button("Load All Cards")) {
                LoadCardSettings();
                SetCardSettingsStatus("Reloaded card defaults from disk.", true);
            }
            ImGui::SameLine();
            if (ImGui::Button("Reset Card")) {
                ResetCardDefaults(sel);
                SetCardSettingsStatus("Reset current card to code defaults.", true);
            }
            ImGui::SameLine();
            ImGui::TextDisabled("Config.h");
            if (!card_settings_status_.empty()) {
                ImGui::TextColored(
                    card_settings_status_ok_ ? ImVec4(0.55f, 1.0f, 0.55f, 1.0f)
                                             : ImVec4(1.0f, 0.45f, 0.45f, 1.0f),
                    "%s", card_settings_status_.c_str());
            }
        }
    }

    if (ImGui::CollapsingHeader("Animation", ImGuiTreeNodeFlags_DefaultOpen)) {
        const char* modes[] = { "Pulse", "Sine", "Bounce", "Oscillate" };
        ImGui::Combo("Anim mode", &anim_mode_, modes, IM_ARRAYSIZE(modes));
        bool p = (paused_ != 0);
        if (ImGui::Checkbox("Paused", &p)) paused_ = p ? 1 : 0;
        ImGui::SliderFloat("Time scale", &time_scale_, 0.0f, 4.0f, "%.2f");
        ImGui::Text("Sim time: %.2fs", sim_time_);
    }

    if (ImGui::CollapsingHeader("Coverflow tuning")) {
        ImGui::TextDisabled(
            "draw order: ±2 (slot 0,4) -> ±1 (slot 1,3) -> center.\n"
            "spacing ±1 too small -> center will cover ±1.");
        ImGui::Spacing();
        ImGui::SliderFloat("spacing ±1 (slot 1,3)", &coverflow_.spacing[0], 1.0f, 4.0f);
        ImGui::SliderFloat("spacing ±2 (slot 0,4)", &coverflow_.spacing[1], 1.5f, 6.0f);
        ImGui::Spacing();
        ImGui::SliderFloat("yaw rad ±1", &coverflow_.yawRad[0], 0.0f, 1.6f);
        ImGui::SliderFloat("yaw rad ±2", &coverflow_.yawRad[1], 0.0f, 1.6f);
        ImGui::Spacing();
        ImGui::SliderFloat("z depth ±1", &coverflow_.zDepth[0], 0.0f, 1.5f);
        ImGui::SliderFloat("z depth ±2", &coverflow_.zDepth[1], 0.0f, 1.5f);
        ImGui::Spacing();
        ImGui::SliderFloat("scale ±1",   &coverflow_.scaleAt[0], 0.2f, 1.0f);
        ImGui::SliderFloat("scale ±2",   &coverflow_.scaleAt[1], 0.2f, 1.0f);
        ImGui::Spacing();
        ImGui::SliderFloat("cull |pos|",   &coverflow_.cullPos,    1.5f, 4.0f);
        ImGui::SliderFloat("lerp speed",   &coverflow_.lerpSpeed,  1.0f, 20.0f);
    }

    ImGui::Separator();
    ImGui::Text("←/→: slide   Space: pause   Esc: quit");
    ImGui::End();

    if (!last_compile_error_.empty()) {
        ImGui::SetNextWindowPos(ImVec2(10, (float)height_ - 200), ImGuiCond_Always);
        ImGui::SetNextWindowSize(ImVec2((float)width_ - 20, 190), ImGuiCond_Always);
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.20f, 0.04f, 0.04f, 0.92f));
        ImGui::Begin("Shader Error",
            nullptr,
            ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove |
            ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoFocusOnAppearing);
        ImGui::TextColored(ImVec4(1, 0.6f, 0.6f, 1), "%s", last_compile_file_.c_str());
        ImGui::Separator();
        ImGui::PushTextWrapPos(0.0f);
        ImGui::TextUnformatted(last_compile_error_.c_str());
        ImGui::PopTextWrapPos();
        ImGui::End();
        ImGui::PopStyleColor();
    }
}

bool App::LoadCardPool() {
    cards_.clear();
    std::ifstream f(config::kCardListPath);
    if (!f.is_open()) return false;

    std::string line;
    while (std::getline(f, line)) {
        line = Trim(line);
        if (line.empty() || line[0] == '#') continue;

        CardEntry entry;
        entry.name = line;
        entry.path = std::wstring(config::kCardDirPath) + Widen(line);
        RecompileCard(entry);
        cards_.push_back(std::move(entry));
    }
    LoadCardSettings();
    card_local_time_.assign(cards_.size(), 0.0f);
    prev_center_idx_ = -1;
    return !cards_.empty();
}

void App::LoadCardSettings() {
    std::unordered_map<std::string, SavedCardState> saved;
    if (!ReadCardSettingsFile(saved)) return;

    for (auto& card : cards_) {
        auto it = saved.find(card.name);
        if (it != saved.end()) CopyStateToCard(it->second, card);
    }
}

bool App::SaveCardSettings() const {
    return WriteCardSettingsFile(cards_);
}

bool App::SaveCurrentCardSettings(const CardEntry& selected) const {
    std::unordered_map<std::string, SavedCardState> saved;
    ReadCardSettingsFile(saved);
    saved[selected.name] = CardToState(selected);
    return WriteCardSettingsFile(cards_, &saved);
}

void App::ResetCardDefaults(CardEntry& card) {
    for (int i = 0; i < 4; ++i) {
        card.params[i] = config::kCardParamDefault[i];
        card.transform[i] = config::kCardTransformDefault[i];
        card.style[i] = config::kCardStyleDefault[i];
    }
    card.color0[0] = config::kCardColor0Default.x;
    card.color0[1] = config::kCardColor0Default.y;
    card.color0[2] = config::kCardColor0Default.z;
    card.color0[3] = config::kCardColor0Default.w;
    card.color1[0] = config::kCardColor1Default.x;
    card.color1[1] = config::kCardColor1Default.y;
    card.color1[2] = config::kCardColor1Default.z;
    card.color1[3] = config::kCardColor1Default.w;
}

void App::SetCardSettingsStatus(const std::string& message, bool ok) {
    card_settings_status_ = message;
    card_settings_status_ok_ = ok;
}

void App::RecompileCard(CardEntry& c) {
    auto ps = shaders_.CompilePS(c.path, "main");
    if (ps.ok) {
        c.ps = ps.shader;
        c.ok = true;
        c.error.clear();
        if (last_compile_file_ == c.name) {
            last_compile_error_.clear();
            last_compile_file_.clear();
        }
    } else {
        c.ok = false;
        c.error = ps.error;
        last_compile_error_ = ps.error;
        last_compile_file_  = c.name;
    }
}

void App::RecompileVS() {
    D3D11_INPUT_ELEMENT_DESC layout_desc[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,                            D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT,    0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    std::string err;
    auto vs = shaders_.CompileVS(config::kQuadVSPath, "main",
        layout_desc, _countof(layout_desc), &err);
    if (vs.ok) {
        vs_ = vs.shader;
        layout_ = vs.layout;
        if (last_compile_file_ == "quad.vs.hlsl") {
            last_compile_error_.clear();
            last_compile_file_.clear();
        }
    } else {
        last_compile_error_ = err.empty() ? "VS compile failed" : err;
        last_compile_file_  = "quad.vs.hlsl";
    }
}

void App::ReloadCardPool() {
    std::unordered_map<std::string, SavedCardState> saved;
    for (auto& c : cards_) {
        SavedCardState s{};
        for (int i = 0; i < 4; ++i) {
            s.params[i] = c.params[i];
            s.transform[i] = c.transform[i];
            s.style[i] = c.style[i];
            s.color0[i] = c.color0[i];
            s.color1[i] = c.color1[i];
        }
        saved[c.name] = s;
    }
    LoadCardPool();
    for (auto& c : cards_) {
        auto it = saved.find(c.name);
        if (it != saved.end()) {
            for (int i = 0; i < 4; ++i) {
                c.params[i] = it->second.params[i];
                c.transform[i] = it->second.transform[i];
                c.style[i] = it->second.style[i];
                c.color0[i] = it->second.color0[i];
                c.color1[i] = it->second.color1[i];
            }
        }
    }
    coverflow_.SetCardCount((int)cards_.size());
    card_local_time_.assign(cards_.size(), 0.0f);
    prev_center_idx_ = -1;
}

void App::ProcessFileEvents(const std::vector<std::wstring>& events) {
    bool vs_dirty = false;
    bool all_dirty = false;
    bool pool_dirty = false;
    bool settings_dirty = false;
    std::set<std::wstring> card_dirty;

    for (const auto& ev : events) {
        size_t slash = ev.find_last_of(L'/');
        std::wstring fname = (slash == std::wstring::npos) ? ev : ev.substr(slash + 1);

        if (fname == L"card_files.txt") pool_dirty = true;
        else if (fname == L"card_settings.txt") settings_dirty = true;
        else if (fname == L"quad.vs.hlsl") vs_dirty = true;
        else if (fname.size() > 6 && fname.substr(fname.size() - 6) == L".hlsli") all_dirty = true;
        else if (fname.size() > 5 && fname.substr(fname.size() - 5) == L".hlsl")
            card_dirty.insert(fname);
    }

    if (vs_dirty) RecompileVS();
    if (pool_dirty) { ReloadCardPool(); return; }
    if (settings_dirty) LoadCardSettings();

    if (all_dirty) {
        for (auto& c : cards_) RecompileCard(c);
    } else {
        for (const auto& f : card_dirty) {
            int n = WideCharToMultiByte(CP_UTF8, 0, f.c_str(), (int)f.size(), nullptr, 0, nullptr, nullptr);
            std::string narrow(n, '\0');
            WideCharToMultiByte(CP_UTF8, 0, f.c_str(), (int)f.size(), narrow.data(), n, nullptr, nullptr);
            for (auto& c : cards_) if (c.name == narrow) RecompileCard(c);
        }
    }
}

void App::UpdateViewProj() {
    float aspect = height_ > 0 ? (float)width_ / (float)height_ : 1.0f;
    XMVECTOR eye = XMVectorSet(0.0f, 0.0f, config::kCameraEyeZ, 1.0f);
    XMVECTOR at  = XMVectorZero();
    XMVECTOR up  = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);
    XMMATRIX V = XMMatrixLookAtLH(eye, at, up);
    XMMATRIX P = XMMatrixPerspectiveFovLH(config::kFovYRad, aspect,
                                          config::kNearPlane, config::kFarPlane);
    XMStoreFloat4x4(&view_proj_, V * P);
}

void App::UpdateCardTimers(float dt) {
    if (cards_.empty()) return;
    if (card_local_time_.size() != cards_.size()) {
        card_local_time_.assign(cards_.size(), 0.0f);
    }
    int center = coverflow_.CenterCardIndex();
    if (prev_center_idx_ >= 0 && prev_center_idx_ != center &&
        prev_center_idx_ < (int)card_local_time_.size()) {
        card_local_time_[prev_center_idx_] = 0.0f;
    }
    for (int i = 0; i < (int)cards_.size(); ++i) {
        if (i == center) {
            if (!paused_) card_local_time_[i] += dt * time_scale_;
        } else {
            card_local_time_[i] = 0.0f;
        }
    }
    prev_center_idx_ = center;
}

void App::Frame(float t, float dt) {
    watcher_events_.clear();
    file_watcher_.Drain(watcher_events_);
    if (!watcher_events_.empty()) ProcessFileEvents(watcher_events_);

    if (imgui_initialized_) {
        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
    }

    if (!paused_) sim_time_ += dt * time_scale_;
    coverflow_.Update(dt);
    UpdateCardTimers(dt);

    if (imgui_initialized_) DrawUi();
    if (imgui_initialized_) ImGui::Render();

    renderer_.BeginFrame(bg_color_);
    auto* ctx = renderer_.Context();

    PerFrameCB pf{};
    pf.uTimeRes[0] = sim_time_;
    pf.uTimeRes[1] = dt;
    pf.uTimeRes[2] = (float)width_;
    pf.uTimeRes[3] = (float)height_;
    pf.uMouse[0] = pf.uMouse[1] = pf.uMouse[2] = pf.uMouse[3] = 0.0f;
    pf.uRenderFlags[0] = render_mode_;
    pf.uRenderFlags[1] = anim_mode_;
    pf.uRenderFlags[2] = paused_;
    pf.uRenderFlags[3] = 0;
    pf.uViewProj = view_proj_;

    D3D11_MAPPED_SUBRESOURCE map{};
    if (SUCCEEDED(ctx->Map(cb_per_frame_.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &map))) {
        memcpy(map.pData, &pf, sizeof(pf));
        ctx->Unmap(cb_per_frame_.Get(), 0);
    }
    ID3D11Buffer* cbs[2] = { cb_per_frame_.Get(), cb_per_card_.Get() };
    ctx->VSSetConstantBuffers(0, 2, cbs);
    ctx->PSSetConstantBuffers(0, 2, cbs);

    UINT stride = sizeof(Vertex);
    UINT offset = 0;
    ID3D11Buffer* vb = vb_.Get();
    ctx->IASetVertexBuffers(0, 1, &vb, &stride, &offset);
    ctx->IASetIndexBuffer(ib_.Get(), DXGI_FORMAT_R16_UINT, 0);
    ctx->IASetInputLayout(layout_.Get());
    ctx->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ctx->RSSetState(rs_.Get());
    ctx->VSSetShader(vs_.Get(), nullptr, 0);
    ID3D11SamplerState* samp = sampler_.Get();
    ctx->PSSetSamplers(0, 1, &samp);

    if (cards_.empty()) {
        renderer_.EndFrame();
        return;
    }

    // Painter's order: outer slots first
    int draw_order[5] = { 0, 4, 1, 3, 2 };
    for (int k = 0; k < 5; ++k) {
        int slot = draw_order[k];
        auto s = coverflow_.GetSlot(slot);
        if (s.visibility <= 0.01f) continue;   // |pos| > cullPos: fade out / skip
        const CardEntry& card = cards_[s.cardIndex];
        if (!card.ps) continue;

        float card_time = (s.cardIndex < (int)card_local_time_.size())
                          ? card_local_time_[s.cardIndex] : 0.0f;

        PerCardCB pc{};
        pc.uWorld = s.world;
        pc.uCardMeta[0] = (float)s.cardIndex;
        pc.uCardMeta[1] = s.isCenter;
        pc.uCardMeta[2] = s.slotOffset;
        pc.uCardMeta[3] = card_time;
        for (int i = 0; i < 4; ++i) pc.uCardParams[i] = card.params[i];
        for (int i = 0; i < 4; ++i) pc.uCardTransform[i] = card.transform[i];
        for (int i = 0; i < 4; ++i) pc.uCardStyle[i] = card.style[i];
        for (int i = 0; i < 4; ++i) pc.uCardColor0[i] = card.color0[i];
        for (int i = 0; i < 4; ++i) pc.uCardColor1[i] = card.color1[i];

        if (SUCCEEDED(ctx->Map(cb_per_card_.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &map))) {
            memcpy(map.pData, &pc, sizeof(pc));
            ctx->Unmap(cb_per_card_.Get(), 0);
        }

        ctx->PSSetShader(card.ps.Get(), nullptr, 0);
        ctx->DrawIndexed(6, 0, 0);
    }

    if (imgui_initialized_) {
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
    }

    renderer_.EndFrame();
    (void)t;
}

void App::Shutdown() {
    file_watcher_.Shutdown();
    if (imgui_initialized_) {
        ImGui_ImplDX11_Shutdown();
        ImGui_ImplWin32_Shutdown();
        ImGui::DestroyContext();
        imgui_initialized_ = false;
    }
    renderer_.Shutdown();
}

int App::Run(HINSTANCE hInstance, int nCmdShow) {
    if (!InitWindow(hInstance, nCmdShow)) return -1;
    if (!renderer_.Init(hwnd_, width_, height_)) {
        MessageBoxA(hwnd_, "Renderer init failed", "Error", MB_OK | MB_ICONERROR);
        return -2;
    }
    if (!InitPipeline()) { Shutdown(); return -3; }
    if (!InitImGui())   { Shutdown(); return -4; }

    auto t0 = std::chrono::high_resolution_clock::now();
    auto tprev = t0;

    MSG msg{};
    while (running_) {
        while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) { running_ = false; break; }
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        if (!running_) break;

        auto now = std::chrono::high_resolution_clock::now();
        float t  = std::chrono::duration<float>(now - t0).count();
        float dt = std::chrono::duration<float>(now - tprev).count();
        tprev = now;

        Frame(t, dt);
    }

    Shutdown();
    return 0;
}
