# 칸 종류 & 방해물 (Cell Types & Obstacles)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-09 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛

## Summary

스테이지 초기 보드에 깔리는 MVP 방해물 두 가지 메커니즘 — **돌**(새 칸 종류: 놓을 수 없고 줄은 채우며 절대 안 지워짐)과
**얼음 겹**(조각 칸 위의 `modifiers` 겹: 맞을 때마다 한 겹씩 벗겨지고 다 벗겨져야 지워짐) — 을 정의한다. 얼음 겹이 얼굴 칸에
씌워지면 **얼어붙은 얼굴**이 되어 "한 번 맞아 녹고, 다음에 맞아야 발동"한다. 모든 효과는 보드 규칙 플래그 3종과 연쇄 해석기
훅 3종만으로 표현되므로 미리보기가 결과를 그대로 보여 준다 (기둥 3).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `보드 & 조각 규칙`, `연쇄 해석기 & 능력 프리미티브` (upstream) — downstream: 스테이지 & 목표, 연쇄 미리보기, 연쇄 연출 재생기, 점수 & 연쇄 배율

## Overview

방해물은 스테이지가 "가장 큰 연쇄 ≠ 가장 좋은 수"를 만들고 난이도를 올리는 도구다 (컨셉 Difficulty scaling: 목표 상승 → 조각
수 제한 → 방해물). 데이터 층에서 이 시스템은 board-rules 규칙 2의 칸 종류 표에 **`STONE` 한 줄**을 더하고, `TILE.modifiers[]`
슬롯에 **`ice` 겹** 하나의 의미를 부여하며, chain-resolver 규칙 21의 훅 3종(`pre_clear`, `can_activate`, `target_filter`)을 구현한다.
해석기·보드 규칙 코드는 칸 종류 이름을 모르므로 방해물을 더해도 수정되지 않는다 (board-rules D6, chain-resolver D10).
플레이어 층에서 방해물은 "어디를, 몇 번, 어떤 순서로 맞혀야 하는가"라는 새 질문을 던진다: 돌은 공간을 빼앗는 대신 줄을
대신 채워 주고, 얼음은 한 번에 안 깨지므로 연쇄의 **여러 웨이브**가 같은 칸을 두드리게 만들며, 얼어붙은 얼굴은 "먼저 녹이고,
그다음 터뜨리는" 2박자 도미노 장치다. MVP는 컨셉의 "방해물 1~2종" 범위 안에서 **메커니즘 2개(돌, 얼음 겹)**, 화면에 보이는 종류
3개(돌, 얼음 칸, 얼어붙은 얼굴)로 제한한다. 플레이어가 직접 조작하는 대상은 아니고, 스테이지 데이터가 깔고 해석기가 풀며
미리보기·연출이 보여 준다.

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` (Gameplay 지정 에이전트) not consulted — Lean mode (Section C는 lean에서
> 생략). Review manually before production.

### Core Rules

**A. MVP 방해물 목록**

1. **돌 (`STONE`) — 새 칸 종류.** board-rules 규칙 2 표에 다음 행을 등록한다 (값 소유 = 이 문서):

   | 칸 종류 | `blocks_placement` | `counts_for_line` | `removable_by_clear` | 내용물 |
   |---|---|---|---|---|
   | `STONE` | true | true | false | 없음 (`modifiers[]` 없음) |

   - 조각·알을 놓을 수 없다 (board-rules F2, `fill_cells`는 빈칸만 고르므로 알도 못 낳는다).
   - 줄 판정에서 차 있는 칸으로 친다 → 돌이 있는 줄은 **더 적은 칸으로 완성된다** (board-rules F5 `line_fill_count`에 포함).
   - 줄 지우기·능력 지우기로 **절대 사라지지 않는다** (board-rules 규칙 11이 건너뜀). MVP에는 돌을 없애는 수단이 없다.
   - 크루 능력의 CLEAR 대상에서 제외된다 (훅 `target_filter`, 규칙 9) — 그래서 미리보기의 "지워질 칸"에 돌이 표시되지 않는다.
2. **얼음 겹 (`ice`) — `TILE`의 수식자.** `TILE.modifiers[]`에 `{ kind: "ice", layers: n }` 항목 하나를 둔다 (`1 ≤ n ≤ ice_max_layers`).
   - 칸 종류는 여전히 `TILE`이다: `blocks_placement = true`, `counts_for_line = true`, `removable_by_clear = true`.
   - 얼음 칸이 지우기 대상(줄 칸 또는 능력 CLEAR 대상)에 들어가면 **지워지는 대신 겹이 1 줄어든다** (훅 `pre_clear`, 규칙 7).
     겹이 0이 되면 `ice` 항목이 사라지고 평범한 `TILE`이 된다. 그 뒤에 다시 대상이 되면 정상적으로 지워진다.
   - 얼음 칸은 스테이지 초기 보드에만 존재한다. 어떤 프리미티브·이벤트도 얼음을 만들거나 겹을 늘리지 않는다 (chain-resolver 규칙 17).
   - 얼음 아래 `TILE`은 보통 얼굴 없는 칸(`is_face = false`, `crew_id = null`, 무채색 판 종이 스티커)이다. 얼굴 칸이면 규칙 3.
3. **얼어붙은 얼굴 — 얼굴 칸 위의 얼음 겹.** `TILE(is_face = true, crew_id = X)` + `ice.layers = frozen_face_layers`(1).
   별도 메커니즘이 아니라 규칙 2의 얼음이 얼굴에 씌워진 경우다:
   - **첫 번째 타격**: 지워지지 않고 녹는다 (`CELL_MODIFIED`, 얼굴은 보드에 그대로). 지워지지 않았으므로 발동하지 않는다.
   - **두 번째 타격 이후**: 평범한 얼굴로서 지워지고 **발동한다** (chain-resolver 규칙 6.5–6.7). 깊이 상한 규칙도 똑같이 적용된다.
   - 녹은 얼굴은 같은 연쇄의 다음 웨이브에서 맞을 수도 있고(규칙 8), 다음 배치까지 기다릴 수도 있다 — 시간 제한 없음.
   - `crew_id`는 팀 밖 크루여도 된다 (crew-definition 규칙 8: 능력 표는 레지스트리 전체).
4. **MVP에서 쓰지 않는 것** — `FACE_FIZZLED(SUPPRESSED)` 사유와 `can_activate = false` 동작은 MVP 방해물이 내지 않는다 (Decision
   Log D3). 훅 지점과 이벤트 사유는 해석기에 그대로 예약해 둔다 (Post-MVP 방해물용).

**B. 데이터 스키마**

5. **칸 종류 등록 (`CellTypeDef`, Custom Resource 데이터)** — `{ id: "STONE", blocks_placement: true, counts_for_line: true,
   removable_by_clear: false, art_key: "stone" }`. board-rules `validate_board`의 "모든 칸 종류가 등록됨" 검사가 이 목록을 읽는다.
6. **수식자 스키마** — `modifiers[]`의 항목은 `{ kind: StringName, layers: int }`. MVP에서 유효한 `kind`는 `"ice"` 하나이며,
   한 칸에 같은 `kind`는 최대 1개다. 알 수 없는 `kind`는 로드 오류. 보드 규칙은 이 배열을 보존만 한다 (board-rules 규칙 2).
   스테이지 초기 보드의 칸 표기 예 (형식 자체는 스테이지 & 목표 GDD 소관):
   - 돌: `{ type: STONE }`
   - 얼음 칸 2겹: `{ type: TILE, is_face: false, crew_id: null, modifiers: [{ kind: ice, layers: 2 }] }`
   - 얼어붙은 냥이 얼굴: `{ type: TILE, is_face: true, crew_id: nyangi, modifiers: [{ kind: ice, layers: 1 }] }`

**C. 훅 구현 (chain-resolver 규칙 21의 세 지점)**

7. **`pre_clear(cell) → CLEAR | KEEP(new_modifiers)`** — 지우기 대상 칸마다 웨이브당 1회 호출된다 (`pending`은 집합이므로 한
   웨이브에서 줄과 능력이 같은 칸을 겹쳐 덮어도 1회).
   - `ice.layers ≥ 1`이면 `KEEP(layers − 1)` (0이 되면 `ice` 항목 제거) → 해석기가 `CELL_MODIFIED(cell, before, after)`를 낸다.
   - 그 밖의 모든 칸(얼음 없는 `TILE`, `STONE`, `EMPTY`)은 `CLEAR` — `STONE`·`EMPTY`는 이어서 `clear_cells`가 조용히 건너뛴다.
8. **`can_activate(face) → bool`** — MVP에서는 항상 `true` (기본값). 얼어붙은 얼굴은 녹기 전에는 `pre_clear`가 `KEEP`하므로 애초에
   지워진 얼굴 목록(규칙 6.5)에 들어오지 않는다. 즉 이 훅에 도달한 얼굴은 언제나 얼음 0겹이다.
9. **`target_filter(cell, primitive) → bool`** — `removable_by_clear(cell)`를 그대로 돌려준다. 즉 `STONE`은 어떤 CLEAR 프리미티브의
   대상도 아니고, 얼음 칸은 대상이다 (능력은 얼음을 깨는 수단). 이 필터 덕분에 `ABILITY_EFFECT.cells`와 미리보기 "지워질 칸"에
   돌이 섞이지 않는다.
10. **훅 순수성** — 세 훅 모두 인자로 받은 칸(칸 종류 플래그·`modifiers[]`)만 읽는 순수 함수다. RNG·시간·트레이·점수·스테이지
    상태를 읽지 않는다 (chain-resolver 규칙 17·21). 훅은 칸 종류 *이름*이 아니라 플래그와 `modifiers`만 본다.

**D. 줄·능력·알·미리보기와의 상호작용 (요약)**

11. **줄 지우기** — 완성 줄의 돌은 남고, 얼음 칸은 한 겹 벗겨져 남고, 나머지는 지워진다. 웨이브가 끝나면 그 줄은 더 이상
    완성 상태가 아니다 (규칙 15의 불변식 보장 참조).
12. **능력** — CLEAR 프리미티브는 돌을 건너뛰고(규칙 9), 얼음을 한 겹 벗긴다(규칙 7). FILL(알)은 빈칸에만 놓이므로 돌·얼음 칸에는
    알이 생기지 않는다. 돌은 `line_fill_count`에 포함되므로 삐약의 `prefer: fuller`가 돌이 있는 줄을 고르기 쉽다 — 의도된 상호작용
    ("돌 옆에 알을 낳아 줄을 메운다").
13. **알** — 방해물은 알 규칙을 바꾸지 않는다. 알이 돌이 있는 줄을 완성하면 그 줄은 정상적으로 다음 웨이브에 합류한다 (chain-resolver 규칙 12).
14. **미리보기** — 방해물의 모든 결과는 `resolve`의 `events`(`CELL_MODIFIED`, `CELLS_CLEARED`, `FACE_ACTIVATED`)로 나오므로 미리보기는
    별도 계산 없이 그대로 표시한다: 겹이 벗겨질 칸에 "금" 표시, 녹을 얼굴에 "녹음" 표시, 녹은 뒤 같은 연쇄에서 발동하면 그 웨이브의
    단계 배지. 해석기와 다른 경로로 방해물을 예측하는 코드는 금지다 (chain-resolver 규칙 3).

**E. 불변식 보장과 로드 시 검증**

15. **안정 보드 불변식 유지 (board-rules 13)** — 웨이브 뒤에 완성 줄이 남으려면 그 줄의 모든 칸이 `STONE`이거나 `KEEP`되어야 한다.
    그런 줄은 생길 수 없다: (a) 얼음과 돌은 런타임에 생기지 않고, (b) 안정 보드에는 완성 줄이 없으므로, 줄을 새로 완성하는 마지막
    칸은 언제나 새로 놓인 조각 칸이나 알(둘 다 얼음 없음, 지울 수 있음)이며, 그 칸은 지워진다. 따라서 방해물이 있어도 해석기 종료 시
    완성 줄은 0개다. 이 논증의 전제(돌·얼음은 초기 보드에서만 옴)를 지키는 것이 규칙 16이다.
16. **로드 시 검증 (`validate_obstacles(board)`, board-rules `validate_board`에 덧붙임)** — 실패는 스테이지 로드 오류:
    - V1: 모든 줄의 돌 수 ≤ `max_stones_per_line` 이고 ≤ 줄 길이 − 1 (F4). 돌만으로 찬 줄은 chain-resolver 규칙 11의 "지울 수 없는
      칸만으로 찬 줄"이다 — 이 검증이 그런 줄을 원천 차단한다.
    - V2: `ice`는 `TILE`에만 있다. `STONE`·`EMPTY`에 `ice`가 있으면 오류.
    - V3: `1 ≤ ice.layers ≤ ice_max_layers`. 얼굴 칸의 얼음은 정확히 `frozen_face_layers`.
    - V4: 알(`origin = EGG`) 칸에는 `ice`가 없다.
    - V5: 얼어붙은 얼굴의 `crew_id`는 크루 레지스트리에 있다 (chain-resolver 규칙 18과 같은 검사).
    - 완성 줄 0개 검사(board-rules 규칙 16)는 돌·얼음 칸을 차 있는 칸으로 센다.

**F. 데이터 기반 값** (standard tier라 Tuning Knobs 섹션은 생략 — 범위와 근거는 여기와 Formulas 변수표에 둔다)

| 값 | 시작값 | 안전 범위 | 소유 | 근거 · 너무 크거나 작으면 |
|---|---|---|---|---|
| `ice_max_layers` | 2 | 1 ~ 3 | 이 문서 (전역 데이터) | 2겹이면 "한 번 더"가 한눈에 읽힌다(빗금 방향 1개/2개). 3 이상은 빗금이 뭉개져 판독이 무너지고 줄 하나에 배치가 너무 많이 든다; 1이면 얼음 칸과 얼어붙은 얼굴의 난이도 차이가 사라진다 |
| `frozen_face_layers` | 1 | 1 (MVP 고정) | 이 문서 | "한 번 녹이고 한 번 터뜨린다"는 2박자가 핵심. 2겹 얼굴은 미리보기에서 보상이 너무 멀어 Post-MVP 검토 (Q2) |
| `max_stones_per_line` | 3 | 0 ~ `board_width` − 2 | 이 문서 (전역 데이터) | 8칸 줄에 돌 3개면 남은 5칸 — 크루 모양(최대 2×3)이 여전히 들어간다. 4개 이상이면 줄이 1~2배치로 완성돼 공짜 줄이 되고 크루 모양이 잘 안 들어간다; 0이면 돌을 쓸 수 없다 |
| 스테이지별 배치 (어디에 몇 개) | — | V1–V5 | 스테이지 & 목표 (스테이지 데이터) | level-designer 소관. 이 문서는 형식과 검증만 정한다 |

### States and Transitions

방해물 시스템은 상태를 들고 있지 않다. 아래는 **칸 단위** 전이다 (모두 해석기 안에서, 웨이브당 최대 1회).

| 현재 칸 | 계기 | 다음 칸 | 이벤트 | 비고 |
|---|---|---|---|---|
| `STONE` | 줄 지우기 / 능력 | `STONE` (변화 없음) | 없음 | 능력 대상에서는 `target_filter`로 제외 |
| `TILE` + `ice:2` | 지우기 대상 | `TILE` + `ice:1` | `CELL_MODIFIED` | 그 웨이브 `kept[]` |
| `TILE` + `ice:1` (얼굴 아님) | 지우기 대상 | `TILE` (얼음 없음) | `CELL_MODIFIED` | |
| `TILE` + `ice:1` (얼굴 = 얼어붙은 얼굴) | 지우기 대상 | 녹은 얼굴 `TILE(is_face)` | `CELL_MODIFIED` | 발동 없음 |
| `TILE` (얼음 없음, 녹은 얼굴 포함) | 지우기 대상 | `EMPTY` | `CELLS_CLEARED` (+ 얼굴이면 `FACE_ACTIVATED` / `FACE_FIZZLED(DEPTH_CAP)`) | 일반 규칙 |
| `STONE` / 얼음 `TILE` | 배치·알 | — (불가) | — | `blocks_placement = true` |
| (없음) | 런타임 생성 | — (불가) | — | 방해물은 초기 보드에서만 |

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 방해물 → 보드 규칙 | `STONE` 칸 종류 + 플래그 3종 값, `modifiers[].ice` 의미, `validate_obstacles` | 보드 규칙 (플래그 스키마·`validate_board`) / 방해물 (값·추가 검증) |
| 연쇄 해석기 | 방해물 → 해석기 (`ctx.hooks`) | `pre_clear`, `can_activate`, `target_filter` 구현 | 해석기 (훅 지점·호출 시점) / 방해물 (동작) |
| 스테이지 & 목표 | 스테이지 → 방해물 / 방해물 → 스테이지 | 초기 보드의 돌·얼음 배치(데이터) / 방해물 목표 입력 `ice_remaining`·`iced_cells` (F3), `CELL_MODIFIED` 이벤트 | 스테이지 (배치·목표 문구) / 방해물 (계수 식) |
| 연쇄 미리보기 | 해석기 경유 | `CELL_MODIFIED` → "금"/"녹음" 표시 그림 | 미리보기 (표시 규칙) / 방해물 (그림) |
| 연쇄 연출 재생기 | 해석기 경유 | `CELL_MODIFIED` 깨짐·녹음 그림 | 연출 (타이밍) / 방해물 (그림) |
| 점수 & 연쇄 배율 | 해석기 경유 | `CELL_MODIFIED`는 점수 없음 (scoring 규칙 6 그대로; scoring Q4 해소) | 점수 GDD |
| 크루 정의 & 능력 | 간접 | 얼어붙은 얼굴의 `crew_id` (레지스트리 전체 능력 표) | 크루 정의 |
| 판 진행 흐름 | 간접 | `ctx.hooks`에 이 문서의 훅을 넣어 `resolve`를 호출 (실제·미리보기 동일) | 판 진행 흐름 |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어
> 생략. Review manually before production. 이 시스템의 식은 균형 곡선이 아니라 판정·계수 식이며, 시작값은 컨셉·아트 바이블
> 판독 제약에서 정했다(프로토타입 검증값 없음 — Open Question Q1).

**F1. 얼음 타격**

The ice_after formula is defined as:

`ice_after(cell, k) = max(0, ice_before(cell, k) − hit(cell, k))`, `hit(cell, k) = 1 if cell ∈ pending(k) else 0`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| ice_before | int | 0 – `ice_max_layers` (2) | calculated (`modifiers[].ice.layers`, 없으면 0) | 웨이브 k 시작 시 칸의 얼음 겹 |
| hit | int | 0 – 1 | calculated (chain-resolver 규칙 6.4의 `pending`) | 이 칸이 웨이브 k의 지우기 대상인가. `pending`은 집합이라 줄+능력이 겹쳐도 1 |
| k | int | 0 – `depth_cap` | calculated | 웨이브 번호 |

칸이 지워지는 조건: `clears(cell, k) = hit(cell, k) = 1 ∧ ice_before(cell, k) = 0 ∧ removable_by_clear(cell)`.

**Output Range:** 0 ~ 2. 한 웨이브에 최대 1겹. **Example:** 2겹 얼음 칸이 웨이브 0의 줄에 걸리고 웨이브 1의 곰곰 3×3 범위에도 걸림 →
웨이브 0: 2 → 1, 웨이브 1: 1 → 0 (`CELL_MODIFIED` 2회), 칸은 남는다. 웨이브 2에 다시 걸려야 지워진다.

**F2. 필요한 타격 수**

The hits_to_clear formula is defined as:

`hits_to_clear(cell) = layers + 1` (얼음 칸·얼어붙은 얼굴), `hits_to_clear(STONE) = ∞`; 얼어붙은 얼굴의 `hits_to_fire = frozen_face_layers + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| layers | int | 1 – `ice_max_layers` | data file (스테이지 초기 보드) | 초기 얼음 겹 |
| frozen_face_layers | int | 1 (MVP 고정) | data file (전역) | 얼굴에 씌우는 얼음 겹 |

