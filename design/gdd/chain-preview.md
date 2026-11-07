# 연쇄 미리보기 (Chain Preview)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Implements Pillar**: 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛

## Summary

[To be designed]

> **Quick reference** — Layer: `[Foundation | Core | Feature | Presentation]` · Priority: `[MVP | Vertical Slice | Alpha | Full Vision]` · Key deps: `[System names or "None"]`

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

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
