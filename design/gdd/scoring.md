# 점수 & 연쇄 배율 (Scoring & Chain Multiplier)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 1 도미노의 손맛 · 기둥 3 보이는 연쇄

## Summary

연쇄 해석기가 낸 이벤트 목록을 읽어 배치 한 번의 점수를 매기는 정수 순수 함수와 스테이지 누계를 정의한다 — 놓은 칸당 1점,
지운 칸당 10점 × 깊이 배율(웨이브마다 +50%, 상한 ×4.0) × 여러 줄 배율(줄당 +100%, 줄 칸에만), 얼굴 발동마다 20점 × 깊이 배율.
플레이어에게는 "도미노가 한 단계 더 이어질수록 숫자가 확실히 커지고, 미리보기에서 본 점수가 그대로 들어온다"는 보상 규칙이며,
스테이지 점수 목표·별 기준·HUD·기록의 입력이다 (기둥 1·3). 모든 값은 `ScoringRules` 데이터 노브다.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `연쇄 해석기 & 능력 프리미티브` (upstream), `보드 & 조각 규칙` (간접) — downstream: 스테이지 & 목표, 판 진행 흐름, 플레이 HUD, 연쇄 미리보기, 연쇄 연출 재생기, 스테이지 진행 & 해금

## Overview

점수 & 연쇄 배율은 **연쇄 해석기의 이벤트 목록을 읽어 배치 한 번의 점수를 매기는 순수 함수**
`score_placement(events, rules) → ScoreBreakdown`과, 한 판(스테이지 시도) 동안 그 점수를 더해 가는 누계 `stage_score`를 소유한다.
점수는 세 갈래다 — 놓은 칸 수에 주는 **배치 점수**, 지워진 칸마다 주고 웨이브 깊이에 따라 커지는 **지우기 점수**(깊이 배율 +50%/단계,
같은 웨이브의 여러 줄 보너스), 얼굴 하나가 발동할 때마다 주는 **발동 점수**. 플레이어에게 이 시스템은 "도미노가 한 단계 더 이어질수록
숫자가 눈에 띄게 커진다"는 보상의 언어이며(기둥 1), 미리보기가 같은 함수를 같은 이벤트에 적용하므로 "놓기 전에 본 예상 점수가
그대로 들어온다"(기둥 3). 해석기는 점수를 모르고(chain-resolver 규칙 20), 점수 시스템은 보드를 판정하지 않는다 — 이벤트만 읽는다.
스테이지 & 목표(점수 목표·별 기준), 플레이 HUD, 결과 화면, 기록이 `stage_score`를 쓴다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No` (`docs/architecture/adr-*.md`
없음. 엔진 도메인 Scripting — `docs/engine-reference/godot/modules/scripting.md` 없음: 엔진 기능에 기대지 않는 정수 규칙 로직이라 feasibility는 엔진 참조와 대조하지 않았다) · Fantasy `[A] Yes`이지만 standard tier라 Player Fantasy 섹션은 생략 — 정서 목표는 Game Feel 절에 둔다. 구현 형태(정적 함수 모듈,
`ScoringRules` Custom Resource)는 → ADR 대상 (연쇄 해석기 critical ADR에 함께 실어도 된다).

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` (Section 6 라우팅: Gameplay → 규칙 시스템) not consulted —
> Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 점수 함수 계약**

1. **입출력** — `score_placement(events, rules) → ScoreBreakdown`.
   - 입력: 연쇄 해석기 `ChainResult.events` 한 벌(배치 1회분), `rules` = `ScoringRules` 데이터(Tuning Knobs 표의 값 전부).
   - 출력: `ScoreBreakdown` = { `placement_points`, `waves[]`(웨이브마다 {`wave`, `line_count`, `line_cells`, `ability_cells`,
     `depth_mult_pct`, `line_mult_pct`, `clear_points`, `activation_points`}), `total` }. `total`은 F5.
2. **순수성** — 이벤트와 `rules`만 읽는다. 보드·트레이·스테이지·시간·전역 상태를 읽지 않는다. **정수 연산만** 쓴다(배율은 백분율 정수,
   나눗셈은 웨이브 단위로 한 번, 내림). 같은 입력 → 같은 `ScoreBreakdown`. 해석기와 같은 이유(플랫폼 간 결정성, 미리보기 = 결과).
3. **단일 구현** — 판 진행 흐름(실제 배치)과 연쇄 미리보기(예상 점수)가 **같은 `score_placement`**를 같은 이벤트에 적용한다. 미리보기용
   근사 점수 계산은 금지다. 연출 재생기·HUD는 `ScoreBreakdown`의 웨이브별 값을 *보여 주기만* 하고 다시 계산하지 않는다.
4. **이벤트 외 정보 금지** — 점수에 필요한 사실은 모두 이벤트에 있다: 놓은 칸 수(`PLACED.cells`), 웨이브 깊이(`wave`), 줄 수
   (`WAVE_BEGIN.rows`·`cols`), 칸별 지워진 이유(`CELLS_CLEARED.cells[].by`), 발동(`FACE_ACTIVATED`). 해석기 이벤트에 점수 필드를 추가해
   달라고 요구하지 않는다 (chain-resolver D7).

**B. 점수의 세 갈래**

5. **배치 점수** — `PLACED.cells`의 칸 수 × `place_points_per_cell` (F1). 줄을 못 지운 배치도 점수가 0이 아니게 한다 — 프로토타입의
   "+칸 수"와 같다. 배율을 받지 않는다.
6. **지우기 점수** — 웨이브 k마다 그 웨이브 `CELLS_CLEARED.cells[]`의 칸을 두 부류로 센다:
   - **줄 칸** `N_line(k)` = `by ∈ {LINE, BOTH}`인 칸 — 깊이 배율 × **여러 줄 배율**을 받는다.
   - **능력 칸** `N_ab(k)` = `by = ABILITY`인 칸 — 깊이 배율만 받는다.
   웨이브 점수는 F4. 얼굴 칸·알 칸·얼굴 없는 조각 칸·피즐한 얼굴 칸은 모두 같은 "칸"이다(종류별 가중치 없음, MVP).
   `kept[]`(훅 `pre_clear`가 `KEEP`한 칸)과 `CELL_MODIFIED`는 지워지지 않았으므로 지우기 점수가 없다.
