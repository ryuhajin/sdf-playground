# Spec: feat/ui-clarify

- **Branch**: feat/ui-clarify
- **Started**: 2026-05-15
- **Completed**: 2026-05-15
- **Status**: Complete

## 목적
ImGui 패널의 두 가지 UX 혼란을 제거한다:
1. `Edit card` 가 항상 `card_01.hlsl` 로 고정 → 슬라이드해도 안 따라옴
2. `spacing (near/far)` 같은 SliderFloat2 라벨이 모호 → 어느 슬라이더가 ±1 인지 ±2 인지 헷갈림 → 사용자가 잘못된 슬라이더를 만져 의도와 다른 결과를 보고 painter's order 문제로 오해

## 배경 / 동기
사용자 보고:
> "edit card의 리스트가 항상 고정 card_01.hlsl인데 왼쪽 오른쪽으로 카드를 움직이면 그 카드의 인덱스와 맞게 리스트가 변경됐으면 좋겠어"
>
> "왜 near가 -2,+2 인덱스 카드고 far가 -1, +1 카드야?"
>
> "spacing의 near 범위를 줄이면(0.500) -2,+2 카드 들이 -1,+1 카드 위로 그려진다"

원인 분석:
- Cards 섹션: `ui_selected_card_` 가 사용자 combo 선택에만 의존, 자동 갱신 로직 없음
- Coverflow tuning: `SliderFloat2("spacing (near/far)", ...)` 의 한 줄 두 값 표시가 어느 쪽이 ±1/±2 인지 시각적으로 불분명. 사용자가 "near = 가장자리(near edge)" 로 오인할 여지 있음.
- Painter's order 오해: 사용자가 `spacing[0]` (실제로는 ±1 카드 거리)를 0.5 로 줄였는데 의도는 ±2 를 줄이는 것이었음. ±1 이 center footprint 안으로 들어가 center 에 가려졌고, ±2 는 그대로라 시각적으로 "±2 가 ±1 위로 그려진" 듯 보임. 실제로는 ±1 vs ±2 painter's order 문제가 아님.

## 작업 항목
- [x] 원인 진단 (위)
- [x] `src/App.cpp` `DrawUi()` Cards 섹션:
  - `ui_selected_card_ = coverflow_.CenterCardIndex();` 매 프레임 동기화
  - Combo box 제거
  - "Editing: card_NN.hlsl (center)" 라벨
  - 4 슬라이더 위에 `(?)` 도움말 hover ( `uCardParams.xyzw` 매핑 설명 )
- [x] `src/App.cpp` `DrawUi()` Coverflow tuning 섹션:
  - 상단 painter's order 안내 1줄
  - SliderFloat2 → 단일 SliderFloat 두 개 (`±1`, `±2` 명시, spacing 만 ±1 최소 1.0)
  - yaw, zDepth, scale 도 동일 패턴
- [x] 빌드 + 백그라운드 실행 확인
- [x] `README.md` 카드 추가 절차에 `uCardParams` 컨벤션 1줄 추가
- [x] `docs/CHANGELOG.md` entry
- [x] spec Status: Complete

## 변경 파일
- `src/App.cpp` (DrawUi 갱신만)
- `README.md`
- `docs/CHANGELOG.md`

## 검증 (End-to-End)
1. **빌드**: `cmake --build build --config Debug` 통과
2. **Cards 섹션**:
   - 처음에 "Editing: card_01.hlsl (center)" + 4 슬라이더
   - → 누르면 "card_02.hlsl (center)" 로 갱신
   - 슬라이더가 항상 center 카드의 params 편집
3. **Coverflow tuning**:
   - `spacing ±1 (slot 1·3)` (최소 1.0), `spacing ±2 (slot 0·4)` 별도 슬라이더
   - draw order 안내문 가시
   - yaw/z/scale 도 분리되어 보임

## 위험 / 비-범위
- 비-center 카드 직접 편집 기능 제거 (현재 요구사항 단순화). 필요해지면 별도 spec
- Depth buffer 도입은 별도 spec

## 참고
- Plan: `C:\Users\da171\.claude\plans\https-github-com-patriciogonzalezvivo-p-shimmying-wadler.md`
