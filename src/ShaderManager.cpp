#include "ShaderManager.h"
#include <fstream>

using Microsoft::WRL::ComPtr;

HRESULT __stdcall ShaderIncludeHandler::Open(D3D_INCLUDE_TYPE,
                                              LPCSTR file_name,
                                              LPCVOID,
                                              LPCVOID* out_data,
                                              UINT* out_bytes) {
    static const char* kSearchDirs[] = {
        "shaders/lib/",
        "shaders/",
        "shaders/cards/",
        ""
    };
    for (const char* dir : kSearchDirs) {
        std::string path = std::string(dir) + file_name;
        std::ifstream f(path, std::ios::binary | std::ios::ate);
        if (!f.is_open()) continue;
        std::streamsize sz = f.tellg();
        if (sz < 0) continue;
        f.seekg(0);
        char* buf = new char[(size_t)sz];
        f.read(buf, sz);
        *out_data = buf;
        *out_bytes = (UINT)sz;
        return S_OK;
    }
    return E_FAIL;
}

HRESULT __stdcall ShaderIncludeHandler::Close(LPCVOID data) {
    delete[] static_cast<const char*>(data);
    return S_OK;
}

namespace {
UINT CompileFlags() {
    UINT f = D3DCOMPILE_ENABLE_STRICTNESS;
#ifdef _DEBUG
    f |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#else
    f |= D3DCOMPILE_OPTIMIZATION_LEVEL3;
#endif
    return f;
}

std::string BlobToString(ID3DBlob* blob) {
    if (!blob) return {};
    return std::string((const char*)blob->GetBufferPointer(), blob->GetBufferSize());
}
}

CompiledVS ShaderManager::CompileVS(const std::wstring& path,
                                    const char* entry,
                                    const D3D11_INPUT_ELEMENT_DESC* layout_desc,
                                    UINT layout_count,
                                    std::string* out_error) {
    CompiledVS r;
    ComPtr<ID3DBlob> code, err;
    ShaderIncludeHandler includer;
    HRESULT hr = D3DCompileFromFile(
        path.c_str(), nullptr, &includer,
        entry, "vs_5_0", CompileFlags(), 0,
        code.GetAddressOf(), err.GetAddressOf());
    if (FAILED(hr)) {
        if (out_error) *out_error = BlobToString(err.Get());
        return r;
    }
    if (FAILED(device_->CreateVertexShader(
            code->GetBufferPointer(), code->GetBufferSize(), nullptr,
            r.shader.GetAddressOf()))) return r;
    if (FAILED(device_->CreateInputLayout(
            layout_desc, layout_count,
            code->GetBufferPointer(), code->GetBufferSize(),
            r.layout.GetAddressOf()))) return r;
    r.bytecode = code;
    r.ok = true;
    return r;
}

CompiledPS ShaderManager::CompilePS(const std::wstring& path, const char* entry) {
    CompiledPS r;
    ComPtr<ID3DBlob> code, err;
    ShaderIncludeHandler includer;
    HRESULT hr = D3DCompileFromFile(
        path.c_str(), nullptr, &includer,
        entry, "ps_5_0", CompileFlags(), 0,
        code.GetAddressOf(), err.GetAddressOf());
    if (FAILED(hr)) {
        r.error = BlobToString(err.Get());
        if (r.error.empty()) r.error = "D3DCompileFromFile failed (file not found?)";
        return r;
    }
    if (FAILED(device_->CreatePixelShader(
            code->GetBufferPointer(), code->GetBufferSize(), nullptr,
            r.shader.GetAddressOf()))) {
        r.error = "CreatePixelShader failed";
        return r;
    }
    r.ok = true;
    return r;
}