**Output Range:** 2 ~ 3 (시작값). 타격은 서로 다른 웨이브(같은 배치의 연쇄 안이든 여러 배치에 걸쳐서든)여야 한다 (F1).
**Example:** 얼어붙은 냥이 얼굴 → `hits_to_fire = 2`. 한 배치에서 웨이브 0 줄이 녹이고 웨이브 1 곰곰 능력이 다시 덮으면, 냥이는
웨이브 1에서 지워져 stage 2로 발동한다 — 한 수 안의 2박자 도미노.

**F3. 방해물 잔량** (스테이지 & 목표의 "방해물" 목표 입력)

The ice_remaining formula is defined as:

`ice_remaining(board) = Σ_{cell ∈ board} ice_layers(cell)`, `iced_cells(board) = |{ cell : ice_layers(cell) ≥ 1 }|`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| ice_layers(cell) | int | 0 – `ice_max_layers` | calculated (`modifiers[]`) | 칸의 현재 얼음 겹 (얼음 없으면 0) |
| board | 보드 | `board_width` × `board_height` | calculated | 해석기 `final_board` 또는 초기 보드 |

**Output Range:** `ice_remaining` 0 ~ 64 × 2 = 128 (실제 스테이지는 ≤ 20 권장 — 스테이지 GDD), `iced_cells` 0 ~ 64. 단조 감소한다 (얼음은
런타임에 생기지 않음). 돌은 세지 않는다 — 돌은 없앨 수 없으므로 목표 대상이 될 수 없다.
**Example:** 2겹 칸 3개 + 얼어붙은 얼굴 2개 → `ice_remaining = 3×2 + 2×1 = 8`, `iced_cells = 5`. 한 배치에서 `CELL_MODIFIED` 3개가 나오면
`ice_remaining` = 8 − 3 = 5 (각 `CELL_MODIFIED`는 정확히 1겹: `ice_remaining_after = ice_remaining_before − count(CELL_MODIFIED)`).

