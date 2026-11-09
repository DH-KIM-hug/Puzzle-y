# 스테이지 & 목표 (Stage & Goals)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-09 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 4 한 판 더

## Summary

스테이지 & 목표는 한 판의 데이터(`StageDef` — 시작 보드, 목표 1~2개, 제한 조각 수, 별 기준, 팀 규칙, 트레이 시드·스크립트)와, 판 도중 연쇄 해석기 이벤트와
점수 누계만 읽어 목표 진행을 세는 `GoalTracker`를 정의한다. 목표는 점수 / 목표 칸 지우기 / 얼음 방해물 풀기 / 연쇄 N 네 가지이고, 목표를 이루면 즉시 클리어되어
남은 조각이 보너스가 되며 별은 클리어(1) + 최종 점수 임계값 2개로 매긴다 — "가장 큰 연쇄를 노릴까, 목표를 먼저 끝낼까"라는 트레이드오프로 미리보기가 "최고 숫자
찾기"로 퇴화하는 위험을 막는다 (기둥 2·3·4). MVP 10스테이지 학습 곡선(얼굴 없는 줄 → 얼굴 → 2단 연쇄 → 3인 팀 → 방해물)을 튜닝 목표와 함께 제안한다.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `보드 & 조각 규칙`, `연쇄 해석기 & 능력 프리미티브`, `점수 & 연쇄 배율`, `트레이 공급`, `칸 종류 & 방해물` (upstream) — downstream: 판 진행 흐름, 팀 편성, 연쇄 미리보기, 스테이지 진행 & 해금, 재화 & 보상, 플레이 HUD, 메타 화면 UI, 튜토리얼

## Overview

스테이지 & 목표는 "한 판이 무엇이고 언제 끝나는가"를 정한다. 데이터 층에서 스테이지는 `StageDef` Custom Resource 하나다:
시작 보드(미리 깐 조각·얼굴·알·방해물), 목표 1~2개, 제한 조각 수, 별 2·3 기준 점수, 팀 규칙(자유 편성 / 고정 팀),
트레이 시드·스크립트 필드(트레이 공급 GDD가 의미를 정한 값), 미리보기 정보량 값이 들어 있다. 판 도중 이 시스템은
**목표 추적기**로 동작한다 — 배치가 커밋될 때마다 연쇄 해석기의 이벤트 목록과 점수 누계만 읽어 목표 진행도를 올리고,
목표 달성(클리어)과 제한 조각 소진(실패)을 판정하며, 클리어 시 남은 조각 보너스와 별 1~3개를 계산한다. "놓을 곳 없음"
실패는 보드 규칙이 판정하고(board-rules 규칙 15), 같은 커밋에서 목표 달성과 막힘이 함께 성립하면 클리어다.

