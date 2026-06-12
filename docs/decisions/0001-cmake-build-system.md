# ADR 0001: CMake 빌드 시스템 채택

- **Status**: Accepted
- **Date**: 2026-05-14
- **Branch / Commit**: 초기 셋업

## Context
DirectX 11 + HLSL 학습 프로젝트를 Windows + Visual Studio 2022에서 시작. 빌드 시스템 선택지:

- VS 솔루션을 GUI로 직접 만들기
- CMake로 솔루션 생성
- Premake / Meson / xmake

핵심 제약:
- 비상업 개인 포트폴리오 — 채용 시 코드 가독성/표준성 중요
- 새 카드 셰이더 파일이 계속 추가될 예정 (자동 등록 선호)
- ImGui 등 외부 의존성을 벤더링 형태로 포함

## Decision
**CMake 3.20+** 채택. `CMakeLists.txt` 한 파일로 빌드 정의.

- `file(GLOB CONFIGURE_DEPENDS)`로 `src/*.cpp` 자동 수집
- ImGui 소스(`external/imgui/imgui*.cpp` + DX11/Win32 backends)를 동일 실행 파일에 컴파일
- `VS_DEBUGGER_WORKING_DIRECTORY = ${CMAKE_SOURCE_DIR}` 로 F5 시 작업 디렉토리 자동 지정
- `VS_STARTUP_PROJECT SDFs`로 솔루션 열면 SDFs가 startup

## Consequences
- **긍정**: 업계 표준이라 포트폴리오로서 인상 좋음. 파일 추가 시 CMake가 자동 인식. 향후 vcpkg/FetchContent 등으로 확장 가능
- **부정**: CMake 문법 학습이 필요. 빌드 한번 더 거쳐야 함 (CMake → 솔루션 → MSBuild)
- **후속 작업**: 없음. 한 번 작성 후 거의 손대지 않음

## Alternatives Considered
- **VS 솔루션 직접**: F5 진입장벽이 가장 낮지만 GUI 종속, 다른 IDE 불가, 포트폴리오 가치 낮음. 거부
- **Premake**: Lua 기반, CMake보다 단순하지만 사용자층 작음. 거부
- **Meson**: 좋지만 VS 통합 약함. 거부

## 참고
- CMake VS Generator docs