**F4. 돌 줄 상한** (로드 시 검증 V1)

The stone_line_ok formula is defined as:

`stone_line_ok(L) = stones(L) ≤ min(max_stones_per_line, len(L) − 1)`; 그 줄을 완성하는 데 필요한 빈칸 = `len(L) − line_fill_count(L)` (board-rules F5)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stones(L) | int | 0 – len(L) | calculated | 줄 L의 `STONE` 칸 수 |
| len(L) | int | 7 – 10 (시작 8) | data file (`board_width`/`board_height`) | 줄 길이 |
| max_stones_per_line | int | 0 – len − 2 (시작 3) | data file (전역) | 줄당 돌 상한 |

**Output Range:** bool. **Example:** 8칸 행에 돌 3개 → 3 ≤ min(3, 7) → 참; 그 행은 나머지 5칸만 채우면 완성. 돌 4개 → 거짓, 로드 오류.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 한 웨이브에서 같은 얼음 칸이 가로 줄·세로 줄·능력 범위에 동시에 걸리면**: 겹은 1만 벗겨진다 (`pending`은 집합, F1). 여러 번
  두드리려면 여러 웨이브가 필요하다 — 이것이 얼음이 연쇄를 보상하는 방식이다.
- **If 얼어붙은 얼굴이 녹은 웨이브에서 그 웨이브의 다른 능력 CLEAR 대상에도 들어 있으면**: 그 CLEAR 대상은 지우기 직후 스냅샷 기준
  (chain-resolver 규칙 15)이고 녹은 얼굴은 차 있으므로 다음 웨이브 `pending`에 들어간다 → 다음 웨이브에서 지워지고 발동한다.
  예: 웨이브 0에서 냥이 얼굴이 녹고, 같은 웨이브 0에 지워진 곰곰 얼굴의 3×3 범위가 냥이를 덮으면 냥이는 웨이브 1에서 발동(stage 2).
