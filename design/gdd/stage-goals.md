# 스테이지 & 목표 (Stage & Goals)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 4 한 판 더

## Summary

[To be designed]

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `[To be designed]`

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
   | `piece_limit` | int | — | 이 판에 공급되는 조각 총수, `piece_limit_min`(3) ~ `piece_limit_max`(40) | 이 문서 |
   | `star_points` | PackedInt32Array | — | `[S2, S3]` — 별 2·3개 기준 `final_score` (기준 `cell_points_ref` = 10에서 적은 값, F1) | 이 문서 |
   | `team_mode` | enum | `FREE` | `FREE`(팀 편성에서 고름) \| `FIXED`(`fixed_team` 그대로, 편성 화면 잠금) (규칙 13) | 이 문서 |
   | `fixed_team` | Array[StringName] | `[]` | `FIXED`일 때 1~3명 crew id, 팀 슬롯 순서 | 이 문서 · crew-definition (id 유효성) |
   | `allowed_crew` | Array[StringName] | `[]` | `FREE`일 때 고를 수 있는 크루 (빈 배열 = 보유 크루 전부). MVP 출시 스테이지는 모두 빈 배열 | 이 문서 |
   | `recommended_team` | Array[StringName] | `[]` | 표시용 추천 (규칙 없음) | 메타 화면 UI |
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
     (`CLEAR_OBSTACLES`만), `depth`: int (`CHAIN`만) }. 의미와 세는 법은 규칙 B.
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
     `removable_by_clear = true`이거나 `EMPTY`; `CLEAR_OBSTACLES` → `keys` 비지 않음, `required ≤` 시작 보드에서 키에 맞는 칸 수(F3c — MVP는
     방해물이 판 도중 생기지 않으므로), 키에 맞는 칸은 `removable_by_clear = true`; `CHAIN` → `1 ≤ depth ≤ depth_cap`(chain-resolver, 6).
     `target_cells`가 있는데 `CLEAR_CELLS` 목표가 없으면 오류(쓸모없는 표식).
   - 조각·별: `piece_limit` 범위 안; `star_points`는 정확히 2개이고 `0 < S2 < S3`.
   - 팀: `FIXED` → `fixed_team` 1~3명, 중복 없음, 모두 레지스트리에 있음; `FREE` → `fixed_team` 비어 있음, `allowed_crew`의 id가 모두 레지스트리에 있고
     비어 있지 않다면 기본 보유 3인(`starter_ids()`) 중 1명 이상 포함.
   - 트레이 필드: tray-supply 규칙 22 (스크립트 검증), `FIXED` 시드 모드에서 `stage_seed` 필수(tray-supply Edge Cases).
   - **린트 경고 (로드는 됨)**: `SCORE` 목표에서 `S2 ≤ required` (클리어하면 별 2가 거의 자동), `goals`가 2개인데 둘 다 `SCORE`·`CHAIN`처럼
     연쇄 하나로 동시에 끝나기 쉬운 조합, `piece_limit`이 F8 안내 범위 밖.

**B. 목표 유형과 세는 법 — 이벤트만 읽는다**

3. **목표 추적기 계약** — `apply_placement(progress, stage, board_before, events, stage_score) → progress'`. 순수 함수다: 입력을 바꾸지 않고,
   `board_before`(이번 배치의 `resolve` 입력 = 안정 보드), 연쇄 해석기 `events`(한 배치분), 커밋 후 `stage_score`(scoring 규칙 11)만 읽는다.
   보드를 다시 판정하지 않고 해석기를 다시 부르지 않는다. **진행도는 단조 증가**한다 — 한 번 센 것은 줄지 않는다. 판 진행 흐름이 배치 커밋 직후
   (점수 확정과 같은 순간, 연출 재생 전) 한 번 부른다. 연쇄 미리보기는 같은 함수를 가상 결과에 적용해 목표 표식을 만든다 (규칙 14).
4. **`SCORE`** — 진행도 = `stage_score` (F3a). `stage_score ≥ required_eff`(F1로 환산)이면 달성. 남은 조각 보너스(F5)는 **포함하지 않는다** —
   보너스는 클리어 *뒤에* 붙는다.
