# Merge Checklist: <branch>

머지(또는 main 통합) 직전에 모든 항목을 확인한다. 미체크 항목이 있으면 머지하지 않는다.

## 코드
- [ ] `cmake --preset vs2022-x64` 통과
- [ ] `cmake --build --preset debug` 통과 (경고 없음 또는 의도된 경고만)
- [ ] `out/bin/Debug/SDFs.exe` 실행 → 5장 카드 정상 렌더, ImGui 패널 표시
- [ ] 핫리로드: `card_01.hlsl` 편집 후 저장 → 1초 내 화면 반영
- [ ] 일부러 셰이더 오류 주입 → 화면 하단에 빨간 에러 표시, 이전 셰이더로 계속 렌더
- [ ] ← / → 키 슬라이드 정상

## 문서
- [ ] `docs/CHANGELOG.md`에 항목 추가 (Conventional Commits 형식)
- [ ] 큰 결정이면 `docs/decisions/NNNN-<slug>.md` 추가 (`templates/adr.md` 복사)
- [ ] 새 카드 추가 시: `shaders/cards/card_files.txt` 갱신
- [ ] `README.md` 영향이 있으면 동기화 (구현 기능, 폴더 구조 등)
- [ ] `docs/specs/<branch>.md`를 `Status: Complete`로 변경

## 규칙
- [ ] 라이센스/attribution 라인 손대지 않음 (`README.md`, `docs/`)
- [ ] PixelSpiritDeck 코드를 직접 복사하지 않음 (영감만)
- [ ] 외부 라이브러리 추가 시 라이센스 호환성 확인 (비상업 OK)

## 비주얼 확인 (선택)
- [ ] 스크린샷/짧은 GIF 캡처 (큰 시각적 변화가 있다면)
