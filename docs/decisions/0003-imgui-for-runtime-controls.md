# ADR 0003: 런타임 컨트롤에 Dear ImGui 채택

- **Status**: Accepted
- **Date**: 2026-05-14
- **Branch / Commit**: 초기 셋업

## Context
카드 셰이더 학습 중에는 색상·애니메이션 모드·카드별 파라미터를 빠르게 바꿔보고 싶다. UI 선택지:

- Dear ImGui (immediate mode)
- Direct2D/DirectWrite로 직접 그린 커스텀 UI
- 키보드 단축키만
- WinAPI 컨트롤 (CreateWindowEx로 버튼/슬라이더)

사용자는 과거 다른 프로젝트에서 ImGui를 써본 경험이 있고 익숙함 (메모리: `feedback-imgui`).

## Decision
**Dear ImGui v1.91.5 docking 브랜치 벤더링**.
- `external/imgui/`에 git clone으로 소스 직접 포함 (NuGet/vcpkg 미사용)
- `imgui_impl_win32` + `imgui_impl_dx11` 백엔드 사용
- CMakeLists에서 같은 실행 파일에 컴파일

패널 구성 (`App::DrawUi`):
- Render: Use Color, Gradient mode, Mask1/Mask2 picker
- Animation: 모드 선택, time scale, pause
- Cards: 풀 정보, 카드별 4슬라이더(`uCardParams`)
- Coverflow tuning: spacing/yaw/zStep/scaleStep/lerpSpeed

## Consequences
- **긍정**: 빠른 반복, 사용자 친숙도 높음, 풍부한 위젯, 메모리·CPU 부담 작음. 셰이더 컴파일 에러 표시도 ImGui 창으로 재활용 → DirectWrite 분리 안 해도 됨
- **부정**: 외부 의존성 1개 추가 (MIT 호환). 빌드 시간 약간 증가 (imgui*.cpp 컴파일 ~몇 초). 입력 이벤트가 ImGui와 앱 사이를 갈라야 함 (`io.WantCaptureKeyboard/Mouse` 체크 필요)
- **후속 작업**: 카드별 파라미터 라벨 커스터마이즈는 추후 카드 메타파일 기능과 함께

## Alternatives Considered
- **Direct2D 커스텀 UI**: 학습용 프로젝트의 핵심 가치(SDF)와 무관한 영역에서 시간 소모. 거부
- **키보드 단축키만**: 색상 picker처럼 연속 값 조절이 비현실적. 거부
- **WinAPI 컨트롤**: 룩앤필 못남, 모달 한계, 시간 소모. 거부
- **ImGui Plot/ImPlot 같은 확장**: 일단 코어 ImGui로 충분. 필요 시 별도 ADR

## 참고
- Dear ImGui repo (MIT)
- 사용자 메모리: `feedback-imgui` (ImGui 선호)