- **If 얼어붙은 얼굴이 깊이 상한 웨이브(k = `depth_cap`)에서 녹으면**: 녹기만 하고(`CELL_MODIFIED`) 남는다. 상한 웨이브에서 이미 녹아 있던
  얼굴이 지워지면 일반 규칙대로 `FACE_FIZZLED(DEPTH_CAP)`.
- **If 웨이브 k의 `pending`이 전부 얼음 칸(KEEP)과 돌뿐이면**: `CELLS_CLEARED.cells = []`, 지워진 얼굴 없음 → 연쇄 종료
  (chain-resolver 규칙 6.5). `CELL_MODIFIED`는 정상적으로 나오고, 그 웨이브는 `chain_depth`에 세지 않는다 (발동 없음).
- **If 녹은 얼굴이 이번 연쇄에서 다시 맞지 않으면**: 평범한 얼굴로 보드에 남는다. 다음 배치의 줄·능력으로 지워질 때 발동한다. 시간 제한·
  재동결 없음.
- **If 돌이 있는 줄이 완성되면**: 돌을 뺀 칸들이 지워지고 돌은 남는다. 점수는 실제로 지워진 칸만 센다 (scoring 규칙 6; board-rules F4
  `cleared = line_cell_count − kept`).
- **If 크루 능력 범위가 돌을 덮으면**: `target_filter`가 돌을 대상에서 빼므로 `ABILITY_EFFECT.cells`·미리보기에 돌이 없다. 범위가 돌만 덮으면
  헛손질(빈 `cells`) — 연출 재생기의 헛손질 연출.