플레이어 쪽에서 이 시스템은 "이번 판에 해야 할 일"과 "아껴 쓸 조각"이다. 목표 네 가지 — **점수**, **목표 칸 지우기**,
**방해물 치우기**, **연쇄 N 달성** — 는 모두 같은 연쇄 해석 결과를 다른 눈으로 센 것이고, 제한 조각 수와 남은 조각 보너스가
"가장 큰 연쇄를 노릴까, 목표를 먼저 끝낼까"라는 선택을 만든다. 컨셉의 위험 *"미리보기가 너무 친절하면 '최고 숫자 뜨는 자리
찾기'로 단순해진다"*에 대한 완화책이 여기 있다 — 연쇄 미리보기는 구조를 다 보여 주지만(기둥 3), 어느 수가 *좋은* 수인지는
목표가 정한다 (chain-preview 규칙 16). 이 시스템이 없으면 연쇄는 점수 숫자만 남기고, 10스테이지 학습 곡선(컨셉 Flow State
Design)과 별 3개 재도전(기둥 4)이 성립하지 않는다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No` — ADR-0001은
`stage_seed`·`tray_seed_mode` 해석만 다루고 스테이지 GDD를 GDD Requirements에 두지 않는다; 데이터 형식은 ADR-0001 결정 8의
"데이터 전용 Custom Resource" 방침을 그대로 따른다 · Fantasy `[A] Yes`이지만 standard tier라 Player Fantasy 섹션은 생략하고
의도는 이 Overview와 Game Feel에 둔다. 구현 형태(`StageDef`/`GoalDef`/`CellSpec` 클래스 배치, 카탈로그 로드 시점) → ADR 또는
ADR-0001 개정.

*기술 타당성 (Godot 4.7, domain Scripting)*: Category `Gameplay`의 규칙 전용 시스템이라 엔진 도메인은 Scripting이며,
`docs/engine-reference/godot/modules/`에 `scripting.md`가 없어 고정 엔진 대비 타당성은 확인하지 않았다 (NOT SOURCEABLE).
의존하는 엔진 기능은 `Resource` `@export`(`PackedStringArray`, `Array[Vector2i]`, 하위 `Resource` 배열)뿐이며, ADR-0001
Verification (3)이 `.tres` int 왕복을 확인했다 — `2.0`처럼 적힌 값은 float로 로드되므로 검증기에서 `TYPE_INT`를 강제한다.

## Detailed Design

> *Specialist note*: `game-designer` · `level-designer` · `systems-designer` (Section 6 라우팅: Gameplay; systems-index 권장
> level-designer, game-designer) not consulted — Lean mode (Section C는 lean에서 생략) 및 이 실행에 Agent 도구 없음. Review manually
> before production. 특히 규칙 G의 10스테이지 표는 **level-designer 검토와 T0 자동 플레이 측정 전의 제안**이다.

### Core Rules

**A. `StageDef` — 스테이지 데이터 (Custom Resource)**

1. **스테이지 = `StageDef` `.tres` 한 개** — 로직 없는 데이터 리소스다 (ADR-0001 결정 8과 같은 방침). `StageCatalog` 리소스 1개가
   스테이지 목록과 순서를 들고, 게임 시작 시 1회 로드·검증 후 읽기 전용이다. 해금 순서·기록은 스테이지 진행 & 해금 GDD 소관이다.

   | 필드 | 형 | 기본 | 의미 · 검증 (규칙 2) | 의미를 정하는 곳 |
   |---|---|---|---|---|
   | `id` | StringName | — | `"1-1"` 형식, 카탈로그 안에서 유일, 영구 불변(세이브 키) | 이 문서 |
   | `schema_version` | int | 1 | 데이터 이주용 | 이 문서 |
   | `name_key` | String | — | 로컬라이즈 키 (스테이지 이름) | 이 문서 |
   | `board_rows` | PackedStringArray | 8줄 × `"........"` | 시작 보드 텍스트. 줄 수 = `board_height`, 각 줄 글자 수 = `board_width`. 글자 하나 = 칸 하나 | 이 문서 (형식) · board-rules (`validate_board`) |
   | `cell_legend` | Dictionary[String → `CellSpec`] | `{".": EMPTY}` | 글자 → 칸 정의. `.`는 항상 `EMPTY`로 예약 | 이 문서 |
   | `target_cells` | Array[Vector2i] | `[]` | 목표 칸 좌표 (row, col) — 보드 위 **겹 표시**이며 칸 종류가 아니다 (규칙 5) | 이 문서 |
   | `goals` | Array[`GoalDef`] | — | 1~`max_goals_per_stage`(2)개, 모두 달성해야 클리어 (규칙 8) | 이 문서 |
   | `piece_limit` | int | — | 이 판에 공급되는 조각 총수, `piece_limit_min`(3) ~ `piece_limit_max`(40). `−1` = 무제한 — **자유 플레이 `StageDef`**(목표 없음; T0 그레이박스·자동 플레이용, round-flow 규칙 24)에서만 허용 | 이 문서 · round-flow F1 |
   | `star_points` | PackedInt32Array | — | `[S2, S3]` — 별 2·3개 기준 `final_score` (기준 `cell_points_ref` = 10에서 적은 값, F1) | 이 문서 |
   | `team_rule` | `TeamRule` | 3인·제한 없음 | { `team_size`: 1–3 (기본 3), `locked`: Array[{`slot`, `crew_id`}] (기본 `[]`), `banned`: Array[StringName] (기본 `[]`) } (규칙 13) | team-composition 규칙 5–8 (의미·검증) · 이 문서 (필드 보유) |
   | `recommended_team` | Array[StringName] | `[]` | 표시용 추천 (규칙 없음) | 메타 화면 UI · 팀 편성 |
   | `stage_seed` | int | — | 0 ~ 2³¹−1, `FIXED` 시드 모드에서 필수 | tray-supply 규칙 18 · ADR-0001 `SeedHash` |
   | `tray_seed_mode` | enum | `FIXED` | `FIXED` \| `PER_ATTEMPT` | tray-supply 규칙 18 |
   | `stage_base_seed` | int | 0 | `PER_ATTEMPT`일 때만 사용 | tray-supply F3 |
   | `tray_script` / `after_script` | Array / enum | `[]` / `GENERATE` | 손으로 짠 트레이 순서 | tray-supply 규칙 19–22 |
   | `rescue_enabled` | bool | true | 최소 구제 | tray-supply 규칙 13 |
   | `allow_faceless_pieces` | bool | false | 얼굴 없는 조각 허용 (튜토리얼) | board-rules 규칙 5 |
   | `faceless_share` | float | 0.0 | 생성 조각의 얼굴 없음 비율 | tray-supply 규칙 11 |
   | `preview_detail` | enum | `FULL` | `FULL` \| `NO_BANNER` \| `FIRST_STAGE_ONLY` — MVP 출시 스테이지는 모두 `FULL` | chain-preview 규칙 17 |
   | `show_predicted_score` | bool | false | 미리보기 예상 총점 한 줄 | chain-preview 규칙 13 |
   | `goal_markers` | bool | true | 미리보기에 목표 표식 강조 (규칙 14) | 이 문서 · chain-preview |

   - **`CellSpec`** = { `type`: StringName (`EMPTY` \| `TILE` \| 방해물 GDD가 등록한 칸 종류 id), `crew_id`: StringName \| null,
     `is_face`: bool, `origin`: `PIECE` \| `EGG`, `modifiers`: Array[StringName] }. board-rules 규칙 2의 칸 = 칸 종류 + 내용물을 그대로 옮긴 것이다.
     시작 보드 칸의 `placement_id`는 0(= "스테이지가 깐 칸").
   - **`GoalDef`** = { `type`: `SCORE` \| `CLEAR_CELLS` \| `CLEAR_OBSTACLES` \| `CHAIN`, `required`: int, `keys`: Array[StringName]
     (`CLEAR_OBSTACLES`만 — 방해물 GDD의 modifier `kind`, MVP는 `ice`), `depth`: int (`CHAIN`만) }. 의미와 세는 법은 규칙 B.
   - **방해물 칸 표기** (obstacles 규칙 6): 돌 `{ type: STONE }`, 얼음 칸 `{ type: TILE, is_face: false, crew_id: null, modifiers: [{kind: ice, layers: n}] }`,
     얼어붙은 얼굴 `{ type: TILE, is_face: true, crew_id: X, modifiers: [{kind: ice, layers: 1}] }`. `CellSpec.modifiers`는 `{kind, layers}` 항목 배열이다.
   - **보드 텍스트 예시** (1-3 제안, 가로 = col 0→7):
     ```
     board_rows = ["........", "........", "...ggG..", "...ggg..", "........", "........", "nnnnn.nn", "........"]
     cell_legend = { ".": EMPTY, "g": TILE(crew gomgom), "G": TILE(crew gomgom, is_face), "n": TILE(crew nyangi) }
     ```
     의도한 해법: 스크립트 첫 조각 냥이 I3_V(얼굴 = 아래 칸)를 5열 4~6행에 놓으면 6행이 완성 → 냥이 얼굴 발동(연쇄 1) → 십자가 5열을 지우며
     곰곰 얼굴 (2, 5)를 깨움 → 곰곰 3×3(연쇄 2). 시작 보드에 완성 줄은 없다(6행 7칸, 5열 2칸).
     같은 크루의 일반 칸과 얼굴 칸은 글자를 달리 둔다. 글자 선택은 자유이며 레전드에 없는 글자는 로드 오류다.

2. **로드 시 검증 (실패 = 스테이지 로드 오류: 개발 중 에러 표시, 출시 빌드에는 검증 통과 데이터만)** — 아래를 모두 만족해야 한다.
   - 보드: `board_rows` 크기 일치, 모든 글자가 `cell_legend`에 있음, 모든 `CellSpec.type`이 등록된 칸 종류, board-rules `validate_board`
     통과(완성 줄 0개, 얼굴 칸은 `crew_id` 있음), 얼굴 칸의 `crew_id`가 크루 레지스트리에 있음(chain-resolver 규칙 18 — 팀 밖 크루도 가능).
   - 목표: `goals` 1~`max_goals_per_stage`개, 같은 `type` 중복 없음, 각 `required ≥ 1`. 유형별: `SCORE` → `required ≤ score_target_max`;
     `CLEAR_CELLS` → `target_cells` 비지 않음, 모든 좌표가 보드 안·중복 없음, `required ≤ |target_cells|`, 목표 칸의 시작 칸 종류는
     `removable_by_clear = true`이거나 `EMPTY`(돌 칸은 목표 칸이 될 수 없다); `CLEAR_OBSTACLES` → `keys` 비지 않음, 모두 방해물 GDD에 등록된
     modifier `kind`, `required ≤` 시작 보드에서 그 `kind`를 가진 칸 수(F3c — 방해물은 판 도중 생기지 않는다, obstacles 규칙 2·15);
     `CHAIN` → `1 ≤ depth ≤ depth_cap`(chain-resolver, 6). `target_cells`가 있는데 `CLEAR_CELLS` 목표가 없으면 오류(쓸모없는 표식).
     방해물 배치 자체는 obstacles `validate_obstacles`(V1–V5)가 검증한다.
   - 조각·별: `piece_limit` 범위 안; `star_points`는 정확히 2개이고 `0 < S2 < S3`. 자유 플레이(`piece_limit = −1`)는 `goals`·`star_points`가 비어 있어야 한다.
   - 팀: team-composition 규칙 6 (`locked` 슬롯 < `team_size`, 중복 금지, `banned`와 충돌 금지, `colour_slot` 중복 금지, 모든 id가 레지스트리에 있음).
     `team_size < 3`이면 `locked`가 모든 슬롯을 채워야 한다(1–2인 팀은 튜토리얼 고정 팀 전용 — 이 문서의 추가 조건).
   - 트레이 필드: tray-supply 규칙 22 (스크립트 검증), `FIXED` 시드 모드에서 `stage_seed` 필수(tray-supply Edge Cases).
   - **린트 경고 (로드는 됨)**: `SCORE` 목표에서 `S2 ≤ required` (클리어하면 별 2가 거의 자동), `goals`가 2개인데 둘 다 `SCORE`·`CHAIN`처럼
     연쇄 하나로 동시에 끝나기 쉬운 조합, `piece_limit`이 F8 안내 범위 밖.

**B. 목표 유형과 세는 법 — 이벤트만 읽는다**

3. **목표 추적기 `GoalTracker` 계약** (round-flow Q3의 이름을 그대로 쓴다):
   - `start(stage_def, start_board)` — 진행 0. 시작 보드에서 **방해물 장부** `ice_cells`(좌표 → 남은 겹, F3c)를 한 번 만든다. 방해물은 판 도중 생기지 않으므로
     (obstacles 규칙 2·15, chain-resolver 규칙 17) 이후 장부는 이벤트만으로 정확히 따라간다.
   - `apply(result, breakdown, stage_score)` — 배치 하나의 `ChainResult`(이벤트 목록)와 커밋 후 누계 `stage_score`(scoring 규칙 11)를 받아 진행을 갱신한다.
     `breakdown`(`ScoreBreakdown`)은 round-flow 커밋 순서 6)이 넘기는 값이며 MVP 목표는 쓰지 않는다. 보드를 다시 판정하지 않고 해석기를 다시 부르지 않는다
     (ADR-0001 결정 3: 목표 진행은 이벤트에서만).
   - `is_met() → bool` (F4), `pieces_out(pieces_left) → bool` (규칙 9), `snapshot()` (HUD·결과 화면용 목표별 진행), `preview(result) → GoalPreview` (규칙 14).
   - **결정성** — 같은 시작 보드와 같은 이벤트 열 → 같은 진행. 정수만 쓴다. **진행도는 단조 증가**한다 — 한 번 센 것은 줄지 않는다. 판 진행 흐름이 배치 커밋
     직후(점수 확정과 같은 순간, 연출 재생 전) 한 번 부른다.
   - **별 계산** `stars(stage_def, round_result) → 0..3` (F7)과 `final_score`(F6)는 상태 없는 함수다 — round-flow `RoundResult.stars`를 채운다.
4. **`SCORE`** — 진행도 = `stage_score` (F3a). `stage_score ≥ required_eff`(F1로 환산)이면 달성. 남은 조각 보너스(F5)는 **포함하지 않는다** —
   보너스는 클리어 *뒤에* 붙는다.
5. **`CLEAR_CELLS` (목표 칸)** — `target_cells` T는 보드 좌표 위의 겹 표시다(칸 종류가 아님 — 칸 내용이 바뀌어도 표시는 그 좌표에 남는다).
   이번 배치의 모든 `CELLS_CLEARED` 이벤트의 `cells[]` 좌표 중 T에 속하는 것을 `done` 집합에 더한다 (F3b). `kept[]`(훅 `pre_clear`가 `KEEP`한 칸)와
   `CELL_MODIFIED`는 세지 않는다 — "지워졌다"만 센다. 지운 이유(`by` = `LINE`·`ABILITY`·`BOTH`)와 칸 출처(`origin` = `PIECE`·`EGG`)는 따지지 않는다:
   알이 채운 칸이 지워져도 그 좌표는 끝난다. 한 좌표는 한 번만 센다. 목표 칸이 빈칸으로 시작하면 플레이어가 그 칸을 채워 지워야 한다.
   진행도 = `|done|`, `|done| ≥ required`이면 달성.
6. **`CLEAR_OBSTACLES` (방해물 — MVP는 얼음)** — `keys`는 방해물 GDD가 등록한 modifier `kind` 목록이다(MVP: `ice` — 얼음 칸과 얼어붙은 얼굴이 모두
   `ice`다, obstacles 규칙 2·3). **단위는 "얼음에서 풀려난 칸"**이다 — obstacles F3의 `iced_cells` 감소분이며, 겹 수(`ice_remaining`)가 아니다 (D5).
   이번 배치의 `CELL_MODIFIED` 이벤트를 순서대로 읽어, `modifiers_before`에 `keys`의 `kind`가 있고 `modifiers_after`에 없는 칸마다 +1 (F3c).
   2겹 얼음은 첫 타격에서 `layers` 2 → 1(진행 없음), 두 번째 타격에서 1 → 0(+1)이다. 얼음이 벗겨진 칸이 나중에 지워지는 것(`CELLS_CLEARED`)은 세지 않는다 —
   이미 센 칸이다. 돌(`STONE`)은 지울 수 없는 칸 종류라 목표가 될 수 없다(obstacles F3 "돌은 세지 않는다"). 얼음 `kind`가 칸에서 지워지는 다른 경로는 MVP에
   없다(얼음 칸은 `pre_clear`가 언제나 `KEEP`한다, obstacles 규칙 7). Post-MVP 방해물이 `CELLS_CLEARED`로 사라지는 종류라면 같은 장부에서 "그 좌표가 처음
   지워질 때 +1"로 센다 — 장부가 시작 보드에서 오므로 알이 채운 칸을 방해물로 잘못 세지 않는다.
7. **`CHAIN` (연쇄 N)** — `CHAIN_END.chain_depth ≥ depth`인 배치마다 +1 (F3d). `required`번이면 달성 (기본 1 = "연쇄 N을 한 번"). `chain_depth`는
   chain-resolver F2 정의 그대로다: 얼굴이 하나 이상 *발동*한 웨이브 수이고, 상한 도달 웨이브와 `SUPPRESSED`만 있는 웨이브는 세지 않는다.
   crew-definition F4a 근사에 따르면 기본 팀은 줄을 지운 배치의 ≈ 90%에서 연쇄 1이 나므로, **일반 스테이지의 `depth`는 3 이상**을 쓴다.
   `depth` 1~2는 연쇄를 처음 가르치는 튜토리얼 스테이지(1-2·1-3)용이다.
8. **목표 묶음** — 스테이지의 목표는 1~2개이며 **모두** 달성해야 클리어다(AND). 달성 순서는 상관없고, 먼저 달성한 목표는 달성 상태로 남는다.
   "둘 중 하나"(OR)는 두지 않는다 (Decision Log D4).

**C. 판 결과 판정**

9. **판정 기준 (시점·우선순위는 round-flow 규칙 7·9)** — 판 진행 흐름은 배치를 커밋할 때마다 채점(scoring) → `GoalTracker.apply` → 트레이 소비·재충전
   → 종료 판정 순서로 부르며, 종료 판정에서 이 시스템의 두 질의를 쓴다:
   1. `is_met()` — 모든 목표가 달성(F4)이면 **`CLEARED`**.
   2. `pieces_out(pieces_left)` — `pieces_left = 0`(F2)이고 목표 미달성이면 참 → **`FAILED(OUT_OF_PIECES)`**. 제한 조각 소진 실패의 *기준*은 이 시스템이
      소유한다 (board-rules D12). round-flow의 "트레이가 비었고 `refill_budget = 0`"은 재충전이 빈 트레이에서만 일어나므로 같은 조건이다(round-flow F2).
   3. 그 밖의 막힘은 board-rules `no_moves` → **`FAILED(NO_MOVES)`** (보드 규칙 판정, 판 진행 흐름 호출).
   우선순위는 `CLEARED` > `FAILED(OUT_OF_PIECES)` > `FAILED(NO_MOVES)`다 — 같은 배치에서 목표 달성과 막힘·조각 소진이 함께 성립하면 **클리어**다
   (board-rules AC-17, round-flow 규칙 9). 연쇄 해석은 동기적으로 한 번에 끝나므로(chain-resolver 규칙 6) "연쇄 도중 달성"은 따로 없다 — 그 배치의 연쇄
   전체가 점수와 진행도에 들어간 뒤 판정한다 (round-flow 규칙 10).
10. **클리어는 즉시** — `CLEARED`가 되면 남은 조각은 쓰지 않고 판이 끝난다(연출 재생 후 결과 화면). 쓰지 않은 조각은 **남은 조각 보너스**(F5)가 된다:
    `final_score = stage_score + leftover_bonus` (F6), 별은 F7. 보너스는 `stage_score`에 더하지 않고 별도 값으로 둔다 — scoring의 누계 정의를 바꾸지
    않는다 (scoring Q7 해소, round-flow Q1 해소: 즉시 종료 + 남은 조각당 보너스). 결과 화면은 `stage_score`, 보너스, `final_score`, 별을 함께 보여 준다.
11. **실패** — `FAILED(OUT_OF_PIECES)`·`FAILED(NO_MOVES)`·포기(`ABANDONED`)는 별 0, 보너스 0. 페널티·재화 차감 없음(컨셉 Recovery from failure). 실패 연출은 귀엽게(기둥 5)
    하며, 원탭 재시작은 직전 팀을 유지한다(기둥 4 — 판 진행 흐름 소관).
12. **재시도** — 진행도·`pieces_placed`·`stage_score`를 0으로 되돌리고 같은 `StageDef`를 다시 로드한다. `tray_seed_mode = FIXED`면 같은 팀일 때 첫 트레이와
    순서가 같다(tray-supply AC-18) — "아까 그 수를 다르게"가 바로 가능하다.

**D. 팀 규칙**

13. **팀 규칙은 team-composition 규칙 5–8의 `team_rule`을 그대로 채택한다** (동시 작성된 제안과 필드 이름·의미 일치 — Decision Log D7). 이 문서는 필드를
    `StageDef`에 두고 스테이지별 값을 정할 뿐, 의미(게스트·금지·기본 팀 해석)는 팀 편성 소관이다.
    - **자유 편성** = `locked` 비어 있음 — 플레이어가 보유 크루 중 `team_size`(3)명을 고른다. **고정 팀** = `locked`가 모든 슬롯을 채움 — 편성 화면에서 바꿀
      수 없다(튜토리얼). 일부 슬롯만 `locked` = "이 크루는 꼭 함께"(MVP 출시 스테이지는 쓰지 않음).
    - `locked` 크루가 보유하지 않은 크루면 **게스트**다 — 그 판에만 빌려 쓰고 보유로 바뀌지 않는다(team-composition 규칙 7).
    - 트레이 스크립트의 `crew_id` 직접 지정은 그 크루가 `locked`된 스테이지에서만 허용한다 (tray-supply 규칙 22의 "팀 고정" = `locked`; tray-supply Q7·
      team-composition Q5 해소).
    - **기본 보유 보장** (crew-definition 규칙 10): MVP 10스테이지는 모두 기본 보유 3인(냥이·곰곰·삐약)과 게스트만으로 별 1개 클리어가 가능해야 하며,
      자동 플레이 수용 기준(AC-SG20)으로 확인한다. 별 3개는 다른 팀이 더 쉬워도 된다(기둥 2 "팀이 경로를 바꾼다").

**E. 미리보기와 목표 표식 (chain-preview Q2 해소)**

14. **`GoalTracker.preview(result) → GoalPreview`** (chain-preview의 `goal_markers` 훅) — 연쇄 미리보기가 가상 결과(같은 `resolve`의 `ChainResult`)에 부르는
    표식 질의. 추적기 상태를 바꾸지 않으며 규칙 B와 **같은 세기 코드**를 쓴다(미리보기용 근사 금지 — chain-resolver 규칙 3과 같은 방침). 반환:
    `target_cells_hit`(아직 안 끝난 목표 칸 중 이 배치로 지워질 좌표), `obstacles_freed`(이 배치로 얼음에서 풀려날 좌표 — 겹만 벗겨질 칸은 obstacles 규칙 14의
    "금" 표시가 이미 보여 준다), `chain_goal_hit`(이 배치의 `chain_depth ≥ depth`인 `CHAIN` 목표 id), `completes_stage`(이 배치로 모든 목표가
    달성되는가). `goal_markers = false`면 미리보기는 이를 무시한다. **점수 목표는 표식이 없다** — 예상 점수는 `show_predicted_score`일 때만 보인다(chain-preview D2,
    "값은 숨긴다"). 표식은 **사실만** 말한다(지워질 목표 칸에 동그라미, 배너에 ✓) — "추천 자리", 히트맵, 다른 앵커와의 비교는 없다(chain-preview 규칙 14).

**F. 트레이드오프 원칙 — "가장 큰 연쇄 ≠ 가장 좋은 수" (레벨 설계 지침)**

15. 스테이지는 아래 지렛대 중 **하나 이상**으로 "미리보기에서 가장 큰 연쇄가 뜨는 자리"와 "목표에 가장 좋은 자리"를 갈라놓는다. 각 MVP 스테이지가 어느
    지렛대를 쓰는지는 규칙 G 표의 "트레이드오프" 열에 적는다.
    - **T1 위치** — 목표 칸·방해물을 기본 팀의 큰 연쇄가 잘 닿지 않는 곳(가장자리·모서리, 얼굴이 모이기 어려운 줄)에 둔다.
    - **T2 탐욕 vs 안전** — 클리어는 즉시이고 남은 조각은 보너스(F5)다. 목표 하나를 남겨 두고 연쇄로 점수를 더 모으면 별이 오를 수 있지만, 조각을 쓸수록
      보너스가 줄고 막힘·소진 실패 위험이 커진다. 조각 1개의 보너스(`leftover_piece_points` 100 ≈ 한 줄 지우기 85점)는 "연쇄를 만들 수 있을 때만 욕심이
      남는다"가 되도록 정했다.
    - **T3 아끼기** — `CHAIN` 목표는 얼굴을 모아 두는 수(줄을 당장 지우지 않음)를 요구하고, 제한 조각 수가 모으는 비용을 만든다 (chain-resolver Edge Cases).
    - **T4 순서** — 얼음 칸이 든 줄은 완성돼도 얼음 칸이 남아(겹만 벗겨짐) 다시 채워야 하고, 얼어붙은 얼굴은 한 번 녹여야 발동한다(obstacles 규칙 2·3).
      돌은 줄을 적은 칸으로 완성시키지만 영영 남는다(obstacles 규칙 1). 그래서 "어느 줄을 먼저 깰까"가 연쇄 경로보다 앞서는 판을 만든다.

**G. MVP 10스테이지 (제안 — 모든 수치는 플레이테스트 튜닝 목표 ‡)**

16. 학습 곡선은 컨셉 Flow State Design을 따른다: 1-1 얼굴 없는 줄 지우기 → 1-2 얼굴 = 스위치 → 1-3 첫 2단 연쇄 → 1-5 3인 팀 → 1-8 방해물. 한 스테이지에 새
    개념은 하나만 넣는다. 별 기준은 `cell_points_ref` = 10 기준 `final_score`이며 F9 절차(자동 플레이 분포)로 확정한다. 방해물은 obstacles GDD의 MVP 세트 — **돌**(`STONE`,
    지형)과 **얼음**(`ice` 1~2겹, 얼굴 위 1겹 = 얼어붙은 얼굴) — 만 쓴다. 팀 열의 "고정"은 `locked`가 모든 슬롯을 채운 팀(규칙 13), "자유"는 `locked` 없음.

    | id | 가르치는 것 | 팀 (`team_rule`) | 트레이 | 시작 보드 요지 | 목표 ‡ | 조각 ‡ | ★2 / ★3 ‡ | 트레이드오프 |
    |---|---|---|---|---|---|---|---|---|
    | 1-1 | 줄이 차면 지워진다 | 고정 [냥이] (`team_size` 1) | `tray_script` 얼굴 없는 I3_H·D2_H·D1 (`LOOP`), `allow_faceless_pieces` | 6·7행에 6칸씩, 빈칸 위치가 서로 다름 | `SCORE` 160 (줄 2개) | 8 | 600 / 750 | T2 (적게 써서 끝내기) |
    | 1-2 | 얼굴이 지워지면 능력! (미리보기 첫 등장) | 고정 [냥이] (`team_size` 1) | `tray_script` 첫 트레이 얼굴 위치 고정, 이후 `GENERATE` | 7행 5칸 + 3열에 흩어진 칸 (십자가 지울 거리) | `CHAIN` depth 1 × 2 | 8 | 700 / 1000 | — (학습) |
    | 1-3 | 첫 2단 연쇄 (냥이 → 곰곰) | 고정 [냥이, 곰곰] (`team_size` 2) | `tray_script` 1트레이 + `GENERATE` | 위 예시: 곰곰 얼굴이 냥이 십자 열 위에 미리 깔림 | `CHAIN` depth 2 × 1 | 10 | 900 / 1300 | — (학습) |
    | 1-4 | 목표 칸 | 고정 [냥이, 곰곰] (`team_size` 2) | 생성, `FIXED` 시드 | 목표 칸 6개를 모서리 쪽 두 줄에 | `CLEAR_CELLS` 6/6 | 12 | 1200 / 1700 | T1 |
    | 1-5 | 3인 팀 · 삐약 알 (첫 팀 편성) | 자유 (추천 냥이·곰곰·삐약) | 생성, `FIXED` 시드 | 거의 빈 판, 7칸 찬 줄 2개 | `SCORE` 1500 | 18 | 2000 / 2600 | T2 |
    | 1-6 | 알이 줄을 채워 다시 불붙인다 | 자유 | 생성, `FIXED` 시드 | 7칸 찬 줄 여러 개 (알 재점화 자리) | `CHAIN` depth 3 × 1 | 15 | 1500 / 2100 | T3 |
    | 1-7 | 목표 칸 vs 큰 연쇄 | 자유 | 생성, `FIXED` 시드 | 목표 칸 8개를 네 모서리 주변에 | `CLEAR_CELLS` 8/8 | 16 | 1700 / 2400 | T1 · T2 |
    | 1-8 | 첫 방해물: 얼음 칸 (한 번 맞으면 깨짐) | 자유 | 생성, `FIXED` 시드 | 1겹 얼음 칸 6개가 줄 3개에 섞임 | `CLEAR_OBSTACLES` [`ice`] 6 | 16 | 1800 / 2500 | T4 |
    | 1-9 | 얼어붙은 얼굴 (녹이고 → 터뜨리기) · 2겹 얼음 | 자유 | 생성, `FIXED` 시드 | 얼어붙은 얼굴 4개(팀 밖 크루 1명 포함) + 2겹 얼음 칸 2개 | `CLEAR_OBSTACLES` [`ice`] 6 + `CHAIN` depth 3 × 1 | 18 | 2000 / 2800 | T3 · T4 |
    | 1-10 | 졸업 — 종합 (돌 첫 등장) | 자유 | 생성, `FIXED` 시드 | 돌 4개(지형) + 목표 칸 6 + 얼음 칸 4, 서로 다른 구역 | `CLEAR_CELLS` 6/6 + `CLEAR_OBSTACLES` [`ice`] 4 | 20 | 2400 / 3300 | T1 · T2 · T4 |

    - **공통 값**: `stage_seed` = 스테이지별 고유값(자동 플레이로 고른 뒤 고정 — 제안 시작값 `1100 + 번호`), `rescue_enabled = true`, `preview_detail = FULL`,
      `show_predicted_score = false`(1-1만 `true` — 점수 목표를 처음 볼 때 "+N 예상" 한 줄로 단위를 익힘), `goal_markers = true`, `team_rule.banned = []`.
    - **튜닝 목표 ‡ (T0 자동 플레이 + 외부 플레이테스트로 확정)**: 기본 보유 3인 기준 자동 플레이 봇의 별 1 클리어율 1-1~1-4 ≥ 95%, 1-5~1-10 ≥ 70%(AC-SG20);
      사람 테스터 첫 시도 별 1 클리어율 1-1~1-4 ≥ 90%, 1-5~1-10 50~80%; 별 3은 클리어한 판의 20~40%(F9의 S3 분위). 목표 수치·조각 수·별 기준은 이 목표에
      맞춰 움직인다 — 표의 값은 crew-definition F4a의 기본 팀 연쇄 근사와 scoring F5 예시(한 줄 ≈ 85, 연쇄 2단 ≈ 300~500)로 잡은 시작값이다.
    - **1-1·1-2·1-3의 스크립트**는 해법 배치 목록을 함께 커밋해 자동 재생 검증한다 (tray-supply AC-15b).

**H. 데이터 기반 값** (standard tier라 Tuning Knobs 섹션은 생략 — 범위와 근거는 여기와 Formulas 변수표에 둔다)

| 값 | 시작값 | 안전 범위 | 소유 | 근거 · 너무 크거나 작으면 |
|---|---|---|---|---|
| `leftover_piece_points` | 100 | 0 ~ 300 | 이 문서 (전역 `StageRules`) | 한 줄 지우기(≈ 85)와 비슷하게 — 크면 "빨리 끝내기"가 모든 판의 정답(연쇄 동기 약화), 작으면 별이 연쇄 점수 경쟁만 남아 "최고 숫자 찾기"로 퇴화 (T2) |
| `cell_points_ref` | 10 | 상수 | 이 문서 | scoring `cell_points` 시작값. 스테이지 데이터의 점수 값은 이 기준으로 적고 F1로 환산 — `cell_points`를 바꿔도 스테이지 데이터를 고치지 않는다 |
| `max_goals_per_stage` | 2 | 1 ~ 3 | 이 문서 | 3개 이상이면 HUD·인지 부담 (세로 폰 HUD 1줄) |
| `piece_limit_min` / `piece_limit_max` | 3 / 40 | — | 이 문서 | 3 미만은 트레이 한 번도 못 채움, 40 초과는 한 판 2~4분(컨셉 Session Length) 초과 |
| `score_target_max` | 20000 | — | 이 문서 | 데이터 오타 방지용 상한 (scoring F6 검증 상한보다 충분히 작다) |
| 스테이지별 값 | 규칙 G 표 | 규칙 2 | 스테이지 데이터 | 목표·조각 수·별 기준은 F8·F9 절차로 정한다 |

### States and Transitions

목표 추적기의 상태는 **한 번의 스테이지 시도** 동안만 존재한다. 전이를 일으키는 쪽은 판 진행 흐름이며, 이 시스템은 `is_met()`·`pieces_out()` 답을 돌려줄 뿐이다 (round-flow 규칙 9).

| 상태 | 진입 | 들고 있는 것 | 다음 |
|---|---|---|---|
| `LOADED` | `StageDef` 로드·검증 통과 | 시작 보드, 목표 정의 | 팀 확정(자유 편성이면 팀 편성 화면, 고정 팀이면 즉시) → `GoalTracker.start` → `IN_PROGRESS` |
| `IN_PROGRESS` | 시도 시작 / 재시도 | 목표별 진행, 목표 칸 `done` 집합, 얼음 장부 `ice_cells` | 배치 커밋 → `apply` → 판 흐름 종료 판정: `is_met()` → `CLEARED` / `pieces_out()` → `FAILED_OUT_OF_PIECES` / `no_moves` → `FAILED_BLOCKED` / 그 밖 → `IN_PROGRESS`; 나가기 → `ABANDONED` |
| `CLEARED` | 모든 목표 달성 | `final_score`, 별 1~3, 남은 조각 수 | 결과 화면 → 재시도(`IN_PROGRESS`) / 다음 스테이지 / 나가기 |
| `FAILED_OUT_OF_PIECES` | 조각 소진 + 목표 미달 | 진행도 (결과 화면 "조금만 더!" 표시용) | 재시도 / 나가기 |
| `FAILED_BLOCKED` | 놓을 곳 없음 (board-rules) | 같음 | 재시도 / 나가기 |
| `ABANDONED` | 판 도중 나가기 | — (기록 없음) | — |

`CLEARED`·`FAILED_*`·`ABANDONED`는 종료 상태다. 종료 뒤에는 `apply`를 부르지 않는다 (호출은 assert). 별·`final_score`의 최고 기록 저장은
스테이지 진행 & 해금 GDD 소관이며, 재화 보상은 재화 & 보상 GDD가 결과(별 수, 첫 클리어 여부)를 읽어 정한다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 스테이지 → 보드 규칙 | 시작 보드(`validate_board`), `allow_faceless_pieces`; 칸 종류 플래그(`removable_by_clear`) 조회 | 보드 규칙 (함수) / 스테이지 (데이터) |
| 연쇄 해석기 | 해석기 → 스테이지 | `CELLS_CLEARED.cells`(목표 칸), `CELL_MODIFIED`(얼음 해제), `CHAIN_END.chain_depth`(연쇄 N); 스테이지 → 해석기: 없음 (스테이지 상태는 해석기 입력이 아니다, chain-resolver 규칙 17) | 해석기 (이벤트 스키마) / 스테이지 (세는 법) |
| 점수 & 연쇄 배율 | 점수 → 스테이지 | 커밋 후 `stage_score` (점수 목표, `final_score`) | 점수 (누계) / 스테이지 (목표·별·보너스) |
| 트레이 공급 | 스테이지 → 트레이 | `stage_seed`, `tray_seed_mode`, `stage_base_seed`, `tray_script`, `after_script`, `rescue_enabled`, `allow_faceless_pieces`, `faceless_share`, 고정 팀 여부; budget = `pieces_left`(판 흐름 경유) | 트레이 (필드 의미·검증) / 스테이지 (값) |
| 칸 종류 & 방해물 (`obstacles.md`) | 방해물 → 스테이지 | 칸 종류 `STONE`·modifier `ice` 표기(`CellSpec`), `validate_obstacles`, `CELL_MODIFIED`로 얼음 해제 (F3 `iced_cells`) | 방해물 (종류) / 스테이지 (배치·목표 키) |
| 크루 정의 & 능력 | 크루 → 스테이지 | 레지스트리 id 유효성, `starter_ids()` | 크루 정의 |
| 판 진행 흐름 (`round-flow.md`) | 판 흐름 → 스테이지 | 시도 시작·재시도(`GoalTracker.start`), 배치 커밋마다 `apply`, 종료 판정에서 `is_met`·`pieces_out`, 결과에 `stars`·`final_score`, budget = `pieces_left` | 판 진행 흐름 (타이밍) / 스테이지 (판정) |
| 팀 편성 (`team-composition.md`) | 스테이지 → 팀 편성 | `team_rule` {`team_size`, `locked`, `banned`}, `recommended_team`, 목표 요약·제한 조각 수·별 기준(표시용) | 스테이지 (규칙) / 팀 편성 (화면·선택) |
| 연쇄 미리보기 | 스테이지 → 미리보기 | `preview_detail`, `show_predicted_score`, `goal_markers`, `goal_preview` 훅 | 스테이지 (세는 법) / 미리보기 (표시) |
| 플레이 HUD · 메타 화면 UI | 스테이지 → UI | 목표 정의·진행도, `pieces_left`, 별 기준, 결과(`final_score`, 별, 보너스) | 각 UI GDD (표시) |
| 스테이지 진행 & 해금 · 재화 & 보상 | 스테이지 → 진행·보상 | 종료 상태, 별, `final_score`, 시도 중 최장 `chain_depth` | 각 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. 모든 식은 정수 연산이다(scoring·chain-resolver와 같은 결정성 방침). 점수 단위의 값은 `cell_points_ref` = 10 기준으로
> 데이터에 적고 F1로 환산한다.

**F1. 점수 값 환산 (스케일 노브 연동)**

The pts_eff formula is defined as:

`pts_eff(x) = ⌊ x × cell_points / cell_points_ref ⌋`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| x | int | 1 – 20000 | data file (`StageDef.goals[SCORE].required`, `star_points`, `leftover_piece_points`) | 기준 스케일로 적은 점수 값 |
| cell_points | int | 1 – 50 (시작 10) | data file (`ScoringRules`, scoring 소유) | 지워진 칸 하나의 기본 점수 |
| cell_points_ref | int | 10 | constant (이 문서) | 스테이지 데이터를 적은 기준 스케일 |

**Output Range:** 시작값(`cell_points` = 10)에서 `pts_eff(x) = x`. `cell_points`를 20으로 올리면 모든 목표·별 기준·보너스가 2배 — scoring Tuning Knobs의
"`cell_points`를 바꾸면 별 기준도 같은 비율로"를 데이터 수정 없이 지킨다. **Example:** `star_points = [600, 750]`, `cell_points = 15` → 900, 1125.

**F2. 남은 조각**

The pieces_left formula is defined as:

`pieces_left = piece_limit − pieces_placed`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| piece_limit | int | 3 – 40 (`−1` = 무제한, 자유 플레이 전용) | data file (`StageDef`) | 이 판에 공급되는 조각 총수 |
| pieces_placed | int | 0 – piece_limit | calculated (커밋된 배치 수 = round-flow `placements_used`) | 놓은 조각 수 |

**Output Range:** 0 ~ `piece_limit`. round-flow F1과 같은 식이다(그쪽이 표시·budget용으로 계산하고, 이 문서는 조각 소진 기준과 보너스에 쓴다). 무제한이면 `pieces_out`은
언제나 거짓, 보너스 없음. **Example:** `piece_limit = 16`, 11번 놓고 클리어 → `pieces_left = 5`.

**F3. 목표 진행 (유형별)**

The goal_progress formula is defined as:

`(a) P_score = stage_score`
`(b) P_cells = | done |,  done ← done ∪ { (r, c) ∈ cells(e) : e ∈ CELLS_CLEARED } ∩ T`
`(c) P_obst += | { e ∈ CELL_MODIFIED : ∃ m ∈ e.modifiers_before, m.kind ∈ keys ∧ ¬∃ m' ∈ e.modifiers_after, m'.kind = m.kind } |`
`(d) P_chain += [ CHAIN_END.chain_depth ≥ depth ]`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stage_score | int | 0 – (scoring F6 상한 × 조각 수) | calculated (scoring 규칙 11, 커밋 후 누계) | 판 누계 점수 |
| T | 좌표 집합 | 1 – 64칸 | data file (`StageDef.target_cells`) | 목표 칸 |
| done | 좌표 집합 | ⊆ T | calculated (추적기 상태) | 이미 지워진 목표 칸 |
| cells(e) | 좌표 목록 | 0 – 64 | calculated (`CELLS_CLEARED.cells[]`의 (r, c); `kept[]` 제외) | 이번 배치에 실제로 지워진 칸 |
| keys | kind 목록 | MVP `[ice]` | data file (`GoalDef.keys`) | 세는 방해물 종류 |
| e.modifiers_before/after | modifier 목록 | — | calculated (`CELL_MODIFIED` 페이로드) | 훅 `pre_clear`가 바꾸기 전·후 수식자 |
| depth | int | 1 – `depth_cap` (6) | data file (`GoalDef.depth`) | 연쇄 N 목표의 N |
| CHAIN_END.chain_depth | int | 0 – 6 | calculated (chain-resolver F2) | 이번 배치의 연쇄 깊이 |

**Output Range:** (a) 0 이상. (b) 0 ~ |T|. (c) 0 ~ 시작 보드의 얼음 칸 수(`iced_cells`, obstacles F3; 스테이지 권장 ≤ 20). (d) 0 ~ `piece_limit`. 모두 단조 증가.
**Example:** 1-8에서 1겹 얼음 칸 2개가 든 줄을 완성 → `CELL_MODIFIED` 2개(각 `ice:1 → 없음`) → `P_obst` +2. 2겹 칸이면 첫 타격 `ice:2 → ice:1`(+0), 다음 타격 +1.
1-6에서 연쇄 3 배치 → `P_chain` = 1 → 달성. 목표 칸 (0, 7)이 웨이브 2에서 알로 채워졌다가 웨이브 3에 지워져도 `done`에 들어간다.

**F4. 클리어 조건**

The stage_cleared formula is defined as:

`is_met = ∀ g ∈ goals : P_g ≥ req_g`,  `req_g = pts_eff(required_g)` (SCORE) / `required_g` (그 밖)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| goals | GoalDef 목록 | 1 – 2개 | data file | 스테이지 목표 |
| P_g | int | F3 | calculated | 목표 g의 진행 |
| required_g | int | ≥ 1 (유형별 상한은 규칙 2) | data file (`GoalDef.required`) | 목표 g의 달성 기준 |

**Output Range:** bool. 목표가 없으면(자유 플레이) 언제나 거짓 — 자유 플레이는 `FAILED(NO_MOVES)`로만 끝난다 (round-flow Edge Cases).
**Example:** 1-10 — `P_cells = 6 ≥ 6` 그리고 `P_obst = 3 < 4` → 거짓. 다음 배치에서 `P_obst = 4` → 참.

**F5. 남은 조각 보너스**

The leftover_bonus formula is defined as:

`leftover_bonus = cleared ? pieces_left × pts_eff(leftover_piece_points) : 0`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cleared | bool | — | calculated (F4 참으로 끝남) | 클리어 여부 |
| pieces_left | int | 0 – 39 | calculated (F2) | 클리어 순간 남은 조각 (트레이에 남은 것 + 아직 안 나온 것) |
| leftover_piece_points | int | 0 – 300 (시작 100) | data file (`StageRules`) | 남은 조각 1개의 보너스 (기준 스케일) |

**Output Range:** 0 ~ 39 × 300 = 11,700 (이론); MVP 스테이지 시작값에서 대개 200 ~ 800. **Example:** 1-7(`piece_limit` 16)을 11개로 클리어 → 5 × 100 = **500**.

**F6. 최종 점수**

The final_score formula is defined as:

`final_score = stage_score + leftover_bonus`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stage_score | int | 0 이상 | calculated (scoring 규칙 11) | 판 누계 (보너스 미포함) |
| leftover_bonus | int | F5 | calculated | 남은 조각 보너스 |

**Output Range:** 실패면 `stage_score`와 같다(별 계산에는 쓰지 않음). 클리어 MVP 스테이지에서 대개 600 ~ 4,000. 6자리 HUD(scoring UI Requirements)에 들어간다.
**Example:** `stage_score = 1,240`, 보너스 500 → **1,740**.

**F7. 별 개수**

The star_rating formula is defined as:

`stars = cleared ? 1 + [ final_score ≥ pts_eff(S2) ] + [ final_score ≥ pts_eff(S3) ] : 0`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cleared | bool | — | calculated (round-flow `outcome = CLEARED`) | 클리어 여부 |
| final_score | int | F6 | calculated | 최종 점수 |
| S2, S3 | int | 0 < S2 < S3 ≤ 20000 | data file (`StageDef.star_points`) | 별 2·3개 기준 (기준 스케일) |

**Output Range:** 0 ~ 3. `S2 < S3`(규칙 2)이므로 별 3이면 별 2 조건도 참 — 결과가 단조롭다. 클리어하면 최소 1개(목표 달성이 곧 별 1).
**Example:** 1-7, `star_points = [1700, 2400]`, `final_score = 1,740` → 1 + 1 + 0 = **★★**. 같은 판을 9개로 클리어(보너스 700)했다면 1,940 → 여전히 ★★;
연쇄 3을 한 번 더 넣어 `stage_score`를 1,900으로 올리고 10개로 끝냈다면 2,500 → **★★★** — 탐욕(T2)이 보상받은 경우.

**F8. 제한 조각 수 설계 안내 (설계 시점 — 런타임 아님)**

The piece_limit_guide formula is defined as:

`piece_limit ≈ ⌈ P_med × slack ⌉`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| P_med | int | 1 – 40 | calculated (T0 자동 플레이: 기본 보유 3인, 고정 시드, 클리어한 판의 사용 조각 수 중앙값) | 목표를 이루는 데 보통 드는 조각 수 |
| slack | float | 1.2 – 1.8 (시작 1.4) | data file (레벨 설계 노트 — 런타임 값 아님) | 여유 배율. 튜토리얼 1-1~1-4는 1.6~1.8, 1-5 이후 1.3~1.5 |

**Output Range:** `piece_limit_min`(3) ~ `piece_limit_max`(40)로 자른다. 밖이면 린트 경고(규칙 2). **Example:** 1-7 자동 플레이 `P_med` = 11 → ⌈11 × 1.4⌉ = **16**.
설계 시점 계산이라 부동소수를 써도 결정성 문제가 없다(결과는 정수로 데이터에 적힌다).

**F9. 별 기준 설계 안내 (설계 시점 — 런타임 아님)**

The star_threshold_guide formula is defined as:

`S2 ≈ Q50( final_score | cleared )`,  `S3 ≈ Q75( final_score | cleared )` — 100 단위로 반올림

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| Q50, Q75 | 분위수 | — | calculated (T0 자동 플레이 ≥ 200판: 추천 팀 3종(crew-definition 규칙 17) × 고정 시드, 클리어한 판의 `final_score` 분포) | 별 기준 후보 |

**Output Range:** 봇 기준 별 2 ≈ 클리어의 절반, 별 3 ≈ 상위 25%. 사람 첫 시도 별 3 목표 20~40%(규칙 G)를 플레이테스트로 보고 ±15% 조정한다.
**Example:** 1-5 봇 클리어 `final_score` 분포 Q50 = 1,960, Q75 = 2,580 → `star_points = [2000, 2600]` (규칙 G 표의 시작값과 같은 방식).

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E는 lean에서 생략) 및 Agent 도구 없음. Review manually before production.

**판정 경계**

- **If 마지막 조각으로 목표를 달성하고 동시에 놓을 곳도 없으면**: `CLEARED` (규칙 9 우선순위). `pieces_left = 0`이므로 보너스 0, 별은 `stage_score`만으로 계산.
- **If 마지막 조각을 놓고도 목표 미달이면**: `FAILED(OUT_OF_PIECES)` — 같은 순간 `no_moves`가 참이어도 실패 사유는 조각 소진으로 표시한다(플레이어가 이해하기 쉬운
  쪽; round-flow 규칙 9 순서와 같음).
- **If 조각이 남았는데 막혔으면**: `FAILED(NO_MOVES)`. 남은 조각 수는 결과 화면에 "조금만 더!" 문맥으로만 보이고 보너스는 없다.
- **If 목표 2개 중 하나만 달성한 채 끝나면**: 실패. 달성한 목표는 결과 화면에 ✓로 남는다(진행 스냅샷) — 별·기록에는 반영하지 않는다.
- **If 한 배치가 두 목표를 동시에 달성하면**: 그 배치에서 `CLEARED`. 어느 것이 먼저인지는 의미가 없다(배치 단위 판정).
- **If 목표가 연쇄 도중(예: 웨이브 1)에 달성되면**: 연쇄는 끝까지 풀리고 그 배치의 점수 전부가 `stage_score`에 들어간 뒤 클리어 판정 (round-flow 규칙 10).
  HUD의 ✓는 연출 박자상 그 웨이브에 띄워도 되지만 판정 시점은 커밋이다 (Game Feel).

**목표 세기**

- **If 목표 칸이 줄과 능력으로 같은 웨이브에 함께 지워지면**: 1번 센다 (`CELLS_CLEARED.by = BOTH`, 좌표 1개).
- **If 목표 칸이 지워진 뒤 알이나 새 조각으로 다시 채워지면**: 이미 `done`이다. 다시 세지 않고 표식도 돌아오지 않는다 (단조 증가).
- **If 목표 칸이 얼음 칸이면**: 얼음이 벗겨지는 타격(`CELL_MODIFIED`)은 목표 칸 진행이 아니다. 얼음이 다 벗겨진 뒤 그 칸이 **지워져야** 끝난다 — 한 칸에 두 목표
  (`CLEAR_OBSTACLES`·`CLEAR_CELLS`)를 겹치면 둘 다 진행한다(얼음 해제 +1, 이후 지움 +1). 레벨 설계 시 의도해서만 쓴다.
- **If 목표 칸이 빈칸으로 시작하면**: 정상 — 조각을 놓아 채운 뒤 지워야 한다. 놓는 것만으로는 진행이 없다.
- **If 목표 칸에 돌이 있으면**: 로드 오류 (돌은 지워지지 않는다, 규칙 2).
- **If 얼어붙은 얼굴이 첫 타격으로 녹은 같은 연쇄에서 다시 맞아 발동하면**: `P_obst` +1(녹을 때), 그 얼굴 발동은 `chain_depth`에도 기여한다(obstacles 규칙 3) —
  1-9가 노리는 "녹이고 터뜨리기"의 정상 경로다.
- **If `KEEP`된 칸이 `CELLS_CLEARED.kept[]`에만 나오면**: 목표 칸·방해물 어느 쪽도 세지 않는다 (obstacles Q4의 `kept` 이름 정리와 무관하게 이 규칙은 같다:
  목표 칸은 `cells[]`만, 방해물은 `CELL_MODIFIED`만 본다).
- **If 연쇄가 깊이 상한(6)에 닿으면**: `chain_depth = 6`(상한 웨이브는 세지 않음, chain-resolver F2) — `depth ≤ 6`인 연쇄 목표는 달성 가능하다. `depth`가 `depth_cap`보다
  크면 로드 오류다. `depth_cap`을 낮추는 데이터 변경은 모든 스테이지 재검증을 요구한다(규칙 2가 로드 시 잡는다).

**점수·별**

- **If `SCORE` 목표 판에서 한 배치가 목표를 크게 넘기면**: 넘친 점수도 `final_score`에 그대로 들어간다(자르지 않음) — 큰 마지막 한 방은 별로 보상된다.
- **If 클리어했는데 `final_score < pts_eff(S2)`이면**: 별 1. 별 1은 클리어 자체의 보상이다.
- **If `cell_points`가 바뀌면**: 목표·별·보너스가 F1로 같이 움직인다. 스테이지 데이터는 고치지 않는다. 단 `place_points_per_cell`·`activation_points_base`처럼
  `cell_points`와 따로 움직이는 노브를 바꾸면 별 기준을 F9로 다시 잰다.
- **If 재시도하면**: 진행·`stage_score`·`pieces_placed` 0. 이전 시도의 별은 스테이지 진행의 최고 기록에만 남는다(최고값 유지는 그쪽 소관).
- **If 판 도중 나가면(포기)**: 별 0, 기록 없음, 페널티 없음.

**데이터·팀**

- **If 고정 팀에 보유하지 않은 크루가 있으면**: 게스트로 쓴다 (team-composition 규칙 7). 보유 상태·가챠 천장에는 영향이 없다.
- **If 자유 편성 스테이지에서 플레이어가 기본 보유 3인을 다른 크루로 바꿨으면**: 정상. 별 1 보장은 "기본 보유 3인으로 *가능*"이지 "어떤 팀으로도 가능"이 아니다.
- **If 시작 보드가 이미 목표를 달성한 상태면**(예: `CLEAR_OBSTACLES`인데 얼음 칸 0): 로드 오류 — `required ≤` 시작 얼음 칸 수 검사가 막는다. `SCORE`는 시작 점수가
  언제나 0이라 해당 없음.
- **If 시작 보드에서 트레이 첫 조각이 하나도 안 들어가면**: 데이터 오류 — 로드 단계의 자동 재생 검증(AC-SG19)이 막고, 런타임에 일어나면 round-flow Edge Cases의
  `FAILED(NO_MOVES)` 경로로 앱은 멈추지 않는다.
- **If 스크립트 스테이지의 해법이 별 1도 못 만드는 데이터면**: 레벨 데이터 버그 — AC-SG19의 커밋된 해법 재생이 잡는다.

**퇴화 전략 (의도 / 비의도)**

- **"목표 하나만 남기고 점수 모으기" (의도)**: 남은 조각 보너스를 포기하고 연쇄로 점수를 모은 뒤 마지막에 목표를 끝내는 플레이. 조각 1개 = 보너스 100(F5)이므로
  한 수에 100점 넘게 못 버는 수는 손해이고, 남은 조각이 줄수록 막힘·소진 실패 위험이 커진다 — T2 "탐욕 vs 안전"의 정상 범위다. 봇 분포(F9)에서 이 전략이
  모든 판의 별 3을 독점하면 `leftover_piece_points`를 올린다.
- **"빨리 끝내기만" (의도, 단 지배하면 안 됨)**: 목표를 최소 조각으로 끝내 보너스만 받는 플레이. 별 3이 연쇄 없이 매번 나오면 별 기준(F9)이 너무 낮거나 보너스가
  너무 크다 — AC-SG21 플레이테스트 관찰 대상.
- **"점수 목표 판에서 아무 데나 놓기" (비의도)**: 배치 점수(칸당 1)만으로는 목표에 못 닿는다 — 1-5의 1500은 줄·연쇄 없이 18조각 × 최대 6 = 108점. 문제없음.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 종류 | 쓰는 것 | 상태 |
|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | Hard | `validate_board`(규칙 16), 칸 종류 플래그(`removable_by_clear`), `allow_faceless_pieces` 의미(규칙 5), "놓을 곳 없음" 판정은 그쪽 소유(D12) | Designed |
| 연쇄 해석기 (`chain-resolver.md`) | Hard | 이벤트 스키마(규칙 19: `CELLS_CLEARED`, `CELL_MODIFIED`, `CHAIN_END.chain_depth`), `depth_cap`, 로드 검증(규칙 18 — 얼굴 `crew_id`) | Designed |
| 점수 & 연쇄 배율 (`scoring.md`) | Hard | 커밋 후 `stage_score`(규칙 11), `cell_points`(F1 환산) | Designed |
| 트레이 공급 (`tray-supply.md`) | Hard | 트레이 필드의 의미·검증(규칙 18–22) — 이 문서는 값을 담는다; F7(크루별 조각 수)을 목표 설계 근거로 사용 | Designed |
| 칸 종류 & 방해물 (`obstacles.md`) | Hard (방해물 목표·보드) | `STONE`·`ice` 표기와 `validate_obstacles`, F3 `iced_cells` 정의, `CELL_MODIFIED` 의미 | Designed (동시 작성) |
| 크루 정의 & 능력 (`crew-definition.md`) | Soft | 레지스트리 id 유효성, `starter_ids()`, 기본 3인 별 1 보장(규칙 10)을 수용 기준으로 받음 | Designed |

**Downstream (이 시스템에 의존)**

| 시스템 | 종류 | 쓰는 것 | 이 문서에 기대하는 것 |
|---|---|---|---|
| 판 진행 흐름 (`round-flow.md`) | Hard | `StageDef`, `GoalTracker`(`start`·`apply`·`is_met`·`pieces_out`·`snapshot`), `stars`, `final_score` | 이름은 round-flow Q3 그대로 — 이 문서가 확정 (`pieces_out`은 round-flow가 말한 "제한 조각 소진 질의") |
| 팀 편성 (`team-composition.md`) | Soft | `team_rule`, `recommended_team`, 목표 요약 | 필드 이름·의미는 team-composition 규칙 5–8 그대로 채택 |
| 연쇄 미리보기 (`chain-preview.md`) | Soft | `preview_detail`, `show_predicted_score`, `goal_markers`, `GoalTracker.preview` | 표식은 사실만 — 비교·추천 없음 (chain-preview Q2 해소) |
| 스테이지 진행 & 해금 (`stage-progression.md`, 미작성) | Hard | `StageCatalog` 순서, 결과(별, `final_score`, 최장 연쇄) | 최고 기록·해금 규칙은 그쪽 |
| 재화 & 보상 (`currency-rewards.md`, 미작성) | Hard | 종료 결과(별 수, 첫 클리어 여부) | 보상량은 그쪽; 필요하면 `StageDef`에 보상 프로필 필드 추가 요청 |
| 플레이 HUD (`gameplay-hud.md`, 미작성) | Hard | 목표 정의·`snapshot()`, `pieces_left`, 별 기준 | 표시 형식 (UI Requirements) |
| 메타 화면 UI (`meta-screens-ui.md`, 미작성) | Soft | 결과 화면 값, 스테이지 선택 요약 | — |
| 튜토리얼 & 힌트 (VS) | Soft | 1-1~1-3의 스크립트·고정 팀 | — |

**양방향성**: board-rules·chain-resolver·scoring·tray-supply·obstacles·crew-definition의 Dependencies 표는 모두 스테이지 & 목표를 downstream으로 적어 일치한다.
round-flow·team-composition은 이 문서를 upstream(데이터)으로 적어 일치한다. **systems-index 불일치 1건 (이 실행에서 반영)**: #10 Depends On에 "연쇄 해석기"가
없다(chain-resolver Q6) — 이벤트를 직접 읽으므로 추가한다. 크루 정의는 Soft(레지스트리 검증)라 Depends On에는 넣지 않고 이 표에만 적는다. team-composition이
제안한 "#14 팀 편성 Depends On += 스테이지 & 목표 (soft)"는 그쪽 소관으로 남긴다.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Lean mode(이 시스템의 시각 피드백은 목표 표식·결과 별 정도로 연쇄 연출만큼 중심이 아님) 및 Agent 도구 없음.
> Review manually before production. 스티커북 톤·색약 규칙은 art-bible을 따른다.

| 이벤트 / 요소 | 시각 | 소리 | 기둥 |
|---|---|---|---|
| 목표 칸 표식 | 판 종이 위 점선 동그라미 스티커 자리(칸 내용과 독립된 겹 — 칸이 차도 테두리가 보임). 색이 아니라 **모양**(점선 원)으로 구분 — 색약 대응 | — | 3 |
| 목표 칸 완료 | 그 칸이 지워지는 웨이브 박자에 동그라미가 "콕" 도장으로 바뀌며 사라짐, HUD 카운터로 작은 별가루가 날아감 | 짧은 도장 "톡" (웨이브 SFX 위에 얹히는 고음, 볼륨 낮게) | 1 |
| 얼음 해제 (방해물 목표 +1) | obstacles 연출(얼음 깨짐) 뒤 HUD 얼음 아이콘으로 조각이 날아감 | obstacles·audio GDD 소관 | 1 |
| 연쇄 N 목표 달성 | 연쇄 배너(chain-presentation)에 ✓ 스티커가 붙음 | 배너 SFX에 작은 "딩" | 1·3 |
| 미리보기 목표 표식 | 지워질 목표 칸의 동그라미가 진하게 맥동, 풀려날 얼음에 "금 + 반짝" (obstacles 규칙 14의 금 표시와 겹치지 않게 반짝만 추가), `completes_stage`면 배너 끝에 "클리어!" 작은 스티커 | 없음 (드래그 중 소리 없음 — chain-preview) | 3 |
| 클리어 | 마지막 연출이 끝나면 판 위 남은 트레이 조각이 하나씩 "보너스 +100" 스티커로 접혀 점수로 날아감 (1개당 ≈ 0.15 s, 최대 1.2 s로 압축) → 별 1~3이 스티커처럼 찍힘 | 조각마다 오르는 음계, 별마다 "뽁" | 1·4 |
| 실패 (조각 소진 / 막힘) | 스티커북 페이지가 "꽉 찼다"/"조각이 다 떨어졌다"는 귀여운 크루 반응(크루가 머쓱해하는 표정) — 비난 문구 없음 | 부드러운 "뿌우" | 5 |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:stage-goals` to produce per-asset visual descriptions,
dimensions, and generation prompts from this section.

