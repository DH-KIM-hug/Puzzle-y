# 연쇄 미리보기 (Chain Preview)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛

## Summary

조각을 끌고 있는 동안, 앵커가 바뀔 때마다 실제 배치와 똑같은 입력으로 연쇄 해석기 `resolve`를 한 번 불러 그 결과를 판 위에 보여 준다 —
웨이브별 지워질 칸(잉크 점선 + 번지는 박자), 얼굴 위 연쇄 단계 배지, 예상 알, 판 밖 배너 "연쇄 N 예상!". 자체 판정이 없어 "본 것이 그대로
터진다"(기둥 3)를 테스트로 보장하고, 얼굴이 스위치라는 규칙을 설명 없이 가르친다. "가장 큰 숫자 찾기" 퇴화를 막기 위해 **구조는 다 보이고
예상 점수는 기본으로 숨기며**, 다른 자리와 비교하는 도구를 주지 않는다.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `연쇄 해석기 & 능력 프리미티브`, `드래그 & 배치 입력` (Hard), `판 진행 흐름` (ctx 공급), `점수 & 연쇄 배율` (Soft, 노브)

## Overview

연쇄 미리보기는 조각을 끌고 있는 동안 **"여기 놓으면 무슨 일이 일어나는가"를 판 위에 그대로 보여 주는** 시스템이다.
데이터 층에서는 드래그 & 배치 입력의 `anchor_changed(piece, anchor | null)` 신호를 받아, 판 진행 흐름이 실제 배치에 쓸
것과 **똑같은 입력**(보드 스냅샷·조각·앵커·`ctx`, 같은 `rng_seed`)으로 연쇄 해석기의 순수 함수 `resolve`를 한 번 부르고,
그 `ChainResult`를 순수 함수 `build_preview_model`로 **표시 모델**(웨이브별 지워질 칸, 얼굴 위 단계 번호 배지, 예상 알,
요약 배너)로 바꾼 뒤 그린다. 자기만의 판정 로직은 하나도 없다 — 해석기 이벤트에 없는 것은 보여 줄 수 없고, 있는 것을
바꾸어 보여 줄 수도 없다. 플레이어 쪽에서 보면 이 시스템은 "얼굴이 스위치"라는 규칙을 설명 없이 가르치는 선생이자
(프로토타입 교훈: 범례로는 읽히지 않았고 미리보기를 넣자 "아하 얼굴"), "놓기 전에 본 도미노가 그대로 터진다"는 약속 그
자체다 (기둥 3 — 미리보기와 결과가 다르면 버그). 동시에 이 시스템은 "가장 큰 숫자 뜨는 자리 찾기" 퇴화 위험의 1차 방어선
이므로, **무엇이 일어나는지(구조)는 다 보여 주되 그것이 몇 점인지(값)는 기본으로 보여 주지 않는다** (규칙 D).

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No`
(`docs/architecture/adr-*.md` 없음) · Fantasy `[A]`이지만 standard tier라 Player Fantasy 섹션 생략 — 정서 목표는 Game Feel 절.
구현 형태(오버레이를 `CanvasItem._draw` 한 노드로 그릴지 칸별 스프라이트 풀로 그릴지, 캐시 자료구조)는 → ADR 대상.

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` · `art-director` (Section 6 라우팅: Gameplay 중 판 위 시각 피드백 →
> 규칙 + VFX/UI 행의 합집합) not consulted — Lean mode (Section C는 lean에서 생략), 이 실행에는 Agent 도구도 없음. Review manually before production.

### Core Rules

**A. 단일 진실 (Pillar 3 계약)**

1. **같은 함수, 같은 입력** — 미리보기는 chain-resolver `resolve(board, piece, anchor, ctx)`를 부른다. `board`는 판 진행 흐름이
   보유한 현재 안정 보드(드래그 중 불변 — placement-input 규칙 20), `ctx`는 판 진행 흐름이 **이번 배치에 쓸** 값 그대로
   (`crew_abilities`, `rules`, `hooks`, `rng_seed = seed_for(stage_seed, placement_index)` — chain-resolver F7)다. 미리보기가
   `ctx`를 스스로 만들거나 고치지 않는다.
2. **자체 판정 금지** — 미리보기 코드는 줄 완성·능력 범위·알 위치를 계산하지 않는다. board-rules 함수나 프리미티브를 직접
   부르지 않으며(`resolve` 경유만), 근사 경로("1웨이브만 빨리 계산" 등)도 두지 않는다 (chain-resolver 규칙 3).
3. **표시 모델은 순수 함수** — `build_preview_model(result: ChainResult, settings) → PreviewModel`. 렌더링과 분리된 순수 함수라
   단위 테스트로 "보이는 것 = 이벤트"를 증명할 수 있다 (AC). 렌더러는 `PreviewModel`만 그린다.
4. **보이는 것은 모두 이벤트에서 온다** — 표시 요소와 원천 이벤트의 대응은 아래 표가 전부다. 표에 없는 정보(다음 트레이,
   다른 앵커의 결과, "추천 자리")는 표시하지 않는다.

   | 표시 요소 | 원천 (chain-resolver 규칙 19) | 내용 |
   |---|---|---|
   | **지워질 칸 윤곽** | `CELLS_CLEARED.cells[]` (웨이브별) | 칸마다 웨이브 번호 `wave` 보관 — 박자 표시(F4)에 사용 |
   | **단계 배지** | `FACE_ACTIVATED` (`cell`, `stage`) | 얼굴 칸에 `stage` 숫자 (= 그 얼굴이 발동하는 "연쇄 N"의 N) |
   | **졸음 배지** | `FACE_FIZZLED(DEPTH_CAP)` | 숫자 대신 "zz" 아이콘 (상한에서 지워지되 발동 안 함) |
   | **갇힘 배지** | `FACE_FIZZLED(SUPPRESSED)` | 숫자 대신 얼음 조각 아이콘 (아이콘 형태는 방해물 GDD) |
   | **예상 알** | `ABILITY_EFFECT(kind = FILL).cells` | 알 고스트 (낳는 순서대로) |
   | **변형 칸 표시** | `CELL_MODIFIED` | "금 감" 표시 (얼음 겹 벗겨짐 등 — 구체 그림은 방해물 GDD) |
   | **요약 배너** | `CHAIN_END` (`chain_depth`, `cap_reached`) | F3 단계표의 문구 |
   | *(선택)* 예상 점수 | `score_placement(events, rules).total` (scoring 규칙 3) | 기본 **꺼짐** — 규칙 13 |

5. **배지 숫자 = `stage`** — 배지는 연쇄 전체 발동 순번(`order_index`)이 아니라 **그 얼굴이 몇 번째 연쇄 단계에서 발동하는가**
   (`stage` = `wave` + 1)를 보인다. 같은 웨이브의 얼굴들은 같은 숫자를 단다. 그래서 가장 큰 배지 숫자 = 배너의 N이며, 숫자가
   "몇 단 도미노인가"로 읽힌다 (프로토타입 v2 검증 방식). 같은 웨이브 안의 순서(`order_index`)는 숫자로 보이지 않고 연출 재생기의
   발동 간격으로만 보인다 (Decision Log D3 — chain-resolver 규칙 9 문구와의 정리는 Open Question Q1).

**B. 재계산과 캐시**

6. **트리거** — `anchor_changed(piece, anchor)` (anchor ≠ null)를 받을 때만 결과를 갱신한다. 입력 시스템은 **유효 앵커가 바뀐
   프레임에만** 이 신호를 내므로(placement-input 규칙 13) 같은 앵커에 머무는 동안·무효 앵커 사이 이동 동안 `resolve` 호출은 0회다.
   미리보기는 프레임마다 폴링하지 않는다.
7. **동기 1프레임** — 신호를 받은 그 프레임 안에 `resolve` → `build_preview_model` → 표시까지 끝낸다 (F2 예산). 비동기·스레드·
   다음 프레임 지연 표시는 쓰지 않는다 — 고스트(입력 소관, 같은 프레임 갱신)와 미리보기가 한 프레임이라도 어긋나 보이면 안 된다.
