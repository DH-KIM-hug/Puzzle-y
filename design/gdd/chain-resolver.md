# 연쇄 해석기 & 능력 프리미티브 (Chain Resolver & Ability Primitives)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛 · 기둥 2 크루가 곧 전략

## Summary

배치 하나를 받아 줄 지우기 → 얼굴 능력 발동 → 능력이 지운 다른 얼굴의 발동 → … 을 웨이브 단위로 깊이 상한(6, 데이터)까지 결정적으로 풀고,
순서 있는 이벤트 목록과 최종 보드를 돌려주는 순수 함수, 그리고 크루 능력을 조합하는 능력 프리미티브 어휘(`clear_cross`, `clear_area`,
`lay_eggs_in_own_line` 등 7종)를 정의한다. 플레이어에게는 "한 번 놓은 결과가 도미노처럼 번지는" 법칙이며, 미리보기·실제 배치·연출·점수가
모두 이 한 벌의 결과를 쓰기 때문에 "놓기 전에 본 연쇄가 그대로 터진다" (기둥 1·3).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `보드 & 조각 규칙`, `시드 RNG` (upstream) — downstream: 점수 & 연쇄 배율, 크루 정의 & 능력, 연쇄 미리보기, 칸 종류 & 방해물, 스테이지 & 목표, 판 진행 흐름, 연쇄 연출 재생기

## Overview

