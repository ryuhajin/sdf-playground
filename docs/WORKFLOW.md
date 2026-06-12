# Workflow

비상업 학습 프로젝트지만 변경을 추적 가능하게 하고, 다른 AI/협업자가 들어와도 일관된 방식으로 일할 수 있도록 정한 규칙.

## 목표
1. 모든 코드 변경은 명시적 spec과 검증 단계를 거친다
2. 큰 기술적 결정은 ADR로 남긴다
3. 무엇을 언제 바꿨는지 CHANGELOG에서 한눈에 본다
4. 다른 Claude/AI 세션이 들어와도 README → WORKFLOW만 읽으면 합류 가능

## Git 초기화

이 저장소는 아직 git 초기화 전일 수 있다. 첫 의미 있는 작업을 마무리할 때 같이 init 한다:
```powershell
git init
git add -A
git commit -m "feat: initial SDF Deck project"
git branch -M main
```

## 브랜치 명명

- `main` — 안정 빌드. 항상 `cmake --build --preset debug` 통과, `SDFs.exe` 정상 실행
- `feat/<slug>` — 새 기능 추가
- `fix/<slug>` — 버그 수정
- `docs/<slug>` — 문서만 변경 (코드 손대지 않음)
- `refactor/<slug>` — 동작 변경 없는 정리
- `chore/<slug>` — 빌드 시스템·외부 의존성 등 부수 변경

`<slug>`는 kebab-case 단어 1~4개. 예: `feat/mouse-drag-slide`, `fix/shader-include`, `docs/screenshot-gif`.

## 브랜치 시작 절차

코드를 손대기 전에 항상:

1. 브랜치 생성: `git checkout -b feat/<slug>`
2. **`docs/specs/<branch-slug>.md`** 작성 (`templates/spec.md` 복사)
   - 목적, 작업 항목, 변경 파일, 검증 방법, 위험
3. spec을 main 머지 전까지 살아있는 문서로 유지 — 작업 항목 체크박스를 진행에 따라 업데이트

> spec 없이 코드부터 짜기 시작하면 멈추고 spec부터 작성한다. 작은 fix라도 동일.

## 커밋 컨벤션 (Conventional Commits)

```
<type>(<scope>): <summary>

[body]
[footer]
```

| type | 사용 |
|---|---|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `docs` | 문서만 |
| `refactor` | 동작 변경 없는 정리 |
| `chore` | 빌드/의존성/도구 |
| `style` | 공백/포매팅만 |

예:
- `fix(shaders): custom ID3DInclude handler for nested hlsli`
- `feat(coverflow): wrap-around indexing for 20+ card pool`
- `docs: backfill ADR 0002 hlsli library structure`

## 머지 전 체크리스트

`docs/templates/merge-checklist.md`의 모든 항목을 확인한다. 핵심:

- 빌드/실행/핫리로드 OK
- `docs/CHANGELOG.md` entry 추가
- 큰 결정이면 ADR 추가
- spec `Status: Complete`로 변경
- README/문서 동기화

## 머지 후

1. 브랜치를 main으로 합친다 (fast-forward 또는 squash 선택)
2. `docs/specs/<branch>.md`를 그대로 둔다 — 의사결정 히스토리로 남김
3. 다음 작업은 다시 새 브랜치 + 새 spec

## ADR (Architecture Decision Records)

큰 기술 결정은 `docs/decisions/NNNN-<slug>.md`로 남긴다 (`templates/adr.md` 복사).

"큰 결정"의 기준:
- 외부 의존성 추가/제거
- 모듈 구조 변경
- 데이터 포맷·API 변경
- 라이센스에 영향 있는 결정
- 같은 문제를 다시 마주칠 가능성이 있는 트레이드오프

번호는 `0001`, `0002`, ... 4자리. 한 번 발급된 번호는 재사용하지 않는다.

상태: `Proposed` → `Accepted` → (필요시) `Superseded by NNNN`

## CHANGELOG

`docs/CHANGELOG.md`. 날짜(ISO 8601) 그룹, 최신이 위. 한 줄당 한 변경, Conventional Commits 헤더 그대로 옮긴다.

## AI 협업 노트

다른 Claude/AI 세션이 이 저장소를 만나면:

1. `README.md` → "워크플로우" 섹션 → 이 파일로 진입
2. `docs/specs/`에 in-progress spec이 있는지 확인
3. 새 작업이면 위 브랜치 시작 절차를 따른다
4. 빌드 산출물은 `out/`에 모이며 소스가 아니다. `*.dir`, `ALL_BUILD`, `ZERO_CHECK`, `CMakeFiles`는 재생성 가능하다
5. 기본 빌드는 `cmake --preset vs2022-x64` 후 `cmake --build --preset debug`
6. 인간이 명시적으로 다른 방식을 요청하면 따른다 (이 워크플로우는 기본값)