8. **결과 캐시** — 결과는 키 (`board_version`, `piece_instance_id`, `anchor`, `rng_seed`)로 최근 `preview_cache_size`(시작값 16)개까지
   LRU 캐시한다 (chain-resolver 규칙 25가 허용). 손가락을 앞뒤로 흔들어 같은 앵커를 다시 밟으면 `resolve` 없이 재표시한다.
   `board_version`이 바뀌면(배치 커밋, 스테이지 시작, 되돌리기 등) 캐시를 전부 비운다. 캐시는 성능 최적화일 뿐이며, 꺼도
   (`preview_cache_size = 0`) 결과는 같아야 한다.
9. **판 진행 흐름은 미리보기 결과를 재사용하지 않는다** — 배치가 커밋되면 판 진행 흐름이 자기 `resolve`를 다시 부른다 (권위 경로).
   디버그 빌드에서는 커밋 직후 판 진행 흐름의 `ChainResult`와 미리보기가 **마지막으로 표시한** 결과의 `board_hash`·이벤트 목록을
   비교해, 다르면 `PREVIEW_MISMATCH` assert를 낸다 (기둥 3 위반 = 버그; 출시 빌드는 오류 로그만).

**C. 표시 생명주기**

10. **표시 시작** — 유효 앵커 결과가 준비된 프레임에 모든 요소를 한 번에 보인다(요소별 순차 등장 없음 — 읽기용 정보이지 연출이
    아니다). 이전 앵커의 표시는 같은 프레임에 교체된다(교차 페이드 없음 — 잔상이 "두 자리의 결과"를 섞어 보이게 함).
11. **지우기** — `anchor_changed(piece, null)`, `drag_ended(RETURNED | CANCELLED)`, 입력 `LOCKED` 전이에서 **즉시** 지운다.
    `drag_ended(COMMITTED)`에서는 조각이 고스트 자리에 붙는 시간(placement-input 규칙 15, 0.06s) 동안 페이드아웃하고 사라진다 —
    이어지는 연쇄 연출이 같은 칸·같은 순서를 재생하므로 "본 것이 그대로 터진다"가 이어서 읽힌다.
12. **상태 없음** — 미리보기는 보드·점수·트레이·기록 어느 것도 바꾸지 않는다. `ScoreBreakdown`을 만들었다면 버린다
    (scoring States 절). 지운 뒤 남기는 것은 캐시뿐이다.

**D. 정보량 — "가장 큰 숫자 찾기" 퇴화 방지**

컨셉 Design Risks: *"미리보기가 너무 친절하면 퍼즐이 '최고 숫자 뜨는 자리 찾기'로 단순해질 수 있다."* 이 시스템의 방침은
**"구조는 보이고, 값은 숨긴다"** — 플레이어가 *어떻게* 번지는지를 보고 스스로 가치를 판단하게 한다.

13. **예상 점수는 기본으로 표시하지 않는다** (`show_predicted_score = false`). 웨이브별 점수도 보이지 않는다. 점수는 놓은 뒤 연출에서
    "+N"으로 처음 보인다 (연출 재생기·HUD 소관) — 결과가 "보상"으로 남는다. 스테이지 데이터가 켜면(예: 점수 목표 튜토리얼 스테이지)
    scoring의 `score_placement`를 같은 이벤트에 적용한 **총점 한 줄**("+401 예상")만 보인다 — 근사·별도 계산 금지 (scoring 규칙 3, D8).
14. **비교 도구를 주지 않는다** — 다른 앵커의 결과를 동시에 보이지 않는다(히트맵·최적 자리 강조·"추천" 없음), 들고 있지 않은 트레이
    조각의 미리보기 없음, 다음 트레이·다음 배치 결과 없음. 비교는 플레이어가 손가락을 옮겨 가며 **기억으로** 한다.
15. **배너의 숫자는 연쇄 단계뿐** — 배너는 `chain_depth`(최대 `depth_cap` = 6)만 말한다. 지운 칸 수·줄 수·배율은 말하지 않는다.
    `chain_depth`는 스테이지 목표 "연쇄 N"의 단위라 목표와 같은 언어이고, 상한이 낮아(6) 숫자 경쟁이 빨리 포화한다.
16. **트레이드오프는 목표가 만든다** — 미리보기는 "최대 연쇄"를 강조하지 않는다(상한 도달 문구도 축하 톤일 뿐 "최고!" 순위 표시가
    아님). 스테이지 & 목표가 특정 칸·방해물·연쇄 N·제한 조각 수로 "가장 큰 연쇄 ≠ 가장 좋은 수"를 만든다 (컨셉 완화책). 목표 관련
    표시(예: 목표 칸이 지워질 칸에 들면 목표 칸 표식 강조)는 스테이지 GDD가 정할 **훅** `goal_markers(result) → cells`로만 추가한다
    — 미리보기가 목표를 판정하지 않는다 (Open Question Q2).
17. **정보량은 데이터 노브** — `preview_detail` ∈ {`FULL`(기본), `NO_BANNER`, `FIRST_STAGE_ONLY`}. `FIRST_STAGE_ONLY`는 웨이브 0과
    stage 1 배지만 보이고 그 뒤는 "…" 배지(다음이 더 있음)로 가린다 — **거짓 정보는 절대 보이지 않으며 숨긴 사실은 숨겼다고 표시한다**
    (기둥 3). MVP 출시 스테이지는 모두 `FULL`; 나머지 값은 외부 플레이테스트에서 "숫자만 쫓는가"를 비교하기 위한 실험 노브다.

**E. 판 위 가독성 (8×8, 세로 폰)**

18. **레이어 순서** (아래 → 위): 판 종이 → 붙은 스티커 → **지워질 칸 윤곽** → 고스트(입력 소관, 35%) → 끌리는 조각(입력 소관) →
    **예상 알** → **배지** → **배너**. 배지와 알이 끌리는 조각 *위*에 그려져, 들고 있는 조각 자신의 얼굴 배지(웨이브 0 발동)도 가려지지
    않는다.
19. **색에 기대지 않는다** (art bible 4절 색약 안전) — 지워질 칸은 크루 색 틴트가 아니라 **잉크 점선 윤곽 + 스티커 "들썩" 그림자
    (1→3px)**로 표시한다. 배지는 잉크 원 + 스티커 백 숫자, 알 고스트는 얼굴 크림 바탕 + 잉크 점선. 크루 색은 미리보기에 쓰지 않는다
    (프로토타입의 크루 색 틴트·노랑 점선은 교체 — art bible 지시).
20. **웨이브 박자는 움직임으로** — 웨이브 k의 윤곽은 `wave_pulse_period_s`(0.9s) 주기로 살짝 숨 쉬며, 위상이 웨이브마다
    `wave_pulse_stagger_s`(0.12s)씩 늦다 (F4). 결과: 판 위에 "0 → 1 → 2" 순서의 물결이 반복되어 숫자를 읽지 않아도 번지는 방향이
    보인다. 모션 줄이기 설정이면 정지 표시 — 순서는 배지 숫자만으로 읽힌다(정보 손실 없음).
21. **크기 하한** — 배지 지름·숫자 크기·윤곽 두께는 칸 크기 `s`에 비례하되 하한을 둔다 (F1). 1080px 폭(`s` ≈ 130px) 기준 배지 지름 52px,
    최소 칸(`s` = 64px)에서도 32 px@1080 이상.
22. **배지 위치** — 얼굴 칸 우상단 모서리(칸 중심에서 (+0.32s, −0.32s))에 중심을 둔다. 얼굴 이목구비(칸 중앙)를 가리지 않는다
    (art bible 원칙 2 "얼굴이 주인공"). 배지가 판 밖으로 나가면(맨 위 행·맨 오른쪽 열) 칸 안쪽으로 밀어 넣는다(F1 클램프).
