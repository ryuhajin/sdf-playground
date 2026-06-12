# Spec: fix/vs-ps-linkage

- **Branch**: fix/vs-ps-linkage
- **Started**: 2026-05-15
- **Completed**: 2026-05-15
- **Status**: Complete

## 목적
VS 출력 시그니처와 PS 입력 시그니처를 정렬해 D3D11 debug layer가 보고하는 TEXCOORD 레지스터 mismatch와 그로 인한 화면 깜빡임을 제거한다.

## 배경 / 동기
디버그 빌드 실행 시 매 `DrawIndexed` 호출에서:
```
D3D11 ERROR: ID3D11DeviceContext::DrawIndexed: Vertex Shader - Pixel Shader linkage error:
Signatures between stages are incompatible.
Semantic 'TEXCOORD' is defined for mismatched hardware registers between the output stage and input stage.
[ EXECUTION ERROR #343: DEVICE_SHADER_LINKAGE_REGISTERINDEX]
```

**원인**: `quad.vs.hlsl`의 출력은 `{SV_Position, TEXCOORD}` 두 슬롯이지만, 카드 PS 입력은 `float2 uv : TEXCOORD` 한 슬롯만 받는다. fxc가 TEXCOORD를 VS 쪽에서는 SV_Position 뒤 register slot에, PS 쪽에서는 첫 slot(v0)에 배치 → 레지스터 인덱스 불일치. semantic 매칭은 되지만 D3D11 debug layer는 register index가 다르면 ERROR로 잡고, 일부 드라이버에선 실제로 깨진 데이터를 읽어 깜빡임이 발생한다.

## 작업 항목
- [x] 원인 진단
- [x] `shaders/lib/sdf_common.hlsli`에 공용 `PSIn` 구조체 추가 (`SV_Position` + `TEXCOORD`)
- [x] `shaders/cards/card_01.hlsl` ~ `card_05.hlsl`을 `float4 main(PSIn i) : SV_Target` 시그니처로 갱신
- [x] 빌드 통과 (`cmake --build`)
- [ ] 실행 후 디버그 출력에 ERROR #343 사라짐 + 깜빡임 없음 확인 — **사용자 인터랙티브 검증 (VS Output 창)**
- [x] ADR 0005 작성
- [x] CHANGELOG entry 추가
- [x] spec Complete
- [x] README의 카드 예제 코드도 새 시그니처로 동기화

## 변경 파일
- `shaders/lib/sdf_common.hlsli` (PSIn 구조체 추가)
- `shaders/cards/card_01.hlsl` ~ `card_05.hlsl` (시그니처 변경, `uv` → `i.uv`)
- `docs/decisions/0005-shared-psin-struct.md` (신규)
- `docs/CHANGELOG.md`

## 검증 (End-to-End)
1. **빌드**: `cmake --build build --config Debug` 통과
2. **실행**: `SDFs.exe` 실행 후 Visual Studio 출력 창에 ERROR #343 안 나옴
3. **시각**: 중앙 카드가 깜빡이지 않고 안정적으로 표시
4. **좌우 슬라이드**: 5장 카드 모두 정상

## 위험 / 비-범위
- **위험**: 카드 작성 API 변경(`uv` → `i.uv`)이 사용자 작성 카드에도 영향. 일관성을 위해 모든 카드에서 동일하게 사용. README/문서에 업데이트
- **비-범위**:
  - VS 자체 구조 변경 (그대로 유지)
  - 추가 PS 입력 (예: 노멀, world pos) — 필요해지면 별도 작업
  - 카드 메타데이터 등 다른 개선

## 참고
- 관련 ADR: [0002](../decisions/0002-hlsli-library-structure.md) (라이브러리 구조), 0005 (이번)
- D3D11 ERROR #343 docs (DEVICE_SHADER_LINKAGE_REGISTERINDEX)