- **If 삐약이 돌이 있는 줄과 없는 줄 중에서 고르면**: `line_fill_count`가 돌을 세므로 `prefer: fuller`는 돌 줄을 고를 수 있다. 의도된 동작이며
  미리보기의 알 고스트로 그대로 보인다.
- **If 알이 돌만 남은 줄의 빈칸을 모두 채우면**: 줄이 완성되고 다음 웨이브에 합류한다. 알은 지워지고 돌은 남는다 — 불변식 유지 (규칙 15).
- **If 얼음 칸만 남고 빈칸이 모두 사라져 놓을 곳이 없으면**: board-rules `no_moves`가 참 → "놓을 곳 없음" 실패. 방해물은 실패 규칙을 바꾸지
  않는다. 스테이지 데이터가 이런 판을 너무 쉽게 만들지 않도록 하는 것은 스테이지 GDD·`/balance-check` 소관.
- **If 스테이지 데이터에 돌만으로 찬 줄, 4개 이상의 돌이 있는 줄, `STONE`의 얼음, 3겹 이상 얼음, 2겹 얼굴 얼음, 알 위의 얼음, 레지스트리에
  없는 `crew_id`의 얼어붙은 얼굴이 있으면**: `validate_obstacles` 실패 → 스테이지 로드 오류. 런타임 보정 없음 (데이터가 곧 진실).
- **If `modifiers[]`에 알 수 없는 `kind`가 있거나 `ice` 항목이 2개 이상이면**: 로드 오류.
- **If 미리보기와 실제 결과의 겹 수가 다르면**: 버그다 — 훅은 순수 함수이고 같은 `resolve`를 쓰므로 생길 수 없다 (chain-resolver AC 대상).
- **If `ice_max_layers`를 데이터로 3으로 올리면**: 규칙상 동작하지만 빗금 그림이 2단계까지만 정의되어 있으므로 아트 추가 없이 올리지 않는다
  (Visual/Audio Requirements).

## Dependencies

| 시스템 | 방향 | 성격 | 인터페이스 | 상태 |
|---|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | upstream | Hard | 칸 종류 플래그 스키마(규칙 2), `modifiers[]` 보존 슬롯, `validate_board`(규칙 16), `line_fill_count`(F5), 불변식 13 | Designed — 일치 (board-rules Dependencies가 이 문서를 downstream Hard로 적음) |
| 연쇄 해석기 & 능력 프리미티브 (`chain-resolver.md`) | upstream | Hard | 훅 지점 3종(규칙 21), `CELL_MODIFIED` 이벤트, 유효 완성 줄(규칙 11), 프리미티브 계약(규칙 17) | Designed — 일치 (chain-resolver는 이 문서를 "Soft — 훅 기본값으로 동작"으로 적음; 이 문서 쪽에서는 Hard) |
| 크루 정의 & 능력 (`crew-definition.md`) | upstream (간접) | Soft | 레지스트리 전체 `crew_abilities` (얼어붙은 얼굴이 팀 밖 크루여도 발동) | Designed — 일치 (crew-definition 규칙 8) |
| 스테이지 & 목표 (`stage-goals.md`) | downstream | Hard | 초기 보드 형식에 돌·얼음 표기, `ice_remaining`·`iced_cells`(F3) 목표 입력 | 미작성 — provisional |
| 연쇄 미리보기 (`chain-preview.md`) | downstream (해석기 경유) | Soft | `CELL_MODIFIED` "금"/"녹음" 표시 그림 | Designed — 갇힘 배지(`SUPPRESSED`)는 MVP에서 쓰이지 않음 (Q3) |
| 연쇄 연출 재생기 (`chain-presentation.md`) | downstream (해석기 경유) | Soft | 얼음 깨짐·녹음 그림 | Designed — 녹음 연출 추가 요청 (Q3) |
| 점수 & 연쇄 배율 (`scoring.md`) | downstream (해석기 경유) | Soft | `CELL_MODIFIED` 점수 없음 | Designed — scoring Q4 해소 (D7) |
| 판 진행 흐름 (`round-flow.md`) | downstream | Soft | `ctx.hooks` 주입 | 미작성 |

**양방향 확인**: systems-index는 이 시스템을 보드 & 조각 규칙·연쇄 해석기에 의존, 스테이지 & 목표가 이 시스템에 의존으로 적어 일치한다.
미리보기·연출·점수는 방해물을 해석기 이벤트로만 알므로 systems-index에 직접 의존을 추가하지 않는다.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — 이 실행에 Agent 도구 없음 (lean에서도 방해물은 플레이어가 읽어야 하는 시각 요소라
> spawn 대상). Review manually before production. 기준은 art bible 4절(의미 색·방해물 표기)이다.

**판독 원칙**: 모든 방해물은 **색 없이도** 구분된다 — 실루엣·텍스처·빗금 방향 수로 읽히고, 색은 보조 단서다 (art bible: 흑백 판독, 색약 대응).
방해물에는 흰 스티커 테두리를 두지 않는다 (흰 여백 = 만질 수 있음 — art bible 의미 색).

