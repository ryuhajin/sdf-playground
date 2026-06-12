# SDF Lab Cards

DirectX 11과 HLSL로 Signed Distance Field(SDF)를 학습하고 실험하기 위해 만든 카드형 shader 앱입니다. 여러 개의 SDF 카드를 coverflow 형태로 넘기면서, 각 카드의 shader와 파라미터를 빠르게 확인할 수 있습니다.

## 프로젝트 개요

SDF Lab Cards는 HLSL shader 안에서 원, 박스, 별, 반복, 회전, 부드러운 합성 같은 SDF 함수들을 직접 조합해보며 SDF 개념을 익히기 위한 작은 Windows 데스크톱 앱입니다. 공통 HLSLI 라이브러리를 나누어 관리하고, shader hot reload를 통해 수정 결과를 실행 중에 빠르게 확인하는 흐름을 목표로 합니다.

목표는 다음과 같습니다.

- SDF 함수 조합을 카드 단위로 빠르게 실험하기
- HLSL/HLSLI 파일을 수정하고 실행 중에 hot reload로 바로 확인하기
- ImGui 패널에서 카드별 파라미터와 transform/style 값을 조정하기
- coverflow UI로 여러 shader 카드를 넘겨보며 비교하기

## 주요 기능

- DirectX 11 기반 카드 렌더링
- HLSL pixel shader 카드 시스템
- HLSLI 공통 SDF 라이브러리
- shader 파일 변경 감지 및 hot reload
- Dear ImGui 기반 런타임 컨트롤 패널
- 카드별 파라미터, transform, fill/stroke style 조정

## 단축키

| 키 | 동작 |
|---|---|
| `← / →` | 이전/다음 카드로 이동 |
| `Space` | 일시정지/재개 |
| `Esc` | 종료 |

## 사용 기술과 라이브러리

- Windows / Win32
- DirectX 11
- HLSL / HLSLI
- Dear ImGui, vendored at `external/imgui`
- CMake
- Visual Studio 2022

Dear ImGui는 submodule이 아니라 `external/imgui` 아래에 소스가 포함된 vendored dependency로 관리합니다.

## HLSLI 라이브러리

`shaders/lib` 아래의 HLSLI 파일들은 카드 shader가 공유하는 SDF 도구 모음입니다.

- `sdf_common.hlsli`: 공통 입력 구조와 좌표 변환 helper
- `sdf_cbuffers.hlsli`: per-frame/per-card constant buffer 정의
- `sdf_mask.hlsli`: fill, stroke, soft mask 처리
- `sdf_color.hlsli`: mask 기반 색상과 palette 처리
- `sdf_shapes.hlsli`: 기본 SDF shape 함수
- `sdf_operators.hlsli`: union, subtract, intersection, smooth min/max 등 조합 연산
- `sdf_transform.hlsli`: rotate, scale, repeat, mirror, polar/kaleido 계열 변환
- `sdf_animation.hlsli`: 시간 기반 animation helper

## 요구사항

- Windows 10 또는 Windows 11
- Visual Studio 2022
- Visual Studio C++ workload
- Windows 10/11 SDK
- CMake 3.20 이상

## 빌드

프로젝트 루트에서 다음 명령을 실행합니다.

```powershell
cmake --preset vs2022-x64
cmake --build --preset debug
```

빌드 산출물은 `out/` 아래에 생성됩니다. `out/`, `.vs/`, `imgui.ini` 같은 로컬 생성 파일은 git에 올리지 않습니다.

## 실행

Visual Studio에서 실행하려면 생성된 솔루션을 엽니다.

```text
out/build/vs2022-x64/SDFs.sln
```

`SDFs` 프로젝트가 startup project로 설정되어 있으며, Visual Studio에서 `F5`로 실행할 수 있습니다.

CLI에서 실행하려면 프로젝트 루트에서 다음 명령을 사용합니다.

```powershell
Start-Process out\bin\Debug\SDFs.exe -WorkingDirectory $PWD
```

## 자세한 문서

- [AI Agent Guide](docs/AGENT_GUIDE.md): 저장소 구조, 작업 흐름, git 규칙
- [Card Authoring Guide](docs/CARD_AUTHORING.md): SDF 카드 추가와 수정 방법
- [Decision Records](docs/decisions/): 주요 설계 결정 기록