## Game Feel

이 시스템이 만드는 감정은 **"한 수 남았다"의 긴장과 "해냈다"의 도장**이다. 판정은 즉시, 보여 주기는 연출 박자에 맞춘다.

| 목표 | 기준 | 소유 |
|---|---|---|
| 판정 즉시 확정 | 목표 진행·클리어·실패는 배치 커밋 프레임에 확정 (연출 전). 건너뛰기·빨리 감기는 결과를 바꾸지 않는다 | 이 문서 · round-flow 규칙 7 |
| 진행 표시 박자 | HUD 목표 카운터는 그 칸이 지워지는(또는 얼음이 깨지는) **웨이브 재생 박자에 맞춰** 1씩 오른다 — 연출이 끝났을 때 정확히 `snapshot()` 값 | HUD · chain-presentation |
| 클리어 → 결과 | 마지막 연출 끝 → 보너스 접기(≤ 1.2 s) → 결과 패널. 클리어 후 결과까지 총 ≤ 2.5 s (round-flow `result_reveal_delay_s` 포함) — "한 판 더" 템포 | round-flow F4 · 메타 화면 UI |
| 남은 조각 경고 | `pieces_left ≤ 3`이면 HUD 숫자가 살짝 통통 튐(색 변화 없음, 시간 압박 연출 없음 — 안티 기둥 "시간 압박") | HUD |
| 실패의 결 | 실패 화면의 첫 요소는 "한 판 더" 큰 버튼, 다음이 진행 스냅샷("목표 칸 5/6 — 하나 남았어요!"). 아까운 실패가 재도전 동기가 되게 (기둥 4) | 메타 화면 UI |
| 탐욕의 손맛 | 목표를 일부러 미룬 끝에 큰 연쇄로 클리어하면 별 3이 찍히는 순간이 연쇄 연출과 이어져 하나의 보상으로 읽혀야 함 (T2) | 연출 · 이 문서 |

