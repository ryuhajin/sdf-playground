# Spec: feat/coverflow-polish

- **Branch**: feat/coverflow-polish
- **Started**: 2026-05-15
- **Completed**: 2026-05-15
- **Status**: Complete

## 목적
카드 deck 디자인 폴리시 5가지 + 상수 중앙 관리 헤더 도입을 한 번에 적용한다.

## 배경 / 동기
사용자 확인 사항:
- 디버그 실행 + 핫리로드 정상 동작
- 디자인/동작 폴리시 5가지 요청
- 매직 넘버 대신 `Config.h` 상수 헤더로 관리 요청

## 작업 항목
- [x] 원인 진단 (wrap-around 점프 = N=5 + 5슬롯 동시 표시)
- [x] `src/Config.h` 신규 — `namespace config` 에 윈도우/색상/카메라/coverflow/셰이더 경로 상수 모음
- [x] `src/Coverflow.h/cpp` — 멤버를 `{near,far}` 배열로, GetSlot piecewise interp + visibility (|pos|>cullPos fade)
- [x] `src/App.h/cpp` — `card_local_time_`, `prev_center_idx_`, `bg_color_` 멤버. Frame()에서 타이머 갱신, PerCardCB.uCardMeta.w 전달, draw cull. 매직 넘버 → `config::` 교체. ImGui 패널: Coverflow tuning 슬라이더 재구성, Background color picker 추가
- [x] `shaders/lib/sdf_common.hlsli` — `#define uCardTime (uCardMeta.w)`
- [x] `shaders/cards/card_01.hlsl` ~ `card_05.hlsl` — `uTimeRes.x` → `uCardTime` 일괄 교체
- [x] 빌드 통과 + 백그라운드 실행 확인 (4초 정상 실행)
- [x] ADR 0006 (per-card 로컬 타임)
- [x] ADR 0007 (piecewise 레이아웃)
- [x] ADR 0008 (상수 중앙 관리)
- [x] `docs/decisions/README.md` 인덱스 갱신
- [x] `docs/CHANGELOG.md` entry 추가
- [x] `README.md` 폴더 구조에 `src/Config.h` 반영
- [x] spec Status: Complete

## 변경 파일
신규:
- `src/Config.h`
- `docs/decisions/0006-per-card-local-time.md`
- `docs/decisions/0007-piecewise-coverflow-layout.md`
- `docs/decisions/0008-config-header.md`

수정:
- `src/Coverflow.h`, `src/Coverflow.cpp`
- `src/App.h`, `src/App.cpp`
- `shaders/lib/sdf_common.hlsli`
- `shaders/cards/card_01.hlsl` ~ `card_05.hlsl`
- `docs/decisions/README.md`
- `docs/CHANGELOG.md`
- `README.md`

## 검증 (End-to-End)
1. **빌드**: `cmake --build build --config Debug` 통과
2. **시각**:
   - 5장 카드 모두 안쪽으로 기울어져 center 향함
   - 중앙 카드가 ±1을 가리지 않음 (spacing 1.8 충분)
   - ±2는 화면 가장자리 멀리 (spacing 3.2), 거의 profile
   - 배경 RGB(70,70,70) 회색
3. **애니메이션**:
   - 중앙 카드만 시간 흐름 → sin/pulse 활성
   - ←/→ 슬라이드 시 새 중앙 카드는 0부터 시작, 떠나는 카드는 정지
4. **점프 버그**:
   - 빠른 슬라이드 시 -2 ↔ +2 순간이동 효과 사라짐 (|pos|>2.5 fade)
5. **ImGui**:
   - Coverflow tuning에 near/far 슬라이더 4쌍 + cullPos + lerpSpeed
   - Background color picker
6. **핫리로드**: 카드 1장 편집 → 즉시 반영, uCardTime 사용 OK

## 위험 / 비-범위
- **위험**: yaw 부호는 분석상 face-center인데 사용자 인지가 다를 수 있음 → 시각적으로 outward로 보이면 v2에서 부호 반전
- **위험**: 카드 풀이 5장이라 |pos|>2.5 cull로도 wrap 순간 카드 누락 가능. 사용자가 추후 카드 추가하면 자연 해결
- **비-범위**:
  - 카드 풀 확장 (5장 → 20장)
  - 카드 메타데이터(이름·라벨)
  - 마우스 드래그 슬라이드

## 참고
- 관련 ADR: 0006, 0007, 0008 (이번 작업 후 작성)
- Plan: `C:\Users\da171\.claude\plans\https-github-com-patriciogonzalezvivo-p-shimmying-wadler.md`