23. **배너 자리** — 배너는 판 **위쪽 바깥**, HUD와 판 사이의 고정 띠(`banner_band`)에 그린다. 판 칸을 덮지 않는다 — 맨 위 행에 놓을 때
    끌리는 조각·배지와 겹치지 않기 위함 (프로토타입은 판 첫 행 위에 그렸음 — 교체).

### States and Transitions

미리보기 자체 상태는 둘뿐이다 (결과는 동기로 즉시 나오므로 "계산 중" 상태가 없다).

| 상태 | 의미 | 들어오는 조건 | 나가는 전이 |
|---|---|---|---|
| `HIDDEN` | 아무것도 그리지 않음 | 시작; `anchor_changed(null)`; `drag_ended(RETURNED \| CANCELLED)`; 입력 `LOCKED`; 커밋 페이드아웃 끝 | `anchor_changed(piece, a)` → (캐시 조회 / `resolve`) → `SHOWING(a)` |
| `SHOWING(a)` | 앵커 `a`의 `PreviewModel` 표시 | `HIDDEN` 또는 다른 `SHOWING`에서 유효 앵커 신호 | 다른 앵커 신호 → `SHOWING(a')` (같은 프레임 교체); 무효/종료 신호 → `HIDDEN`; `drag_ended(COMMITTED)` → 0.06s 페이드 → `HIDDEN` |

`board_version` 변경은 상태 전이가 아니라 캐시 비우기다. 드래그 중에는 보드가 바뀌지 않으므로(placement-input 규칙 20) `SHOWING` 중
`board_version`이 바뀌면 프로그래밍 오류 — 디버그 assert 후 `HIDDEN`.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 드래그 & 배치 입력 | 입력 → 미리보기 | `anchor_changed(piece_ref, anchor \| null)`, `drag_ended(reason)`; 끌리는 조각의 레이어(규칙 18 순서 요구) | 입력 GDD (신호) / 이 문서 (표시) |
| 연쇄 해석기 | 미리보기 → 해석기 | `resolve` 호출 → `ChainResult` (`events`, `summary`) | 해석기 (결과·이벤트 스키마) |
| 판 진행 흐름 | 판 흐름 → 미리보기 | 현재 보드 스냅샷·`board_version`, 이번 배치의 `ctx`(`rng_seed` 포함); 커밋 후 권위 `ChainResult` (디버그 비교, 규칙 9) | 판 진행 흐름 (`ctx` 파생) |
| 점수 & 연쇄 배율 | 미리보기 → 점수 (노브가 켜졌을 때만) | `score_placement(events, rules).total` | 점수 GDD (값) / 이 문서 (표시 여부) |
| 스테이지 & 목표 | 스테이지 → 미리보기 | `preview_detail`, `show_predicted_score` 스테이지별 값; (선택) `goal_markers` 훅 | 스테이지 GDD (데이터·목표 판정) |
| 크루 정의 & 능력 | 간접 (해석기 경유) | 없음 — 미리보기는 크루별 분기 없음. 새 크루 능력은 이벤트만으로 표시 가능해야 한다 (크루 GDD 수용 기준) | 크루 GDD |
| 칸 종류 & 방해물 | 간접 (해석기 경유) | `CELL_MODIFIED`, `FACE_FIZZLED(SUPPRESSED)` 표시용 아이콘 | 방해물 GDD (아이콘) |
| 연쇄 연출 재생기 | 미리보기 → 연출 (시각 연속성) | 같은 칸·같은 단계 번호를 연출이 재생; 커밋 시 미리보기 페이드아웃과 연출 시작이 겹침 | 연출 GDD |
| 플랫폼 & 화면 | 플랫폼 → 미리보기 | 칸 크기 `s`, 판 사각형, `banner_band` 사각형 | 플랫폼 & 화면 GDD |
| 설정 & 접근성 (VS) | 설정 → 미리보기 | 모션 줄이기(규칙 20), (후보) 배지 크게 | 설정 GDD |
| 튜토리얼 & 힌트 (VS) | 미리보기 → 튜토리얼 | 첫 `SHOWING` 중 `chain_depth ≥ 1` 순간 (첫 "얼굴 = 스위치" 안내 타이밍) | 튜토리얼 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. 모든 크기 값은 placement-input F5의 `px@1080` 단위, 칸 크기 `s`는 board-rules UI Requirements를 따른다.

**F1. 배지 크기와 위치**

The badge_size formula is defined as:

`badge_d = max(badge_scale × s, badge_min_px × k_px)` · `numeral_px = 0.7 × badge_d` · `badge_center = clamp(cell_center + (0.32s, −0.32s), cell_rect ⊖ badge_d/2)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| s | float | 64–135 px | calculated (board-rules UI Req: 보드 폭 / 8) | 화면상 칸 한 변 |
| badge_scale | float | 0.32–0.48 | data file (시작 0.40) | 칸 대비 배지 지름 |
| badge_min_px | int | 28–40 | data file (시작 32) | 배지 지름 하한 (px@1080) |
| k_px | float | 0.67–1.33 | calculated (placement-input F5: 화면 폭 / 1080) | 기준 px → 실제 px |
| cell_rect ⊖ r | rect | — | calculated | 칸 사각형을 r만큼 안쪽으로 줄인 영역 (배지가 판 밖으로 안 나가게) |

**Output Range:** 1080 폭(`s` ≈ 130): `badge_d` = 52px, 숫자 36px. 최소 칸(`s` = 64): `max(25.6, 32)` = 32px, 숫자 22px — 폰 화면에서
약 3.5mm 숫자로 판독 가능선. `badge_d`는 칸의 50%를 넘지 않는다(`s` ≥ 64에서 32/64 = 0.5) — 얼굴 이목구비 가림 방지.
**Example:** 720px 폭 기기: `k_px` = 0.667, 보드 폭 688 → `s` = 86, `badge_d = max(34.4, 21.3)` = 34.4px, 숫자 24px.

**F2. 앵커 변경 프레임 비용 (성능 예산)**

The preview_frame_cost formula is defined as:

`t_preview = hit × t_cache + (1 − hit) × (t_resolve + t_score × show_score) + t_model + t_draw(n_elem)` ≤ `preview_budget_ms`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| hit | int | 0–1 | calculated | 캐시 적중 여부 (규칙 8) |
| t_cache | float ms | ≈ 0.01 | calculated | 캐시 조회 |
| t_resolve | float ms | ≤ 1 (데스크톱 headless) | calculated (chain-resolver F8·AC-17) | 해석 1회 |
| t_score | float ms | ≤ 0.1 | calculated (scoring AC-S14) | 채점 1회 |
| show_score | int | 0–1 | data file (`show_predicted_score`, 기본 0) | 예상 점수 노브 |
| t_model | float ms | ≤ 0.2 | calculated | `build_preview_model` (이벤트 선형 순회) |
| t_draw(n_elem) | float ms | — | calculated | 표시 요소 `n_elem`(F5) 갱신·그리기 |
| preview_budget_ms | float | 2–6 | data file (시작 4.0) | 저가 Android 실기기에서 미리보기 몫 상한 |

**Output Range:** 데스크톱 headless 목표 `t_resolve + t_model` ≤ 1.2ms. 저가 Android(T0 그레이박스 측정) 목표 `t_preview` ≤ 4ms —
16.7ms 프레임에서 입력·고스트·나머지 렌더에 12ms 이상을 남긴다. 앵커가 바뀌지 않는 프레임의 미리보기 비용 = 박자 애니메이션(F4)
갱신뿐, ≤ 0.5ms. 측정 전 수치이므로 T0에서 실측해 갱신한다.
**Example:** 연쇄 3, 캐시 미스, 점수 꺼짐: 0.6 + 0.1 + 그리기(요소 30개) ≈ 1ms (데스크톱 추정).

**F3. 배너 단계표**

The banner_tier formula is defined as:

`banner(result) = NONE if chain_depth = 0 · ABILITY if chain_depth = 1 · CHAIN(N) if 2 ≤ chain_depth ∧ ¬cap_reached · CHAIN_MAX(N) if cap_reached`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| chain_depth | int | 0–6 | calculated (`CHAIN_END`, chain-resolver F2 / registry `chain_depth`) | 얼굴이 발동한 웨이브 수 |
| cap_reached | bool | — | calculated (`CHAIN_END`) | 깊이 상한 도달 |

**Output Range:** 문구(현지화 키, HUD/UI 문자열 소유): `NONE` → 배너 없음(줄만 지우는 배치 — 윤곽만 보임), `ABILITY` → "능력 발동!",
`CHAIN(N)` → "연쇄 N 예상!", `CHAIN_MAX(N)` → "연쇄 N 예상! 최대!" (N = `depth_cap`). `preview_detail = NO_BANNER`이면 항상 `NONE`.
**Example:** 냥이 → 곰곰 → (줄) 3단: `chain_depth = 3`, 상한 6 미도달 → "연쇄 3 예상!".

**F4. 웨이브 박자 위상**

The wave_pulse formula is defined as:

`lift_px(k, t) = lift_base_px + lift_amp_px × ½(1 − cos(2π × (t − k × stagger) / period))` (모션 줄이기면 `lift_amp_px = 0`)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0–6 | calculated (`CELLS_CLEARED.wave`) | 칸이 지워질 웨이브 |
| t | float s | ≥ 0 | calculated | `SHOWING` 진입 후 경과 시간 (앵커가 바뀌면 0부터) |
| lift_base_px | float | 1–3 | data file (시작 2) | 정지 시 "들썩" 그림자 오프셋 (art bible 원칙 3: 붙음 1–2px) |
| lift_amp_px | float | 0–3 | data file (시작 2) | 숨쉬기 진폭 — 최대 4px로 드래그 그림자(6–10px)보다 낮게 |
| stagger | float s | 0.08–0.2 | data file (`wave_pulse_stagger_s`, 시작 0.12) | 웨이브 간 위상 지연 |
| period | float s | 0.6–1.5 | data file (`wave_pulse_period_s`, 시작 0.9) | 한 주기 |

**Output Range:** 2–4px. 웨이브 6까지의 위상 지연 합 0.72s < period 0.9s라 한 주기 안에 0→6 물결이 다 보인다 (`depth_cap × stagger < period`
제약 — 데이터 검증). 그림자 오프셋만 바꾸므로 셰이더 비용 없음 (art bible: 미리 블러한 실루엣 스프라이트).
**Example:** t = 0.12s: 웨이브 0 칸은 상승 중(≈ 2.3px), 웨이브 1 칸은 막 시작(2px) — 0에서 1로 번지는 것이 보인다.

**F5. 표시 요소 수 상한**

The overlay_elements formula is defined as:

`n_elem = |∪ CELLS_CLEARED.cells| + n_activated + n_fizzled + n_eggs + n_modified + 1` ≤ `W × H + F_board + E_max + W × H + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| \|∪ cells\| | int | 0–64 | calculated | 지워질 칸 (칸은 연쇄 전체에서 한 번만 지워짐 — chain-resolver AC-12) |
| n_activated + n_fizzled | int | 0–F_board | calculated | 배지 수 ≤ 보드 위 얼굴 수 |
| n_eggs | int | 0–`eggs_laid` | calculated (`CHAIN_END.eggs_laid`) | 알 고스트 |
| n_modified | int | 0–64 | calculated | 변형 칸 (MVP 방해물 없으면 0) |
| W, H | int | 8 | constant (registry `board_width`/`board_height`) | 판 크기 |

