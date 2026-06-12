#pragma once
#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>

class Renderer {
public:
    bool Init(HWND hwnd, int width, int height);
    void Shutdown();

    void BeginFrame(const float clear_rgba[4]);
    void EndFrame();
    void Resize(int width, int height);

    ID3D11Device*           Device()    const { return device_.Get(); }
    ID3D11DeviceContext*    Context()   const { return context_.Get(); }
    IDXGISwapChain1*        SwapChain() const { return swap_.Get(); }
    ID3D11RenderTargetView* RTV()       const { return rtv_.Get(); }
    int Width()  const { return width_; }
    int Height() const { return height_; }

private:
    bool CreateBackBufferRTV();
    void ReleaseBackBuffer();

    Microsoft::WRL::ComPtr<ID3D11Device>           device_;
    Microsoft::WRL::ComPtr<ID3D11DeviceContext>    context_;
    Microsoft::WRL::ComPtr<IDXGISwapChain1>        swap_;
    Microsoft::WRL::ComPtr<ID3D11RenderTargetView> rtv_;
    int width_  = 0;
    int height_ = 0;
};
