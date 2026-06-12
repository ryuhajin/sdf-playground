# ADR 0009: VS Presets와 격리된 빌드 출력

- **Status**: Accepted
- **Date**: 2026-06-05
- **Branch / Commit**: chore/build-output

## Context

기존 빌드는 `cmake -B build -G "Visual Studio 17 2022" -A x64`로 루트 바로 아래 `build/`를 만들었다. Visual Studio 생성기는 정상적으로 동작하지만 `SDFs.dir`, `ALL_BUILD.dir`, `ZERO_CHECK.dir`, `CMakeFiles`, `.vcxproj` 같은 산출물이 많이 생겨 프로젝트 소스 구조를 읽기 어렵게 했다.

목표는 Visual Studio 2022 F5 디버깅을 유지하면서, 빌드 산출물을 재생성 가능한 한 위치로 모아 SDF 카드와 HLSLI 라이브러리 작업에 집중하기 쉬운 구조를 만드는 것이다.

## Decision

Visual Studio 2022 생성기를 계속 사용하되 `CMakePresets.json`을 표준 진입점으로 채택한다.

- Configure preset: `vs2022-x64`
- Build presets: `debug`, `release`
- CMake binary dir: `out/build/vs2022-x64`
- Runtime output: `out/bin/<Config>/SDFs.exe`

`build/`는 과거 산출물 위치로만 취급하고, 새 빌드는 `out/` 아래에서 재생성한다. `*.dir`, `ALL_BUILD`, `ZERO_CHECK`는 제거 대상 파일이 아니라 Visual Studio/CMake가 필요한 중간 산출물로 문서화한다.

## Consequences

- **긍정**: 루트에는 소스, 셰이더, 문서, 설정 파일만 남고 빌드 산출물은 `out/`으로 격리된다.
- **긍정**: 새 에이전트나 작업자가 `cmake --preset vs2022-x64`와 `cmake --build --preset debug`만 기억하면 된다.
- **부정**: Visual Studio 생성기의 보조 타깃(`ALL_BUILD`, `ZERO_CHECK`)과 `.dir` 폴더 자체는 계속 생성된다.
- **후속 작업**: Ninja를 설치하거나 별도 CLI 전용 흐름이 필요해지면 새 preset을 추가해 비교한다.

## Alternatives Considered

- **기존 `build/` 유지**: 동작은 안정적이지만 루트에 중간 산출물이 계속 보이고 정리 기준이 흐려진다. 거부.
- **Ninja를 기본 생성기로 전환**: 빌드 트리는 더 작아질 수 있지만 현재 환경에 Ninja가 설치되어 있지 않고 Visual Studio F5 흐름을 유지하는 요구와 맞지 않는다. 거부.
- **Visual Studio 프로젝트 직접 관리**: CMake 재생성 흐름과 파일 자동 수집 장점을 잃는다. 거부.

## 참고

- 관련 ADR: [0001](0001-cmake-build-system.md)