5. **`CLEAR_CELLS` (목표 칸)** — `target_cells` T는 보드 좌표 위의 겹 표시다(칸 종류가 아님 — 칸 내용이 바뀌어도 표시는 그 좌표에 남는다).
   이번 배치의 모든 `CELLS_CLEARED` 이벤트의 `cells[]` 좌표 중 T에 속하는 것을 `done` 집합에 더한다 (F3b). `kept[]`(훅 `pre_clear`가 `KEEP`한 칸)와
   `CELL_MODIFIED`는 세지 않는다 — "지워졌다"만 센다. 지운 이유(`by` = `LINE`·`ABILITY`·`BOTH`)와 칸 출처(`origin` = `PIECE`·`EGG`)는 따지지 않는다:
   알이 채운 칸이 지워져도 그 좌표는 끝난다. 한 좌표는 한 번만 센다. 목표 칸이 빈칸으로 시작하면 플레이어가 그 칸을 채워 지워야 한다.
   진행도 = `|done|`, `|done| ≥ required`이면 달성.
6. **`CLEAR_OBSTACLES` (방해물)** — `keys`는 방해물 GDD가 등록한 **칸 종류 id** 또는 **modifier id** 목록이다. 이번 배치의 `CELLS_CLEARED`
   `cells[]`를 이벤트 순서대로 훑으며, 이 배치에서 **처음** 지워지는 좌표 (r, c)마다: `board_before[r][c]`의 칸 종류가 `keys`에 있거나 그 칸의
   `modifiers`에 `keys`의 항목이 있으면 +1 (F3c). 같은 배치에서 같은 좌표가 다시 지워지면(알이 채운 뒤 다시 지워짐) 세지 않는다 — 그 칸은 이미
   방해물이 아니다. 근거: MVP에서 방해물은 판 도중 생기지 않는다(프리미티브는 알만 만든다, chain-resolver 규칙 17). 겹 벗기기(`CELL_MODIFIED`)는
   세지 않는다 — **완전히 치워야** 1개 (Open Question Q2).
7. **`CHAIN` (연쇄 N)** — `CHAIN_END.chain_depth ≥ depth`인 배치마다 +1 (F3d). `required`번이면 달성 (기본 1 = "연쇄 N을 한 번"). `chain_depth`는
   chain-resolver F2 정의 그대로다: 얼굴이 하나 이상 *발동*한 웨이브 수이고, 상한 도달 웨이브와 `SUPPRESSED`만 있는 웨이브는 세지 않는다.
   crew-definition F4a 근사에 따르면 기본 팀은 줄을 지운 배치의 ≈ 90%에서 연쇄 1이 나므로, **일반 스테이지의 `depth`는 3 이상**을 쓴다.
   `depth` 1~2는 연쇄를 처음 가르치는 튜토리얼 스테이지(1-2·1-3)용이다.
8. **목표 묶음** — 스테이지의 목표는 1~2개이며 **모두** 달성해야 클리어다(AND). 달성 순서는 상관없고, 먼저 달성한 목표는 달성 상태로 남는다.
   "둘 중 하나"(OR)는 두지 않는다 (Decision Log D4).

**C. 판 결과 판정**

9. **판정 시점과 순서** — 판 진행 흐름은 배치를 커밋할 때마다 (1) `stage_score` 갱신(scoring), (2) `apply_placement`, (3) `evaluate`를 이 순서로
   부른다. `evaluate(progress, stage, pieces_placed) → ONGOING | CLEARED | FAILED_OUT_OF_PIECES`:
   1. 모든 목표가 달성(F4)이면 **`CLEARED`**.
   2. 아니고 `pieces_left = 0`(F2)이면 **`FAILED_OUT_OF_PIECES`** — 제한 조각 소진 실패는 이 시스템이 판정한다 (board-rules D12).
   3. 아니면 `ONGOING`. 그 뒤 판 진행 흐름이 (필요하면 재충전 후) `no_moves`를 평가해 참이면 **`FAILED_BLOCKED`**로 끝낸다 (board-rules 규칙 15).
   따라서 같은 배치에서 목표 달성과 막힘(또는 조각 소진)이 함께 성립하면 **클리어**다 (board-rules AC-17). 결과 우선순위: `CLEARED` > `FAILED_OUT_OF_PIECES`
   > `FAILED_BLOCKED`. 연쇄 해석은 동기적으로 한 번에 끝나므로(chain-resolver 규칙 6) "연쇄 도중 달성"은 따로 없다 — 그 배치의 연쇄 전체가 점수와
   진행도에 들어간 뒤 판정한다.