**Output Range:** 실전 근사 최악 ≈ 64 + 12 + 12 + 0 + 1 ≈ 90 요소. 렌더러는 요소 풀을 128개로 미리 잡아(재할당 없음) 이 상한을 덮는다.
**Example:** 연쇄 3 (칸 30, 얼굴 4, 알 3, 배너 1) → 38 요소.

**F6. 드래그 한 번의 `resolve` 호출 수**

The preview_resolve_calls formula is defined as:

`resolve_calls(drag) = preview_requests(drag) − cache_hits(drag)` ≤ `min(preview_requests(drag), anchor_count)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| preview_requests | int | 0–∞ | calculated (placement-input F7) | 유효 앵커가 바뀐 프레임 수 |
| cache_hits | int | 0–preview_requests | calculated | 캐시에서 꺼낸 횟수 |
| anchor_count | int | 1–64 | calculated (board-rules F1; 2×3 조각 42) | 이 조각의 서로 다른 앵커 수 |
| preview_cache_size | int | 0–64 | data file (시작 16) | LRU 용량 |

**Output Range:** `preview_cache_size ≥ anchor_count`이면 드래그 한 번에 앵커당 최대 1회. 시작값 16은 앞뒤 흔들기를 덮고, 메모리는
결과 16개 × (이벤트 ≲ 100개) — 무시할 수준. 캐시 0이면 `resolve_calls = preview_requests`.
**Example:** (3,2)→(3,3)→(3,2)→(3,3) 4회 요청, 캐시 16 → `resolve` 2회.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 유효 앵커에서 줄이 하나도 완성되지 않으면** (`chain_depth = 0`, `waves = 0`): 고스트만 보이고 미리보기 요소는 없다 (`SHOWING`이지만 빈 모델).
  "아무 일 없음"도 정확한 미리보기다.
- **If 줄만 지워지고 얼굴이 없으면**: 웨이브 0 윤곽만, 배지·배너 없음 (F3 `NONE`). 일반 블록 퍼즐과 같은 화면 — 얼굴의 가치가 대비로 보인다.
- **If 들고 있는 조각 자신의 얼굴이 웨이브 0에서 지워지면**: 그 얼굴 칸(고스트 위)에 배지 1이 끌리는 조각보다 위 레이어로 보인다 (규칙 18).
- **If 같은 웨이브에서 얼굴 여러 개가 발동하면**: 모두 같은 숫자 배지 (규칙 5). 발동 간 순서는 연출에서만 보인다.
- **If 깊이 상한에서 얼굴이 피즐하면**: 그 얼굴은 "zz" 배지, 배너는 `CHAIN_MAX` ("최대!"). 숫자 배지를 달지 않는다 — 발동하지 않는 얼굴에 숫자가 붙으면 거짓이다.
- **If 얼어붙은 얼굴(`SUPPRESSED`)이 지워지면**: 얼음 배지. 그 웨이브에 발동이 없으면 배너는 직전 `chain_depth` 기준 (해석기 계산 그대로).
- **If 알이 줄을 완성해 재점화하면**: 알 고스트가 보이고, 그 줄의 칸은 다음 웨이브 윤곽(다음 박자)으로, 그 줄의 얼굴은 다음 숫자 배지로 보인다 — 인과가 알 → 줄 → 얼굴 순서로 읽힌다.
- **If 예상 알이 이후 웨이브에서 다시 지워지면**: 알 고스트 위에 그 웨이브의 윤곽이 겹쳐 그려진다 (둘 다 사실).
- **If 같은 칸이 두 이유로 대상이 되면** (`by = BOTH`): 윤곽은 한 번, 웨이브 번호는 그 칸이 실제로 지워지는 웨이브 하나 (칸은 한 번만 지워짐).
- **If 손가락·끌리는 조각이 일부 배지를 가리면** (조각 아래 행의 얼굴): 배지는 조각 위에 그려지므로 조각에는 가리지 않는다. 손가락에 가린 배지는
  막을 수 없다 — 배너가 요약(N)을 항상 판 밖에 보여 주므로 정보는 남는다. 손가락은 조각 아래 0.6칸이라 가리는 범위는 대개 조각 바로 아래 1행이다.
- **If 앵커가 같은 프레임에 여러 번 바뀌면** (빠른 스와이프로 이동 이벤트가 몰림): 입력은 마지막 이동의 앵커만 확정한다 — 미리보기는 그 프레임의 마지막
  `anchor_changed`만 처리한다 (한 프레임에 `resolve` 최대 1회). 중간 앵커는 그리지 않는다.
- **If 빠르게 쓸어 지나가 유효 앵커마다 1프레임씩만 머물면**: 매 프레임 정확한 결과를 그린다(디바운스 없음 — 고스트와 1프레임 어긋남 금지, 규칙 7). 비용은 F2 예산 안.
- **If 놓기 직전 마지막 앵커의 결과가 캐시에서 왔으면**: 판 진행 흐름은 독립으로 `resolve`한다 (규칙 9). 캐시 키에 `board_version`·`rng_seed`가 있어 오래된 결과가 보일 수 없다.
- **If 커밋 결과가 마지막 미리보기와 다르면**: 버그 (기둥 3). 디버그 `PREVIEW_MISMATCH` assert, 출시 빌드는 오류 로그 + 결과는 판 진행 흐름 쪽(권위)으로 진행. 원인 후보:
  `ctx` 불일치(다른 `rng_seed`·`hooks`), 드래그 중 보드 변경, 캐시 키 누락 — 모두 AC-P02/P05가 막는다.
- **If 드래그 중 보드가 바뀌면** (규칙 위반): 디버그 assert, 캐시 비우고 `HIDDEN`. 다음 `anchor_changed`부터 새 보드로.
- **If 미리보기 결과가 매우 크면** (연쇄 6, 보드 대부분이 지워짐): 윤곽 64칸 + 배지 ≤ 얼굴 수. 박자 물결 덕에 덩어리로 보이지 않는다. 요소 풀 128개 안 (F5).
- **If 모션 줄이기가 켜져 있으면**: 박자 물결 정지, 커밋 페이드 0s. 웨이브 순서는 배지 숫자로만 — 정보 손실 없음.
- **If `preview_detail = FIRST_STAGE_ONLY`이면**: 웨이브 0 윤곽과 stage 1 배지만, stage ≥ 2 얼굴은 "…" 배지, 이후 웨이브 윤곽·알은 숨김, 배너는 "능력 발동!"까지만.
  숨겼다는 사실("…")은 반드시 보인다 — 숨긴 부분을 "없음"으로 오해시키면 기둥 3 위반.
- **If 플레이어가 모든 자리를 쓸어 보며 최대 연쇄를 찾으면** (퇴화 전략 후보): 금지하지 않는다 — 계획 퍼즐의 정상 행동이다. 다만 비교 도구가 없고(규칙 14),
  점수가 숨겨져 있고(규칙 13), 목표가 최대 연쇄와 엇갈리게 설계되므로(규칙 16) "가장 큰 N = 정답"이 아니다. 실제로 숫자만 쫓는지는 외부 플레이테스트로 확인 (Q3).
- **If 화면이 작아 `s` < 64px가 되면**: board-rules가 64px 하한을 보장한다. F1 하한(32 px@1080)으로 배지는 그래도 읽힌다.
- **If 배지가 맨 위 행·맨 오른쪽 열 얼굴에 붙으면**: F1 클램프로 칸 안쪽으로 밀어 넣는다 — 판 밖(배너 띠·HUD)과 겹치지 않는다.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 (`chain-resolver.md`) | **Hard** | `resolve`, 이벤트 스키마(규칙 19), `CHAIN_END` 요약, 캐시 허용(규칙 25), 표시 정보 위임(규칙 26) | Designed — 일치 (배지 숫자 정의만 Q1) |
| 드래그 & 배치 입력 (`placement-input.md`) | **Hard** | `anchor_changed(piece_ref, anchor\|null)`, `drag_ended(reason)`, 고스트·끌리는 조각 레이어, 드래그 중 보드 불변(규칙 20) | Designed — 일치 |
| 판 진행 흐름 (`round-flow.md`) | **Hard** (데이터 공급) | 보드 스냅샷·`board_version`, 이번 배치의 `ctx`(`rng_seed`), 커밋 후 권위 결과(디버그 비교) | 미작성 — provisional 계약 (규칙 1·9) |
| 점수 & 연쇄 배율 (`scoring.md`) | **Soft** (노브 켜짐 시) | `score_placement` 동일 호출 → `total` | Designed — 일치 (scoring D8 "총점 한 줄" 권장 → 이 문서는 기본 꺼짐, 켜면 총점 한 줄) |
| 플랫폼 & 화면 (`platform-display.md`) | Soft | 칸 크기 `s`, 판·`banner_band` 사각형, `k_px` | 미작성 |
| 스테이지 & 목표 (`stage-goals.md`) | Soft | `preview_detail`, `show_predicted_score` 스테이지 값, `goal_markers` 훅 | 미작성 — provisional |
| 칸 종류 & 방해물 (`obstacles.md`) | Soft | `SUPPRESSED`·`CELL_MODIFIED` 아이콘 | 미작성 |
| 설정 & 접근성 (VS) | Soft | 모션 줄이기 | 미작성 |

**Downstream (이 시스템에 의존)**

| 시스템 | 강도 | 쓰는 것 |
|---|---|---|
| 크루 정의 & 능력 (`crew-definition.md`) | 수용 기준 | "모든 능력은 이 미리보기 어휘(윤곽·배지·알·변형 표시)로 정확히 보인다" — 새 표시 요소가 필요한 능력은 이 문서 개정 필요 |
| 연쇄 연출 재생기 (`chain-presentation.md`) | Soft | 미리보기와 같은 칸·같은 단계 번호를 재생해 시각 연속성 유지 |
| 튜토리얼 & 힌트 (VS) | Soft | 첫 `chain_depth ≥ 1` 미리보기 순간 |
| 플레이 HUD | Soft | `banner_band` 공유 (HUD는 드래그 중 그 띠를 비워 둔다) |

**양방향성**: chain-resolver Dependencies(Downstream)에 `chain-preview.md`가 Hard로 있음(일치). placement-input Dependencies에 `chain-preview.md`
Hard downstream 있음(일치). systems-index #8 Depends On = 연쇄 해석기, 드래그 & 배치 입력 (일치). **누락 2건** — (1) 판 진행 흐름은 미리보기에
`ctx`를 공급하는데 index #8 Depends On에 없다; 의존 방향은 placement-input과 같은 패턴(판 흐름이 미리보기에 데이터를 *주입*)으로 보아
**판 흐름 → 미리보기**로 고정하고, 판 진행 흐름 #11 Depends On에 연쇄 미리보기를 추가할 것을 제안한다. (2) 점수는 노브가 켜질 때만 쓰는
Soft 의존 — scoring Q5의 제안대로 index #8 Depends On에 "점수 (Soft)" 추가 권장. 둘 다 Open Question Q4 (`/map-systems` 소관).

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — 플레이어가 읽고 두는 판 위 시각 피드백이 이 시스템의 전부라 lean에서도 spawn 대상이지만
> 이 실행에는 Agent 도구가 없어 생략. Art bible 1·3·4절 기준으로 작성. Review manually before production.

| 요소 | 그림 | 근거 |
|---|---|---|
| 지워질 칸 | 칸 안쪽 6% 인셋 **잉크 점선 윤곽**(불투명 70%, 대시 0.12·간격 0.08 — 칸 한 변 비율) + 스티커 접지 그림자 2→4px "들썩" 숨쉬기 (F4). 크루 색 틴트 없음 | art bible 원칙 3 (상태 = 그림자 높이), 4절 (점선은 잉크) |
| 단계 배지 | 잉크 `#3b2f25` 원 + 스티커 백 `#fffdf8` 숫자, 흰 여백 테두리 2px(스티커 문법), 낮은 그림자 1px. 둥근 손글씨 숫자 폰트(프로토타입 Jua 계열) | art bible 4절 "번호 배지 = 잉크 원 + 스티커 백 숫자" |
| 졸음 / 갇힘 배지 | 같은 잉크 원 안에 "zz" / 얼음 조각 아이콘 (얼음 회색 `#b9c3c9`는 아이콘 안에만) | 기둥 5 (실패가 아니라 귀여운 마무리), art bible 방해물 색 |
| 예상 알 | 얼굴 크림 `#fbf1d6` 타원 55% + 잉크 점선 테두리. 모두 같은 프레임에 표시 (낳는 순서는 모델에만 보관 — 연출이 사용) | art bible 4절 "예상 칸은 얼굴 크림 + 점선", 프로토타입 v2 |
| 요약 배너 | 판 위쪽 띠에 스티커 라벨(흰 여백 + 그림자) 위 잉크 글씨 "연쇄 N 예상!", N만 금색 `#ffe278` 하이라이트 위 잉크 숫자. `CHAIN_MAX`는 금박 별 1개 추가 | art bible 4절 "금색 = 연쇄 단계 숫자 하이라이트", 원칙 1 (UI도 스티커) |
| 금지 | 네온 글로우·빨간 경고·크루 색 틴트·홀로그램(판 위 반짝임은 얼굴 칸 전용) | art bible 회피 목록, 원칙 4 |
| 오디오 | 미리보기는 소리를 내지 않는다 — 앵커가 바뀔 때마다 소리가 나면 쓸어 보기가 시끄러워진다. 유효 앵커 진입 "톡"은 입력 GDD 소관. **예외 후보**: `chain_depth ≥ 2`가 처음 보일 때 아주 작은 기대감 큐(VS, 오디오 GDD) | 컨셉 Audio Needs, 입력 GDD V/A |