연쇄 해석기는 말랑 크루의 심장이다. 데이터 층에서는 **순수 함수 하나** — `resolve(board, piece, anchor, ctx) → ChainResult`
— 로서, 배치 하나를 받아 줄 지우기 → 지워진 얼굴의 능력 발동 → 능력이 지운 다른 얼굴의 발동 → … 을 깊이 상한까지
결정적으로 풀고, 그 과정을 **순서 있는 이벤트 목록**과 최종 보드로 돌려준다. 함께 이 문서는 크루 능력을 이루는
**능력 프리미티브 어휘**(`clear_cross`, `clear_area`, `lay_eggs_in_own_line` …)와 그 실행 계약을 소유한다. 크루 정의는
프리미티브를 데이터로 조합할 뿐이고, 해석기는 특정 크루를 모른다 (systems-index의 순환 차단 계약).
플레이어 쪽에서 보면 이 시스템은 "한 번 놓은 결과가 캐릭터 능력으로 여러 단계 번지는" 도미노의 법칙 그 자체이며
(기둥 1), 드래그 중 미리보기가 같은 함수를 호출하므로 "놓기 전에 결과를 본다"가 거짓말이 아니게 된다 (기둥 3 —
"미리보기와 실제 결과가 다르면 버그"). 연출 재생기는 이벤트를 재생만 하고, 점수 시스템은 이벤트를 읽어 점수를
매길 뿐이다 — 해석기는 점수·연출·입력·트레이를 모른다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing; Layer `Foundation`과 충돌 시
Category 우선) · ADR ref `[B] No` (`docs/architecture/adr-*.md` 없음 — 이 GDD와 병행할 첫 critical ADR 후보) · Fantasy `[B] No`
(Foundation; standard tier라 Player Fantasy 섹션 생략). 구현 형태(정적 함수 모듈 vs RefCounted 서비스, 프리미티브를
Custom Resource로 둘지 enum + 파라미터 Dictionary로 둘지, 보드 복제 방식)는 → ADR 대상.

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` (Section 6 라우팅: Gameplay → 규칙 시스템) not consulted —
> Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 해석기 계약**

1. **입출력** — `resolve(board, piece, anchor, ctx) → ChainResult`.
   - 입력: 안정 보드(board-rules 불변식 13 — 완성 줄 0개), 조각 인스턴스(`shape`·`crew_id`·`face_index`), 앵커,
     `ctx` = { `crew_abilities`(crew_id → 능력 정의, 크루 정의 GDD가 제공), `rules`(아래 데이터 값), `rng_seed`(int),
     `hooks`(칸 종류 & 방해물이 등록한 훅, 없으면 기본값) }.
   - 출력: `ChainResult` = { `events`(순서 있는 목록, 규칙 E), `final_board`, `summary`(= `CHAIN_END` 페이로드) }.
   - 전제: `can_place(board, piece, anchor) = true` (board-rules F2). 위반은 assert — 해석기는 거짓 배치를 해석하지 않는다.
2. **순수성** — 입력을 바꾸지 않는다. 시간·프레임·전역 상태·엔진 싱글턴(전역 `randi()` 등)을 읽지 않는다. 같은 입력
   → 같은 `events`(순서 포함)·같은 `final_board`. 정수 연산만 쓴다(부동소수 없음 — 플랫폼 간 결정성).
3. **단일 구현 (TD 조건)** — 판 진행 흐름(실제 배치)과 연쇄 미리보기(가상 배치)와 자동 플레이 테스트가 **같은 `resolve`**를
   호출한다. 미리보기용 근사 경로, 연출용 별도 판정은 금지다. 연출 재생기는 `events`를 재생만 하고 보드를 판정하지 않는다.
4. **보드 규칙 재사용** — 줄 판정·칸 비우기·채우기는 board-rules의 `place`, `full_lines`, `line_cells`, `clear_cells`,
   `fill_cells`, `line_fill_count`, `empty_cells_in_line`만으로 한다. 해석기는 칸 종류 *이름*을 읽지 않는다 (플래그 3종과 훅만).

**B. 웨이브(wave)와 깊이(depth)**

5. **웨이브** — 한 번에 함께 지워지는 칸 묶음 하나. 웨이브는 0부터 번호가 붙고 **웨이브 번호 = 깊이**다
   (웨이브 0 = 배치가 완성한 줄; 웨이브 k ≥ 1 = 웨이브 k−1에서 발동한 능력의 결과).
6. **해석 루프** (이 순서가 곧 사양이다):
   1. `B ← place(board, piece, anchor)`; `PLACED` 이벤트. `k ← 0`.
   2. `pending ← line_cells(effective_full_lines(B))` (규칙 11). 비어 있으면 → 9.
   3. **웨이브 k 시작** — `WAVE_BEGIN(k, causes, rows, cols)`.
   4. **지우기** — 훅 `pre_clear`(규칙 21)를 거친 뒤 `(B, cleared) ← clear_cells(B, pending)`; `CELLS_CLEARED`.
   5. **얼굴 수집** — `faces ← cleared` 중 `is_face = true`이고 `crew_id ≠ null`인 칸, **row-major 순서** (규칙 9).
      없으면 → 9.
   6. **상한 검사** — `k ≥ depth_cap`이면 모든 얼굴이 `FACE_FIZZLED(DEPTH_CAP)`, `DEPTH_CAP_REACHED` 1회 → 9 (규칙 10).
   7. **발동** — 얼굴마다 순서대로 훅 `can_activate`(규칙 21)를 검사하고, 통과한 얼굴의 능력을 실행한다 (규칙 C).
      `clear_targets` = 모든 발동 얼굴의 CLEAR 프리미티브 결과 합집합(스냅샷 기준, 규칙 15),
      FILL 프리미티브는 얼굴 순서 → 능력 내 프리미티브 순서대로 `B`에 즉시 적용한다 (규칙 16).
      통과한 얼굴이 0개면 → 9.
   8. **다음 웨이브** — `pending ← clear_targets ∪ line_cells(effective_full_lines(B))` (알이 채운 줄이 **같은 다음 웨이브**에
      합류한다 — 규칙 12). 비어 있으면 → 9. 아니면 `k ← k + 1`, → 3.
   9. **종료** — `CHAIN_END(summary)`. `final_board = B`.
7. **연쇄 깊이 (`chain_depth`)** — 얼굴이 하나 이상 *발동*한 웨이브의 수 (F2). 플레이어에게 보이는 "연쇄 N"의 N이며,
   프로토타입의 `chainNow`와 같다. 줄만 지우고 얼굴 발동이 없으면 `chain_depth = 0`.
8. **종료 보장** — 웨이브 k ≥ 1은 웨이브 k−1에 발동이 있어야만 생기고, 발동은 지워진 얼굴을 소비하며, 어떤 프리미티브도
   얼굴을 만들지 않는다(규칙 17). 따라서 웨이브 수 ≤ min(`depth_cap`, 보드 위 얼굴 수) + 1 (F3). 깊이 상한은 무한 루프 방지책이
   아니라 **설계 상한**이다 — 무한 루프는 구조상 불가능하다. 추가 안전장치로 `max_waves_guard`(= `depth_cap` + 1)를 넘으면
   assert(디버그) + 즉시 종료(출시)한다.

**C. 동시 발동 순서**

9. **얼굴 순서 = row-major** — 같은 웨이브에서 지워진 얼굴들은 (row 오름차순, 같은 row면 col 오름차순)으로 발동한다. 이는
   board-rules `clear_cells`의 반환 순서와 같다. 발동 순번 `order_index`는 연쇄 전체에서 1부터 이어지는 전역 번호이며,
   연출 재생기의 같은 웨이브 안 발동 간격 순서와 `CELLS_CLEARED.source_order`가 이 값을 쓴다. **미리보기 배지 숫자는 `order_index`가
   아니라 `stage`(= `wave` + 1)다** (chain-preview 규칙 5·D3 — 같은 웨이브 얼굴은 같은 숫자; D13). 순서가 결과에 영향을 주는 곳은
   FILL 프리미티브뿐이다(CLEAR는 합집합).
10. **깊이 상한에서의 동작 (TD 조건 — board-rules Q1 해소)** — 웨이브 k = `depth_cap`은 **정상적으로 지워진다**(줄 칸 + 직전
    능력 대상 모두). 그 웨이브에서 지워진 얼굴은 발동하지 않고 `FACE_FIZZLED(reason = DEPTH_CAP)`로 사라진다. 이 웨이브에서는
    FILL이 일어나지 않으므로 새 완성 줄이 생기지 않고, 해석기 종료 시 완성 줄 0개(board-rules 불변식 13)가 보장된다.
    연출은 피즐 얼굴을 "꾸벅 조는" 다정한 연출로 보여 준다 (기둥 5; 연출 재생기 GDD).
11. **유효 완성 줄** — `effective_full_lines(B)` = board-rules `full_lines(B)` 중 `removable_by_clear = true`인 칸이 1개 이상인 줄.
    지울 수 없는 칸만으로 찬 줄은 지워도 그대로 차 있으므로 웨이브를 만들지 않는다 (방해물 GDD는 이런 줄이 생기지 않게
    설계해야 한다 — Edge Cases). MVP 기본 칸 종류(`EMPTY`, `TILE`)에서는 `full_lines`와 같다.
12. **알 재점화** — FILL(알)로 완성된 줄은 같은 발동이 낳은 CLEAR 대상과 **한 웨이브로 합쳐** 다음 웨이브에서 지워진다. 그 줄에
    있던 얼굴은 다음 웨이브의 얼굴로서 발동한다 (도미노가 알을 타고 이어진다 — 컨셉 Core Mechanics 2). 프로토타입은 능력 지우기를
    먼저 하고 줄 판정을 나중에 해 능력 지우기가 알이 채운 줄을 깨뜨릴 수 있었다 — 본 설계는 합집합으로 바꾼다 (Decision Log D4).

**D. 능력 프리미티브 (데이터 어휘)**

13. **능력 = 프리미티브 호출 목록** — 크루 능력은 `[{ primitive: <id>, params: {…} }, …]` 데이터다 (1개 이상). 크루 정의 GDD가
    크루별 목록을 정하고, 이 문서는 프리미티브의 의미·파라미터·검증만 정한다. 새 크루 = 새 조합 또는 새 프리미티브 (기둥 2 "새 동작").
14. **MVP 프리미티브 어휘** — 모든 좌표는 발동 얼굴 칸 `(fr, fc)` 기준, 보드 밖 칸은 버린다. "대상"은 칸 좌표 집합이며
    빈칸·지울 수 없는 칸이 섞여도 오류가 아니다 (board-rules 규칙 11).

    | id | 종류 | 파라미터 (기본값) | 대상 / 효과 | 예시 크루 (크루 정의 GDD 소관) |
    |---|---|---|---|---|
    | `clear_cross` | CLEAR | `reach` (−1 = 줄 끝까지) | 얼굴의 행과 열에서 거리 ≤ `reach`인 칸 | 냥이 십자 할퀴기 (`reach = −1`) |
    | `clear_line` | CLEAR | `axis` (`row` \| `col`), `reach` (−1) | 얼굴의 행 *또는* 열 한쪽 | (후보) |
    | `clear_area` | CLEAR | `radius` (1) | 체비쇼프 거리 ≤ `radius`인 정사각 영역 | 곰곰 3×3 (`radius = 1`) |
    | `clear_diagonals` | CLEAR | `reach` (−1) | 얼굴을 지나는 두 대각선에서 거리 ≤ `reach` | (후보) |
    | `clear_pattern` | CLEAR | `offsets` [(dr, dc)…] | 얼굴 기준 상대 좌표 목록 | (후보 — 일반화 탈출구) |
    | `lay_eggs_in_own_line` | FILL | `count` (3), `prefer` (`fuller`), `order` (`nearest`) | 얼굴의 행·열 중 고른 줄의 빈칸에 알 `count`개 (F5) | 삐약 알 낳기 |
    | `lay_eggs_pattern` | FILL | `offsets` [(dr, dc)…] | 상대 좌표 중 빈칸에 알 (목록 순서) | (후보) |

    - 알 = board-rules `TILE(origin = EGG, is_face = false, crew_id = 발동 크루)`. 줄 판정에서 조각 칸과 같고 능력은 없다.
    - `prefer`: `fuller`(빈칸이 더 적은 줄, 동률이면 행) \| `emptier`(빈칸이 더 많은 줄, 동률이면 행) \| `row` \| `col`.
      고른 줄에 빈칸이 없으면 다른 줄로 넘어간다. `order`: `nearest`(얼굴과의 맨해튼 거리 오름차순, 동률 row-major) \| `row_major`.
    - 발동 얼굴 자신의 칸은 이미 지워져 비어 있으므로 `lay_eggs_in_own_line`의 첫 알은 얼굴 자리(거리 0)에 놓인다 — 프로토타입과
      같고, "삐약이 떠난 자리에 알"로 읽힌다.
15. **CLEAR 스냅샷 규칙** — 웨이브 k의 모든 CLEAR 대상은 **4단계(지우기) 직후, 어떤 FILL도 적용되기 전의 보드**를 기준으로
    계산한다. 그 보드에서 차 있는 칸만 `clear_targets`에 남는다. 따라서 같은 웨이브에서 낳은 알은 같은 웨이브의 CLEAR에
    지워지지 않는다(프로토타입과 같음). 여러 얼굴의 대상이 겹치면 한 번만 지워진다(합집합).
16. **FILL 순차 규칙** — FILL은 얼굴 순서(규칙 9) → 능력 내 프리미티브 순서대로 보드에 즉시 적용되며, 뒤의 FILL은 앞의 FILL이
    채운 칸을 빈칸으로 보지 않는다. 대상은 `empty_cells_in_line` 등 빈칸 조회로만 고르므로 `fill_cells`의 assert에 걸리지 않는다.
17. **프리미티브 계약 (모든 프리미티브, MVP 이후 추가분 포함)** — 출력은 (스냅샷 보드, 얼굴 좌표, 얼굴 `crew_id`, `params`,
    `ctx.rng_seed`에서 파생한 스트림)에만 의존한다. 금지: 얼굴 칸 생성, 칸 이동·교환, 트레이·점수·스테이지 상태 읽기, 시간 의존,
    직접 웨이브 생성(결과는 CLEAR 대상 또는 FILL 칸뿐). 새 프리미티브는 이 계약과 "미리보기로 정확히 보일 것"(기둥 3)을
    수용 기준으로 이 문서에 추가한다.
18. **로드 시 검증** — 알 수 없는 프리미티브 id, 범위 밖 파라미터(`radius < 0`, `count < 1`, 빈 `offsets`, `reach < −1`), 빈 능력 목록,
    능력이 정의되지 않은 `crew_id`의 얼굴(스테이지 초기 보드 포함)은 데이터 로드 오류다. 런타임 보정은 하지 않는다.

**E. 이벤트 목록 스키마**

19. **이벤트 공통 필드** — `seq`(0부터 연속), `type`, `wave`(`PLACED`·`CHAIN_END`는 null). 좌표는 `(r, c)` 정수. 이벤트 순서는
    규칙 6의 실행 순서 그대로이며, 한 웨이브 안에서는 `WAVE_BEGIN` → `CELL_MODIFIED`* → `CELLS_CLEARED` → (얼굴 순서대로:
    `FACE_ACTIVATED` → 그 얼굴의 `ABILITY_EFFECT`* (프리미티브 순서) \| `FACE_FIZZLED`) → `DEPTH_CAP_REACHED`?.

    | type | 페이로드 | 주 소비자 |
    |---|---|---|
    | `PLACED` | `crew_id`, `anchor`, `cells[]`, `face_cell` (null 가능) | 연출, 점수(배치 점수가 있다면) |
    | `WAVE_BEGIN` | `wave`(= 깊이), `causes` ⊆ {`LINE`, `ABILITY`}, `rows[]`, `cols[]` (이 웨이브에 든 유효 완성 줄, 오름차순) | 연출(단계 컷인), 점수(줄 수), HUD |
    | `CELL_MODIFIED` | `cell`, `modifiers_before`, `modifiers_after` (훅 `pre_clear`가 지우지 않고 바꾼 칸) | 연출, 방해물 목표 |
    | `CELLS_CLEARED` | `cells[]` = {`r`, `c`, `crew_id`, `is_face`, `origin`, `by` (`LINE` \| `ABILITY` \| `BOTH`), `source_order`(이 칸을 대상으로 삼은 가장 앞 얼굴의 `order_index`, 줄만이면 null)} row-major; `line_cell_count`; `ability_cell_count`; `kept[]` | 점수(칸 수·깊이), 스테이지 목표(특정 칸), 연출 |
    | `FACE_ACTIVATED` | `order_index`, `cell`, `crew_id`, `ability_id`, `stage` (= `wave` + 1, "연쇄 N"의 N) | 연출(컷인·`order_index` 순서), 미리보기(단계 배지 = `stage`), 오디오 |
    | `ABILITY_EFFECT` | `order_index`, `primitive`, `kind` (`CLEAR` \| `FILL`), `cells[]` (CLEAR: 다음 웨이브에 실제로 지워질 차 있는 칸 / FILL: 낳은 알 칸, 낳은 순서) | 연출, 미리보기(예상 알) |
    | `FACE_FIZZLED` | `cell`, `crew_id`, `reason` (`DEPTH_CAP` \| `SUPPRESSED`) | 연출(꾸벅), 미리보기 |
    | `DEPTH_CAP_REACHED` | `wave` | 연출, HUD |
    | `CHAIN_END` | `chain_depth`, `waves`, `cells_cleared_total`, `lines_cleared_total`, `faces_activated`, `faces_fizzled`, `eggs_laid`, `cap_reached`, `board_hash` | 판 진행 흐름, 스테이지 목표(연쇄 N), 미리보기 요약("연쇄 N 예상"), 기록 |

20. **해석기는 점수를 계산하지 않는다** — 점수·배율은 점수 & 연쇄 배율 GDD가 `WAVE_BEGIN`(줄 수)·`CELLS_CLEARED`(칸 수, 깊이)를
    읽어 계산한다 (F6은 참조용). 이벤트 스키마에 점수 필드를 두지 않는다 — 점수 규칙이 바뀌어도 해석기와 미리보기의 일치가 깨지지 않는다.

**F. 훅 지점 (칸 종류 & 방해물 GDD가 채움)**

21. 해석기가 정의하는 훅은 셋이며, 훅이 없으면 기본값으로 동작한다. 훅은 칸의 `modifiers[]`(board-rules가 보존만 하는 슬롯)를
    읽는 순수 함수여야 하고 규칙 17의 금지 사항을 똑같이 따른다.

    | 훅 | 호출 시점 | 시그니처 (개념) | 기본값 | 예 (방해물 GDD 소관) |
    |---|---|---|---|---|
    | `pre_clear` | 규칙 6.4, 지우기 직전 칸마다 | cell → `CLEAR` \| `KEEP(new_modifiers)` | `CLEAR` | 얼음 겹: 첫 타격엔 겹만 벗겨짐 → `CELL_MODIFIED` |
    | `can_activate` | 규칙 6.7, 얼굴마다 | face cell → bool | true | 얼어붙은 얼굴: 지워지되 발동 안 함 → `FACE_FIZZLED(SUPPRESSED)` |
    | `target_filter` | 규칙 15, CLEAR 대상 계산 시 | cell, primitive → bool | true | 능력에는 안 지워지고 줄로만 지워지는 칸 |

    `KEEP`된 칸은 그 웨이브의 `clear_cells` 입력에서 빠진다. `SUPPRESSED` 얼굴만 있는 웨이브는 `chain_depth`에 세지 않는다.

**G. 시드 RNG 계약 (시드 RNG 시스템 #3의 GDD 절 — 구현은 ADR)**

22. 해석기는 전역 랜덤을 쓰지 않는다. 랜덤이 필요한 프리미티브는 `ctx.rng_seed`로 해석기 안에서 만든 **지역** 난수 스트림만 쓴다
    (Godot에서는 `RandomNumberGenerator` 인스턴스에 seed 지정 — 전역 `randi()` 금지). 같은 `rng_seed` → 같은 결과.
23. `rng_seed`는 판 진행 흐름이 `seed_for(stage_seed, placement_index)`(F7)로 만들어 미리보기와 실제 배치에 **같은 값**을 넘긴다.
    그래서 랜덤 프리미티브가 생겨도 미리보기 = 결과가 유지된다. 트레이 공급·가챠는 같은 시드 RNG 서비스의 **다른 스트림**을 쓰며
    해석기 스트림을 소비하지 않는다.
24. **MVP 프리미티브는 RNG를 쓰지 않는다** (안티 기둥 "예측 불가능한 연쇄"). `uses_rng = true` 프리미티브 도입은 "미리보기에 결과가
    그대로 보인다"를 수용 기준으로 별도 결정한다 (Open Question Q4). MVP에서는 `rng_seed`를 바꿔도 결과가 같아야 한다 (AC).

**H. 미리보기 지원 (TD 조건)**

25. 미리보기는 앵커 칸이 **바뀔 때만** `resolve`를 다시 부른다 (트리거는 드래그 & 배치 입력 GDD). 해석기는 순수하므로 결과를
    (`board_version`, 조각 인스턴스 id, `anchor`, `rng_seed`) 키로 캐시해도 된다. `can_place = false`인 앵커에서는 부르지 않는다.
26. 미리보기가 표시할 정보(지워질 칸, 단계 배지(`stage`), 예상 알, "연쇄 N 예상")는 모두 `events`/`summary`에 이미 있다. 무엇을 얼마나
    보여 줄지는 연쇄 미리보기 GDD 소관이다 ("가장 큰 숫자 찾기" 퇴화 위험의 튜닝 지점).

**I. 데이터 기반 값** (standard tier라 Tuning Knobs 섹션은 생략 — 범위와 근거는 여기와 Formulas 변수표에 둔다)

| 값 | 시작값 | 안전 범위 | 소유 | 근거 · 너무 크거나 작으면 |
|---|---|---|---|---|
| `depth_cap` | 6 | 3 ~ 10 (테스트용 0 허용) | 이 문서 (전역 데이터) | 프로토타입 검증값. 작으면 도미노가 금방 끊겨 기둥 1이 약해지고, 크면 연출 시간(웨이브당 ≈ 0.5s)이 늘어 "한 판 더" 템포가 처지고 점수 배율 상한이 커진다 (F6) |
| `face_order` | `row_major` | `row_major` (MVP 고정) | 이 문서 | 보드 규칙 반환 순서와 같아 미리보기 번호를 읽기 쉽다 (D3). 다른 순서는 Open Question Q2 |
| 프리미티브 파라미터 | 규칙 14 표 | 규칙 18 검증 범위 | 크루 정의 GDD (크루별 값) | 크루 개성의 원천 (기둥 2) |
| `max_waves_guard` | `depth_cap` + 1 | 파생값 | 이 문서 | 안전장치 — 정상 동작에서는 닿지 않는다 (규칙 8) |
| *(참조)* 깊이별 점수 배율 | +50%/단계 | — | 점수 & 연쇄 배율 GDD | 이 문서는 소유하지 않는다 (F6) |

### States and Transitions

해석기는 호출 사이에 상태를 들고 있지 않다. 아래는 **한 번의 `resolve` 호출 안의** 단계 전이다 (규칙 6).

| 단계 | 하는 일 | 다음 단계 | 조건 |
|---|---|---|---|
| `PLACE` | `place` → `PLACED` | `LINE_CHECK` | 항상 (전제: `can_place`) |
| `LINE_CHECK` (k = 0) | `pending ← 유효 완성 줄 칸` | `CLEAR` / `END` | pending 비었으면 `END` |
| `CLEAR` (웨이브 k) | `WAVE_BEGIN`, `pre_clear` 훅, `clear_cells`, `CELLS_CLEARED` | `GATHER_FACES` | 항상 |
| `GATHER_FACES` | 지워진 얼굴을 row-major로 수집 | `ACTIVATE` / `FIZZLE` / `END` | 얼굴 없음 → `END`; k ≥ `depth_cap` → `FIZZLE` |
| `ACTIVATE` | 얼굴 순서대로 `can_activate` → CLEAR 대상(스냅샷) + FILL 즉시 적용 | `NEXT_WAVE` / `END` | 발동한 얼굴 0개 → `END` |
| `FIZZLE` | 모든 얼굴 `FACE_FIZZLED(DEPTH_CAP)`, `DEPTH_CAP_REACHED` | `END` | 항상 |
| `NEXT_WAVE` | `pending ← clear_targets ∪ 유효 완성 줄 칸` | `CLEAR` (k+1) / `END` | pending 비었으면 `END` |
| `END` | `CHAIN_END(summary)` 반환 | — | 보드는 안정 (불변식 13) |

판 진행 흐름 관점에서 해석기 호출은 board-rules의 **해결 중(Resolving)** 시점 전체에 해당하지만, 해석기 자체는 동기 함수로 한 번에
끝난다. "연출 대기"는 판 진행 흐름의 상태이며, 그동안 보드 상태는 이미 `final_board`다 (연출이 끝나기 전에 게임 상태가 확정됨).

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 해석기 → 보드 규칙 호출 | `place`, `full_lines`, `line_cells`, `clear_cells`, `fill_cells`, `line_fill_count`, `empty_cells_in_line`; 칸 플래그 3종, `modifiers[]` 슬롯 | 보드 규칙 (함수) / 해석기 (호출 순서) |
| 시드 RNG | RNG → 해석기 | `rng_seed` 정수 1개 (판 진행 흐름이 파생해 전달) | 시드 RNG ADR (스트림 분리) / 해석기 (지역 스트림 사용 규칙) |
| 크루 정의 & 능력 | 크루 → 해석기 | `crew_abilities` (crew_id → 프리미티브 호출 목록), 프리미티브 파라미터 값 | 해석기 (어휘·계약) / 크루 정의 (조합·값) |
| 칸 종류 & 방해물 | 방해물 → 해석기 | 훅 3종 구현 (`pre_clear`, `can_activate`, `target_filter`) | 해석기 (훅 지점) / 방해물 (구체 동작) |
| 판 진행 흐름 | 판 흐름 → 해석기 → 판 흐름 | 호출(보드·조각·앵커·ctx) → `ChainResult`; `final_board`를 새 판 상태로 커밋, `events`를 연출에 전달 | 판 진행 흐름 (호출 타이밍) |
| 연쇄 미리보기 | 미리보기 → 해석기 | 같은 `resolve`를 가상 배치로 호출, `events`·`summary` 표시 | 해석기 (결과) / 미리보기 (표시 정보량) |
| 드래그 & 배치 입력 | 입력 → 미리보기 → 해석기 | 앵커 변경 이벤트 = 재계산 트리거 (규칙 25) | 입력 GDD |
| 점수 & 연쇄 배율 | 해석기 → 점수 | `WAVE_BEGIN.rows/cols`, `CELLS_CLEARED`(칸 수·`wave`), `CHAIN_END` | 점수 GDD (점수 공식·배율) |
| 스테이지 & 목표 | 해석기 → 스테이지 | `CHAIN_END.chain_depth` (연쇄 N 목표), `CELLS_CLEARED.cells` (특정 칸 목표), `CELL_MODIFIED` (방해물 목표) | 스테이지 GDD |
| 연쇄 연출 재생기 | 해석기 → 연출 | `events` 전체 — 재생만, 상태 변경·판정 금지 | 연출 GDD |
| 플레이 HUD · 오디오 | 간접 (연출/판 흐름 경유) | 현재 `stage`, 상한 도달 | 각 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가
> 없어 생략. Review manually before production. 이 시스템의 식은 대부분 깊이·개수·범위 계산이며, 균형 곡선(점수 배율)은
> 점수 & 연쇄 배율 GDD 소유다 (F6은 참조용 사본). 시작값은 프로토타입 검증값이다.

**F1. 웨이브 깊이**

The wave_depth formula is defined as:

`depth(wave_k) = k`, `activates(wave_k) = (k < depth_cap)`, `stage(face in wave_k) = k + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0 – `depth_cap` | calculated (해석 루프) | 웨이브 번호 = 깊이 |
| depth_cap | int | 3–10 (시작 6; 테스트 0 허용) | data file (`depth_cap`) | 얼굴이 발동할 수 있는 마지막 웨이브 다음 번호 |
| stage | int | 1 – `depth_cap` | calculated | `FACE_ACTIVATED.stage`, 화면의 "연쇄 N" |