7. **깊이 배율** — 웨이브 k의 칸은 `depth_mult_pct(k)`(F2)를 받는다: 시작값 100% + 50%/단계, 상한 400%. 웨이브 번호 = 깊이
   (chain-resolver 규칙 5)이므로 웨이브 0(배치가 완성한 줄)은 ×1.0, 첫 능력이 지운 웨이브 1은 ×1.5 … 프로토타입 `1 + depth × 0.5`와 같다.
8. **여러 줄 배율** — 웨이브 k의 유효 완성 줄 수 `L(k) = |WAVE_BEGIN.rows| + |WAVE_BEGIN.cols|`가 2 이상이면 그 웨이브의 **줄 칸**은
   `line_mult_pct(L)`(F3)를 받는다: 시작값 줄당 +100% (2줄 ×2, 3줄 ×3 — 프로토타입 `× lineCount`와 같다). 웨이브 0뿐 아니라 알이 줄을
   여러 개 완성한 뒤의 웨이브에도 똑같이 적용한다 (줄은 줄이다). 능력 칸에는 적용하지 않는다 — 프로토타입에서도 능력 웨이브는 `lineCount = 1`.
9. **발동 점수** — `FACE_ACTIVATED` 하나마다 `activation_points_base × depth_mult_pct(k) / 100` (k = 그 얼굴이 지워진 웨이브 = `stage − 1`).
   "얼굴이 터졌다"는 사건 자체를 보상한다 (systems-index "얼굴 발동 점수"). `FACE_FIZZLED`(DEPTH_CAP·SUPPRESSED)에는 발동 점수가 없고
   `fizzle_points`(시작값 0)만 준다 — 피즐 얼굴 칸은 이미 상한 배율(×4.0)의 지우기 점수를 받는다 (chain-resolver Q1 해소, D6).
10. **배치 총점** — `total = placement_points + Σ_k (clear_points(k) + activation_points(k)) + fizzle_points × 피즐 수` (F5).
    배치 하나의 점수는 해석기 결과가 커밋될 때 **한 번에** `stage_score`에 더해진다.

**C. 누계와 소비**

11. **`stage_score`** — 스테이지 시도 시작(첫 진입·재시도) 때 0, 배치가 커밋될 때마다 `+= total`. 음수가 되지 않는다(감점 규칙 없음).
    상한 없음 — 64비트 정수(GDScript `int`)로 F6 상한이 충분히 들어간다.
12. **점수 확정 시점** — 판 진행 흐름이 `final_board`를 커밋하는 그 순간 `stage_score`도 확정된다(연출 재생 전). 연출이 스킵되어도 점수는 같다.
    HUD는 웨이브 재생 박자에 맞춰 숫자를 올려 *보여 줄* 뿐이다 (Game Feel).
13. **기록 대상** — 결과 화면·스테이지 진행은 `stage_score`와 시도 중 최대 `placement total`(한 방 최고점)을 읽는다. 최고 기록 저장은 스테이지 진행
    & 해금 GDD 소관. 별 기준·점수 목표 수치는 스테이지 & 목표 GDD가 스테이지 데이터로 정한다 — 이 문서는 수치를 정하지 않고 계산법만 정한다.
14. **크루별·과금 보정 없음 (MVP)** — 크루 종류, 크루 레벨, 등급은 점수에 영향을 주지 않는다. 같은 배치는 누가 했든 같은 점수 — 안티 기둥
    "과금 = 수치 우위" 방지. T2 레벨업(+20% 상한)이 점수에 닿을지는 크루 레벨업 GDD가 결정하며(Open Question Q3), 닿더라도 이 문서의
    공식에 항을 추가하는 방식으로만 한다.

### States and Transitions

`score_placement`는 상태가 없다. 누계 `stage_score`의 상태는 아래 표뿐이며, 전이를 일으키는 쪽은 판 진행 흐름이다.

| 상태 | 들어오는 조건 | 하는 일 | 나가는 조건 |
|---|---|---|---|
| `IDLE` | 앱 시작, 스테이지 밖 | `stage_score` 없음 | 스테이지 시도 시작 → `ACTIVE` |
| `ACTIVE` | 스테이지 시도 시작 / 재시도 | `stage_score ← 0`, `best_placement ← 0` | 배치 커밋 → `ACTIVE`(누계 갱신) · 시도 종료(클리어·실패·포기) → `FINAL` |
| `FINAL` | 시도 종료 | 값 동결, 스테이지 & 목표·결과 화면·진행 기록이 읽음 | 재시도 → `ACTIVE` · 나가기 → `IDLE` |

미리보기는 상태를 바꾸지 않는다 — 예상 점수는 `ScoreBreakdown`만 만들고 버린다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 연쇄 해석기 | 해석기 → 점수 | `PLACED.cells`, `WAVE_BEGIN.rows/cols`, `CELLS_CLEARED.wave`·`cells[].by`, `FACE_ACTIVATED.stage`, `FACE_FIZZLED` | 해석기 (이벤트 스키마) / 점수 (해석 방법) |
| 판 진행 흐름 | 판 흐름 → 점수 | 커밋 시 `score_placement` 호출, 시도 시작·종료 신호 | 판 진행 흐름 (호출 타이밍) / 점수 (누계 규칙) |
| 연쇄 미리보기 | 미리보기 → 점수 | 가상 배치 `events`로 같은 함수 호출 → 예상 `total`·웨이브별 값 | 점수 (값) / 미리보기 (표시 여부·형태) |
| 스테이지 & 목표 | 점수 → 스테이지 | `stage_score` (점수 목표 판정, 별 기준) | 스테이지 (목표·별 수치) |
| 플레이 HUD | 점수 → HUD | `stage_score`, 웨이브별 `clear_points`·배율 (연출 박자에 맞춘 증가 표시) | HUD GDD (표시) |
| 연쇄 연출 재생기 | 점수 → 연출 | 웨이브별 `clear_points` (떠오르는 "+N" 숫자) | 연출 GDD |
| 스테이지 진행 & 해금 · 결과 화면 | 점수 → 진행 | 시도 종료 `stage_score`, `best_placement` | 진행 GDD (저장) |
| 무한 모드 · 월드맵 & 기록 (T3) | 점수 → | 같은 함수·누계 재사용 | 각 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어
> 생략. Review manually before production. 시작값은 프로토타입(`prototypes/sticker-place-concept/prototype.html` `place`·`clearCells`)
> 검증값을 그대로 옮겼고, 새로 더한 값은 `activation_points_base` 하나뿐이다 (D5). 모든 식은 정수 연산이다 — 배율은 백분율 정수(`150` = ×1.5).

