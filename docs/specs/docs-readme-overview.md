# Spec: docs/readme-overview

- **Branch**: docs/readme-overview
- **Started**: 2026-09-28
- **Status**: In Progress

## 목적
처음 방문한 사람이 한눈에 프로젝트를 이해하도록 README를 개요·스크린샷·기능·빌드·조작 중심으로 다시 쓰고, VolumetricCloud·WaterShader README와 같은 구조로 통일한다.

## 배경 / 동기
기존 README에는 카드 목록·스크린샷·동작 원리 설명이 없었고, 세 포트폴리오 저장소의 README 구조가 서로 달랐다.

## 작업 항목
- [x] 공통 섹션 순서(개요 → 스크린샷 → 기능 → 구현 포인트 → 빌드와 실행 → 조작 → 구조 → 문서 → 참고 자료)로 README 재작성
- [x] 카드 01~13 목록 표, ImGui 패널 표, 핫 리로드 흐름도 추가
- [ ] `docs/images/`에 스크린샷 추가 (`hero.png`, `card-05-metaball.png`, `card-10-dissolve.png`, `card-11-topographic.png`, `card-12-volume.png`)

## 변경 파일
- `README.md`
- `docs/CHANGELOG.md`
- `docs/specs/docs-readme-overview.md`
- `docs/images/*.png` (사용자 제공 예정)

## 검증 (End-to-End)
- 코드 변경 없음 — 빌드 영향 없음
- README의 상대 링크가 모두 저장소에 존재하는지 확인
- 키 조작·빌드 명령·출력 경로를 `src/App.cpp`, `CMakePresets.json`, `CMakeLists.txt`와 대조

## 위험 / 비-범위
- 깨질 수 있는 것: 스크린샷 추가 전에 push하면 README 이미지가 깨져 보인다
- 이 브랜치에서 하지 않을 것: 코드·셰이더 변경

## 참고
- 관련 ADR: 없음