**Output Range:** k ∈ [0, `depth_cap`]. k = `depth_cap`인 웨이브는 지워지기만 하고 발동하지 않는다 (규칙 10).
**Example:** `depth_cap = 6` — 웨이브 0~5의 얼굴은 stage 1~6으로 발동, 웨이브 6의 얼굴은 `FACE_FIZZLED(DEPTH_CAP)`.

**F2. 연쇄 깊이**

The chain_depth formula is defined as:

`chain_depth = |{ k : A_k > 0 }|`, 그리고 `chain_depth ≤ min(depth_cap, F_board)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| A_k | int | 0 – 얼굴 수 | calculated | 웨이브 k에서 *발동한* 얼굴 수 (`SUPPRESSED`·`DEPTH_CAP` 제외) |
| F_board | int | 0 – 64 | calculated | 배치 직후 보드 위 얼굴 칸 수 (방금 놓은 조각 포함) |
| depth_cap | int | F1 | data file | 깊이 상한 |

**Output Range:** 0 ~ `depth_cap` (시작 6). 줄을 지우지 못한 배치·얼굴 없는 줄 지우기 = 0. 발동은 웨이브 0부터 연속이므로
`chain_depth` = 발동이 있었던 마지막 웨이브 번호 + 1.
**Example:** 웨이브 0에서 냥이 발동 → 웨이브 1에서 곰곰 발동 → 웨이브 2는 얼굴 없이 지워짐 → `chain_depth = 2` ("연쇄 2").

**F3. 웨이브 수 상한 (종료 보장)**

The max_waves formula is defined as:

`waves ≤ min(depth_cap, F_board) + 1`, 안전장치 `max_waves_guard = depth_cap + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| waves | int | 0 – 7 (시작값 기준) | calculated (`CHAIN_END.waves`) | 실행된 웨이브 수 (줄을 못 지웠으면 0) |
| F_board, depth_cap | int | F2 | calculated / data file | — |