10. **클리어는 즉시** — `CLEARED`가 되면 남은 조각은 쓰지 않고 판이 끝난다(연출 재생 후 결과 화면). 쓰지 않은 조각은 **남은 조각 보너스**(F5)가 된다:
    `final_score = stage_score + leftover_bonus` (F6), 별은 F7. 보너스는 `stage_score`에 더하지 않고 별도 값으로 둔다 — scoring의 누계 정의를 바꾸지
    않는다 (scoring Q7 해소). 결과 화면은 `stage_score`, 보너스, `final_score`, 별을 함께 보여 준다.
11. **실패** — `FAILED_OUT_OF_PIECES`·`FAILED_BLOCKED`는 별 0, 보너스 0. 페널티·재화 차감 없음(컨셉 Recovery from failure). 실패 연출은 귀엽게(기둥 5)
    하며, 원탭 재시작은 직전 팀을 유지한다(기둥 4 — 판 진행 흐름 소관).
12. **재시도** — 진행도·`pieces_placed`·`stage_score`를 0으로 되돌리고 같은 `StageDef`를 다시 로드한다. `tray_seed_mode = FIXED`면 같은 팀일 때 첫 트레이와
    순서가 같다(tray-supply AC-18) — "아까 그 수를 다르게"가 바로 가능하다.

**D. 팀 규칙**

13. **`FREE`** — 플레이어가 팀 편성에서 보유 크루 중 3명을 고른다(`allowed_crew`가 있으면 그 안에서). **`FIXED`** — `fixed_team`이 그대로 팀이 되고 편성 화면은
    잠긴다(튜토리얼). `FIXED` 팀의 크루는 **보유하지 않아도 된다** — 스테이지가 그 판에만 빌려준다(보유 상태는 바뀌지 않음; 보유 크루 GDD는 이를 보유로 세지
    않는다). 팀 크기 1~2명은 `FIXED`에서만 가능하다. **기본 보유 보장** (crew-definition 규칙 10): `FREE` MVP 스테이지는 모두 기본 보유 3인(냥이·곰곰·삐약)만으로
    별 1개 클리어가 가능해야 하며, 이는 자동 플레이 수용 기준(AC-SG20)으로 확인한다. 별 3개는 다른 팀이 더 쉬워도 된다(기둥 2 "팀이 경로를 바꾼다").

**E. 미리보기와 목표 표식 (chain-preview Q2 해소)**