**Godot 4.7 주의 (engine reference)**: `CanvasItem` 선 그리기에 안티앨리어싱 페더가 더 이상 붙지 않아 선이 가늘어 보인다
(`docs/engine-reference/godot/breaking-changes.md` Rendering). 점선 윤곽을 `draw_dashed_line`으로 그린다면 두께를 F1처럼 `s`에 비례
(시작값 0.035s, 최소 3 px@1080)로 잡고 실기기에서 확인한다. 미리 구운 점선 9-슬라이스 텍스처도 대안 — ADR에서 결정.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:chain-preview`
to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

| 목표 | 기준 | 소유 |
|---|---|---|
| 같은 프레임 | 앵커가 바뀐 프레임에 고스트와 미리보기가 함께 바뀐다 — 미리보기 지연 0프레임 (규칙 7, F2) | 이 문서 |
| 깜빡임 없음 | 경계 떨림으로 미리보기가 깜빡이지 않는다 (입력 히스테리시스 0.24칸 띠 + 같은 앵커 재계산 0회) | 입력 GDD (F3) / 이 문서 (규칙 6) |
| 한눈에 요약 | 드래그 중 0.5초 안에 "몇 단 연쇄인가"를 배너로, "어느 얼굴이 몇 번째인가"를 배지로 읽는다 | 이 문서 (AC-P12 플레이테스트 관찰) |
| 번지는 방향 | 숫자를 읽지 않아도 박자 물결로 0 → 1 → 2 번짐이 보인다 (F4) | 이 문서 |
| 본 것이 터진다 | 놓은 뒤 연출이 미리보기와 같은 칸·같은 단계 번호·같은 알 자리를 재생한다 — "아하"가 "역시!"로 이어진다 | 이 문서 (규칙 9·11) / 연출 GDD |
| 쓸어 보기 즐거움 | 손가락을 옮길 때마다 판이 "다른 미래"를 조용히 보여 준다 — 소리·흔들림 없이 정보만 (오디오 행) | 이 문서 |
| 보상은 놓은 뒤 | 점수 숫자는 놓은 뒤 처음 보인다 (규칙 13) — 미리보기는 계획, 연출은 보상 | 이 문서 / HUD·연출 GDD |

턴 기반이라 시간 압박 피드백은 없다 (안티 기둥).

## UI Requirements

- **배너 띠 `banner_band`**: HUD와 판 사이 고정 높이 띠(시작값 0.6s). 드래그 중에만 미리보기가 쓰고, 평소에는 HUD가 비워 둔다(겹침 금지).
  레이아웃·세이프 영역은 플랫폼 & 화면 GDD와 게임플레이 화면 UX 스펙이 확정한다.
- **문자열**: `preview.banner.ability` ("능력 발동!"), `preview.banner.chain` ("연쇄 {n} 예상!"), `preview.banner.chain_max` ("연쇄 {n} 예상! 최대!"),
  `preview.score` ("+{points} 예상" — 노브 켜짐 시). 숫자는 로캘 형식. 배너 폭은 최장 로캘 문자열 + 여백 기준, 넘치면 글자 크기 85%까지 줄인다.
- **판독성**: 배지 숫자 ≥ 22 px@1080 (F1), 배너 글자 ≥ 0.45s. 잉크/스티커 백 대비 ≥ 11:1 (art bible 대비표, 잉크/얼굴 크림 11.9:1 수준).
- **접근성 (MVP)**: 색만으로 정보를 주지 않는다(윤곽·숫자·아이콘·움직임); 모션 줄이기 시 정지 표시; 소리 없음 — 청각 정보 의존 없음.
  (VS 설정 후보: 배지 크게 `badge_scale` 0.48, 미리보기 끄기는 두지 않는다 — 기둥 3의 핵심 기능이자 규칙 학습 수단.)
- **입력 없음**: 미리보기 요소는 터치를 받지 않는다 (드래그 포인터를 가로채지 않음).

> **📌 UX Flag — 연쇄 미리보기**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the
> gameplay screen (board + `banner_band` + tray + HUD) **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`,
> not the GDD directly. (board-rules·placement-input UX Flag와 같은 화면 스펙에 포함)

