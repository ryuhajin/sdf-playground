#include "Renderer.h"
#include <dxgi1_3.h>

using Microsoft::WRL::ComPtr;

bool Renderer::Init(HWND hwnd, int width, int height) {
    width_ = width;
    height_ = height;

    UINT flags = 0;
#ifdef _DEBUG
    flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    D3D_FEATURE_LEVEL want[] = { D3D_FEATURE_LEVEL_11_0 };
    D3D_FEATURE_LEVEL got{};
    HRESULT hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags,
        want, _countof(want), D3D11_SDK_VERSION,
        device_.GetAddressOf(), &got, context_.GetAddressOf());
    if (FAILED(hr)) {
#ifdef _DEBUG
        flags &= ~D3D11_CREATE_DEVICE_DEBUG;
        hr = D3D11CreateDevice(
            nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags,
            want, _countof(want), D3D11_SDK_VERSION,
            device_.GetAddressOf(), &got, context_.GetAddressOf());
#endif
        if (FAILED(hr)) return false;
    }

    ComPtr<IDXGIDevice> dxgi_device;
    if (FAILED(device_.As(&dxgi_device))) return false;
    ComPtr<IDXGIAdapter> adapter;
    if (FAILED(dxgi_device->GetAdapter(adapter.GetAddressOf()))) return false;
    ComPtr<IDXGIFactory2> factory;
    if (FAILED(adapter->GetParent(IID_PPV_ARGS(factory.GetAddressOf())))) return false;

    DXGI_SWAP_CHAIN_DESC1 sd{};
    sd.Width = width;
    sd.Height = height;
    sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = 2;
    sd.Scaling = DXGI_SCALING_STRETCH;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    sd.AlphaMode = DXGI_ALPHA_MODE_IGNORE;

    if (FAILED(factory->CreateSwapChainForHwnd(
        device_.Get(), hwnd, &sd, nullptr, nullptr, swap_.GetAddressOf())))
        return false;

    factory->MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);

    return CreateBackBufferRTV();
}

bool Renderer::CreateBackBufferRTV() {
    ComPtr<ID3D11Texture2D> back;
    if (FAILED(swap_->GetBuffer(0, IID_PPV_ARGS(back.GetAddressOf())))) return false;
    if (FAILED(device_->CreateRenderTargetView(back.Get(), nullptr, rtv_.GetAddressOf())))
        return false;
    return true;
}

void Renderer::ReleaseBackBuffer() {
    if (context_) context_->OMSetRenderTargets(0, nullptr, nullptr);
    rtv_.Reset();
}

void Renderer::Resize(int width, int height) {
    if (!swap_ || (width == width_ && height == height_)) return;
    if (width <= 0 || height <= 0) return;
    ReleaseBackBuffer();
    swap_->ResizeBuffers(0, (UINT)width, (UINT)height, DXGI_FORMAT_UNKNOWN, 0);
    width_ = width;
    height_ = height;
    CreateBackBufferRTV();
}

void Renderer::BeginFrame(const float clear_rgba[4]) {
    ID3D11RenderTargetView* rtv = rtv_.Get();
    context_->OMSetRenderTargets(1, &rtv, nullptr);
    context_->ClearRenderTargetView(rtv, clear_rgba);

    D3D11_VIEWPORT vp{};
    vp.Width = (float)width_;
    vp.Height = (float)height_;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    context_->RSSetViewports(1, &vp);
}

void Renderer::EndFrame() {
    swap_->Present(1, 0);
}

void Renderer::Shutdown() {
    ReleaseBackBuffer();
    swap_.Reset();
    context_.Reset();
    device_.Reset();
}