**Output Range:** 0 ~ `depth_cap + 1` = 7. 웨이브 k ≥ 1은 웨이브 k−1의 발동이 있어야 생기고 프리미티브는 얼굴을 만들지 못하므로(규칙 17)
이 상한을 넘을 수 없다. `max_waves_guard` 도달은 버그 신호다.
**Example:** 얼굴 2개뿐인 보드 → 최대 3웨이브 (발동 2단 + 마지막 지우기).

**F4. CLEAR 프리미티브 대상 크기** (빈 보드 기준 최대, 보드 밖은 잘림)

The primitive_target_size formula is defined as:

`|clear_cross(reach=−1)| = W + H − 1`; `|clear_cross(reach=n)| ≤ 4n + 1`; `|clear_line(row, −1)| = W`;
`|clear_area(ρ)| ≤ (2ρ + 1)²`; `|clear_diagonals(−1)| ≤ 2·min(W, H) − 1`; `|clear_pattern| ≤ |offsets|`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| W, H | int | 7–10 (시작 8) | data file (board-rules `board_width`/`board_height`) | 보드 크기 |
| reach / n | int | −1 또는 1–9 | data file (크루 정의의 파라미터) | 십자·대각선 팔 길이 (−1 = 줄 끝) |
| ρ | int | 0–3 | data file (크루 정의의 `radius`) | 정사각 반경 (0 = 얼굴 칸만) |

**Output Range:** 8×8에서 십자 15칸, 3×3 9칸(모서리 얼굴이면 4칸), 대각선 최대 15칸(8×8은 14). 실제로 지워지는 칸은 이 중 차 있고
지울 수 있는 칸뿐이며, 얼굴 칸 자체는 이미 비어 있다.
**Example:** 냥이 얼굴 (3, 5), `clear_cross(−1)` → 3번 행 8칸 + 5번 열 8칸 − 교차 1 = **15**칸 대상.

**F5. 알 낳을 줄과 칸 고르기** (`lay_eggs_in_own_line`)

The egg_selection formula is defined as:

`E_row = empty_cells_in_line(row fr)`, `E_col = empty_cells_in_line(col fc)`;
`line = prefer_fuller ? (|E_col| < |E_row| ? col : row) : …`, 고른 줄이 비면 다른 줄;
`eggs = first_min(count, |E_line|) of sort(E_line, key = (|r − fr| + |c − fc|, r, c))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| (fr, fc) | int pair | 보드 안 | calculated | 발동 얼굴 좌표 (이미 지워져 빈칸) |
| E_row, E_col | 칸 목록 | 1 – W / 1 – H | calculated (board-rules F5 `empty_cells_in_line`) | 얼굴 행·열의 빈칸 — 같은 웨이브 앞선 FILL 반영 (규칙 16) |
| count | int | 1–8 (삐약 3) | data file (크루 정의) | 낳을 알 수 |
| prefer | enum | `fuller` \| `emptier` \| `row` \| `col` | data file | 줄 선택 규칙 (동률 → 행) |

**Output Range:** 0 ~ `count`개. 얼굴 칸은 항상 빈칸이므로 같은 웨이브 FILL이 그 칸을 먼저 채우지 않은 한 1개 이상.
**Example:** 삐약 얼굴 (3, 5) 지워짐, 3번 행 빈칸 2개 {(3,1),(3,5)}, 5번 열 빈칸 4개 → `fuller` = 행 → 거리순 (3,5)=0, (3,1)=4 →
알 **2개**(count 3이지만 빈칸 2개). 3번 행이 꽉 차 다음 웨이브에서 지워진다 (재점화, 규칙 12).

**F6. 깊이별 점수 배율 — 참조 사본 (소유: 점수 & 연쇄 배율 GDD F2 — 이 문서는 값을 정하지 않는다)**

The depth_mult_pct formula is defined as:

`depth_mult_pct(k) = min(100 + depth_step_pct × k, depth_mult_max_pct)` (정수 백분율 — scoring F2와 같은 식·같은 변수명, D14)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0 – `depth_cap` | calculated (`CELLS_CLEARED`의 `wave`) | 그 칸이 지워진 웨이브의 깊이 |
| depth_step_pct | int | 25–100 (시작 50) | data file (`scoring.md` 소유) | 깊이 1단계당 배율 증가 (컨셉·프로토타입 +50%) |
| depth_mult_max_pct | int | 200–600 (시작 400) | data file (`scoring.md` 소유) | 배율 상한 — `depth_cap`과의 결합을 끊는다 |

**Output Range:** 100 (k = 0) ~ 400 (k = `depth_cap` = 6, 상한과 일치). `depth_cap`을 올려도 상한 400에서 멈춘다 (scoring D3) — 이 문서의
`depth_cap`을 바꾸면 scoring Tuning Knobs의 상호작용 행을 다시 본다.
**Example:** 웨이브 2에서 9칸 → 프로토타입 공식 `9 × 10 × (1 + 0.5 × 2)` = 180점. 칸당 점수·동시 줄 보너스 등 최종 공식은 점수 GDD가
확정한다. **해석기는 이 식을 계산하지 않는다** (규칙 20) — 웨이브 깊이가 이벤트에 정확히 실리는 것만 보장한다.

**F7. 배치별 시드 파생** (provisional — 시드 RNG ADR에서 확정)

The seed_for formula is defined as:

`rng_seed = hash32(stage_seed, STREAM_RESOLVER, placement_index)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stage_seed | int | 0 – 2³¹−1 | data file (스테이지 데이터) 또는 판 시작 시 파생 | 판 단위 시드 |
| STREAM_RESOLVER | int const | 고정 | constant (ADR) | 트레이·가챠 스트림과 분리하는 스트림 태그 |
| placement_index | int | 0 – 제한 조각 수 | calculated (판 진행 흐름) | 이 판의 몇 번째 배치인가 |

**Output Range:** 32비트 정수. 같은 판·같은 배치 순번이면 미리보기와 실제가 같은 값을 받는다. MVP에서는 결과에 영향이 없다 (규칙 24).
**Example:** `stage_seed = 1201`, 3번째 배치(`placement_index = 2`) → 미리보기 10회 재계산과 실제 커밋 모두 같은 `rng_seed`.

**F8. 해석 비용** (성능 예산의 근거 — TD 조건 "<1 ms 추정")

The resolve_cost formula is defined as:

`cell_ops ≈ waves × (2·W·H + |pending| + Σ_faces |target_f|)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| waves | int | 0–7 | calculated (F3) | 웨이브 수 |
| 2·W·H | int | 128 (8×8) | calculated | 웨이브마다 행·열 완성 판정 칸 읽기 |
| \|pending\| | int | 0–64 | calculated | 그 웨이브에서 지울 칸 |
| \|target_f\| | int | 0–15 (F4) | calculated | 얼굴별 CLEAR 대상·FILL 후보 칸 |

**Output Range:** 최악 근사 7 × (128 + 64 + 4 × 15) ≈ **1,764**회 칸 연산 + 이벤트 생성. 데스크톱 headless에서 ≪ 1 ms 예상(미측정).
미리보기는 앵커가 바뀔 때만 1회 부르므로 드래그 한 번에 최대 `anchor_count`(board-rules F1, 2×3 조각 42)회.
**Example:** 연쇄 3(웨이브 4), 얼굴 4개, 평균 대상 10칸 → 4 × (128 + 20) + 40 ≈ 630회.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 배치가 줄을 하나도 완성하지 않으면**: 이벤트는 `PLACED`, `CHAIN_END(chain_depth = 0, waves = 0)` 두 개뿐이고 `final_board = place(...)`.
- **If 배치로 행과 열이 동시에 완성되면**: 한 웨이브(웨이브 0)로 함께 지워진다. `WAVE_BEGIN.rows/cols`에 둘 다 실리고 교차 칸은 한 번만
  (board-rules F4: 15칸). "동시 줄"은 웨이브가 아니라 줄 수로 표현된다 — 보너스는 점수 GDD 소관.
- **If 같은 웨이브에서 얼굴 여러 개가 지워지면**: row-major 순서로 각각 발동한다 (규칙 9). 같은 크루 얼굴 2개도 각각 발동해 대상이 합쳐진다.
  `stage`는 모두 같은 값(k + 1)이다 — 동시 발동은 깊이를 올리지 않는다.
- **If 두 얼굴의 CLEAR 대상이 겹치면**: 합집합으로 한 번만 지운다. `CELLS_CLEARED.source_order`는 더 앞선 얼굴의 `order_index`다 (연출이 한 얼굴에서 뻗어 나가게 보이기 위함).
- **If 한 얼굴의 CLEAR 대상에 다른 얼굴이 있으면**: 그 얼굴은 다음 웨이브에서 지워지며 발동한다 — 도미노의 기본 동작.
- **If CLEAR 대상이 같은 웨이브에서 이미 지워진 칸이면**: 스냅샷에서 빈칸이므로 대상에서 빠진다 (빈 웨이브를 만들지 않음).
- **If 발동 얼굴의 CLEAR 대상이 모두 빈칸이고 FILL도 없으면**: 발동은 일어났으므로 `chain_depth`에 세지만 다음 웨이브가 없어 연쇄가 끝난다.
  `ABILITY_EFFECT.cells`는 빈 목록 — 연출은 "헛손질"을 보여 준다.
- **If FILL(알)이 줄을 완성하면**: 그 줄은 같은 발동의 CLEAR 대상과 합쳐 다음 웨이브에서 지워진다 (규칙 12). 그 줄의 얼굴은 다음 웨이브에서 발동한다.
- **If 같은 웨이브의 삐약 두 마리가 같은 줄을 고르면**: 앞선 얼굴(row-major)이 먼저 알을 낳고, 뒤 얼굴은 남은 빈칸만 본다 (규칙 16). 빈칸이 모자라면 덜 낳는다 (`eggs_laid` < count).
- **If `lay_eggs_in_own_line`의 행·열 모두에 빈칸이 없으면** (앞선 FILL이 얼굴 칸까지 채운 경우): 알 0개, `ABILITY_EFFECT.cells = []`. 오류 아님.
- **If 알이 같은 웨이브의 CLEAR 대상 위치에 놓이면**: 불가능 — CLEAR 대상은 스냅샷에서 *차 있던* 칸이고 FILL은 *빈* 칸에만 놓인다 (규칙 15·16).
- **If 웨이브 k = `depth_cap`에 얼굴이 있으면**: 칸은 지워지고 얼굴은 `FACE_FIZZLED(DEPTH_CAP)`, `DEPTH_CAP_REACHED` 1회 후 종료. FILL이 없으므로 새 완성 줄은 없다 (규칙 10).
  피즐 얼굴은 점수 GDD가 원하면 칸 점수로는 센다 (일반 칸과 같이 `CELLS_CLEARED`에 있음).
- **If 깊이 상한 직전 웨이브(k = `depth_cap` − 1)의 알이 줄을 완성하면**: 다음 웨이브 k = `depth_cap`에서 그 줄이 지워지고 그 안의 얼굴은 피즐한다 — 상한에서도 보드는 안정으로 끝난다.
- **If `depth_cap = 0`이면** (테스트·특수 스테이지): 웨이브 0만 지워지고 모든 얼굴이 피즐한다 — 일반 블록 퍼즐과 같은 동작.
- **If 얼굴 없는 조각(`crew_id = null`)·알이 지워지면**: 얼굴 수집에서 빠진다 (발동·피즐 이벤트 없음).
- **If 얼굴의 `crew_id`가 `ctx.crew_abilities`에 없으면** (예: 스테이지 초기 보드에 팀 밖 크루 얼굴): 로드 시 검증 오류 (규칙 18). 해석기는 팀이 아니라
  **크루 레지스트리 전체**의 능력 표를 받는다 — 스테이지가 팀 밖 크루 얼굴을 미리 깔 수 있게 하기 위함.
- **If `can_activate` 훅이 거짓이면** (얼어붙은 얼굴): 칸은 지워지고 `FACE_FIZZLED(SUPPRESSED)`. 그 웨이브에 발동 얼굴이 하나도 없으면 연쇄가 끝나고 `chain_depth`에 세지 않는다.
- **If `pre_clear` 훅이 `KEEP`을 돌려주면**: 칸은 남고 `CELL_MODIFIED`. 그 칸이 얼굴이면 발동하지 않는다(지워지지 않았으므로). 같은 웨이브에서 두 번 타격되어도 웨이브당 훅은 칸마다 1회만 호출한다.
- **If 완성 줄이 지울 수 없는 칸만으로 차 있으면**: 유효 완성 줄이 아니므로 무시 (규칙 11). 이런 줄은 board-rules 불변식 13을 깨므로 방해물 GDD가 데이터 검증으로 막아야 한다 — 해석기는 디버그 경고를 낸다.
- **If `resolve`가 `can_place = false`인 앵커로 호출되면**: assert (프로그래밍 오류). 미리보기는 그런 앵커에서 해석기를 부르지 않는다 (규칙 25).
- **If 웨이브 수가 `max_waves_guard`를 넘으면**: 정상 동작에서는 불가능(F3). 디버그 빌드 assert, 출시 빌드는 현재 보드로 즉시 `CHAIN_END` + 오류 로그.
- **If 미리보기 직후 실제 배치 결과가 미리보기와 다르면**: 버그다 (기둥 3). 같은 입력·같은 `rng_seed`를 넘기는지 확인하는 회귀 테스트가 AC-14다.
- **If 보드에 얼굴이 많아 한 배치로 상한까지 가면** (퇴화 전략 — "얼굴 모아 한 방"): 의도된 고숙련 플레이다 (컨셉 Key Dynamics "얼굴들을 일렬로 모아 두었다가").
  상한 6과 배율 상한 4.0(F6)이 보상 폭주를 막는다. 스테이지 제한 조각 수가 모으는 비용을 만든다 (스테이지 GDD).

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | Hard | 함수 7종, 칸 플래그 3종, `modifiers[]`, 행 먼저·row-major 반환 순서, 불변식 13 | Designed — 계약 일치 (아래 양방향성) |
| 시드 RNG (#3, ADR only) | Hard (계약) / MVP 실사용 없음 | `rng_seed` 정수, 스트림 분리 | 미작성 — 규칙 G가 provisional 계약 |
| 크루 정의 & 능력 (`crew-definition.md`) | Hard (데이터) | `crew_abilities` 표 — 프리미티브 조합·파라미터 | 미작성 — 해석기가 어휘를 소유하고 크루가 이를 따른다 (index상 크루 → 해석기 의존이 정방향; 해석기는 데이터만 받음) |
| 칸 종류 & 방해물 (`obstacles.md`) | Soft (훅 기본값으로 동작) | 훅 3종 구현 | 미작성 — 훅 지점은 이 문서 소유 |

**Downstream (이 시스템에 의존)** — 모두 아직 GDD 없음, 아래는 이 문서가 제안하는 계약 (provisional).

| 시스템 | 강도 | 쓰는 것 | 이 문서가 기대하는 것 |
|---|---|---|---|
| 점수 & 연쇄 배율 (`scoring.md`) | Hard | `WAVE_BEGIN`, `CELLS_CLEARED.wave`·칸 수, `CHAIN_END` | 깊이 배율(F6) 소유; 해석기에 점수 필드를 요구하지 않음 |
| 크루 정의 & 능력 (`crew-definition.md`) | Hard | 프리미티브 어휘(규칙 14), 계약(규칙 17), 검증(규칙 18) | 크루 6명 능력을 어휘 안에서 조합; 새 프리미티브가 필요하면 이 문서에 추가 요청 |
| 연쇄 미리보기 (`chain-preview.md`) | Hard | `resolve` 동일 호출, `events`·`summary` | 별도 판정 로직 없음; 앵커 변경 시에만 재계산 |
| 칸 종류 & 방해물 (`obstacles.md`) | Hard | 훅 지점 3종, 유효 완성 줄 규칙 | 지울 수 없는 칸만으로 된 줄이 생기지 않게 데이터 검증 |
| 스테이지 & 목표 (`stage-goals.md`) | Hard | `chain_depth`, `CELLS_CLEARED.cells`, `CELL_MODIFIED`, 스테이지 `stage_seed` 제공 | 목표 판정은 스테이지 소유 |
| 판 진행 흐름 (`round-flow.md`) | Hard | `resolve` 호출, `final_board` 커밋, `rng_seed` 파생(F7) | 해석 결과 커밋 후 연출 대기, 그 뒤 트레이 재충전·`no_moves` (board-rules 계약) |
| 연쇄 연출 재생기 (`chain-presentation.md`) | Hard | `events` 전체 | 재생만 — 보드 판정·상태 변경 금지 |
| 플레이 HUD · 오디오 · 튜토리얼 | Soft | `stage`, `DEPTH_CAP_REACHED`, 첫 `FACE_ACTIVATED` | — |

**양방향성**: board-rules의 Dependencies·Interactions는 이 시스템을 Hard downstream으로 적고 함수 6종(`place`는 판 진행 흐름 쪽으로 기재)과
불변식 13 보장·얼굴 발동 순서 정의를 기대한다 → 규칙 6·9·10이 이를 충족한다 (board-rules Q1 해소). systems-index의 Depends On에서
점수·크루 정의·미리보기·방해물·판 진행 흐름·연출은 이 시스템을 직접 의존으로 적어 일치한다. **불일치 1건**: 스테이지 & 목표는
`chain_depth`·지워진 칸을 읽지만 index Depends On에 "연쇄 해석기"가 없다 → 스테이지 GDD 작성 시 추가 필요 (Open Question Q6).
각 하위 GDD는 Dependencies에 이 문서를 upstream으로 적어야 한다.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — 시각 피드백이 핵심인 Gameplay 시스템이라 lean에서도 spawn 대상이지만 이 실행에는
> Agent 도구가 없어 생략. Art bible 미작성. Review manually before production.
> 해석기는 아무것도 그리지 않는다. 이 절은 **이벤트가 연출로 무엇을 읽히게 해야 하는가**만 정하고, 구체 연출(타이밍·파티클·컷인)은
> 연쇄 연출 재생기 GDD, 미리보기 표시는 연쇄 미리보기 GDD 소관이다.

| 이벤트 | 읽혀야 하는 것 | 근거 |
|---|---|---|
| `WAVE_BEGIN` | 웨이브마다 하나의 "박자" — 웨이브 k+1은 웨이브 k가 끝난 뒤 시작해 도미노 순서가 눈에 보인다. stage ≥ 2부터 "연쇄 N" 컷인 | 기둥 1, 프로토타입 컷인 |
| `CELLS_CLEARED` | 스티커가 들썩 → 떼어짐. `by = ABILITY` 칸은 `source_order` 얼굴에서 뻗어 나가는 방향으로 순차 떼어짐 | 기둥 1 "줄 지우기보다 압도적으로 시원" |
| `FACE_ACTIVATED` | 얼굴이 "툭" 튀어 오르며 능력 이름 컷인, 같은 웨이브 얼굴은 `order_index` 순서로 짧은 간격을 두고 | 기둥 3 (순서 번호가 미리보기와 같아야 함) |
| `ABILITY_EFFECT` (FILL) | 알이 "톡" 놓이고, 그 알로 완성된 줄이 다음 박자에 지워짐 — 재점화가 인과로 읽혀야 함 | 프로토타입 교훈 "판을 채우는 능력이 연쇄의 고리" |
| `FACE_FIZZLED` | 얼굴이 꾸벅 졸며 사라짐 (DEPTH_CAP) / 얼음에 갇혀 사라짐 (SUPPRESSED). 실패가 아니라 귀여운 마무리 | 기둥 5 |
| `DEPTH_CAP_REACHED` | "최대 연쇄!" 축하 연출 — 상한은 벌이 아니라 정점 | 기둥 1·5 |
| 오디오 | 웨이브 깊이에 따라 피치가 한 단계씩 올라가는 연쇄 SFX, 크루별 발동 음성/효과음. 사운드 명세·Android 지연은 오디오 GDD | 컨셉 Audio Needs |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:chain-resolver`
to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