## Cross-References

| 이 문서가 참조하는 것 | 대상 문서 | 종류 | 상태 |
|---|---|---|---|
| `resolve` 계약·순수성·단일 구현(규칙 1–3), 이벤트 스키마(규칙 19), 캐시·앵커 변경 시 재계산(규칙 25), 표시 정보량 위임(규칙 26), `order_index`·`stage` 정의(규칙 9, `FACE_ACTIVATED`), F7 `rng_seed`, F8 비용, AC-14·16·17 | `design/gdd/chain-resolver.md` | 상위 계약 | 일치 — 배지 숫자를 `stage`로 쓰는 점만 규칙 9 문구와 정리 필요 (Q1) |
| `anchor_changed`·`drag_ended` 신호(규칙 13·19), 고스트 유효 시만·35%(규칙 12, V/A), 놓을 앵커 = 마지막 보인 앵커(규칙 14), 드래그 중 보드 불변(규칙 20), 커밋 스냅 0.06s(규칙 15), F5 `px@1080`, F7 | `design/gdd/placement-input.md` | 상위 계약 | 일치 |
| `score_placement` 단일 구현(규칙 3), 미리보기 상태 없음(States), D8 총점 한 줄 권장, AC-S12 | `design/gdd/scoring.md` | 상위 계약 (Soft) | 일치 — 기본 꺼짐은 scoring UI Req (3)이 이 문서에 위임한 결정 |
| 칸 크기 ≈ 130px@1080·최소 64px (UI Req), `anchor_count` (F1) | `design/gdd/board-rules.md` | 상위 계약 | 일치 |
| 기둥 3 "미리보기 ≠ 결과면 버그", Design Risk "최고 숫자 뜨는 자리 찾기", Open Question "얼굴을 노리는가 숫자만 쫓는가" | `design/gdd/game-concept.md` § Pillars, Risks | 규칙 출처 | 완화책 = 규칙 D |
| 얼굴 주인공(원칙 2), 상태 = 그림자 높이(원칙 3), 번호 배지·예상 칸·잉크 점선·색약 검수(4절), 금색 = 연쇄 숫자 | `design/art/art-bible.md` § 1, 4 | 시각 계약 | 일치 — 프로토타입 크루 색 틴트를 잉크 점선으로 교체 |
| 웨이브 틴트·단계 번호 배지·예상 알·"연쇄 N 예상!"·"능력 발동!" | `prototypes/sticker-place-concept/prototype.html`, `REPORT.md` | 검증된 시작값 | 일치 — 배너 위치(판 밖)·틴트 색 교체. 코드 재사용 금지 (throwaway) |
| `CanvasItem` 선 페더 제거 (4.7) | `docs/engine-reference/godot/breaking-changes.md` | 엔진 제약 | 반영 (V/A 주의) |
| `ctx` 공급·커밋 후 권위 `resolve` | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| `preview_detail`·`show_predicted_score` 스테이지 값, `goal_markers` 훅 | `design/gdd/stage-goals.md` (미작성) | 하위 계약 | provisional |
| 능력 = 미리보기 어휘로 표시 가능 | `design/gdd/crew-definition.md` | 하위 계약 | provisional (수용 기준 요청) |
| 얼음 배지·변형 칸 아이콘 | `design/gdd/obstacles.md` (미작성) | 하위 계약 | provisional |
| 연출이 같은 칸·번호 재생 | `design/gdd/chain-presentation.md` (미작성) | 하위 계약 | provisional |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략. Review manually before production.
> Story types: 모델·트리거·일치 = **Logic/Integration** → `tests/unit/chain_preview/`, `tests/integration/chain_preview/` (BLOCKING);
> 화면 = **UI/Visual** → `production/qa/evidence/` 스크린샷 보관 (BLOCKING). 픽스처는 chain-resolver AC와 같은 보드 문자열 팩토리·테스트 전용 능력 표를 쓴다.
> 표시 검증은 렌더 픽셀이 아니라 `PreviewModel`(규칙 3)을 비교한다 — 픽셀은 스크린샷 AC만.

