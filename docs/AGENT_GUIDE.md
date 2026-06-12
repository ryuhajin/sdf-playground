# AI Agent Guide

이 문서는 AI 에이전트나 미래의 작업자가 이 저장소를 빠르게 이해하고 안전하게 수정하기 위한 작업 가이드입니다. GitHub 방문자용 소개는 루트의 `README.md`를 기준으로 합니다.

## 저장소 목적

SDF Lab Cards는 DirectX 11 + HLSL 기반 SDF 학습용 카드 실험 앱입니다. 핵심 작업은 `shaders/cards`의 카드 shader와 `shaders/lib`의 공통 HLSLI 함수를 수정하면서, SDF 함수 조합과 shader 구조를 익히고 실행 중 hot reload로 결과를 빠르게 확인하는 것입니다.

작업을 시작할 때 우선 확인할 문서입니다.

- `README.md`: 사람용 프로젝트 개요, 빌드, 실행
- `docs/CARD_AUTHORING.md`: 카드 추가/수정 절차
- `docs/HLSL_CARD_FLOW.md`: 카드 shader 렌더링 흐름 상세
- `docs/CURRENT_SHADER_MODEL.md`: 현재 shader 모델과 공통 함수 구조
- `docs/WORKFLOW.md`: 브랜치, spec, ADR 중심의 작업 방식
- `docs/decisions/`: 주요 설계 결정 기록

## 주석 작성/수정 원칙

- 이 저장소의 새 코드 주석은 한국어로 작성한다.
- 기존 주석에는 사용자의 의도나 학습 맥락이 담겨 있을 수 있으므로, 주석 자체를 정리, 번역, 삭제하기 전에는 사용자 확인을 받는다.
- 코드 변경 때문에 주석이 명백히 틀려지는 경우에는 사용자에게 변경 필요성을 짧게 알리고 코드와 함께 정리한다.
- 사용자가 특정 주석 변경을 명시적으로 요청한 경우에는 그 요청 범위 안에서 진행한다.

## 폴더 역할

- `src/`: Win32, DirectX 11, ImGui 기반 앱 코드
- `shaders/`: HLSL/HLSLI shader와 카드 파일
- `docs/`: 작업 문서, spec, ADR, 템플릿
- `external/imgui/`: vendored Dear ImGui 소스
- `out/`: CMake/Visual Studio 빌드 산출물이며 git 제외
- `.vs/`: Visual Studio 로컬 설정이며 git 제외

## 주요 모듈

- `App`: 앱 루프, Win32 메시지 처리, 입력, ImGui 패널, 카드 상태 관리
- `Renderer`: D3D11 device, swap chain, render target 생성과 관리
- `ShaderManager`: HLSL compile, custom include 처리, compile error 전달
- `Coverflow`: 카드 위치, 슬라이드 이동, 보간, 표시 슬롯 계산
- `FileWatcher`: shader 파일 변경 감지와 hot reload 트리거

## 렌더링 흐름

1. Win32 메시지와 키 입력을 처리한다.
2. `Coverflow`가 현재 카드 위치와 슬롯별 transform을 갱신한다.
3. 카드별 constant buffer를 갱신한다.
4. 공통 vertex shader가 quad를 카드 위치에 배치한다.
5. 카드별 pixel shader가 SDF 함수를 조합해 색상을 계산한다.
6. ImGui overlay를 그린다.
7. swap chain을 present한다.

## 카드 작업 흐름

카드는 `shaders/cards` 아래의 HLSL 파일로 관리합니다.

- `card_NN.hlsl`: 카드별 pixel shader
- `card_files.txt`: 앱에 로드할 카드 파일 목록
- `card_settings.txt`: 카드별 params, transform, style 기본값
- `shaders/lib/*.hlsli`: 카드들이 공유하는 SDF 함수, transform, animation, mask/color helper

작은 shader helper 함수 몇 개를 추가하거나 카드 표현을 국소적으로 바꾸는 작업은 `shaders/lib/*.hlsli` 또는 개별 `card_NN.hlsl`에서 바로 진행해도 됩니다. 새 카드를 추가하거나 카드 설정 형식을 바꾸는 작업은 먼저 `docs/CARD_AUTHORING.md`를 확인합니다.

공통 HLSLI API를 크게 바꾸면 기존 카드들이 깨질 수 있습니다. 이 경우 브랜치를 만들고, 영향받는 카드와 문서를 함께 갱신합니다.

## Git Rules

`main`은 안정 브랜치로 유지합니다. GitHub에 올린 뒤에는 `main`에서 바로 큰 구조 변경을 하지 않습니다.

현재 브랜치에서 해도 되는 작은 수정입니다.

- README 오타 수정
- 문서 링크 수정
- HLSL/HLSLI에 작은 helper 함수 몇 개 추가
- 카드 shader의 국소적인 파라미터나 표현 수정
- 빌드 산출물과 무관한 작은 문서 정리

반드시 새 브랜치를 만들고 작업해야 하는 큰 변경입니다.

- 빌드 환경 변경
- CMake 구조 변경
- 외부 라이브러리 추가 또는 업데이트
- 폴더 구조 변경
- 렌더링 파이프라인 변경
- shader include 구조 변경
- 공통 HLSLI API를 크게 바꾸는 작업
- 카드 설정 파일 형식이나 로딩 규칙 변경

브랜치 이름은 다음 규칙을 사용합니다.

- `feat/<slug>`: 새 기능
- `fix/<slug>`: 버그 수정
- `docs/<slug>`: 문서 변경
- `refactor/<slug>`: 동작 변경 없는 구조 정리
- `chore/<slug>`: 빌드, 의존성, 기타 관리 작업

큰 변경 브랜치에서는 `docs/specs/<slug>.md`를 작성하거나 갱신합니다. 중요한 설계 결정이 생기면 `docs/decisions/`에 ADR을 추가합니다.

병합 전 확인 사항입니다.

```powershell
cmake --preset vs2022-x64
cmake --build --preset debug
```

가능하면 앱을 실행해 카드 렌더링, 키 입력, shader hot reload가 정상인지 확인합니다. 사용자에게 보이는 변경이나 구조적 변경이 있으면 `docs/CHANGELOG.md`도 갱신합니다.

## Git에 올리지 않을 것

다음 항목은 로컬 생성물 또는 개인 설정이므로 commit하지 않습니다.

- `.vs/`
- `out/`
- `build/`
- `imgui.ini`
- `*.user`
- `*.suo`
- `*.VC.db`
- `external/imgui/.git/`

`external/imgui`는 vendored dependency로 소스 파일은 포함하지만, 내부 `.git` 디렉터리는 포함하지 않습니다.