14. **`goal_preview(stage, progress, board_before, preview_events) → GoalPreview`** — 연쇄 미리보기가 가상 결과에 부르는 표식 훅. 순수 함수이며 규칙 B와
    **같은 세기 코드**를 쓴다(미리보기용 근사 금지 — chain-resolver 규칙 3과 같은 방침). 반환: `target_cells_hit`(아직 안 끝난 목표 칸 중 이 배치로 지워질 좌표),
    `obstacles_hit`(이 배치로 치워질 방해물 좌표), `chain_goal_hit`(이 배치의 `chain_depth ≥ depth`인 `CHAIN` 목표 id), `completes_stage`(이 배치로 모든 목표가
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
    - **T4 순서** — 방해물이 줄 완성을 막아(지워야 줄이 열림) 연쇄 경로보다 치우는 순서가 먼저인 판.

**G. MVP 10스테이지 (제안 — 모든 수치는 플레이테스트 튜닝 목표 ‡)**

16. 학습 곡선은 컨셉 Flow State Design을 따른다: 1-1 얼굴 없는 줄 지우기 → 1-2 얼굴 = 스위치 → 1-3 첫 2단 연쇄 → 1-5 3인 팀 → 1-8 방해물. 한 스테이지에 새
    개념은 하나만 넣는다. 별 기준은 `cell_points_ref` = 10 기준 `final_score`이며 F9 절차(자동 플레이 분포)로 확정한다. 방해물 id `crate`·`frozen`은 **가칭**이다 —
    칸 종류 & 방해물 GDD(미작성)가 MVP 방해물을 확정하면 바꾼다 (Q1).

    | id | 가르치는 것 | 팀 (`team_mode`) | 트레이 | 시작 보드 요지 | 목표 ‡ | 조각 ‡ | ★2 / ★3 ‡ | 트레이드오프 |
    |---|---|---|---|---|---|---|---|---|
    | 1-1 | 줄이 차면 지워진다 | `FIXED` [냥이] | `tray_script` 얼굴 없는 I3_H·D2_H·D1 (`LOOP`), `allow_faceless_pieces` | 6·7행에 6칸씩, 빈칸 위치가 서로 다름 | `SCORE` 160 (줄 2개) | 8 | 600 / 750 | T2 (적게 써서 끝내기) |
    | 1-2 | 얼굴이 지워지면 능력! (미리보기 첫 등장) | `FIXED` [냥이] | `tray_script` 첫 트레이 얼굴 위치 고정, 이후 `GENERATE` | 7행 5칸 + 3열에 흩어진 칸 (십자가 지울 거리) | `CHAIN` depth 1 × 2 | 8 | 700 / 1000 | — (학습) |
    | 1-3 | 첫 2단 연쇄 (냥이 → 곰곰) | `FIXED` [냥이, 곰곰] | `tray_script` 1트레이 + `GENERATE` | 위 예시: 곰곰 얼굴이 냥이 십자 열 위에 미리 깔림 | `CHAIN` depth 2 × 1 | 10 | 900 / 1300 | — (학습) |
    | 1-4 | 목표 칸 | `FIXED` [냥이, 곰곰] | 생성, `FIXED` 시드 | 목표 칸 6개를 모서리 쪽 두 줄에 | `CLEAR_CELLS` 6/6 | 12 | 1200 / 1700 | T1 |
    | 1-5 | 3인 팀 · 삐약 알 (첫 팀 편성) | `FREE` (추천 냥이·곰곰·삐약) | 생성, `FIXED` 시드 | 거의 빈 판, 7칸 찬 줄 2개 | `SCORE` 1500 | 18 | 2000 / 2600 | T2 |
    | 1-6 | 알이 줄을 채워 다시 불붙인다 | `FREE` | 생성, `FIXED` 시드 | 7칸 찬 줄 여러 개 (알 재점화 자리) | `CHAIN` depth 3 × 1 | 15 | 1500 / 2100 | T3 |
    | 1-7 | 목표 칸 vs 큰 연쇄 | `FREE` | 생성, `FIXED` 시드 | 목표 칸 8개를 네 모서리 주변에 | `CLEAR_CELLS` 8/8 | 16 | 1700 / 2400 | T1 · T2 |
    | 1-8 | 첫 방해물 (`crate` 가칭: 칸을 막고 지우면 사라짐) | `FREE` | 생성, `FIXED` 시드 | 상자 6개가 줄 3개에 섞임 | `CLEAR_OBSTACLES` [`crate`] 6 | 16 | 1800 / 2500 | T4 |
    | 1-9 | 얼어붙은 얼굴 (`frozen` 가칭 modifier) | `FREE` | 생성, `FIXED` 시드 | 얼어붙은 얼굴 4개(팀 밖 크루 포함 가능) | `CLEAR_OBSTACLES` [`frozen`] 4 + `CHAIN` depth 3 × 1 | 18 | 2000 / 2800 | T3 · T4 |
    | 1-10 | 졸업 — 종합 | `FREE` | 생성, `FIXED` 시드 | 목표 칸 6 + 상자 4, 서로 다른 구역 | `CLEAR_CELLS` 6/6 + `CLEAR_OBSTACLES` [`crate`] 4 | 20 | 2400 / 3300 | T1 · T2 · T4 |

    - **공통 값**: `stage_seed` = 스테이지별 고유값(자동 플레이로 고른 뒤 고정 — 제안 시작값 `1100 + 번호`), `rescue_enabled = true`, `preview_detail = FULL`,
      `show_predicted_score = false`(1-1만 `true` — 점수 목표를 처음 볼 때 "+N 예상" 한 줄로 단위를 익힘), `goal_markers = true`, `allowed_crew = []`.
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

목표 추적기의 상태는 **한 번의 스테이지 시도** 동안만 존재한다. 전이를 일으키는 쪽은 판 진행 흐름이며, 이 시스템은 `evaluate` 결과를 돌려줄 뿐이다.

| 상태 | 진입 | 들고 있는 것 | 다음 |
|---|---|---|---|
| `LOADED` | `StageDef` 로드·검증 통과 | 시작 보드, 목표 정의 | 팀 확정(`FREE`면 편성, `FIXED`면 즉시) → `IN_PROGRESS` |
| `IN_PROGRESS` | 시도 시작 / 재시도 | `progress` (목표별 값, `done` 집합), `pieces_placed = 0` | 배치 커밋 → `apply_placement` + `evaluate` → `IN_PROGRESS` / `CLEARED` / `FAILED_OUT_OF_PIECES`; 판 흐름의 `no_moves` → `FAILED_BLOCKED`; 나가기 → `ABANDONED` |
| `CLEARED` | 모든 목표 달성 | `final_score`, 별 1~3, 남은 조각 수 | 결과 화면 → 재시도(`IN_PROGRESS`) / 다음 스테이지 / 나가기 |
| `FAILED_OUT_OF_PIECES` | 조각 소진 + 목표 미달 | 진행도 (결과 화면 "조금만 더!" 표시용) | 재시도 / 나가기 |
| `FAILED_BLOCKED` | 놓을 곳 없음 (board-rules) | 같음 | 재시도 / 나가기 |
| `ABANDONED` | 판 도중 나가기 | — (기록 없음) | — |

`CLEARED`·`FAILED_*`·`ABANDONED`는 종료 상태다. 종료 뒤에는 `apply_placement`를 부르지 않는다 (호출은 assert). 별·`final_score`의 최고 기록 저장은
스테이지 진행 & 해금 GDD 소관이며, 재화 보상은 재화 & 보상 GDD가 결과(별 수, 첫 클리어 여부)를 읽어 정한다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 스테이지 → 보드 규칙 | 시작 보드(`validate_board`), `allow_faceless_pieces`; 칸 종류 플래그(`removable_by_clear`) 조회 | 보드 규칙 (함수) / 스테이지 (데이터) |
| 연쇄 해석기 | 해석기 → 스테이지 | `CELLS_CLEARED.cells`(목표 칸·방해물), `CHAIN_END.chain_depth`(연쇄 N); 스테이지 → 해석기: 없음 (스테이지 상태는 해석기 입력이 아니다, chain-resolver 규칙 17) | 해석기 (이벤트 스키마) / 스테이지 (세는 법) |
| 점수 & 연쇄 배율 | 점수 → 스테이지 | 커밋 후 `stage_score` (점수 목표, `final_score`) | 점수 (누계) / 스테이지 (목표·별·보너스) |
| 트레이 공급 | 스테이지 → 트레이 | `stage_seed`, `tray_seed_mode`, `stage_base_seed`, `tray_script`, `after_script`, `rescue_enabled`, `allow_faceless_pieces`, `faceless_share`, 고정 팀 여부; budget = `pieces_left`(판 흐름 경유) | 트레이 (필드 의미·검증) / 스테이지 (값) |
| 칸 종류 & 방해물 (미작성) | 방해물 → 스테이지 | 등록된 칸 종류 id·modifier id (`CellSpec.type`, `keys`), 각 종류의 규칙 플래그 | 방해물 (종류) / 스테이지 (배치·목표 키) |
| 크루 정의 & 능력 | 크루 → 스테이지 | 레지스트리 id 유효성, `starter_ids()` | 크루 정의 |
| 판 진행 흐름 (미작성) | 판 흐름 → 스테이지 | 시도 시작·재시도, 배치 커밋마다 `apply_placement`·`evaluate` 호출, `no_moves` 실패 통지, budget 계산 | 판 진행 흐름 (타이밍) / 스테이지 (판정) |
| 팀 편성 (미작성) | 스테이지 → 팀 편성 | `team_mode`, `fixed_team`, `allowed_crew`, `recommended_team` | 스테이지 (규칙) / 팀 편성 (화면·선택) |
| 연쇄 미리보기 | 스테이지 → 미리보기 | `preview_detail`, `show_predicted_score`, `goal_markers`, `goal_preview` 훅 | 스테이지 (세는 법) / 미리보기 (표시) |
| 플레이 HUD · 메타 화면 UI | 스테이지 → UI | 목표 정의·진행도, `pieces_left`, 별 기준, 결과(`final_score`, 별, 보너스) | 각 UI GDD (표시) |
| 스테이지 진행 & 해금 · 재화 & 보상 | 스테이지 → 진행·보상 | 종료 상태, 별, `final_score`, 시도 중 최장 `chain_depth` | 각 GDD |

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