## UI Requirements

| 화면 / 요소 | 요구 | 정보 출처 |
|---|---|---|
| 플레이 HUD — 목표 패널 | 목표 1~2개를 아이콘 + 진행으로 한 줄에: 점수 `현재 / 목표`, 목표 칸 `◌ 남은 수`, 얼음 `❄ 남은 수`(obstacles UI Requirements의 택일 → **`iced_cells` 기준 남은 칸 수**), 연쇄 `연쇄 N ✓/✗ (k/required)`. 달성한 목표는 ✓ 스티커 | `snapshot()`, `StageDef.goals` |
| 플레이 HUD — 남은 조각 | `남은 조각 n` (F2). 무제한(자유 플레이)이면 숨김 (round-flow UI) | F2 |
| 플레이 HUD — 별 기준 | 점수 바 위에 별 2·3 눈금 (`final_score`가 아니라 `stage_score` 기준임을 혼동하지 않도록, 눈금 옆에 "+ 남은 조각 보너스" 작은 표기) | `star_points`, F1 |
| 결과 화면 (클리어) | `stage_score`, 남은 조각 보너스(n × 100), `final_score`, 별 1~3, 최장 연쇄, 버튼: "한 판 더"(가장 큼) / "다음" / "팀 바꾸기" | F5–F7, round-flow `RoundResult` |
| 결과 화면 (실패) | 사유(조각 소진 / 놓을 곳 없음), 목표별 진행 스냅샷, "한 판 더"(가장 큼) / "팀 바꾸기" / 나가기 | `snapshot()` |
| 스테이지 선택 / 팀 편성 요약 | 스테이지 이름, 목표 요약(아이콘), 제한 조각 수, 별 기준, 내 최고 별 | `StageDef`, 스테이지 진행 |
| 스테이지 시작 카드 | 판 시작 시 0.8 s 목표 카드("목표 칸 6개를 지워요 · 조각 12개") — 탭으로 즉시 닫힘. 튜토리얼 문구는 VS(튜토리얼 GDD) | `StageDef` |