**미리보기 == 런타임 (기둥 3)**

- **AC-P01 (규칙 1·2, 단일 구현)** — **GIVEN** 미리보기 모듈 소스, **WHEN** 정적 검사하면, **THEN** board-rules 판정 함수(`full_lines`, `line_cells`, `clear_cells`, `fill_cells`
  등)·프리미티브 구현을 직접 참조하지 않고 해석기 호출은 `resolve` 하나뿐이다. **AND** `score_placement` 외 점수 계산 코드가 없다.
- **AC-P02 (규칙 1·4, 표시 = 결과)** — **GIVEN** chain-resolver AC-14의 고정 시드 판 50개와 각 판의 모든 유효 (조각, 앵커), **WHEN** 미리보기 경로로 만든 `PreviewModel`과
  판 진행 흐름 실제 배치 경로의 `ChainResult`로 만든 `PreviewModel`을 비교하면, **THEN** 지워질 칸(웨이브 번호 포함)·배지(칸, 숫자/종류)·예상 알(칸, 순서)·배너 단계가
  100% 같다. **AND** 각 칸이 실제로 지워진 칸 집합과 지워질 칸 윤곽 집합이 정확히 같다(누락·추가 0). (통합 테스트)
- **AC-P03 (규칙 13, 예상 점수 = 실제 점수)** — **GIVEN** AC-P02 픽스처와 `show_predicted_score = true`, **WHEN** 미리보기의 예상 총점과 커밋 후 `stage_score` 증가분을 비교하면,
  **THEN** 1점도 다르지 않다 (scoring AC-S12와 공동).
- **AC-P04 (규칙 9, 디버그 불일치 감지)** — **GIVEN** 테스트용으로 미리보기에 다른 `rng_seed`를 주입한 랜덤 프리미티브 테스트 픽스처, **WHEN** 커밋하면, **THEN** 디버그 빌드에서
  `PREVIEW_MISMATCH`가 발생한다. **AND** 정상 `ctx`에서는 AC-P02 픽스처 전체에서 0회.
- **AC-P05 (규칙 8, 캐시 무해)** — **GIVEN** 같은 드래그 경로(앵커 수열 20개, 반복 포함), **WHEN** `preview_cache_size` 0과 16으로 각각 재생하면, **THEN** 매 단계 `PreviewModel`이
  같다. **AND** 커밋으로 `board_version`이 바뀐 뒤 같은 앵커를 밟으면 캐시를 쓰지 않고 새 보드로 `resolve`한다.

**모델 규칙**

- **AC-P06 (규칙 5, 배지 = stage)** — **GIVEN** chain-resolver AC-03 픽스처(냥이 → 곰곰), **WHEN** 모델을 만들면, **THEN** (7,5) 냥이 배지 1, (4,5) 곰곰 배지 2, 배너 `CHAIN(2)`
  "연쇄 2 예상!". **AND** AC-04 픽스처(한 행 얼굴 3개)에서 세 배지가 모두 1.
- **AC-P07 (F3, 배너 단계)** — **GIVEN** `chain_depth` 0·1·3과 상한 도달(AC-08 픽스처), **WHEN** 배너를 구하면, **THEN** 각각 `NONE`·`ABILITY`·`CHAIN(3)`·`CHAIN_MAX(6)`.
  **AND** `preview_detail = NO_BANNER`이면 모두 `NONE`.
- **AC-P08 (피즐·알)** — **GIVEN** AC-08 픽스처, **WHEN** 모델을 만들면, **THEN** 웨이브 6의 얼굴은 숫자 배지가 아니라 졸음 배지이고 숫자 배지 최대값 = 6. **GIVEN** AC-07
  픽스처(알 재점화), **THEN** 예상 알 2개가 `ABILITY_EFFECT.cells` 순서와 같고, 알이 완성한 3번 행 칸은 다음 웨이브 번호로, (3,2) 냥이는 배지 2로 표시된다.
- **AC-P09 (규칙 13, 점수 기본 숨김)** — **GIVEN** 기본 설정, **WHEN** 어떤 미리보기든, **THEN** 모델에 점수 필드가 없고 `score_placement` 호출 0회.
- **AC-P10 (규칙 14, 비교 도구 없음)** — **GIVEN** 드래그 중, **WHEN** 모델을 검사하면, **THEN** 현재 (조각, 앵커) 하나의 결과만 담고, 다른 앵커·다른 트레이 조각의 결과는 없다.
- **AC-P11 (규칙 17, 숨김은 표시됨)** — **GIVEN** `preview_detail = FIRST_STAGE_ONLY`와 AC-03 픽스처, **WHEN** 모델을 만들면, **THEN** 냥이 배지 1, 곰곰 칸은 "…" 배지,
  웨이브 2 윤곽 없음, 배너 `ABILITY`. 숨긴 요소 위치에 거짓 요소(빈 표시·다른 숫자)가 없다.

**트리거·생명주기**

- **AC-P13 (규칙 6, 재계산 횟수)** — **GIVEN** 드래그 중 같은 유효 앵커에 60프레임, **WHEN** 미리보기가 갱신되면, **THEN** `resolve` 1회 (chain-resolver AC-16과 공동).
  **AND** 무효 앵커 사이 이동 30프레임 동안 0회, 유효 앵커 3번 변경 시 (캐시 비우고) 3회, (3,2)→(3,3)→(3,2)→(3,3) 경로는 캐시 16에서 2회 (F6).
- **AC-P14 (규칙 7, 같은 프레임)** — **GIVEN** 녹화한 입력 재생, **WHEN** 앵커가 바뀌는 프레임을 검사하면, **THEN** 같은 프레임에 고스트 위치와 `PreviewModel` 앵커가 같다 (지연 0프레임).
- **AC-P15 (규칙 10·11, 지우기)** — **GIVEN** `SHOWING`, **WHEN** `anchor_changed(null)` / `drag_ended(RETURNED)` / `drag_ended(CANCELLED)` / 입력 `LOCKED`이면, **THEN** 같은 프레임에 `HIDDEN`.
  `drag_ended(COMMITTED)`이면 0.06s 페이드 후 `HIDDEN`(모션 줄이기 시 0s). 어느 경우든 보드·점수·트레이가 바뀌지 않는다(규칙 12).

**성능 (F2·F5)**

- **AC-P16 (F2, 데스크톱)** — **GIVEN** 연쇄 6단 + 얼굴 밀집 최악 근사 픽스처, **WHEN** headless 데스크톱에서 `resolve` + `build_preview_model` 1,000회, **THEN** 평균 ≤ 1.2ms/회.
- **AC-P17 (F2, 실기기)** — **GIVEN** 저가 Android 기준 기기(T0 그레이박스, 기기는 플랫폼 & 화면 GDD가 지정), **WHEN** 최악 픽스처에서 앵커를 매 프레임 바꾸며 10초 쓸면,
  **THEN** 미리보기 몫 ≤ 4ms/프레임, 프레임 드롭(> 16.7ms) 0회, 앵커가 그대로인 프레임의 미리보기 몫 ≤ 0.5ms. 측정 로그를 `production/qa/evidence/`에 보관.