| 요소 | 형태 (1차 단서) | 색 (보조) | 겹/상태 표기 |
|---|---|---|---|
| 돌 | 둥글게 깎인 자갈 실루엣, 칸보다 약간 작게(칸 가장자리 여백), 점묘 텍스처, **그림자 없음**(판에 박혀 있음 — 조각은 그림자로 떠 있음) | 회갈색 `#9a8c7e` | 없음 (영구) |
| 얼음 칸 2겹 | 각진 결정면 판이 칸을 덮음 + **잉크 빗금 두 방향(교차 빗금)** | 차가운 회색 `#b9c3c9` | 빗금 방향 수 = 겹 수 |
| 얼음 칸 1겹 | 같은 결정면 + **잉크 빗금 한 방향** + 모서리에 잔금 | `#b9c3c9` | |
| 얼어붙은 얼굴 | 얼굴 이목구비가 결정면 아래로 비쳐 보임(크루 실루엣·표정 유지, 채도 낮춤) + 빗금 한 방향 | `#b9c3c9` 위에 크루 색 30% | "얼굴이 갇혀 있다"가 읽혀야 함 (art bible) |
| 녹은 얼굴 | 평범한 얼굴 칸과 **완전히 같은 그림** (흰 테두리·반짝 스프라이트 복귀) | 크루 색 | 녹은 뒤 별도 표식 없음 — 상태가 2개뿐이라 판독 단순 |

**이벤트 연출 (타이밍은 연쇄 연출 재생기 소관, 그림은 이 문서)**
- `CELL_MODIFIED` (2 → 1겹): 빗금 한 방향이 "찰칵" 금 가며 떨어짐 + 작은 회색 조각 2–3개 (0.12s, 떼어짐 구간 안 — chain-presentation 규칙 13).
- `CELL_MODIFIED` (1 → 0겹, 얼음 칸): 결정판이 깨져 흩어지고 아래 무채색 스티커가 드러남.
- `CELL_MODIFIED` (1 → 0겹, 얼어붙은 얼굴): 결정판이 깨지고 얼굴이 "부르르" 몸을 털며 흰 테두리 복귀 — 표정은 기존 3장 중 하나 재사용
  (art bible "얼굴 1명당 표정 3장" 유지). 실패가 아닌 "깨어남"으로 읽혀야 한다 (기둥 5).
- **오디오**: 겹 깨짐 = 짧고 높은 "찰칵"(유리·얼음 계열, 칸 지우기 SFX보다 짧게), 얼굴 녹음 = "찰칵" + 작은 "뾰롱"(깨어남). 돌은 소리 없음.
  같은 웨이브의 여러 `CELL_MODIFIED`는 SFX 1회로 묶는다 (오디오 GDD로 요청).

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:obstacles` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

- **얼음 = 두드리는 손맛**: 연쇄의 여러 웨이브가 같은 얼음을 "찰칵, 찰칵" 두드리는 것이 기둥 1의 작은 박자다. 깨짐 연출은 칸 지우기보다 짧고
  날카롭게 — 지우기(떼어짐)의 말랑함과 대비.
- **얼어붙은 얼굴 = 약속**: 녹는 순간 얼굴이 깨어나는 연출은 "다음엔 이게 터진다"는 약속이어야 한다. 녹고 바로 같은 연쇄에서 터지는 2박자는
  일반 발동보다 한 박자 더 길게 느껴지지 않도록 녹음 연출은 기존 떼어짐 구간 안에 넣는다 (추가 시간 0).
- **돌 = 무게**: 움직이지 않고 흔들리지도 않는다 (연쇄 중 다른 칸이 들썩여도 돌은 고정). 그래서 "절대 안 지워짐"이 몸으로 읽힌다.
- 방해물은 입력 반응성에 영향이 없다 — 배치 불가 칸 위 스냅 표시는 일반 차 있는 칸과 같다 (드래그 & 배치 입력 GDD).

## UI Requirements

- **미리보기 표시** (chain-preview 규칙 4 표의 "변형 칸 표시" 행을 이 문서가 채움): `CELL_MODIFIED`가 예정된 칸에 잉크 지그재그 "금" 오버레이
  (얼음 칸), 얼어붙은 얼굴이면 "금" + 작은 물방울 아이콘("녹음"). 같은 칸이 한 연쇄에서 두 번 벗겨지면 금 오버레이에 웨이브 박자 점 2개.
  녹은 뒤 같은 연쇄에서 발동할 얼굴은 일반 단계 배지(`stage`)를 함께 단다.
- **HUD 방해물 목표**: 스테이지 목표가 방해물형이면 "얼음 조각 아이콘 × 남은 수"(`iced_cells` 또는 `ice_remaining` — 스테이지 GDD가 택일)를 표시.
  아이콘은 얼음 칸 그림의 축소판(빗금 포함)으로 색 없이도 읽힌다.
- **터치 타깃 없음**: 방해물은 탭·드래그 대상이 아니다.

> **📌 UX Flag — 칸 종류 & 방해물**: This system has UI requirements (미리보기 금/녹음 오버레이, HUD 방해물 목표 카운터). In Phase 4
> (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics.
> Stories that reference UI should cite `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 참조 대상 | 문서 | 관계 | 상태 |
|---|---|---|---|
| 칸 종류 플래그 3종, `modifiers[]` 슬롯, `validate_board`, 불변식 13, F4 `kept`, F5 `line_fill_count` | `design/gdd/board-rules.md` | 상위 계약 (이 문서가 값을 채움) | 일치 |
| 훅 3종, 해석 루프 규칙 6, 유효 완성 줄 규칙 11, 스냅샷 규칙 15, 프리미티브 계약 17, `CELL_MODIFIED`·`FACE_FIZZLED(SUPPRESSED)` | `design/gdd/chain-resolver.md` | 상위 계약 (이 문서가 구현) | 일치 — `SUPPRESSED`는 MVP 미사용 (D3) |
| 레지스트리 전체 `crew_abilities` | `design/gdd/crew-definition.md` 규칙 8 | 얼어붙은 얼굴 발동 근거 | 일치 |
| `CELL_MODIFIED`·`kept` 점수 없음, Q4 | `design/gdd/scoring.md` 규칙 6, Q4 | 하위 — Q4를 "별도 점수 없음"으로 해소 | 해소 요청 (scoring Q4 갱신 필요) |
| 변형 칸 표시, 갇힘 배지 | `design/gdd/chain-preview.md` 규칙 4 | 하위 — 그림 제공, 갇힘 배지는 MVP 미사용 | provisional |
| 얼음 깨짐 타이밍, `SUPPRESSED` 바르르 | `design/gdd/chain-presentation.md` 규칙 13 | 하위 — 녹음 연출 추가 요청 | provisional |
| 방해물 목표, 초기 보드 형식 | `design/gdd/stage-goals.md` | 하위 | 미작성 |
| 방해물 색·텍스처 | `design/art/art-bible.md` 4절 | 시각 기준 | 일치 (얼음 `#b9c3c9`+빗금, 돌 `#9a8c7e`+점묘) |
| 방해물 1~2종, 얼어붙은 얼굴, Difficulty scaling | `design/gdd/game-concept.md` | 범위 근거 | 일치 |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략. Review manually
> before production. 모든 Logic 항목은 `resolve`·`validate_obstacles`를 직접 호출하는 단위 테스트(`tests/unit/obstacles/`)로 검증한다.

