cmake_minimum_required(VERSION 3.20)
project(SDFs CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# MSVC 런타임을 정적 링크 (Debug=/MTd, Release=/MT) — .exe 단독 실행 가능.
# 동적 링크 시 vcruntime140d.dll 등 Debug DLL 로드 실패로 더블클릭 실행이 안 됨.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(MSVC)
    add_compile_options(/utf-8 /W3 /permissive- /Zc:__cplusplus)
    add_compile_definitions(UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
endif()

set(IMGUI_DIR ${CMAKE_SOURCE_DIR}/external/imgui)
set(IMGUI_SOURCES
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/backends/imgui_impl_win32.cpp
    ${IMGUI_DIR}/backends/imgui_impl_dx11.cpp
)

file(GLOB SDFS_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_SOURCE_DIR}/src/*.cpp
    ${CMAKE_SOURCE_DIR}/src/*.h
)

add_executable(SDFs WIN32
    ${SDFS_SOURCES}
    ${IMGUI_SOURCES}
)

target_include_directories(SDFs PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${IMGUI_DIR}
    ${IMGUI_DIR}/backends
)

target_link_libraries(SDFs PRIVATE
    d3d11
    d3dcompiler
    dxgi
    dwrite
    d2d1
)

# 프로젝트 루트 절대 경로를 매크로로 주입 — main.cpp 가 working directory 를
# 이 경로로 고정해서, .exe 를 어디서 실행하든 상대 경로 셰이더 로드가 작동.
target_compile_definitions(SDFs PRIVATE
    SDF_SOURCE_ROOT="${CMAKE_SOURCE_DIR}"
)

set_target_properties(SDFs PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/out/bin"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_SOURCE_DIR}/out/bin/Debug"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/out/bin/Release"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_SOURCE_DIR}/out/bin/RelWithDebInfo"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_SOURCE_DIR}/out/bin/MinSizeRel"
    VS_GLOBAL_VcpkgApplocalDeps "false"
    VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

set_property(DIRECTORY ${CMAKE_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT SDFs)

source_group("imgui" FILES ${IMGUI_SOURCES})
source_group(TREE ${CMAKE_SOURCE_DIR}/src PREFIX "src" FILES ${SDFS_SOURCES})
