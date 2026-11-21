# Concept Prototype Report: 말랑 크루 블리츠 (실시간 매치-3 + 크루 스킬)

> **Date**: 2026-11-07
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

60초 블리츠에서 크루 3명의 게이지를 채워 스킬을 터뜨리고 스킬 간 연쇄가 일어나면,
플레이어는 결과 화면에서 곧바로 "한 판 더"를 누른다 — 첫 5분 안에 자발적 재시작 3회 이상,
그리고 "스킬 쓰는 순간이 제일 재밌다"는 반응으로 확인한다.

---

## Riskiest Assumption Tested

캐스케이드 도중 입력을 받는 실시간 보드가 끊김 없이 느껴지는가.
기술적으로는 성립했다(칸 단위 상태로 보드 잠금 없이 동작, 헤드리스 ~60fps, 에러 0).
그러나 플레이테스트에서 드러난 진짜 위험은 기술이 아니라 **차별성**이었다.

---

## Approach

단일 `prototype.html` (캔버스, 인라인 JS). 약 반나절.

**Path chosen:** HTML
**Reason for path:** 폰 브라우저에서 바로 플레이 가능하고, 매치-3는 브라우저 지연에 크게 민감하지 않음.

**Shortcuts taken (intentional):**
- 하드코딩된 수치(게이지 최대치 14/18/12, 점수 공식), 고정 크루 3명
- 캔버스로 그린 스티커 동물(실제 아트 없음), 사운드 없음
- 가챠·수집·팀 편성·스테이지 목표·세이브 없음
- 헤드리스 테스트용 `window.__mc` 훅

---

## Result

- 사용자(1인 플레이테스트) 첫 반응: **"너무…… 다른 게임이랑 변별력이 없네"**
- 크루 연쇄(삐약 → 냥이 → 곰곰)는 **체감됐지만 평범했다.**
  - "고양이부터 차는 것도 아니고 각각 차는 거여서, 연쇄 의미도 적을 때도 있음" — 게이지가 크루별로
    독립적으로 차기 때문에, 순서대로 이어 쓰는 판단이 필요 없는 순간이 많았다.
- **매치-3 바탕 자체가 문제**로 지목됨: 스와이프해서 3개 맞추는 기본 판이 다른 게임과 같아서, 위에 어떤 스킬을 얹어도 다르게 느껴지지 않는다.
- 특별히 살리고 싶은 순간은 꼽지 못함.
- 기술 검증(헤드리스): 콘솔 에러 0, 65초 ~60fps, 스킬·크루 연쇄·결과·재시작·스와이프 동작. 연쇄 카운터 누적 버그 1건 수정.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | N/A |
| Prototype duration | ~반나절 |
| Playtesters | 1 internal (개발자 본인) / 0 external |
| Feel assessment | 조작·성능 문제 지적 없음. "다른 매치-3와 구별되지 않는다"가 핵심 반응 |
| Hypothesis verdict | REFUTED (재미의 근거가 될 차별점이 성립하지 않음) |

---

## Recommendation: PIVOT

스킬 연쇄는 동작하고 체감됐지만, 게이지가 독립적으로 차는 구조라 연쇄의 의미가 약했고,
무엇보다 매치-3 바탕이 기존 게임과 구별되지 않았다. 컨셉의 핵심 욕구 — **많은 캐릭터가
각자의 고유 능력으로 퍼즐을 푼다 + 수집** — 는 유효하지만, 그 능력이 "점수를 더 내는 보너스"가
아니라 **"퍼즐의 해법 그 자체"**가 되는 다른 퍼즐 바탕이 필요하다.

---

## If Pivoting

**Pivot direction:** 매치-3를 버리고, 캐릭터 능력이 곧 해법인 퍼즐 바탕으로 교체.
후보(브레인스토밍 때 나온 것 포함): 능력자 보드(캐릭터 배치형 논리 퍼즐), 릴레이 탈출(소코반 + 캐릭터 교체),
그 외 새 방향.
**What to keep:** 많은 캐릭터·고유 능력, 수집(적당한 가챠: 천장·조각·확률 공개), 스티커북 비주얼,
3인 팀 편성, 짧은 판·즉시 재도전.
**Next step:** `/brainstorm 능력이 곧 해법인 수집형 퍼즐` 로 바탕을 고른 뒤 `/prototype [새 바탕]`

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  "검증된 공식(레퍼런스 게임) 위에 시너지만 얹으면 차별화된다"는 가정이 깨졌다. 바탕 장르가 정체성을 압도한다.
- **What surprised us that didn't show up in the brainstorm?**
  "연쇄"라고 설계했지만, 게이지가 각자 차면 연쇄는 선택이 아니라 우연이 된다.
  연쇄를 차별점으로 쓰려면 앞 크루의 결과가 다음 크루를 **반드시** 움직이게 해야 한다.
- **What would we test differently next time?**
  바탕 메커닉이 다른 게임과 구별되는지부터 확인한다 — 2~3개 바탕을 아주 작게 만들어 나란히 비교.

---

> *Prototype code location: `prototypes/match3-blitz-concept/`*
> *This code is throwaway. Never refactor into production.*