- **AC-O01 [Logic] (규칙 1, 배치)** — **GIVEN** (3, 3)이 `STONE`인 보드, **WHEN** 그 칸을 덮는 앵커로 `can_place`, **THEN** 거짓.
- **AC-O02 [Logic] (규칙 1, 줄 완성)** — **GIVEN** 3번 행에 돌 3개 + 조각 칸 4개 + 빈칸 1개, **WHEN** 1칸 조각을 빈칸에 놓고 `resolve`, **THEN**
  웨이브 0에 3번 행이 포함되고, 조각 칸 5개만 `CELLS_CLEARED`에 있으며, `final_board`의 돌 3개는 그대로이고 3번 행은 완성 상태가 아니다.
- **AC-O03 [Logic] (규칙 9, 능력과 돌)** — **GIVEN** 곰곰 얼굴 3×3 범위 안에 돌 2개와 조각 칸 3개, **WHEN** 곰곰이 발동, **THEN** 해당
  `ABILITY_EFFECT.cells`에 돌 좌표가 없고 조각 칸 3개만 있다.
- **AC-O04 [Logic] (규칙 7·F1, 겹 감소)** — **GIVEN** 2겹 얼음 칸이 완성 줄에 포함, **WHEN** `resolve`, **THEN** `CELL_MODIFIED`(before `ice:2`,
  after `ice:1`) 1개, 그 칸은 `CELLS_CLEARED.cells`에 없고 `kept[]`에 있으며 `final_board`에서 `ice:1`.
- **AC-O05 [Logic] (F1, 웨이브당 1겹)** — **GIVEN** 2겹 얼음 칸이 웨이브 0에서 가로 줄·세로 줄 교차점에 있음, **WHEN** `resolve`, **THEN**
  그 칸의 `CELL_MODIFIED`는 1개이고 `final_board`에서 `ice:1`.
- **AC-O06 [Logic] (F1, 여러 웨이브)** — **GIVEN** 1겹 얼음 칸이 웨이브 0 줄에, 그리고 웨이브 0에서 지워지는 곰곰 얼굴의 3×3 범위에 있음,
  **WHEN** `resolve`, **THEN** 웨이브 0에 `CELL_MODIFIED`(1 → 0), 웨이브 1의 `CELLS_CLEARED`에 그 칸이 있다.
- **AC-O07 [Logic] (규칙 3, 얼어붙은 얼굴 첫 타격)** — **GIVEN** 얼어붙은 냥이 얼굴(`ice:1`)만 완성 줄에 걸리고 다른 얼굴 없음, **WHEN** `resolve`,
  **THEN** `CELL_MODIFIED` 1개, `FACE_ACTIVATED`·`FACE_FIZZLED` 0개, `chain_depth = 0`, `final_board`의 그 칸은 `is_face = true`·얼음 없음.
- **AC-O08 [Logic] (규칙 3·F2, 같은 연쇄 2박자)** — **GIVEN** AC-O06 배치에서 얼음 칸 대신 얼어붙은 냥이 얼굴, **WHEN** `resolve`, **THEN** 냥이의
  `FACE_ACTIVATED.stage = 2`이고 그 앞에 같은 칸의 `CELL_MODIFIED`가 있다.
- **AC-O09 [Logic] (규칙 3, 다음 배치)** — **GIVEN** AC-O07의 `final_board`, **WHEN** 녹은 냥이 얼굴을 지우는 새 배치를 `resolve`, **THEN**
  냥이가 `FACE_ACTIVATED`로 발동한다.
- **AC-O10 [Logic] (규칙 15, 불변식)** — **GIVEN** 돌·얼음 칸이 섞인 시드 고정 보드 100개와 무작위가 아닌 고정 배치 목록, **WHEN** 각 배치를
  `resolve`, **THEN** 모든 `final_board`에 `full_lines`가 0개.
- **AC-O11 [Logic] (규칙 16, 검증)** — **GIVEN** 각각 V1–V5 중 하나를 위반하는 스테이지 보드 6종(돌 4개 줄, `STONE`의 얼음, `ice:3`, 얼굴 `ice:2`,
  알 위 얼음, 미등록 `crew_id`), **WHEN** 로드, **THEN** 6종 모두 거부되고 오류 메시지가 위반 칸 좌표와 규칙 번호를 담는다.
- **AC-O12 [Logic] (F3, 잔량)** — **GIVEN** 2겹 칸 3개 + 얼어붙은 얼굴 2개 보드, **WHEN** `CELL_MODIFIED` 3개를 내는 배치 후, **THEN**
  `ice_remaining`이 8 → 5, 그리고 모든 배치에서 `ice_remaining_after = before − count(CELL_MODIFIED)`.
- **AC-O13 [Logic] (규칙 10·14, 미리보기 일치)** — **GIVEN** 방해물이 있는 보드와 임의 앵커, **WHEN** 미리보기 경로와 실제 배치 경로로 같은 `ctx`(같은
  `hooks`)를 써서 `resolve`, **THEN** 두 `events`가 완전히 같다 (`CELL_MODIFIED` 포함).
- **AC-O14 [Logic] (규칙 4, SUPPRESSED 미사용)** — **GIVEN** MVP 방해물만 있는 임의 보드, **WHEN** `resolve`, **THEN** `FACE_FIZZLED(reason = SUPPRESSED)`가
  나오지 않는다.
