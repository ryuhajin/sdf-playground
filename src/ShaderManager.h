#pragma once
#include <Windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <string>
#include <vector>
#include <unordered_map>

class ShaderIncludeHandler : public ID3DInclude {
public:
    HRESULT __stdcall Open(D3D_INCLUDE_TYPE include_type,
                           LPCSTR file_name,
                           LPCVOID parent_data,
                           LPCVOID* out_data,
                           UINT* out_bytes) override;
    HRESULT __stdcall Close(LPCVOID data) override;
};

struct CompiledVS {
    Microsoft::WRL::ComPtr<ID3D11VertexShader> shader;
    Microsoft::WRL::ComPtr<ID3D11InputLayout>  layout;
    Microsoft::WRL::ComPtr<ID3DBlob>           bytecode;
    bool ok = false;
};

struct CompiledPS {
    Microsoft::WRL::ComPtr<ID3D11PixelShader> shader;
    bool ok = false;
    std::string error;
};

class ShaderManager {
public:
    void Init(ID3D11Device* device) { device_ = device; }

    CompiledVS CompileVS(const std::wstring& path,
                         const char* entry,
                         const D3D11_INPUT_ELEMENT_DESC* layout_desc,
                         UINT layout_count,
                         std::string* out_error = nullptr);

    CompiledPS CompilePS(const std::wstring& path, const char* entry);

private:
    ID3D11Device* device_ = nullptr;
};