**F1. 배치 점수**

The placement_points formula is defined as:

`placement_points = n_placed × place_points_per_cell`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n_placed | int | 1 – `max_piece_cells` (6) | calculated (`PLACED.cells`의 길이) | 이번에 놓은 조각의 칸 수 |
| place_points_per_cell | int | 0 – 5 (시작 1) | data file (`ScoringRules`) | 놓은 칸 하나당 점수 |

**Output Range:** 1 ~ 6 (시작값 기준). 0이면 배치 점수 없음. **Example:** 4칸 조각 → 4 × 1 = **4**점 (프로토타입 `score += p.cells.length`).

**F2. 깊이 배율**

The depth_mult_pct formula is defined as:

`depth_mult_pct(k) = min(100 + depth_step_pct × k, depth_mult_max_pct)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0 – `depth_cap` (6) | calculated (`CELLS_CLEARED.wave` / `FACE_ACTIVATED.stage − 1`) | 웨이브 번호 = 깊이 |
| depth_step_pct | int | 25 – 100 (시작 50) | data file | 깊이 1단계당 배율 증가 (컨셉·프로토타입 +50%) |
| depth_mult_max_pct | int | 200 – 600 (시작 400) | data file | 배율 상한. `depth_cap`을 올려도 보상이 폭주하지 않게 끊는다 |

**Output Range:** 100 (k = 0) ~ 400 (k = 6, 시작값에서 상한과 정확히 일치). `depth_cap`을 8로 올리면 100 + 50 × 8 = 500이지만 상한 400에서
멈춘다 — chain-resolver F6이 "두 값은 함께 조정"이라 적은 결합을 상한 하나로 끊는다 (D3).
**Example:** k = 0, 1, 2, 3, 6 → 100, 150, 200, 250, 400.

**F3. 여러 줄 배율**

The line_mult_pct formula is defined as:

`line_mult_pct(L) = 100 + multi_line_step_pct × max(0, L − 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| L | int | 0 – `board_width + board_height` (16) | calculated (`|WAVE_BEGIN.rows| + |WAVE_BEGIN.cols|`) | 그 웨이브의 유효 완성 줄 수 |
| multi_line_step_pct | int | 0 – 150 (시작 100) | data file | 두 번째 줄부터 줄당 더하는 배율 |

**Output Range:** L ≤ 1 → 100. 시작값에서 2줄 200, 3줄 300 (프로토타입 `× lineCount`와 정확히 같다). 일반 플레이 L ≤ 3; 한 번의 배치로 가능한
이론 최대는 1×6 막대가 행 1 + 열 6을 동시에 채우는 L = 7 → 700. **Example:** 행 1 + 열 1 → L = 2 → **200**.

**F4. 웨이브 점수**

The wave_points formula is defined as:

`clear_points(k) = ⌊ (N_line(k) × line_mult_pct(L(k)) + N_ab(k) × 100) × cell_points × depth_mult_pct(k) / 10000 ⌋`
`activation_points(k) = Σ_{FACE_ACTIVATED in wave k} ⌊ activation_points_base × depth_mult_pct(k) / 100 ⌋`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N_line(k) | int | 0 – 64 | calculated (`CELLS_CLEARED.cells[].by ∈ {LINE, BOTH}`) | 웨이브 k에서 줄 때문에(또는 줄과 능력 둘 다로) 지워진 칸 수. 줄 칸 수는 board-rules F4 `line_cell_count − kept` |
| N_ab(k) | int | 0 – 64 | calculated (`by = ABILITY`) | 능력으로만 지워진 칸 수 |
| L(k) | int | 0 – 16 | calculated (F3) | 웨이브 k의 줄 수 |
| cell_points | int | 1 – 50 (시작 10) | data file | 지워진 칸 하나의 기본 점수 |
| depth_mult_pct(k) | int | 100 – 400 | calculated (F2) | 깊이 배율 |
| activation_points_base | int | 0 – 100 (시작 20) | data file | 얼굴 발동 1회의 기본 점수 |

**Output Range:** 웨이브 0의 한 줄 8칸 → 80. 실전 웨이브 하나는 대개 40 ~ 600. 이론 상한(한 웨이브 64칸 전부 줄 칸, L = 7, ×4.0)
64 × 700 × 10 × 400 / 10000 = 17,920 — 64비트 정수에 여유롭다. 내림은 웨이브 단위로 **한 번**만 한다(칸마다 내리지 않음); 시작값에서는
나머지가 생기지 않는다 (10 × 50의 배수).
**Example (프로토타입 일치)**: 웨이브 2에서 능력 칸 9개 → (0 + 9 × 100) × 10 × 200 / 10000 = **180** (chain-resolver F6 예시와 같다).
웨이브 0에서 행 1 + 열 1 = 15칸 → 15 × 200 × 10 × 100 / 10000 = **300** (프로토타입 `15 × 10 × 1 × 2`). 웨이브 1에서 발동 1회 → 20 × 150 / 100 = **30**.

**F5. 배치 총점**

The placement_total formula is defined as:

`total = placement_points + Σ_{k=0}^{waves−1} ( clear_points(k) + activation_points(k) ) + fizzle_points × n_fizzled`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| placement_points | int | F1 | calculated | 배치 점수 |
| waves | int | 0 – `depth_cap` + 1 (7) | calculated (`CHAIN_END.waves`) | 웨이브 수 |
| n_fizzled | int | 0 – 64 | calculated (`CHAIN_END.faces_fizzled`) | 피즐한 얼굴 수 (DEPTH_CAP + SUPPRESSED) |
| fizzle_points | int | 0 – 100 (시작 0) | data file | 피즐 얼굴 1개당 위로 점수 |

**Output Range:** 줄 없는 배치 1 ~ 6. 한 줄 ≈ 85. 연쇄 2단 ≈ 300 ~ 500. 연쇄 6단(상한) ≈ 1,500 ~ 3,000. 이론 상한은 F6.
**Example (chain-resolver AC-03 픽스처형 — 냥이 → 곰곰 도미노)**: 1칸 조각 → F1 = 1. 웨이브 0: 7번 행 8칸, L = 1 → 80; 냥이 발동(k = 0) → 20.
웨이브 1: 냥이 십자 대상 중 차 있던 10칸(곰곰 얼굴 포함), 능력 칸 → 10 × 100 × 10 × 150 / 10000 = 150; 곰곰 발동(k = 1) → 30.
웨이브 2: 곰곰 3×3 중 차 있던 6칸 → 6 × 100 × 10 × 200 / 10000 = 120. **total = 1 + 80 + 20 + 150 + 30 + 120 = 401**.
(칸 수는 픽스처가 정한다; AC-S09가 같은 식을 정확한 픽스처로 고정한다.)

**F6. 배치 총점 상한 (검증용)**

The placement_total_bound formula is defined as:

`total_max ≤ max_piece_cells × place_points_per_cell + C_total × cell_points × line_mult_pct(L_max) × depth_mult_max_pct / 10000 + F_board × activation_points_base × depth_mult_max_pct / 100`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| C_total | int | ≤ 64 + `eggs_laid` | calculated (`CHAIN_END.cells_cleared_total`) | 한 배치에서 지워진 칸 총수 |
| L_max | int | 7 (단일 배치 웨이브 0 최대) — 알 웨이브까지 보수적으로 16 | constant (보드 8×8 파생) | 한 웨이브 최대 줄 수 |
| F_board | int | 0 – 64 | calculated | 보드 위 얼굴 수 |

**Output Range:** 시작값·보수적 가정(C_total 128, L 16)에서 약 87,000 (6자리 이하) — int 오버플로·HUD 자릿수(최대 6자리) 검증용이다. 실제 플레이에서 나올 값이 아니다.
**Example:** 6 + 128 × 10 × 1600 × 400 / 10000 + 64 × 20 × 4 = 6 + 81,920 + 5,120 ≈ 87,046 → HUD 숫자 영역은 6자리를 수용한다 (UI Requirements).

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 배치가 줄을 하나도 완성하지 않으면**: `waves = 0`, `total = placement_points` (1 ~ 6). 점수 0인 배치는 없다(`place_points_per_cell ≥ 1`인 한).
- **If 한 칸이 줄과 능력 둘 다에 걸려 `by = BOTH`이면**: 줄 칸으로 한 번만 센다 (여러 줄 배율을 받는다). 두 번 세지 않는다 — 해석기가 칸을 한 번만 지우는 것과 같다.
- **If 웨이브 k ≥ 1에 알이 완성한 줄과 능력 칸이 섞이면**: 줄 칸은 `line_mult_pct(L(k))`, 능력 칸은 ×1.0의 줄 배율, 둘 다 `depth_mult_pct(k)` (규칙 6·8).
- **If 같은 웨이브에서 얼굴이 여러 개 발동하면**: 발동마다 `activation_points_base × depth_mult_pct(k)`를 따로 준다. 동시 발동은 깊이를 올리지 않으므로 배율은 같다 (chain-resolver Edge Cases).
- **If 발동했지만 효과가 없는 얼굴(헛손질)이면**: 발동 점수는 준다 — 컷인이 떴고 `chain_depth`에도 센다 (chain-resolver D12와 일관).
- **If 얼굴이 깊이 상한에서 피즐하면 (`DEPTH_CAP`)**: 그 얼굴 칸은 웨이브 `depth_cap`의 칸으로 ×4.0 지우기 점수를 받고, 발동 점수는 없고, `fizzle_points`(시작 0)를 받는다.
  "최대 연쇄!" 연출이 보상 역할을 한다 — 상한이 손해로 느껴지는지는 플레이테스트로 본다 (Q1).
- **If 얼굴이 `SUPPRESSED`로 피즐하면** (얼어붙은 얼굴): DEPTH_CAP과 같은 처리. 방해물 GDD가 별도 보상을 원하면 이 문서의 `fizzle_points`를 사유별로 나누는 요청을 한다.
- **If `pre_clear`가 칸을 `KEEP`하면** (얼음 겹 등): 그 칸은 `CELLS_CLEARED`에 없으므로 점수 없음. 겹 벗기기 점수가 필요하면 방해물 GDD가 `CELL_MODIFIED`당 점수 항을 요청한다 (Q4).
- **If `CELLS_CLEARED.cells`가 비어 있는 웨이브가 오면**: 해석기 계약상 생기지 않는다 (chain-resolver 규칙 15: 빈 웨이브를 만들지 않음). 오더라도 `clear_points = 0`; 디버그 assert.
- **If 이벤트 목록이 스키마를 어기면** (`CELLS_CLEARED` 앞에 `WAVE_BEGIN` 없음, `wave` 역행): 프로그래밍 오류 — 디버그 assert, 출시 빌드는 그 배치를 `placement_points`만으로 채점하고 오류 로그.
  점수 함수는 보드를 재판정해 "고치지" 않는다.
- **If 미리보기의 예상 점수와 실제 점수가 다르면**: 버그다 (기둥 3). 같은 `events`를 넣는 한 다를 수 없으므로 원인은 해석기 입력 불일치 — chain-resolver AC-14와 이 문서 AC-S12가 함께 막는다.
- **If 연출을 스킵하면**: 점수는 이미 커밋되어 같다. HUD는 즉시 최종값으로 점프한다.
- **If 재시도하면**: `stage_score ← 0`, `best_placement ← 0`. 이전 시도의 점수는 결과 화면·기록에만 남는다.
- **If `depth_cap = 0`이면** (테스트·특수 스테이지): 웨이브 0만 있으므로 배율은 줄 배율뿐, 모든 얼굴이 피즐 — 일반 블록 퍼즐 점수가 된다.
- **If `depth_cap`을 상한 배율보다 깊게 올리면**: 깊이 배율은 `depth_mult_max_pct`에서 멈춘다 (F2). 웨이브 수가 늘어 총점은 늘지만 단계당 증가는 멈춘다.
- **If 튜닝 값이 범위를 벗어나면** (`cell_points < 1`, `depth_step_pct < 0`, `depth_mult_max_pct < 100`, 음수 점수): `ScoringRules` 로드 시 검증 오류. 런타임 보정 없음 (chain-resolver 규칙 18과 같은 방침).
- **If 퇴화 전략 "줄을 일부러 아껴 두었다가 여러 줄 동시"**: 의도된 숙련 플레이다 — 블록 퍼즐 장르의 기본 쾌감이다. 다만 여러 줄 배율(×L)이 깊이 배율(최대 ×4.0)을 압도하면
  "얼굴 도미노"보다 "줄 동시 지우기"가 지배 전략이 된다(기둥 1 약화). 시작값에서 3줄 동시(≈ 22칸 × 3 = 660)는 연쇄 3단과 비슷한 크기라 균형이 맞는지 T0 플레이테스트에서 본다 (Q2).
  기울면 `multi_line_step_pct`를 50으로 낮추는 것이 1차 조정 수단이다.
- **If 퇴화 전략 "얼굴만 모아 한 방"**: 의도된 고숙련 플레이 (chain-resolver Edge Cases). 상한 배율 ×4.0과 스테이지 제한 조각 수가 폭주를 막는다. 별 기준은 스테이지 GDD가 이 문서의 시작값으로 정한다.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 (`chain-resolver.md`) | Hard | 이벤트 스키마: `PLACED.cells`, `WAVE_BEGIN.rows/cols`, `CELLS_CLEARED.wave`·`cells[].by`, `FACE_ACTIVATED.stage`, `FACE_FIZZLED`, `CHAIN_END.waves`·`faces_fizzled`; `depth_cap` | Designed — 계약 일치. F6 참조 공식을 이 문서 F2가 소유로 넘겨받음 |
| 보드 & 조각 규칙 (`board-rules.md`) | Soft (간접, 해석기 경유) | `line_cell_count`(F4) 의미, `max_piece_cells`, 보드 크기 (상한 계산) | Designed — 일치 |

**Downstream (이 시스템에 의존)** — 모두 아직 GDD 없음, 아래는 이 문서가 제안하는 계약 (provisional).

| 시스템 | 강도 | 쓰는 것 | 이 문서가 기대하는 것 |
|---|---|---|---|
| 스테이지 & 목표 (`stage-goals.md`) | Hard | `stage_score` (점수 목표, 별 1~3 기준) | 별·목표 수치는 스테이지 데이터; 점수 공식을 재정의하지 않음 |
| 연쇄 미리보기 (`chain-preview.md`) | Soft | `score_placement` 동일 호출 → 예상 점수 | 표시 여부·형태 결정; 근사 계산 금지 |
| 판 진행 흐름 (`round-flow.md`) | Hard | 커밋 시 호출, 시도 시작·종료 | 해석 결과 커밋과 같은 순간 점수 커밋 |
| 플레이 HUD (`gameplay-hud.md`) | Hard | `stage_score`, 웨이브별 값 | 6자리 수용, 연출 박자 증가 표시 |
| 연쇄 연출 재생기 (`chain-presentation.md`) | Soft | 웨이브별 `clear_points` | "+N" 떠오르는 숫자 |
| 스테이지 진행 & 해금 · 결과 화면 | Soft | 시도 종료 `stage_score`, `best_placement` | 최고 기록 저장 |
| 무한 모드 · 월드맵 & 기록 (T3) | Hard | 같은 함수·누계 | — |
| 크루 레벨업 (T2) | 미정 | (점수에 닿는다면) 보정 항 | Q3 — 닿지 않는 쪽이 권장 |

**양방향성**: chain-resolver Dependencies는 이 시스템을 Hard downstream으로 적고 "깊이 배율(F6) 소유; 해석기에 점수 필드를 요구하지 않음"을 기대한다
→ 규칙 4·F2가 충족한다. board-rules는 이 시스템을 Soft downstream(F4 칸 수·줄 수)으로 적어 일치한다. systems-index의 Depends On에서 스테이지 & 목표·
플레이 HUD·무한 모드·월드맵 & 기록이 "점수"를 적어 일치한다. **불일치 2건 (index 소관, 수정하지 않고 기록)**: (1) 판 진행 흐름이 이 시스템을 호출(커밋 시 채점)하지만 index의 판 진행 흐름 Depends On에
"점수"가 없다 — 스테이지 & 목표를 경유하는 간접 의존으로 볼 수도 있으나 직접 호출이므로 추가 권장 (Q5). (2) 연쇄 미리보기 Depends On에 "점수"가 없다 — 예상 점수를 표시한다면 추가 필요 (Q5).
**명명 차이 1건**: chain-resolver F6은 `depth_step_bonus`(float 0.5)로 적었고 이 문서는 정수 `depth_step_pct`(50)로 소유한다 — 값은 같다.
chain-resolver 다음 개정 때 F6 변수명을 이 문서로 맞춘다 (Q6).

## Tuning Knobs

> standard tier는 이 섹션을 생략하지만 사용자 요청("모든 값을 튜닝 노브로")으로 둔다 (D1). 모든 값은 `ScoringRules` 데이터 파일 하나에 있다 — 코드에 숫자를 두지 않는다.
> *Specialist note*: `systems-designer` not consulted — 노브 간 상호작용이 있어(아래 표) lean에서도 대상이지만 Agent 도구 없음. Review manually before production.

| 노브 | 시작값 | 안전 범위 | 영향 | 너무 크면 | 너무 작으면 | 근거 |
|---|---|---|---|---|---|---|
| `place_points_per_cell` | 1 | 0 – 5 | 줄을 못 지운 배치의 최소 보상 | 아무 데나 놓기만 해도 점수 목표 달성 — 지우기 가치 희석 | 0이면 실패 배치가 "0점"으로 보여 위축 | 프로토타입 `+cells` |
| `cell_points` | 10 | 1 – 50 | 모든 지우기 점수의 기본 단위 (스케일만 바꿈) | 숫자 인플레이션(HUD 자릿수) | 배치 점수와 차이가 줄어 지우기 보상이 약해짐 | 프로토타입 `× 10`. 스케일 노브 — 바꾸면 스테이지 별 기준도 같은 비율로 |
| `depth_step_pct` | 50 | 25 – 100 | 연쇄 1단계당 보상 증가 — 기둥 1의 핵심 노브 | 연쇄 하나가 판 점수를 지배, 별 기준이 연쇄 운에 좌우 | 연쇄가 줄 지우기와 별 차이 없어 도미노 동기 소멸 | 컨셉·프로토타입 +50% |
| `depth_mult_max_pct` | 400 | 200 – 600 | 깊이 배율 상한 | `depth_cap`과 함께 보상 폭주 | `depth_cap`보다 일찍 멈춰 깊은 단계가 무의미 | `100 + 50 × depth_cap(6)` = 400 |
| `multi_line_step_pct` | 100 | 0 – 150 | 여러 줄 동시 보너스 | "줄 아껴 두기"가 얼굴 도미노보다 지배 전략 (Edge Cases) | 0이면 블록 퍼즐 기본 쾌감 상실 | 프로토타입 `× lineCount` |
| `activation_points_base` | 20 | 0 – 100 | 얼굴 발동 자체의 보상 | 효과 없는 발동(헛손질)도 크게 보상 — 얼굴만 지우는 플레이 | 0이면 프로토타입과 같음 (발동은 칸 수로만 보상) | 새 값 (D5): 칸 2개 몫 — 지우기 점수를 넘지 않게 |
| `fizzle_points` | 0 | 0 – 100 | 상한·억제로 피즐한 얼굴의 위로 점수 | 상한에 일부러 맞추는 플레이 | — | Q1: 플레이테스트 전 0 |

**상호작용**: `depth_step_pct` × `depth_cap`(chain-resolver 소유) ≥ `depth_mult_max_pct` − 100이 되면 상한이 깊은 단계를 평평하게 만든다 — 둘 중 하나를 바꾸면 상한을 다시 본다.
`cell_points`를 바꾸면 모든 스테이지의 점수 목표·별 기준이 같은 비율로 바뀌어야 한다 (스테이지 GDD가 별 기준을 `cell_points` 배수로 적으면 자동). `multi_line_step_pct`와
`depth_step_pct`의 비율이 "줄 동시 vs 연쇄" 전략 균형을 정한다 (Q2). 깊이 상한 `depth_cap` 자체는 chain-resolver 소유 — 여기서 중복 정의하지 않는다.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Agent 도구 없음, art bible 미작성. Review manually before production.
> 점수 시스템은 아무것도 그리지 않는다. 이 절은 **점수가 무엇을 읽히게 해야 하는가**만 정한다 — 구체 연출은 연쇄 연출 재생기 · 플레이 HUD GDD 소관.

| 순간 | 읽혀야 하는 것 | 근거 |
|---|---|---|
| 웨이브 k의 칸이 떼어질 때 | 그 웨이브 `clear_points`가 "+N"으로 지워진 칸 무리의 중심에서 떠오름. k ≥ 1이면 강조 스타일(크기·색 한 단계 위) | 프로토타입 `addFloat(…, depth > 0)` · 기둥 1 |
| 깊이 배율이 오를 때 | "×1.5 → ×2.0 …"이 연쇄 컷인과 함께 보여 "한 단계 더 = 더 큼"이 숫자로 읽힘 | 기둥 1·3 |
| 여러 줄 동시 | "2줄 동시!" 플로팅 (프로토타입과 같음) + 배율 표시 | 프로토타입 |
| 배치 총점이 큰 배치 | `total`이 스테이지 점수 목표의 일정 비율을 넘으면 HUD 숫자 "통통" 강조 (임계값은 HUD GDD) | 기둥 1 |
| 오디오 | 점수 증가 틱 SFX는 연쇄 SFX(깊이에 따라 피치 상승)와 겹치지 않게 HUD 쪽에서 묶어 재생. 상세는 오디오 GDD | 컨셉 Audio Needs |

## Game Feel

| 목표 | 기준 | 소유 |
|---|---|---|
| 연쇄 = 더 큰 숫자 | 같은 칸 수라도 웨이브가 깊을수록 숫자가 확실히 커 보여야 한다 — 시작값에서 깊이 3 웨이브는 웨이브 0의 2.5배 | 이 문서 (F2) |
| 예상 = 결과 | 미리보기에 예상 점수를 띄운다면, 놓은 뒤 들어오는 점수와 1점도 다르지 않다 | 이 문서 규칙 3 · AC-S12 |
| 즉시 확정 | 채점은 해석과 같은 프레임에 끝난다 (`score_placement` ≤ 0.1ms; 이벤트 수십 개 선형 순회) | 이 문서 (AC-S14) |
| 숫자 박자 | HUD 숫자는 웨이브 재생 박자에 맞춰 웨이브 단위로 오른다 — 마지막 웨이브가 끝나면 정확히 `stage_score` | HUD · 연출 GDD |
| 다정함 | 줄을 못 지운 배치도 "+칸 수"가 뜬다 — 0점 피드백 없음. 감점 없음 | 기둥 5 · 규칙 5·11 |

## UI Requirements

점수 시스템 자체는 화면 요소를 만들지 않는다. 요구 사항: (1) HUD의 점수 영역은 **6자리**(F6 상한)를 잘림 없이 표시한다; (2) 숫자는 `tabular-nums`처럼 폭이 고정된 숫자 글꼴로 증가 중 흔들리지 않는다;
(3) 예상 점수를 미리보기에 띄울지, 띄운다면 총점만인지 웨이브별인지는 연쇄 미리보기 GDD가 정한다 — "가장 큰 숫자 찾기" 퇴화 위험(chain-resolver 규칙 26)이 있으므로 MVP 권장은
**총점 한 줄**("+401 예상") (D8). 현지화: 숫자는 로캘 천 단위 구분 기호를 따른다 — 문자열은 HUD GDD 소유.

📌 **UX Flag** — 플레이 HUD 점수 영역과 미리보기 예상 점수 표기는 `/ux-design`(gameplay HUD)에서 다룬다.

## Cross-References

| 이 문서가 참조하는 것 | 대상 문서 | 종류 | 상태 |
|---|---|---|---|
| 이벤트 스키마(규칙 19), 웨이브 = 깊이(규칙 5), 해석기는 점수를 계산하지 않음(규칙 20), `depth_cap` 6, F6 참조 공식, Q1(피즐 보너스) | `design/gdd/chain-resolver.md` | 상위 계약 | 일치 — F6 소유를 이 문서 F2로 확정, Q1은 D6으로 답함. 변수명 차이 1건 (Q6) |
| `line_cell_count`(F4), `max_piece_cells` 6, 보드 8×8 | `design/gdd/board-rules.md` | 상위 계약 (간접) | 일치 |
| 연쇄 단계당 +50%(시작값, `/design-system`에서 확정), 별 1~3, 점수 목표 | `design/gdd/game-concept.md` § Core Mechanics 3·5 | 규칙 출처 | 일치 — +50% 확정 |
| 배치 `+cells`, 지우기 `cells × 10 × (1 + 0.5·depth) × lines(>1)` | `prototypes/sticker-place-concept/prototype.html` (`place`, `clearCells`) | 검증된 시작값 | 일치 — 단 알 줄과 능력 칸이 한 웨이브에 섞일 때 줄 배율을 줄 칸에만 적용 (D4); 발동 점수 추가 (D5) |
| "점수 & 연쇄 배율 — 줄 지우기·얼굴 발동 점수와 단계당 +50%" | `design/gdd/systems-index.md` | 범위 | 일치 |
| 점수 목표, 별 기준 수치 | `design/gdd/stage-goals.md` (미작성) | 하위 계약 | provisional |
| 예상 점수 표시 | `design/gdd/chain-preview.md` (미작성) | 하위 계약 | provisional |
| 커밋 타이밍, 시도 시작·종료 | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| 점수 표시, 증가 박자 | `design/gdd/gameplay-hud.md`, `design/gdd/chain-presentation.md` (미작성) | 하위 계약 | provisional |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 Agent 도구 없음. Review manually before production.
> Story type: **Logic** → 자동 단위 테스트 `tests/unit/scoring/` (BLOCKING). 픽스처는 **손으로 쓴 이벤트 목록**(해석기 없이)과 테스트 전용 `ScoringRules`
> (시작값 사본)로 만든다 — 실제 튜닝 값이 바뀌어도 테스트 기대값이 흔들리지 않게 한다. AC-S12만 해석기와 묶는 통합 테스트다.

**규칙 (Section C)**

- **AC-S01 (규칙 1·2, 순수성)** — **GIVEN** 이벤트 목록 E와 규칙 R, **WHEN** `score_placement(E, R)`를 두 번 부르면, **THEN** 두 `ScoreBreakdown`이 필드까지 같고 E·R은 호출 전과 같다.
  **AND** 점수 모듈 코드에 부동소수 리터럴·`float` 연산이 없다 (정적 검사).
- **AC-S02 (규칙 5, 줄 없는 배치)** — **GIVEN** `PLACED(cells 4개)`, `CHAIN_END(waves=0)`, **WHEN** 채점, **THEN** `total = 4`, `waves[]` 비어 있음.
- **AC-S03 (규칙 6, 줄 칸/능력 칸 구분)** — **GIVEN** 웨이브 1 `CELLS_CLEARED`에 `by=LINE` 8칸·`by=ABILITY` 3칸·`by=BOTH` 1칸, `WAVE_BEGIN.rows=[2], cols=[]`, **WHEN** 채점, **THEN** `line_cells = 9`, `ability_cells = 3`,
  `clear_points = (9 × 100 + 3 × 100) × 10 × 150 / 10000 = 180`.
- **AC-S04 (규칙 6, KEEP 칸)** — **GIVEN** `CELLS_CLEARED.kept`에 2칸, `CELL_MODIFIED` 2개, **WHEN** 채점, **THEN** 그 2칸은 점수에 들어가지 않는다.
- **AC-S05 (규칙 9, 발동·피즐)** — **GIVEN** 웨이브 0에 `FACE_ACTIVATED` 2개, 웨이브 6에 `FACE_FIZZLED(DEPTH_CAP)` 1개, **WHEN** 채점, **THEN** 웨이브 0 `activation_points = 40`, 웨이브 6 `activation_points = 0`,
  피즐 점수 0 (`fizzle_points = 0`). **AND** `fizzle_points`만 5로 바꾸면 total이 정확히 5 늘어난다.
- **AC-S06 (규칙 11·12, 누계)** — **GIVEN** `ACTIVE` 상태에서 total 4·85·401인 배치 3번, **WHEN** 각 커밋 후 읽으면, **THEN** `stage_score`는 4·89·490, `best_placement = 401`. **AND** 재시도 시 둘 다 0.
- **AC-S07 (규칙 14, 크루 무관)** — **GIVEN** 같은 이벤트 목록에서 `crew_id`만 다른 크루로 바꾼 두 벌, **WHEN** 채점, **THEN** total이 같다.

**공식 (Section D)**

- **AC-S08 (F1·F2·F3 표)** — **GIVEN** 시작값, **WHEN** 함수를 직접 부르면, **THEN** `placement_points(6) = 6`; `depth_mult_pct(0..6) = 100,150,200,250,300,350,400`; `line_mult_pct(0,1,2,3,7) = 100,100,200,300,700`.
  **AND** `depth_step_pct = 50`, `depth_mult_max_pct = 400`, `k = 8`이면 400 (상한).
- **AC-S09 (F4·F5, 도미노 골든 값)** — **GIVEN** F5 Example의 이벤트 목록(1칸 배치; 웨이브 0 행 8칸 LINE + 냥이 발동; 웨이브 1 ABILITY 10칸 + 곰곰 발동; 웨이브 2 ABILITY 6칸),
  **WHEN** 채점, **THEN** 웨이브별 `clear_points = 80, 150, 120`, `activation_points = 20, 30, 0`, **total = 401**.
- **AC-S10 (F4, 프로토타입 일치)** — **GIVEN** 웨이브 0 행 1 + 열 1 (15칸, L=2) 한 웨이브, **WHEN** 채점, **THEN** `clear_points = 300`. **AND** 웨이브 2 ABILITY 9칸이면 180.
- **AC-S11 (F4 내림)** — **GIVEN** `cell_points = 7`, `depth_step_pct = 33`, 웨이브 1 LINE 5칸, **WHEN** 채점, **THEN** `clear_points = ⌊5 × 100 × 7 × 133 / 10000⌋ = 46` (칸마다가 아니라 웨이브에서 한 번 내림).
- **AC-S12 (규칙 3, 미리보기 = 결과)** — **GIVEN** chain-resolver AC-14의 판 50개와 모든 유효 배치, **WHEN** 미리보기 경로와 실제 배치 경로의 `events`를 각각 채점하면,
  **THEN** `ScoreBreakdown`이 100% 같다. (통합 테스트 `tests/integration/scoring/`)
- **AC-S13 (F6, 상한·데이터 검증)** — **GIVEN** 64칸 전부 LINE·L=16·k=6인 합성 웨이브, **WHEN** 채점, **THEN** 오버플로 없이 F6 범위 안의 정수. **AND** `cell_points = 0` 또는 `depth_mult_max_pct = 50`인
  `ScoringRules`는 로드가 거부되고 오류에 노브 이름·값이 적힌다.
- **AC-S14 (성능)** — **GIVEN** 연쇄 6단 최악 근사 이벤트 목록, **WHEN** headless 데스크톱에서 `score_placement` 10,000회, **THEN** 평균 ≤ 0.1ms/회.
- **AC-S15 (노브 데이터화)** — **GIVEN** `ScoringRules` 파일에서 `depth_step_pct`만 100으로 바꾸면, **WHEN** AC-S09 픽스처를 채점, **THEN** 코드 변경 없이 웨이브 1·2 배율이 200·300으로 바뀐다
  (`clear_points = 80, 200, 180`, `activation_points = 20, 40, 0`, total = 521).

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 상한 피즐 얼굴이 "손해"로 느껴지는가 → `fizzle_points` > 0 필요? (chain-resolver Q1 승계; MVP는 0) | systems-designer · game-designer | T0 플레이테스트 |
| Q2 | "줄 아껴 두기"(×L)와 "얼굴 도미노"(×깊이)의 균형 — `multi_line_step_pct` 100이 도미노를 가리지 않는가 | systems-designer | T0 플레이테스트 · `/balance-check` |
| Q3 | T2 크루 레벨업(+20% 상한)이 점수에 닿는가 — 닿으면 별 기준이 과금·육성에 좌우 (안티 기둥). 권장: 닿지 않음 | economy-designer · 크루 레벨업 GDD | `/design-system crew-levelup` |
| Q4 | 방해물 겹 벗기기(`CELL_MODIFIED`)·특정 칸 지우기에 별도 점수가 필요한가 | 칸 종류 & 방해물 GDD | `/design-system obstacles` |
| Q5 | systems-index: 판 진행 흐름 → 점수, (예상 점수 표시 시) 연쇄 미리보기 → 점수 의존 추가 | producer · `/map-systems` | 해당 GDD 작성 전 |
| Q6 | chain-resolver F6 변수명 `depth_step_bonus`(float) → `depth_step_pct`(int) 정렬 | chain-resolver 개정 | 다음 `/design-review chain-resolver` |
| Q7 | 스테이지 클리어 시 남은 조각 보너스를 둘 것인가 — 둔다면 스테이지 & 목표 소유, 이 문서의 누계에 더하는 항으로 | 스테이지 & 목표 GDD | `/design-system stage-goals` |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 | standard 필수 5 + Formulas(숫자 규칙) + **Tuning Knobs**(사용자 요청 "모든 값을 튜닝 노브로", standard 기본 생략을 넘어섬) + Visual/Audio·Game Feel(Gameplay)·UI·Cross-References·Open Questions. Player Fantasy는 tier 생략 | Tuning Knobs 생략하고 Formulas 표에만 — 사용자 요청과 어긋남 |
| D2 | 연산 방식 | 정수 백분율 + 웨이브 단위 1회 내림 (해석기와 같은 결정성 방침) | float 배율 — 미리보기·실제·플랫폼 간 반올림 차이 위험 |
| D3 | 깊이 배율 형태 | 선형 +50%/단계 + 상한 400% (`depth_cap`과 결합 해제) | 상한 없음 — `depth_cap`을 올리면 보상 자동 증가; 지수(×1.5^k) — 6단에서 ×11.4로 폭주, 별 기준이 연쇄 하나에 좌우 |
| D4 | 여러 줄 배율 적용 범위 | 줄 칸(`LINE`·`BOTH`)에만, 모든 웨이브에 | 웨이브 전체 칸에 — 알 줄 하나가 능력 칸까지 ×L로 키움; 웨이브 0에만 — 알로 여러 줄 완성한 연쇄 보상이 사라짐 |
| D5 | 얼굴 발동 점수 | `activation_points_base = 20` × 깊이 배율 (index "얼굴 발동 점수" 반영, 칸 2개 몫) | 0 (프로토타입 그대로) — 노브로 남겨 플레이테스트에서 0으로 되돌릴 수 있음; 큰 값(≥ 50) — 헛손질도 큰 보상 |
| D6 | 피즐 얼굴 (chain-resolver Q1) | 칸 점수는 ×4.0으로 받고 발동 점수 없음, `fizzle_points = 0` 노브 | 상한 보너스 즉시 도입 — 상한에 맞추는 플레이 유도, 근거 없음 |
| D7 | 점수 확정 시점 | 해석 결과 커밋과 같은 순간, 연출과 무관 | 연출 재생 중 누적 — 스킵·중단 시 점수 불일치 |
| D8 | 미리보기 표시 권장 | 총점 한 줄 (결정은 미리보기 GDD) | 웨이브별 상세 — "가장 큰 숫자 찾기" 퇴화 위험 |
| D9 | 크루·과금 보정 | MVP 없음, T2도 비권장 (Q3) | 크루별 점수 가중 — "과금 = 수치 우위" 안티 기둥 |
| D10 | 감점·콤보 유지 보너스 | 없음 (턴 사이 콤보 없음 — 점수는 배치 단위로 닫힘) | 연속 배치 콤보 — 미리보기로 보이지 않는 상태가 생겨 기둥 3 약화 |