| 목표 | 기준 | 소유 |
|---|---|---|
| 즉시 확정 | 놓기 → `resolve` 완료까지 ≤ 1프레임 (F8; 60fps 16.7ms 안, 목표 ≤ 1ms). 연출이 끝나기 전에 게임 상태는 이미 확정 | 이 문서 (AC-17) |
| 미리보기 반응 | 앵커 변경 프레임에 미리보기 갱신 (`resolve` 1회 + 표시). 같은 앵커에서는 재계산 0회 | 이 문서 (비용) / 미리보기·입력 GDD (트리거) |
| 도미노 박자 | 웨이브 간격 시작값 ≈ 0.5s (프로토타입 0.24s 떼어짐 + 0.3s 대기), 연쇄 6단 전체 ≤ 약 4s — "한 판 더" 템포를 깨지 않는 상한 | 연출 재생기 GDD (값), 이 문서 (`depth_cap`이 상한을 정함) |
| 스킵 가능 | 연출은 탭으로 빠르게 넘길 수 있어야 한다 — 상태가 이미 확정되어 있으므로 스킵은 재생 속도만 바꾼다 | 연출 재생기 · 판 진행 흐름 GDD |
| 결정성 체감 | 같은 판 같은 배치는 언제나 같은 연쇄 — 미리보기에서 본 "연쇄 3 예상"이 그대로 터진다 | 이 문서 규칙 2·3 |

턴 기반이라 시간 압박 피드백은 없다 (안티 기둥 "시간 압박 아님").

## UI Requirements

해석기 자체는 UI가 없다 (텍스트·화면 요소를 직접 만들지 않으며 현지화 문자열도 없다). 플레이어가 보는 연쇄 정보는 연쇄 미리보기·
연쇄 연출 재생기·플레이 HUD GDD가 `events`/`summary`로부터 만든다. 크루 능력 이름 문자열은 크루 정의 GDD가 소유한다
(`ability_id` → 현지화 키). 따라서 이 시스템 단독의 UX Flag는 없다 — 게임플레이 화면 UX 스펙은 board-rules의 UX Flag가 이미 요구한다.

## Cross-References

| 이 문서가 참조하는 것 | 대상 문서 | 종류 | 상태 |
|---|---|---|---|
| 함수 7종, 플래그 3종, `modifiers[]`, 행 먼저·row-major 순서, 불변식 13, `TILE(origin=EGG)`, F4·F5 | `design/gdd/board-rules.md` § Core Rules 2·8–13, Formulas F4·F5 | 상위 계약 | 일치 — 불변식 13 보장(규칙 10)·발동 순서(규칙 9)로 board-rules Q1 해소 |
| 얼굴 1칸, 냥이 십자·곰곰 3×3·삐약 알 3개(더 꽉 찬 줄, 가까운 순), 알 재점화, 깊이 상한 6, +50%/단계, 동시 발동 순서는 해석기 GDD에서 정의, 미리보기와 처리 공유 | `design/gdd/game-concept.md` § Core Mechanics 2–3 | 규칙 출처 | 일치 |
| 순수 함수(보드+배치 → 이벤트 목록), 연출은 재생만, 주입 시드 RNG, 깊이 상한 6 데이터 + 상한 동작 정의, 미리보기·런타임 공유, 앵커 변경 시에만 재계산, 크루 = 프리미티브 조합 Custom Resource | `production/gate-checks/gate-check-systems-design-2026-11-07.md` § TD-PHASE-GATE 조건 | 기술 조건 | 일치 (구현 형태는 ADR) |
| `simulate`, `clearCells`, `abilityRange`, `chickEggs`의 동작 | `prototypes/sticker-place-concept/prototype.html`, `REPORT.md` | 검증된 시작값 | 일치 — 단 알이 채운 줄 처리 순서만 변경 (D4). 프로토타입은 throwaway, 코드 재사용 금지 |
| 프리미티브 계약 소유·순환 차단, 시드 RNG = 해석기 GDD 한 절 + ADR, 칸 종류 훅 지점 소유 | `design/gdd/systems-index.md` § Circular Dependencies, Recommended Design Order 주석 | 경계 | 일치 |
| 깊이별 점수 배율, 칸당 점수 | `design/gdd/scoring.md` (미작성) | 하위 계약 | provisional (F6 참조) |
| 크루 6명 능력 조합, `ability_id` 문자열 | `design/gdd/crew-definition.md` (미작성) | 하위 계약 | provisional |
| 훅 3종 구체 동작, 지울 수 없는 줄 검증 | `design/gdd/obstacles.md` (미작성) | 하위 계약 | provisional |
| 미리보기 표시 정보량, 재계산 트리거 | `design/gdd/chain-preview.md`, `design/gdd/placement-input.md` (미작성) | 하위 계약 | provisional |
| `rng_seed` 파생, `final_board` 커밋, 연출 대기 | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| 연쇄 N 목표, 특정 칸 목표, `stage_seed` | `design/gdd/stage-goals.md` (미작성) | 하위 계약 | provisional |
| 이벤트 재생 타이밍, 피즐·상한 연출 | `design/gdd/chain-presentation.md` (미작성) | 하위 계약 | provisional |

## Acceptance Criteria