- **AC-O15 [Logic] (규칙 12, 알)** — **GIVEN** 삐약 발동 줄 후보 두 개(돌 3개가 있는 행: 차 있음 6, 열: 차 있음 4), **WHEN** `lay_eggs_in_own_line(prefer = fuller)`,
  **THEN** 알이 행의 빈칸에 놓이고 돌·얼음 칸에는 놓이지 않는다.
- **AC-O16 [UI] (Visual, 흑백 판독)** — **GIVEN** 돌·얼음 2겹·얼음 1겹·얼어붙은 얼굴·녹은 얼굴·일반 칸이 한 줄씩 있는 테스트 보드, **WHEN** 기기에서
  실행해 흑백(채도 0) 스크린샷을 찍음, **THEN** 6종이 모두 구분된다 — 스크린샷을 `production/qa/evidence/`에 보관.
- **AC-O17 [Visual] (연출)** — **GIVEN** AC-O08 배치, **WHEN** 실제로 놓아 연출 재생, **THEN** 얼음 깨짐 → 얼굴 깨어남 → 같은 연쇄의 stage 2 발동이
  순서대로 보이고, 녹음 연출로 추가된 재생 시간이 0이다(같은 배치를 얼음 없이 재생한 시간과 같음) — 스크린샷/영상 보관, 리드 사인오프.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | `ice_max_layers = 2`, `max_stones_per_line = 3`은 판독·검증 제약에서 정한 값이다. 실제 난이도는 그레이박스 스테이지로 검증 필요 | level-designer · `/balance-check` | T0 그레이박스 플레이테스트 |
| Q2 | 2겹 얼어붙은 얼굴, 줄로만 지워지는 칸(`target_filter` 활용), 발동 금지 얼굴(`SUPPRESSED`) 등 Post-MVP 방해물 후보 | game-designer | Vertical Slice 이후 |
| Q3 | chain-preview 규칙 4의 "갇힘 배지"·chain-presentation 규칙 13의 `SUPPRESSED` 바르르는 MVP에서 쓰이지 않는다 — 그 행을 "Post-MVP 예약"으로 표기하고, 녹음 표시/연출(이 문서 UI·Visual)을 추가하도록 두 GDD를 갱신 | 각 GDD 소유자 · `/propagate-design-change` | 다음 `/consistency-check` |
| Q4 | `kept`의 뜻이 두 문서에서 다르다: board-rules F4 `kept` = 줄 칸 중 `removable_by_clear = false`(돌), chain-resolver `CELLS_CLEARED.kept[]`·scoring 규칙 6 = 훅 `KEEP` 칸(얼음). 점수는 `cells[].by`로 세므로 결과는 같지만 이름을 정리해야 함 (제안: 이벤트 `kept[]` = KEEP 칸만, 돌은 `cells`·`kept` 어디에도 없음) | systems-designer · `/consistency-check` | 스테이지 GDD 작성 전 |
| Q5 | scoring Q4 해소 반영: scoring.md Open Questions Q4를 "해소 — 방해물 GDD D7: 별도 점수 없음"으로 갱신 | scoring 소유자 | 다음 `/consistency-check` |

### Decision Log (사용자 위임 — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(숫자 규칙 있음)·Edge Cases·Dependencies·AC + Visual/Audio·Game Feel(Gameplay 필수)·Cross-References(의존 있음)·UI Requirements·Open Questions. Player Fantasy·Tuning Knobs 생략, 데이터 값 표는 Core Rules F절 | Tuning Knobs 섹션 — tier 규칙 위반 |
| D2 | MVP 방해물 세트 | 메커니즘 2개: 돌(칸 종류) + 얼음 겹(수식자). 얼어붙은 얼굴 = 얼굴 위 얼음 | (a) 3개 이상 독립 메커니즘(사슬, 이동 방해물, 번지는 방해물) — 컨셉 "1~2종" 초과, 미리보기 판독 부담; (b) 얼음만 — 공간 압박 장치가 없어 스테이지 다양성 부족 |
| D3 | 얼어붙은 얼굴 동작 | 얼음 1겹: 첫 타격에 녹고(`KEEP`), 다음 타격에 지워지며 발동 | `can_activate = false` → 지워지되 발동 안 함(`SUPPRESSED`) — chain-resolver 예시였지만, 얼굴이 그냥 사라지는 "벌칙"일 뿐 퍼즐이 없고 기둥 1 도미노에 기여하지 않음. "녹이고 터뜨리는" 2박자가 도미노 설계에 맞음. 훅·사유는 Post-MVP용으로 예약 |
| D4 | 돌의 줄 판정 | `counts_for_line = true` (줄을 채움, 남음) | `counts_for_line = false` — 그 행·열 전체가 영구히 완성 불가가 되어 8×8에서 너무 가혹하고 판을 죽은 공간으로 만듦 |
| D5 | 능력과 돌 | `target_filter = removable_by_clear` → 돌 제외 | 대상에 남기고 `clear_cells`가 건너뛰게 함 — `ABILITY_EFFECT.cells`("실제로 지워질 칸")와 미리보기가 돌을 잘못 표시 |
| D6 | 얼음 타격 단위 | 웨이브당 최대 1겹, `ice_max_layers = 2` | 줄·능력 겹침마다 1겹 — 같은 웨이브 내 순서 의존·판독 어려움; 3겹 — 빗금 판독 한계 |
| D7 | 겹 벗기기 점수 (scoring Q4) | 별도 점수 없음 — 칸이 최종적으로 지워질 때 일반 칸 점수 | `CELL_MODIFIED`당 점수 항 — 점수식 추가 대비 이득 작음, 방해물 목표가 이미 보상 |
| D8 | 얼음 위치 | `TILE`에만, 스테이지 초기 보드에서만 | 런타임 동결 능력/방해물 — 프리미티브 계약 17 위반, 불변식 논증(규칙 15)이 깨짐 |
| D9 | 겹 수 표기 | 빗금 방향 수(1 = 한 방향, 2 = 교차) + 결정면 형태, 색은 보조 | 숫자 배지 — 보드에 숫자가 미리보기 단계 배지와 충돌; 색 농도만 — 색약·흑백에서 판독 불가 |
| D10 | 돌 상한 | 줄당 3개, 데이터 검증 오류 | 무제한 — 공짜 줄·돌만으로 찬 줄(해석기 규칙 11 위반) 위험 |
