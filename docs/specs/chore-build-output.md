# Spec: chore-build-output

- **Branch**: chore/build-output
- **Started**: 2026-06-05
- **Status**: Complete

## 목적

Visual Studio 빌드 흐름은 유지하면서 CMake/VS 산출물을 `out/` 아래로 격리해 프로젝트 루트를 단순하게 만든다.

## 작업 항목

- [x] `CMakePresets.json` 추가 (`vs2022-x64`, `debug`, `release`)
- [x] 실행 파일 출력 위치를 `out/bin/<Config>/SDFs.exe`로 변경
- [x] 사용하지 않는 `imgui_demo.cpp`를 빌드 대상에서 제외
- [x] `README.md`, `docs/WORKFLOW.md`, 템플릿, changelog, ADR 갱신
- [x] 과거 `build/` 산출물 제거

## 변경 파일

- `CMakeLists.txt`
- `CMakePresets.json`
- `.gitignore`
- `README.md`
- `docs/...`

## 검증 (End-to-End)

- Configure: `cmake --preset vs2022-x64` 통과
- 빌드: `cmake --build --preset debug` 통과
- 실행: `out/bin/Debug/SDFs.exe` smoke test 통과 (`Launched=True`, `ExitCode=0`)
- 정리: 루트의 과거 `build/` 폴더 삭제 후에도 preset 빌드 통과

## 위험 / 비-범위

- 깨질 수 있는 것: Visual Studio가 생성하는 `*.dir`, `ALL_BUILD`, `ZERO_CHECK`는 사라지지 않고 `out/build/vs2022-x64/`로 이동한다.
- 이 브랜치에서 하지 않을 것: HLSLI 라이브러리 확장, 카드 셰이더 API 변경.
