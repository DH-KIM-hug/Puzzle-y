# Concept Prototype Report: 말랑 크루 스티커 (블록 배치 + 얼굴 능력 도미노)

> **Date**: 2026-11-07
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md
> **Carry-forward**: PIVOT #1 from `../match3-blitz-concept/` (PIVOT-NOTE.md)

---

## Hypothesis

크루 모양 조각을 붙여 줄을 지울 때 얼굴 칸이 능력을 쓰고, 그 능력이 다른 얼굴을 지워 연쇄가 터지면,
플레이어는 "얼굴을 어디 둘지" 고민하며 다른 블록 퍼즐과 다르다고 느낀다.

---

## Riskiest Assumption Tested

바탕(블록 배치)이 단순하면서도 원형 장르(블록 블래스트류)와 구별되는가 — 차별점은 원형에 없는
"한 번 놓은 결과가 캐릭터 능력으로 여러 단계 번지는 도미노 연쇄".

---

## Approach

단일 `prototype.html` (캔버스). v1 → 플레이테스트 → v2.

**Path chosen:** HTML — 폰에서 바로 플레이, 턴 기반이라 브라우저 지연 무관.

**Shortcuts taken (intentional):** 크루 3명 고정, 하드코딩 수치, 캔버스 도형 아트, 사운드·가챠·팀 편성·스테이지 없음.

---

## Result

- 첫 반응: **"괜찮은데?"** — 매치-3 버전("변별력이 없네")과 대비되는 긍정 반응.
- 사용자가 연쇄 기준을 질문 → 설명 후 **"아하 얼굴"**: v1에서는 얼굴 칸이 연쇄의 스위치라는 것이
  화면만으로 전달되지 않았다(하단 범례로는 부족).
- 원형 장르에 연쇄가 있는지 질문 → 원형은 동시 지우기·연속 콤보만 있고 반응형 연쇄가 없다는 점이 차별점으로 확인됨.
- v2 반영: 얼굴 칸 반짝임 강조, 드래그 중 **연쇄 전체 미리보기**(발동 순서 번호·예상 알·"연쇄 N 예상"),
  첫 판 안내, 삐약 알을 얼굴 위치 기반으로 변경. 이후 판정 **PROCEED**.
- 헤드리스: 에러 0, 미리보기 예측(연쇄 3) = 실제(연쇄 3, 능력 4회), 자동 플레이 한 판 정상.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | N/A (v1 → v2 한 번 개선) |
| Prototype duration | 수 시간 |
| Playtesters | 1 internal / 0 external |
| Feel assessment | 긍정("괜찮은데?"). 규칙 가독성(얼굴=스위치)이 v1의 문제 → v2에서 시각화 |
| Hypothesis verdict | PARTIALLY CONFIRMED — 차별성은 인정, "얼굴 위치를 노리는가"는 v2 미리보기 이후 추가 관찰 필요 |

---

## Recommendation: PROCEED

같은 사용자가 매치-3 버전은 "변별력이 없다"고 했고 이 버전은 "괜찮다"고 했다. 차별점(얼굴 능력 도미노)은
원형 장르에 없는 요소로 확인됐다. 단, 얼굴이 스위치라는 규칙은 강조·미리보기 없이는 읽히지 않으므로
**연쇄 미리보기는 본 게임의 필수 기능**으로 가져간다. 외부 플레이테스트로 "얼굴을 노리는가"를 계속 확인한다.

---

## If Proceeding

- **Core tuning values discovered:** 8×8 판, 조각 3개 트레이, 얼굴 1칸/조각, 연쇄 깊이 상한 6, 연쇄 단계당 점수 +50%
- **Assumptions confirmed:** 단순한 드래그 배치 위에 캐릭터 능력 연쇄를 얹으면 원형과 구별된다
- **Assumptions disproved:** "범례 텍스트로 규칙이 전달된다" — 아니다, 보드 위 시각화가 필요
- **Emergent mechanics:** 연쇄 전체 미리보기가 "어디 둘까"를 계획 퍼즐로 바꿈. 삐약(알)처럼 판을 채우는 능력이 연쇄를 다시 점화하는 고리 역할
- **Shared rules simulator:** 미리보기와 실제 처리가 같은 규칙 함수를 써야 예측이 맞는다 → 본 개발에서도 결정적(deterministic) 규칙 모듈 하나로

**Next steps:**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. `/map-systems`
4. `/design-system [mechanic]`

---

## Lessons Learned

- **What assumptions were broken by actually building this?** 규칙 설명은 텍스트가 아니라 보드 위 미리보기로 해야 한다.
- **What surprised us that didn't show up in the brainstorm?** 판을 "채우는" 능력(알)이 지우는 능력만큼 연쇄에 중요하다.
- **What would we test differently next time?** 처음부터 외부 테스터 1명 이상, 그리고 "규칙을 설명 없이 이해하는가"를 첫 질문으로.

---

> *Prototype code location: `prototypes/sticker-place-concept/`*
> *This code is throwaway. Never refactor into production.*
