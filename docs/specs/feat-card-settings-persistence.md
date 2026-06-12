# Spec: feat-card-settings-persistence

- **Branch**: feat/card-settings-persistence
- **Started**: 2026-06-05
- **Status**: Complete

## 목적

ImGui에서 조정한 카드별 `params`, `transform`, `style` 값을 파일에 저장하고 앱 재실행 시 기본값으로 복원한다.

## 작업 항목

- [x] `shaders/cards/card_settings.txt` line-based 설정 파일 추가
- [x] 카드 설정 로드/저장 함수 추가
- [x] Cards 패널에 `Save Card`, `Save All Cards`, `Load All Cards`, `Reset Card` 버튼 추가
- [x] 카드 설정 파일 변경 감지 시 hot reload 적용
- [x] README와 changelog 갱신

## 변경 파일

- `src/App.h`, `src/App.cpp`, `src/Config.h`
- `shaders/cards/card_settings.txt`
- `README.md`, `docs/CHANGELOG.md`

## 검증 (End-to-End)

- 빌드: `cmake --build --preset debug` 통과
- 앱 실행 후 Cards 패널 버튼으로 저장/로드/리셋 확인

## 위험 / 비-범위

- 저장 대상은 카드별 `params`, `transform`, `style`만 포함한다.
- 전역 Render 색상, Background, Coverflow tuning 값 저장은 이번 범위에 포함하지 않는다.