> **qa-lead 검토 (2026-11-07, 사용자 위임 — 질문 없이 진행)**. 각 AC 앞 태그 = 스토리 유형 → 증거 위치·게이트:
> `[Logic]` 자동 단위 테스트 `tests/unit/<system>/<system>_<feature>_test.gd` (BLOCKING) · `[Integration]` `tests/integration/<system>/` (BLOCKING) ·
> `[UI]` 화면별 보존 스크린샷 `production/qa/evidence/` (BLOCKING) · `[Visual/Feel]` 보존 스크린샷/녹화 + 리드 서명 (BLOCKING) · `[Config]` 데이터 로드·스모크 (ADVISORY) ·
> `[Perf]` `tests/performance/<system>/` — 시간 측정은 결정적이지 않아 CI 차단 스위트 밖에서 돌리고 임계값 초과 시 실패로 보고 (ADVISORY; 5개 스토리 유형 밖의 qa-lead 추가 분류) ·
> `[Playtest]` `/playtest-report` 설계 검증 (ADVISORY — 스토리 완료 조건 아님).
> **결정성**: 테스트 실행 중 보드를 무작위 생성하지 않는다. 픽스처는 커밋된 파일 `tests/fixtures/boards/*.txt`(보드 문자열)와 `tests/fixtures/parity/`이며,
> "시드 판"은 오프라인에서 한 번 생성해 커밋한 파일이다. 모든 `stage_seed`·`rng_seed`는 픽스처에 적는다.
> **불변식 (미리보기 = 런타임 = 점수)**은 하나의 테스트 `tests/integration/preview_parity/preview_parity_test.gd`가 소유하고 정의는 chain-preview AC-P02다 —
> 다른 GDD의 같은 AC는 그 테스트의 단언 조각을 가리킬 뿐 별도 테스트를 만들지 않는다.
> debug assert 검증은 gdUnit4 `assert_error(...)`로 포착한다 (포착되지 않으면 구현이 assert 직전 `push_error`를 내고 `is_push_error`로 확인).
> 이 GDD의 테스트 파일: `tests/unit/chain_resolver/chain_resolver_{basic,order,fill,depth_cap,primitives,events,rng}_test.gd`.
> 픽스처는 board-rules와 같은 보드 문자열 팩토리(`.` 빈칸, `#` 조각 칸, `E` 알, 얼굴은 크루 문자 `N` 냥이 · `G` 곰곰 · `P` 삐약)와
> 테스트 전용 능력 표(냥이 `clear_cross(−1)`, 곰곰 `clear_area(1)`, 삐약 `lay_eggs_in_own_line(3, fuller, nearest)`)로 만든다 — 실제 크루
> 데이터가 바뀌어도 해석기 테스트가 깨지지 않게 한다. 기대값은 커밋된 이벤트 목록 골든 파일(`tests/fixtures/parity/<fixture>.events.json`)과 비교한다.
> 아래 AC-01·03·04·04b·07·08의 픽스처는 불변식 테스트(chain-preview AC-P02)의 명명 경계 픽스처로 재사용된다.

**규칙 (Section C)**

- **AC-01 [Logic] (규칙 1·6, 줄 없음)** — **GIVEN** 빈 8×8 보드와 1칸 조각, **WHEN** `resolve`, **THEN** 이벤트는 `PLACED`, `CHAIN_END(chain_depth=0, waves=0)` 2개이고
  `final_board`는 `place` 결과와 칸 단위로 같다.
- **AC-02 [Logic] (규칙 2, 순수성)** — **GIVEN** 보드 B, **WHEN** `resolve(B, …)`를 부르면, **THEN** B는 호출 전과 칸 단위로 같다. **AND** 같은 입력으로 두 번 부르면
  `events`가 `seq`·필드까지 동일하다.
- **AC-03 [Logic] (규칙 6·9, 기본 도미노)** — **GIVEN** 7번 행이 (7,3)만 빈 보드, (7,5)에 냥이 얼굴, 5번 열의 (4,5)에 곰곰 얼굴(그 밖의 얼굴 없음),
  **WHEN** (7,3)에 1칸 조각을 놓으면, **THEN** 웨이브 0에서 7번 행이 지워지고 냥이 발동(stage 1) → 웨이브 1에서 십자 대상과 함께 (4,5) 곰곰이 지워져
  발동(stage 2) → 웨이브 2에서 (4,5) 주변 3×3의 차 있는 칸이 지워지고 종료, `chain_depth = 2`, `waves = 3`. **AND** 전체 `events`가 골든 `domino_ng.events.json`과 같다.
- **AC-04 [Logic] (규칙 9, 동시 얼굴 순서)** — **GIVEN** 한 번에 지워지는 행에 얼굴 3개 (7,6) 곰곰, (7,1) 냥이, (7,4) 삐약, **WHEN** `resolve`, **THEN** `FACE_ACTIVATED.order_index`
  1·2·3이 각각 (7,1)·(7,4)·(7,6)이고 세 얼굴 모두 `stage = 1`.
- **AC-04b [Logic] (규칙 9·15, 동시 얼굴 — 중복 발동 없음)** — **GIVEN** 행 7과 열 3이 함께 완성되고 교차 칸 (7,3)이 냥이 얼굴, **WHEN** `resolve`, **THEN** (7,3)의
  `FACE_ACTIVATED`는 정확히 1개. **AND** 같은 웨이브에서 줄과 능력 범위에 동시에 든 얼굴(`by = BOTH`)도 정확히 1회 발동한다.
- **AC-05 [Logic] (규칙 15, CLEAR 스냅샷)** — **GIVEN** 같은 웨이브에서 냥이와 삐약이 발동하고 삐약의 알 칸이 냥이 십자 범위 안, **WHEN** `resolve`, **THEN** 그 알은
  다음 웨이브 `CELLS_CLEARED`에 없다 (알이 줄을 완성하는 경우는 AC-07).
- **AC-06 [Logic] (규칙 16, FILL 순차)** — **GIVEN** 같은 행에서 지워지는 삐약 2마리, 그 행이 빈칸만 남음, **WHEN** `resolve`, **THEN** 앞 삐약(row-major)의 알 3개가 먼저 놓이고
  뒤 삐약은 남은 빈칸에서만 고르며 두 `ABILITY_EFFECT.cells`가 겹치지 않는다.
- **AC-07 [Logic] (규칙 12, 알 재점화)** — **GIVEN** 삐약 얼굴 (3,5), (3,5) 삐약이 5번 열 줄 지우기로 지워진 직후 3번 행의 빈칸이 (3,1)·(3,5) 2개뿐, (3,2)에 냥이 얼굴,
  **WHEN** 삐약 발동, **THEN** 알 2개로 3번 행이 완성되어 다음 웨이브의 `WAVE_BEGIN.causes`에 `LINE`이 있고 rows = [3], 그 웨이브에서 (3,2) 냥이가 stage 2로 발동한다.
- **AC-08 [Logic] (규칙 10, 상한 도달)** — **GIVEN** 연쇄 7단이 가능한 픽스처와 `depth_cap = 6`, **WHEN** `resolve`, **THEN** stage 1~6 발동, 웨이브 6의 얼굴은 모두
  `FACE_FIZZLED(DEPTH_CAP)`, `DEPTH_CAP_REACHED` 정확히 1회, `CHAIN_END.cap_reached = true`, `final_board`에 완성 줄 0개.
  **AND** `depth_cap = 7`로 같은 픽스처를 풀면 `cap_reached = false`, `DEPTH_CAP_REACHED` 0회 (상한 직전 경계).
- **AC-09 [Logic] (규칙 I, 상한은 데이터)** — **GIVEN** AC-08 픽스처, **WHEN** 데이터만 `depth_cap = 3`으로 바꾸면, **THEN** 코드 변경 없이 `chain_depth = 3`, 웨이브 3에서 피즐.
  **AND** `depth_cap = 0`이면 웨이브 0의 모든 얼굴이 피즐하고 `chain_depth = 0`.
- **AC-10 [Logic] (규칙 8, 종료)** — **GIVEN** 커밋된 고정 픽스처 200개(얼굴 밀집 보드 포함), **WHEN** `resolve`, **THEN** 모두 `waves ≤ min(depth_cap, F_board) + 1`이고
  `max_waves_guard`에 닿지 않는다.
- **AC-11 [Logic] (규칙 14·18, 프리미티브 어휘·검증)** — **GIVEN** 얼굴 (0,0)에서 프리미티브 7종 각각, **WHEN** 대상을 계산하면, **THEN** 보드 밖 칸이 없고 F4 크기와 일치한다
  (모서리 `clear_area(1)` = 4칸). **AND** 알 수 없는 id, `radius = −1`, 빈 능력 목록 데이터는 로드가 거부되고 오류에 크루 id·위반 조건이 적힌다.
- **AC-12 [Logic] (규칙 19, 이벤트 스키마)** — **GIVEN** AC-03 픽스처, **WHEN** `events`를 검사하면, **THEN** `seq`는 0부터 빈틈없이 증가, 웨이브 안 순서가 규칙 19와 같고,
  모든 `CELLS_CLEARED.cells`가 row-major, 모든 칸이 정확히 한 번만 지워진다(웨이브를 가로질러 중복 없음).
- **AC-13 [Logic] (규칙 21, 훅 기본값·주입)** — **GIVEN** 테스트 훅 `can_activate = false`(특정 modifier), **WHEN** 그 얼굴이 지워지면, **THEN** `FACE_FIZZLED(SUPPRESSED)`이고
  해석기 코드 변경 없음. **AND** 훅을 주입하지 않으면 AC-03 골든과 같다.
- **AC-23 [Logic] (규칙 6 전제, 무효 배치)** — **GIVEN** `can_place = false`인 (조각, 앵커) — 겹침 1건, 보드 밖 1건, **WHEN** `resolve`, **THEN** 각각 debug assert가 나고
  입력 보드는 바뀌지 않는다 (해석기는 거짓 배치를 해석하지 않는다).