- **AC-P18 (F5, 요소 풀)** — **GIVEN** 판 64칸이 모두 지워지는 픽스처, **WHEN** 표시하면, **THEN** 요소 수 ≤ 128이고 드래그 중 노드·리소스 새 할당 0회.

**가독성 (UI/Visual — 스크린샷 증거)**

- **AC-P12 (규칙 18–23, 판독)** — **GIVEN** 1080×2400과 720×1600 세로 화면에서 연쇄 3 미리보기(들고 있는 조각 자신의 얼굴 발동 포함), **WHEN** 스크린샷을 찍으면, **THEN**
  배지 지름이 F1 값 이상, 배지가 끌리는 조각 위에 보이고, 배너가 판 칸과 겹치지 않으며, 배지가 얼굴 이목구비(칸 중앙 50%)를 가리지 않는다. 내부 플레이테스터가 0.5초
  안에 "연쇄 몇?"에 답한다.
- **AC-P19 (규칙 19, 색약)** — **GIVEN** AC-P12 화면, **WHEN** 그레이스케일과 제1·2·3색맹 시뮬레이션을 적용하면, **THEN** 지워질 칸·배지·예상 알을 모두 구분할 수 있고
  얼굴 칸을 1초 안에 모두 찾는다 (art bible 4절 검수 기준). 스크린샷 4장 보관.
- **AC-P20 (규칙 20, 모션 줄이기)** — **GIVEN** 모션 줄이기 켬, **WHEN** 연쇄 3 미리보기, **THEN** 윤곽이 움직이지 않고(그림자 2px 고정) 배지·배너·알은 같다.

**퇴화 위험 관찰 (플레이테스트 — 자동화 대상 아님)**

- **AC-P21 (규칙 D)** — **GIVEN** 외부 테스터 ≥ 3명, 스테이지 3개(점수·특정 칸·연쇄 N 목표 각 1), **WHEN** 플레이를 관찰·인터뷰하면, **THEN** (a) "얼굴이 스위치"를 설명 없이
  말로 설명한다, (b) 특정 칸 목표 스테이지에서 최대 연쇄가 아닌 자리를 의도적으로 고른 배치가 1회 이상 관찰된다. 실패 시 Q3의 `preview_detail` 실험으로 간다.
  `/playtest-report`로 기록.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | chain-resolver 규칙 9는 "미리보기의 발동 순서 번호가 `order_index`를 그대로 쓴다"고 적었다. 이 문서는 배지 숫자를 `stage`로 정했다 (D3). chain-resolver 문구를 "`stage`(배지), `order_index`(연출 순서)"로 고칠지 | game-designer · chain-resolver 소유자 | `/design-review chain-resolver` 또는 `/consistency-check` |
| Q2 | 스테이지 목표 표식을 미리보기에 얹을지 (`goal_markers` 훅: 목표 칸이 지워질 칸에 들면 강조, 연쇄 N 목표 달성 시 배너에 ✓) — 트레이드오프를 보이게 하지만 정보량이 는다 | game-designer · 스테이지 GDD | `/design-system stage-goals` |
| Q3 | 외부 플레이테스트에서 숫자만 쫓는다면: `preview_detail` `NO_BANNER`/`FIRST_STAGE_ONLY` 비교 실험, 또는 후반 스테이지 기본값 변경 — 단 기둥 3("놓기 전에 결과를 본다")과의 긴장은 creative-director 판단 | creative-director · game-designer | T0/T1 외부 플레이테스트 (AC-P21) |
| Q4 | systems-index: 판 진행 흐름 #11 Depends On에 연쇄 미리보기 추가(판 흐름이 `ctx` 주입), 연쇄 미리보기 #8 Depends On에 점수(Soft) 추가 | producer · `/map-systems` | 판 진행 흐름 GDD 작성 전 |
| Q5 | 능력 대상 방향 표시(냥이 십자 팔이 뻗는 화살표 등)를 둘지 — 지금은 칸 윤곽 + 박자만. 크루가 늘어 "왜 저 칸이?"가 생기면 재검토 | art-director · ux-designer | 크루 6명 그레이박스 후 |
| Q6 | 렌더 방식 ADR: 단일 `_draw` 노드 vs 요소 풀 스프라이트, 점선을 `draw_dashed_line`(4.7 페더 제거) vs 구운 9-슬라이스 | technical-director | `/architecture-decision` (해석기 critical ADR과 함께 또는 직후) |
| Q7 | 미리보기 첫 등장 시(첫 스테이지 첫 `chain_depth ≥ 1`) 튜토리얼 말풍선을 붙일지 — MVP는 설명 없이(가설 측정), VS에서 결정 | game-designer · 튜토리얼 GDD | VS |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(크기·예산·박자 등 숫자 규칙 있음)·Edge Cases·Dependencies·AC + 필수(Visual/Audio·Game Feel — Gameplay, Cross-References — 의존 있음) + UI Requirements·Open Questions ("All of them" 권장안). Player Fantasy·Tuning Knobs 생략, 데이터 값은 Formulas 변수표 | Tuning Knobs 추가 — tier 규칙 위반 |
| D2 | **"가장 큰 숫자" 완화책** | **"구조는 보이고 값은 숨긴다"**: 칸·배지·알·연쇄 N은 전부, 예상 점수는 기본 숨김(스테이지가 켜면 총점 한 줄), 비교 도구 없음, 배너는 연쇄 단계만, 트레이드오프는 스테이지 목표가 만듦, 정보량은 실험 노브 | (a) scoring D8 권장 "총점 한 줄" 기본 표시 — 점수 비교가 곧 "최고 숫자 찾기"; (b) 웨이브 0만 미리보기 — 프로토타입에서 규칙 학습이 안 됐던 v1으로 후퇴, 기둥 3 약화; (c) 최적 자리 힌트 — 퍼즐 제거 |
| D3 | 배지 숫자 | `stage` (연쇄 단계, 같은 웨이브 같은 숫자 — 프로토타입 v2) | `order_index` (chain-resolver 규칙 9 문구) — 동시 발동 얼굴에 1·2·3이 붙어 "3단 연쇄"로 오독, 배너 N과 불일치 (Q1) |
| D4 | 웨이브 구분 | 잉크 점선 + 웨이브별 위상 지연 숨쉬기 (색 없음) | 웨이브별 색/농도 틴트(프로토타입) — art bible 색약·크루 색 규칙 위반; 웨이브 숫자를 칸마다 — 판이 숫자로 뒤덮임 |
| D5 | 배너 위치 | 판 위쪽 바깥 고정 띠 | 판 첫 행 위(프로토타입) — 맨 위 행 배치 시 끌리는 조각·배지와 겹침 |
| D6 | 레이어 | 윤곽은 끌리는 조각 아래, 알·배지·배너는 위 | 전부 아래 — 들고 있는 조각 자신의 얼굴 배지가 가려짐; 전부 위 — 윤곽이 조각을 덮어 고스트 판독 저하 |
| D7 | 재계산 | 유효 앵커 변경 시 동기 1회 + LRU 16 캐시, 디바운스 없음 | 디바운스/비동기 — 고스트와 프레임 어긋남; 전 앵커 선계산 — 비용 42배, 비교 도구 유혹 |
| D8 | 커밋 시 결과 재사용 | 판 진행 흐름이 독립 `resolve` + 디버그 비교 | 미리보기 결과를 그대로 커밋 — 빠르지만 불일치 버그를 숨김(비교 대상이 사라짐) |
| D9 | 오디오 | 미리보기 무음 | 앵커마다 큐 — 쓸어 보기가 시끄러움 |
| D10 | 미리보기 끄기 설정 | 두지 않음 | 접근성 옵션으로 제공 — 규칙 학습 수단이자 기둥 3 핵심이라 끄면 게임이 다른 게임이 됨 |