텍스트는 모두 로컬라이즈 키. 목표 아이콘은 색만으로 구분하지 않는다(모양 + 숫자).

> **📌 UX Flag — 스테이지 & 목표**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD
> element this system contributes to **before** writing epics — 플레이 HUD 목표 패널·남은 조각(`design/ux/hud.md`), 결과 화면·스테이지 시작 카드
> (`design/ux/result-screen.md`). Stories that reference UI should cite `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 참조하는 내용 | 원천 문서 | 관계 | 상태 |
|---|---|---|---|
| 스테이지 = 제한 조각 수 + 목표(점수/특정 칸/방해물/연쇄 N), 별 1~3, MVP 10스테이지, 학습 곡선, "최고 숫자 찾기" 위험, 안티 기둥 시간 압박 없음 | `design/gdd/game-concept.md` § Core Mechanics 5, Flow State Design, Design Risks, Anti-Pillars | 규칙 출처 | 일치 — 컨셉 Open Question "목표 기본형"은 4형 모두 MVP, 플레이테스트로 선호 측정(Q4) |
| 제한 조각 소진 실패 소유, `validate_board`, `allow_faceless_pieces`, 클리어 우선(AC-17) | `design/gdd/board-rules.md` 규칙 5·15·16, D12, AC-17 | 상위 계약 | 일치 |
| 이벤트 스키마, `chain_depth`, `depth_cap` 6, 스테이지 → 해석기 의존 추가(Q6) | `design/gdd/chain-resolver.md` 규칙 7·19, F2, Q6 | 상위 계약 | 일치 — Q6은 이 실행에서 index에 반영 |
| `stage_score`, `cell_points` 스케일, 남은 조각 보너스(Q7) | `design/gdd/scoring.md` 규칙 11·13, Tuning Knobs, Q7 | 상위 계약 | Q7 해소: 보너스는 별도 항, 누계 불변 |
| 트레이 필드, `FIXED` 시드, `tray_script`, 팀 고정 질문(Q7) | `design/gdd/tray-supply.md` 규칙 18–22, Q7 | 상위 계약 | Q7 해소: 팀 고정 = `team_rule.locked` |
| 돌·얼음 표기, `iced_cells`/`ice_remaining` 택일 | `design/gdd/obstacles.md` 규칙 1–3·6·16, F3, UI Requirements | 상위 계약 | `iced_cells` 택함 (D5) |
| 기본 보유 3인 별 1 보장, 추천 팀, 연쇄 N ≥ 3 권장 | `design/gdd/crew-definition.md` 규칙 10·17, F4a | 수용 기준 | 일치 (AC-SG20) |
| `goal_markers` 훅, `preview_detail`·`show_predicted_score` | `design/gdd/chain-preview.md` 규칙 13·16·17, Q2 | 하위 계약 | Q2 해소: 표식 채택(사실만) |
| `GoalTracker`·`stars`·제한 조각 질의 이름, 남은 조각 처리(Q1) | `design/gdd/round-flow.md` 규칙 4–12, Q1·Q3 | 하위 계약 | Q1·Q3 해소 |
| `team_rule` {team_size, locked, banned}, 게스트 | `design/gdd/team-composition.md` 규칙 5–8, Q5 | 하위 계약 | 그대로 채택, Q5 해소 |
| `StageDef` = 데이터 전용 Custom Resource, `stage_seed` 범위 | `docs/architecture/adr-0001-pure-deterministic-rules-core.md` 결정 8, Ordering Note | 구현 방침 | 일치 |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 Agent 도구가 없어 생략. Review manually before production.
> 태그 = 스토리 유형 → 증거·게이트 (tray-supply AC 머리말과 같은 규약): `[Logic]` `tests/unit/stage_goals/` (BLOCKING) · `[Integration]` `tests/integration/stage_goals/`
> (BLOCKING) · `[UI]` 보존 스크린샷 `production/qa/evidence/` (BLOCKING) · `[Config]` 데이터 로드·스모크 (ADVISORY) · `[Playtest]` `/playtest-report` (ADVISORY — 스토리 완료 조건 아님).
> **결정성**: 이벤트 목록은 커밋된 픽스처(`tests/fixtures/stage_goals/*.events.json`, 손으로 쓴 것은 "산술 전용"이라 명시) 또는 커밋된 보드 문자열에서 실제 `resolve`로 만든다.
> 모든 `stage_seed`는 픽스처에 적는다. 테스트 파일: `tests/unit/stage_goals/stage_goals_{load,goals,outcome,stars,preview}_test.gd`,
> `tests/integration/stage_goals/stage_goals_{round,catalog}_test.gd`.

**데이터·로드 (규칙 1–2)**

- **AC-SG01 [Logic] (규칙 1)** — **GIVEN** 1-3 예시 `board_rows`·`cell_legend`, **WHEN** 로드, **THEN** (2, 5)는 `TILE(gomgom, is_face)`, (6, 5)는 `EMPTY`, `placement_id` 모두 0, 완성 줄 0개.
- **AC-SG02 [Logic] (규칙 2)** — **GIVEN** 각각 하나씩 규칙을 어긴 `StageDef` 12종(레전드에 없는 글자 · 8줄이 아닌 보드 · 목표 0개 · 목표 3개 · `CHAIN depth = 7` · `CLEAR_CELLS`인데
  `target_cells` 비어 있음 · 목표 칸이 보드 밖 · 목표 칸이 `STONE` · `CLEAR_OBSTACLES [ice] 5`인데 시작 얼음 칸 4 · `star_points = [700, 600]` · `FIXED` 시드인데 `stage_seed` 없음 ·
  `team_size = 2`인데 `locked` 1칸), **WHEN** 로드, **THEN** 12종 모두 로드 오류이고 오류 메시지에 위반 필드 이름이 들어 있다.
- **AC-SG03 [Logic] (규칙 2 린트)** — **GIVEN** `SCORE 1500`·`star_points = [1400, 2000]`인 스테이지, **WHEN** 로드, **THEN** 로드는 성공하고 린트 경고 1건("S2 ≤ required").
- **AC-SG04 [Config] (규칙 G)** — **GIVEN** MVP `StageCatalog`(10개), **WHEN** 로드, **THEN** 오류 0·린트 경고 0, id `1-1`~`1-10` 순서, 모든 스테이지 `preview_detail = FULL`.

**목표 세기 (규칙 3–8, F3·F4)**

- **AC-SG05 [Logic] (규칙 4, F1)** — **GIVEN** `SCORE 160`, `cell_points = 10`, **WHEN** 커밋 후 `stage_score`가 159 → 165, **THEN** `is_met()`는 거짓 → 참. **AND** `cell_points = 20`이면
  기준은 320이다.
- **AC-SG06 [Logic] (규칙 5)** — **GIVEN** `target_cells = {(0,7), (7,0)}`와 `CELLS_CLEARED` 픽스처: (0,7)이 `by = BOTH`로 1회, 웨이브 2에서 (0,7)이 알로 다시 지워짐, (7,0)은 `kept[]`에만,
  **WHEN** `apply`, **THEN** `P_cells = 1`이고 `done = {(0,7)}`.
- **AC-SG07 [Logic] (규칙 6, F3c)** — **GIVEN** 시작 보드에 1겹 얼음 칸 A, 2겹 얼음 칸 B, 얼어붙은 얼굴 C와 `CLEAR_OBSTACLES [ice] 3`, **WHEN** 배치 1(A `ice:1→없음`, B `ice:2→1`),
  배치 2(B `ice:1→없음`, C `ice:1→없음`, 같은 연쇄에서 C가 지워져 발동), **THEN** `P_obst`는 1 → 3, 배치 2 뒤 `is_met()` 참, A가 이후 `CELLS_CLEARED`로 지워져도 3 그대로.
- **AC-SG08 [Logic] (규칙 7)** — **GIVEN** `CHAIN depth 3 × 2`, **WHEN** `chain_depth` 2·3·6·0인 배치 4개, **THEN** `P_chain` = 0·1·2·2, 세 번째 배치 뒤 `is_met()` 참.
- **AC-SG09 [Logic] (규칙 8)** — **GIVEN** 1-10 목표(`CLEAR_CELLS 6` + `CLEAR_OBSTACLES 4`), **WHEN** 목표 칸 6을 먼저 끝내고 얼음 3 → 4, **THEN** 얼음 4가 되는 배치에서만 `is_met()` 참,
  그 전 `snapshot()`은 목표 칸 ✓ + 얼음 3/4.
- **AC-SG10 [Logic] (규칙 3 결정성·단조)** — **GIVEN** 같은 시작 보드와 같은 이벤트 열, **WHEN** `GoalTracker`를 두 번 돌림, **THEN** 모든 배치 뒤 `snapshot()`이 같고, 어떤 배치 뒤에도 진행 값이 줄지 않는다.

**판 결과 (규칙 9–12, F2·F5–F7)**

- **AC-SG11 [Integration] (규칙 9)** — **GIVEN** `piece_limit = 4`, 4번째 배치가 목표를 달성하고 그 뒤 `no_moves`도 참인 픽스처 판, **WHEN** 4번째 커밋, **THEN** outcome `CLEARED`, `pieces_left = 0`, 보너스 0 (board-rules AC-17과 같은 단언).
- **AC-SG12 [Integration] (규칙 9)** — **GIVEN** `piece_limit = 4`, 목표 미달, **WHEN** 4번째 커밋, **THEN** `pieces_out(0)` 참 → `FAILED(OUT_OF_PIECES)`; **AND** 같은 순간 `no_moves`가 참인 변형에서도 사유는 `OUT_OF_PIECES`.
- **AC-SG13 [Logic] (F5–F7)** — **GIVEN** `star_points = [1700, 2400]`, `leftover_piece_points = 100`, `cell_points = 10`, **WHEN** (`stage_score`, `pieces_left`, cleared) = (1240, 5, 참) / (1900, 6, 참) /
  (1500, 1, 참) / (3000, 0, 거짓), **THEN** `final_score` = 1740 / 2500 / 1600 / 3000이고 별 = 2 / 3 / 1 / 0.
- **AC-SG14 [Integration] (규칙 10)** — **GIVEN** 목표를 7번째 배치에 달성하는 판(`piece_limit` 12), **WHEN** 커밋, **THEN** 판이 즉시 끝나 8번째 배치를 받을 수 없고 `RoundResult.pieces_left = 5`,
  `stage_score`에는 보너스가 들어 있지 않으며 `final_score = stage_score + 500`.
- **AC-SG15 [Integration] (규칙 12)** — **GIVEN** `FIXED` 시드 스테이지에서 3배치 후 재시도, **WHEN** 재시작, **THEN** 진행·`stage_score`·`pieces_placed` 0이고 첫 트레이가 첫 시도와 같다(tray-supply AC-18 연계).

**팀·미리보기 (규칙 13–14)**

- **AC-SG16 [Integration] (규칙 13)** — **GIVEN** 1-3(`team_size 2`, `locked` [냥이, 곰곰])과 곰곰을 보유하지 않은 세이브, **WHEN** 스테이지 시작, **THEN** 팀 = [냥이, 곰곰](곰곰은 게스트),
  편성 화면에서 바꿀 수 없고, 판이 끝난 뒤 보유 크루 목록은 그대로다.
- **AC-SG17 [Logic] (규칙 14)** — **GIVEN** 목표 칸 (3,3) 미완료와 (3,3)을 지우는 가상 `ChainResult`, **WHEN** `preview(result)`, **THEN** `target_cells_hit = {(3,3)}`이고, 그 뒤 `snapshot()`은
  호출 전과 같다(추적기 상태 불변). **AND** 같은 결과를 `apply`하면 `P_cells`가 정확히 `target_cells_hit` 크기만큼 오른다 (미리보기 = 실제).
- **AC-SG18 [Logic] (규칙 14)** — **GIVEN** 마지막 남은 목표를 달성하는 가상 결과, **WHEN** `preview`, **THEN** `completes_stage = true`; `SCORE` 목표만 남은 판에서는 `show_predicted_score = false`이면
  표식이 비어 있다(점수 표식 없음).

**콘텐츠 검증 (규칙 G, F8·F9)**

- **AC-SG19 [Integration] (규칙 G)** — **GIVEN** 스크립트 스테이지 1-1·1-2·1-3과 커밋된 해법 배치 목록, **WHEN** 자동 재생, **THEN** 모든 배치가 `can_place = true`이고 `CLEARED`, 별 ≥ 1 (tray-supply AC-15b와 같은 하네스).
- **AC-SG20 [Integration] (규칙 13 — 기본 보유 보장)** — **GIVEN** MVP 10스테이지 × 기본 보유 3인(고정 팀은 그 팀) × 고정 봇 시드 50개, **WHEN** T0 자동 플레이 봇으로 플레이,
  **THEN** 모든 스테이지에서 별 1 클리어가 1회 이상 나오고, 클리어율이 1-1~1-4 ≥ 95%, 1-5~1-10 ≥ 70%. 미달 스테이지는 `piece_limit`·목표를 F8로 조정하기 전까지 이 AC가 실패한다.
- **AC-SG21 [Playtest] (규칙 F·G — 퇴화 위험)** — **GIVEN** 외부 테스터 ≥ 5명이 1-1~1-10을 처음 플레이, **WHEN** 관찰·로그 집계, **THEN** (a) 1-4·1-7에서 미리보기상 가장 큰 연쇄가 아닌 자리를
  목표 때문에 고른 배치가 테스터당 1회 이상(chain-preview AC-P21과 공유), (b) 별 3 비율이 클리어의 20~40%, (c) 1-1~1-4 첫 시도 클리어율 ≥ 90%. 벗어나면 별 기준·보너스를
  F9로 재조정하고 결과를 `/playtest-report`에 기록한다.

**UI**

- **AC-SG22 [UI] (UI Requirements)** — **GIVEN** 1-10 진행 중(목표 칸 4/6, 얼음 3/4, 남은 조각 7), **WHEN** HUD 캡처, **THEN** 두 목표가 아이콘(모양)+숫자로 한 줄에, 남은 조각 7, 별 눈금 2개가 보이는
  스크린샷이 `production/qa/evidence/`에 보존된다. 클리어·실패 결과 화면도 각각 1장.

*Section D 공식별 커버리지*: F1 → AC-SG05 · F2 → AC-SG11/14 · F3 → AC-SG05–08 · F4 → AC-SG09 · F5–F7 → AC-SG13 · F8·F9(설계 시점) → AC-SG20/21.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 10스테이지 표(규칙 G)의 목표 수치·조각 수·별 기준은 근사로 잡은 시작값이다 — T0 자동 플레이(AC-SG20)와 F8·F9로 확정. 특히 1-9(얼음 6 + 연쇄 3, 18조각)가 9번째로 적절한 난이도인가 | level-designer · systems-designer | T0 자동 플레이 → `/balance-check` |
| Q2 | 얼음 2겹 칸을 "벗길 때마다 진행"(`ice_remaining`)으로 바꿀 필요가 있는가 — 현재는 완전 해제만 셈(D5). 2겹 칸의 첫 타격이 "헛손질"로 느껴지면 재검토 | game-designer | T0 플레이테스트 |
| Q3 | `leftover_piece_points` 100이 "탐욕 vs 안전"(T2)의 균형점인가 — 봇·사람 데이터에서 한쪽 전략이 별 3을 독점하면 조정 | systems-designer | AC-SG21 이후 |
| Q4 | 컨셉 Open Question "어떤 목표형이 가장 재밌나" — 4형 모두 MVP에 넣고 외부 테스트에서 스테이지별 재시도율·선호를 기록해 T2 스테이지 배분에 반영 | game-designer · producer | T1 외부 플레이테스트 |
| Q5 | `FIXED` 시드 해법 외우기 (tray-supply Q4) — 별 3 획득 후 `PER_ATTEMPT` "연습 모드"를 열지 | game-designer | 메타 화면 UI 설계 시 |
| Q6 | 재화 & 보상이 스테이지별 보상 차등을 원하면 `StageDef`에 `reward_profile` 필드를 추가할지(현재 없음) | economy-designer · 재화 & 보상 GDD | `/design-system currency-rewards` |
| Q7 | 1-1의 `show_predicted_score = true`가 이후 스테이지(기본 false)와 기대 불일치를 만드는가 — 숨기는 시점에 안내가 필요한지 | game-designer · 튜토리얼 GDD | VS |
| Q8 | `CellSpec.modifiers`가 obstacles 규칙 6의 `{kind, layers}` 객체 배열인데 board-rules 규칙 2는 `modifiers[]`를 보존만 한다 — `.tres` 표현(하위 Resource vs Dictionary)과 ADR-0001의 int 강제 검증 범위 | lead-programmer | `/architecture-decision` (StageDef 로드) |

### Decision Log (사용자 위임 — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 | standard 필수 5 + Formulas(별·보너스·목표 수치 정의) + Visual/Audio·Game Feel(Gameplay 필수)·UI·Cross-References·Open Questions. Player Fantasy·Tuning Knobs는 tier 생략(값은 규칙 H 표) | Tuning Knobs 별도 섹션 — 다른 standard GDD와 형식 불일치 |
| D2 | 스테이지 데이터 형식 | `StageDef` Custom Resource + 보드는 글자 격자 텍스트 + `cell_legend` | 칸마다 하위 Resource 64개 — 에디터·diff에서 읽을 수 없음; JSON 파일 — 프로젝트 데이터 방침(ADR-0001 결정 8)과 불일치 |
| D3 | 목표 유형 | 컨셉의 4형 그대로(`SCORE`·`CLEAR_CELLS`·`CLEAR_OBSTACLES`·`CHAIN`), 모두 이벤트로만 셈 | 5번째 "줄 N개 지우기" — 1-1 학습엔 편하지만 `SCORE`로 대체 가능, 컨셉 범위 밖; 크루별 발동 횟수 목표 — 팀 강제가 되어 기둥 2 자유 약화 |
| D4 | 목표 묶음 | 1~2개, 모두 달성(AND) | OR 목표 — HUD·판정 문구 복잡; 3개 이상 — 세로 HUD 한 줄 초과 |
| D5 | 방해물 목표 단위 | 얼음에서 풀려난 칸(`iced_cells` 감소, `CELL_MODIFIED`의 `ice` 해제) — obstacles UI의 택일 요청에 답 | `ice_remaining`(겹 수) — 2겹 칸이 2로 세져 "얼음 6개" 문구와 실제 칸 수가 어긋남(Q2로 재검토 여지); `CELLS_CLEARED` 기준 — 얼음 칸은 지워지지 않고 KEEP되므로 셀 수 없음 |
| D6 | 목표 칸 표현 | 좌표 겹 표시(칸 종류 아님), 지워진 적이 있으면 완료 | 목표 칸을 칸 종류로 — 조각을 놓으면 칸 종류가 `TILE`로 바뀌어 사라짐(board-rules 규칙 2 "칸은 종류 하나"); "그 칸에 놓기" 목표 — 지우기 퍼즐과 무관 |
| D7 | 팀 규칙 필드 | team-composition 규칙 5의 `team_rule` {team_size, locked, banned} 그대로 채택 | 이 문서 초안의 `team_mode`/`fixed_team`/`allowed_crew` — 동시 작성된 팀 편성 제안과 이름이 갈라져 consistency 충돌 |
| D8 | 클리어 시점 | 목표 달성 즉시 종료 (round-flow 현행) | 남은 조각을 계속 놓는 "보너스 놓기" — 판이 길어지고(기둥 4) 클리어 후 실패 가능성 같은 이상한 상태 |
| D9 | 남은 조각 처리 | 조각당 보너스 100(기준 스케일), `stage_score`와 별도 항 (scoring Q7·round-flow Q1 해소) | 보너스 없음 — 빨리 끝내는 동기 없음, 별이 점수 경쟁만 → "최고 숫자 찾기"; `stage_score`에 합산 — scoring 누계 정의와 점수 목표 판정이 섞임 |
| D10 | 별 기준 | 별 1 = 클리어, 별 2·3 = `final_score` 임계값 2개(스테이지 데이터), `cell_points` 기준 스케일 환산 | 별 = 남은 조각 수만 — 연쇄(기둥 1)가 별에 보상되지 않음; 별마다 다른 조건(예: 별 3 = 연쇄 5) — 표현력은 높지만 HUD·결과 설명 부담, MVP 이후 후보; 점수만(남은 조각 무시) — T2 트레이드오프 소실 |
| D11 | 미리보기 목표 표식 (chain-preview Q2) | 채택 — 목표 칸·풀려날 얼음·연쇄 목표 ✓·`completes_stage`, 같은 세기 코드, 점수 표식 없음 | 표식 없음 — 트레이드오프가 보이지 않아 "목표 vs 연쇄" 선택이 기억 싸움이 됨(기둥 3); 예상 진행 숫자까지 — 비교 도구화 |
| D12 | 10스테이지 학습 곡선 | 1-1 얼굴 없음 → 1-2 얼굴 → 1-3 2단 연쇄 → 1-4 목표 칸 → 1-5 3인 팀 → 1-6 알 → 1-7 목표 vs 연쇄 → 1-8 얼음 → 1-9 얼어붙은 얼굴 → 1-10 종합(돌) | 1-4 전에 3인 팀 — 삐약 알은 읽기 어려워 2인으로 목표 개념부터; 방해물 1-6 이전 — 컨셉 곡선 순서(목표 → 조각 제한 → 방해물)와 어긋남 |
| D13 | 시드 정책 | MVP 10스테이지 모두 `FIXED` (tray-supply D6) | `PER_ATTEMPT` — 재도전이 운 시험 |
| D14 | 1~2인 고정 팀 | 1-1~1-4만, `team_size < 3`이면 `locked` 필수 | 자유 편성 1~2인 — 팀 편성 화면 규칙 복잡, MVP 필요 없음 |