**미리보기·RNG (TD 조건)**

- **AC-14 [Integration] (규칙 3, 미리보기 = 결과)** — 불변식 테스트 `tests/integration/preview_parity/preview_parity_test.gd`(정의: chain-preview AC-P02)의
  **해석기 단언**: 모든 사례에서 미리보기 경로와 실제 커밋 경로의 `ChainResult`가 같다 — `events`(`seq`·모든 필드), `final_board` 칸 단위, `chain_depth`, `waves`, `cap_reached`.
- **AC-15 [Logic] (규칙 22–24, RNG)** — **GIVEN** AC-03 픽스처, **WHEN** `rng_seed`를 0, 1, 2³¹−1로 바꿔 해석하면, **THEN** 결과가 모두 같다 (MVP 프리미티브는 RNG 미사용).
  **AND** 해석기 소스에 전역 `randi`/`randf`/`randomize` 호출이 없다 (정적 검사, 같은 테스트 파일).
- **AC-22 [Logic] (F7)** — **GIVEN** `stage_seed = 1201`, **WHEN** `seed_for(1201, 2)`를 미리보기 쪽과 커밋 쪽에서 각각 부르면, **THEN** 같은 값.
  **AND** `placement_index` 0–99의 100개 값이 서로 다르다. (시드 RNG ADR 확정 후 해시 골든값 추가)

**공식 (Section D)**

- **AC-17 [Perf] (F8, 성능)** — **GIVEN** 연쇄 6단 + 얼굴 밀집 최악 근사 픽스처, **WHEN** headless 데스크톱에서 `resolve` 1,000회, **THEN** 평균 ≤ 1ms/회.
  실기기 프레임 예산은 chain-preview AC-P17이 소유한다.
- **AC-18 [Logic] (F1·F2·F3)** — **GIVEN** AC-03·AC-08 픽스처, **WHEN** 요약을 읽으면, **THEN** `chain_depth`는 2·6, `waves`는 3·7, 모든 `FACE_ACTIVATED.stage = wave + 1`.
- **AC-19 [Logic] (F4)** — **GIVEN** 빈 8×8 보드와 얼굴 (3,5), **WHEN** `clear_cross(−1)`, `clear_area(1)`, `clear_diagonals(−1)` 대상 크기를 구하면, **THEN** 15, 9, 12 (주대각 6 + 반대각 7 − 얼굴 1).
- **AC-20 [Logic] (F5)** — **GIVEN** 삐약 (3,5), 3번 행 빈칸 {(3,1),(3,5)}, 5번 열 빈칸 4개, **WHEN** `lay_eggs_in_own_line(3, fuller, nearest)`, **THEN** 알은 [(3,5), (3,1)] 순서로 2개.
  **AND** 행·열 빈칸 수가 같으면 행을 고른다.
- **AC-21 [Logic] (F6 인계)** — **GIVEN** AC-03·AC-08 픽스처의 `events`, **WHEN** 검사하면, **THEN** 모든 `CELLS_CLEARED`에 정수 `wave`가 있고 그 값이 직전 `WAVE_BEGIN.wave`와 같다.
  **AND** 이벤트 스키마에 점수 필드가 없다. 점수 값 검증은 scoring AC.

> 삭제: 이전 AC-16(재계산 트리거 횟수)은 chain-preview AC-P13·placement-input AC-07과 중복 — 소유는 chain-preview AC-P13.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 깊이 상한 6이 실제로 자주 닿는가, 닿으면 피즐 얼굴이 "손해"로 느껴지는가 — **부분 해소**: 점수 쪽은 scoring D6(`fizzle_points` = 0 노브)로 정함. 빈도 추정(systems-designer 리뷰, 기본 팀·무작위 배치): 줄을 지운 배치 중 상한 6 도달 ≈ 1–2% — 드묾. 체감은 T0 플레이테스트 | systems-designer · 점수 GDD | T0 플레이테스트 |
| Q2 | 동시 얼굴 순서: row-major vs "트리거에 가까운 순"(연출상 더 자연스러울 수 있음). MVP는 row-major 고정 (D3) | game-designer · 연출 GDD | `/design-system chain-presentation` |
| Q3 | ~~크루 6명을 MVP 어휘 7종으로 "새 동작" 6개로 만들 수 있는가~~ — **해소**: crew-definition 규칙 6 (기존 7종만으로 6명 구성) | game-designer · 크루 정의 GDD | 해소 (crew-definition) |
| Q4 | RNG 프리미티브를 허용할 것인가 (시드로 미리보기에 보이면 기둥 3 위반이 아닌가) | creative-director · game-designer | T2 크루 확장 전 |
| Q5 | 이벤트 목록을 리플레이/버그 리포트용으로 저장할 것인가 (결정적이므로 배치 기록만으로 재현 가능) | lead-programmer | 세이브 / ADR |
| Q6 | systems-index에 스테이지 & 목표 → 연쇄 해석기 직접 의존 추가 (`chain_depth`·지워진 칸 사용) | producer · `/map-systems` | 스테이지 GDD 작성 전 |
| Q7 | 첫 critical ADR: 해석기 모듈 형태, 프리미티브 표현(Custom Resource vs enum+Dictionary), 시드 스트림 분리, 4.7 typed-return override 규칙 영향 | technical-director | `/architecture-decision` (이 GDD 직후) |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(숫자 규칙 있음)·Edge Cases·Dependencies·AC + 필수 선택 섹션(Visual/Audio·Game Feel — Gameplay 필수, Cross-References — 의존 있음) + UI Requirements·Open Questions ("All of them" 권장안). Player Fantasy·Tuning Knobs 생략 | Tuning Knobs 섹션 추가 — tier 규칙 위반; 데이터 값 표를 Core Rules I에 둠 |
| D2 | 해석기 입력 | 안정 보드 + 조각 + 앵커 (`place`를 해석기 안에서 호출) — TD 조건 "board + placement → event list" 그대로, 미리보기가 한 번의 호출로 끝남 | 배치된 보드를 입력으로 받기 — 미리보기·판 흐름이 각자 `place`를 불러 경로가 둘로 갈림 |
| D3 | 동시 얼굴 순서 | row-major (board-rules `clear_cells` 반환 순서와 동일) | 트리거와의 거리순 — 동률 규칙이 더 필요하고 미리보기 번호가 읽기 어려움 (Q2); placement_id 순 — 플레이어에게 안 보이는 기준 |
| D4 | 알이 채운 줄 처리 | 같은 발동의 CLEAR 대상과 **합쳐** 다음 웨이브로 (규칙 12) — 알로 완성한 줄이 능력 지우기에 깨지지 않고 항상 터짐, 웨이브 = 깊이로 단순 | 프로토타입 방식(능력 지우기 먼저, 줄 판정 나중) — 알 재점화가 능력 대상 위치에 따라 사라져 예측이 어려움 |
| D5 | 깊이 상한 동작 | 상한 웨이브는 지우되 얼굴은 피즐, FILL 없음 → 불변식 13 자동 보장 | 상한 웨이브의 얼굴을 지우지 않고 남김 — 그 줄이 완성 상태로 남아 불변식 위반; 상한에서 남은 줄도 안 지움 — 같은 위반 |
| D6 | CLEAR/FILL 평가 | CLEAR는 지우기 직후 스냅샷 합집합, FILL은 순차 즉시 적용 (프로토타입과 같음) | 얼굴마다 순차 전부 적용 — 얼굴 순서가 CLEAR 결과까지 바꿔 미리보기가 복잡해짐 |
| D7 | 점수 위치 | 해석기는 점수를 계산하지 않음; 깊이·칸 수·줄 수만 이벤트로 (F6은 참조) | 이벤트에 점수 포함 — 점수 튜닝마다 해석기·골든 테스트 변경 |
| D8 | 프리미티브 어휘 | MVP 7종 (CLEAR 5 · FILL 2), `clear_pattern`·`lay_eggs_pattern`을 일반화 탈출구로 | 크루별 전용 함수 — "새 크루 = 새 코드", 순환 의존 재발 |
| D9 | RNG | 지역 스트림 + 배치별 시드 파생, MVP 프리미티브는 RNG 미사용 | 전역 RNG — 미리보기 ≠ 결과; RNG 능력 MVP 포함 — 안티 기둥 위반 |
| D10 | 방해물 확장 | 훅 3종(`pre_clear`, `can_activate`, `target_filter`) + 기본값 | 칸 종류별 분기 — 방해물마다 해석기 수정 |
| D11 | 능력 표 범위 | 팀이 아니라 크루 레지스트리 전체 | 팀 3명만 — 스테이지가 팀 밖 크루 얼굴을 미리 깔 수 없음 |
| D12 | 발동했지만 효과 없는 얼굴 | `chain_depth`에 셈 (얼굴은 발동했고 플레이어가 컷인을 봄) | 세지 않음 — 화면의 "연쇄 N"과 요약이 어긋남 |
| D13 | 미리보기 배지 숫자 (systems-designer 리뷰, chain-preview Q1 해소) | 배지 = `stage`, `order_index`는 연출 순서·`source_order` 전용 — 규칙 9·이벤트 표·규칙 26 문구 수정 | 배지 = `order_index` — 동시 발동 얼굴에 1·2·3이 붙어 "3단 연쇄"로 오독 (chain-preview D3) |
| D14 | F6 사본 정렬 (systems-designer 리뷰, scoring Q6 해소) | scoring F2의 정수식·변수명(`depth_step_pct`, 상한 `depth_mult_max_pct`)으로 교체 | float `depth_step_bonus` 유지 — 소유 문서와 이름·상한 불일치 |
