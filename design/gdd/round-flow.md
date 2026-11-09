# 판 진행 흐름 (Round Flow)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-09 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 4 한 판 더 · 기둥 3 보이는 연쇄 · 기둥 5 다정한 세계

## Summary

판 진행 흐름은 스테이지 한 판을 세우고(`StageDef` + 팀 → 보드·트레이·점수·목표), 배치마다 재확인 → 해석 → 적용 → 채점 → 목표 → 트레이 소비·재충전 → 종료 판정을
**커밋 프레임에 한 번에 확정**한 뒤 연출에 넘기고, 클리어 우선(클리어 > 조각 소진 > 막힘)으로 판을 끝낸다. 결과 화면의 **원탭 "한 판 더"**는 같은 팀·같은 스테이지 시드로
0.5 s 안에 다시 시작하고(기둥 4), 타이머가 없으므로 일시정지·백그라운드는 연출만 멈추거나 플러시하며, MVP에 되돌리기는 없다. T0 `RoundFlow` 코드를 확장하는 형태다 (ADR-0001).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `보드 & 조각 규칙`, `연쇄 해석기`, `점수 & 연쇄 배율`, `트레이 공급`, `스테이지 & 목표`, `팀 편성`, `드래그 & 배치 입력`, `연쇄 미리보기`, `연쇄 연출 재생기` (upstream) — downstream: 화면 흐름, 플레이 HUD, 메타 화면 UI, 오디오, 스테이지 진행·재화·세이브(신호)

## Overview

판 진행 흐름은 스테이지 한 판(attempt)의 **진행자**다. 데이터 층에서는 `StageDef`(스테이지 & 목표)와 팀(팀 편성)을 받아 판을 세우고,
보드·트레이·점수 누계·목표 진행·배치 카운터를 보관하며, 배치 1회마다 정해진 순서(권위 재확인 → 해석 → 적용 → 채점 → 목표 →
트레이 소비·재충전 → 종료 판정)를 **같은 프레임 안에 동기로** 실행한 뒤, 연출 재생기에 결과를 넘기고 재생이 끝나면 입력을 다시 연다.
`ResolveContext`를 만드는 유일한 곳(ADR-0001 결정 9)이라 미리보기와 실제 배치가 같은 시드를 쓰도록 보장한다. 플레이어 쪽에서는
거의 보이지 않는다 — 플레이어가 느끼는 것은 "놓으면 터지고, 끝나면 결과가 뜨고, 한 번 누르면 바로 같은 판이 다시 시작된다"는 템포다.
이 시스템이 없으면 규칙 코어는 있어도 *게임*이 없다: 언제 판이 끝나는지, 실패와 클리어가 겹치면 무엇이 이기는지, 재시작이 무엇을
유지하는지가 정해지지 않는다. 기둥 4 "한 판 더"의 원탭 재시작(가설 기준 3의 직접 측정 대상)과, 타이머 없는(안티 기둥 "시간 압박")
일시정지·백그라운드 처리가 이 문서의 몫이다. 구현 형태는 ADR-0001이 정한다 — 순수 `RoundCore`(규칙 코어)를 감싼 `RoundFlow`.
T0 그레이박스에 이미 구현된 부분(`src/gameplay/round/round_flow.gd`, `src/game/game_screen.gd`)은 규칙 J에서 이 설계와 대조한다.

## Detailed Design

### Core Rules

**A. 소유와 경계**

1. **판 진행 흐름이 소유하는 상태** (판 1회 = attempt 1회): `stage_def`(읽기 전용), `team`(크루 id 1–3, 읽기 전용), `attempt_index`,
   `stage_seed`, `RoundCore`(안정 보드·`placement_index`·`board_version`·`StageScoreTally`), `TrayState`, 목표 진행(`GoalTracker`, 스테이지 & 목표 소유
   형식), `pieces_dealt`, `placements_used`, 라운드 상태(아래 States), `RoundResult`(종료 시).
2. **판정하지 않는다** — 배치 가능·줄·연쇄·점수·트레이 내용·목표 달성·별은 각 소유 시스템의 순수 함수를 부를 뿐이다(ADR-0001).
   판 진행 흐름이 정하는 것은 **호출 순서·시점·우선순위**와 **판의 시작·끝**이다.
3. **`ResolveContext`의 유일한 출처** — `context_for_next_placement()`는
   `ResolveContext{abilities, rules, rng_seed = hash32(stage_seed, STREAM_RESOLVER, placement_index), hooks}`(chain-resolver F7)를 돌려준다.
   미리보기와 커밋은 반드시 이 메서드로 받은 값을 쓴다 (ADR-0001 결정 9, chain-preview 규칙 1·9).

**B. 판 세우기 (SETUP)**

4. **입력** — `start(stage_def, team)`. `stage_def`는 스테이지 & 목표가 정의하는 데이터(`StageDef`: 시작 보드, `piece_limit`(없으면 ∞),
   목표 목록, 별 기준, 트레이 필드 `tray_seed_mode`·`stage_seed`/`stage_base_seed`·`tray_script`·`after_script`·`rescue_enabled`·
   `allow_faceless_pieces`·`faceless_share`, 팀 고정 여부). `team`은 팀 편성이 검증해 넘긴 크루 id 목록(팀 슬롯 순서).
5. **세우는 순서** (한 프레임, 동기):
   1) `stage_seed` 결정 — tray-supply 규칙 18·F3: `FIXED`면 `stage_def.stage_seed`, `PER_ATTEMPT`면 `hash32(stage_base_seed, STREAM_ATTEMPT, attempt_index)`.
   2) 시작 보드 = `stage_def`의 보드를 `BoardRules.validate_board`로 검증한 사본. 실패 → 로드 오류(아래 Edge Cases), 판을 시작하지 않는다.
   3) `RoundCore.start(board, abilities, chain_rules, scoring_rules, stage_seed, 0, hooks)` — `stage_score = 0`, `best_placement = 0`(scoring `ACTIVE`).
   4) `GoalTracker` 시작(스테이지 & 목표 계약: 시작 보드·목표 목록을 받아 진행 0).
   5) `TraySupplyRules.init_state(team, stage_tray_config, stage_seed)` → 첫 `refill(board, budget = piece_limit)`; `pieces_dealt += m`.
   6) 시작 보드에서 `no_moves` 평가(드묾 — 스테이지 데이터 오류 신호). 참이면 디버그 assert + 그대로 `FAILED(NO_MOVES)`로 보낸다.
   7) `attempt_started(stage_id, team, attempt_index, stage_seed)` 신호 → `READY`, 입력 켬.
6. **시도 번호** — 같은 스테이지·같은 팀으로 이어지는 재시작마다 `attempt_index += 1`. 스테이지나 팀이 바뀌면 0부터. `FIXED`에서는 시드에 영향이 없고
   기록(가설 지표 F5)에만 쓴다.

**C. 배치 1회의 순서 (커밋 파이프라인)** — `placement_requested(slot, anchor)`를 받으면 **같은 프레임 안에서** 아래를 순서대로 실행한다.
게임 상태는 7단계가 끝나는 순간 전부 확정되며, 이후의 연출·빨리 감기·건너뛰기·백그라운드는 결과를 바꾸지 못한다 (scoring 규칙 12, chain-resolver
States 절과 같은 원칙).

7. **커밋 순서**:
   1) **잠금** — 입력은 이미 `COMMITTING → LOCKED`(placement-input 규칙 15). 판 상태 `DRAGGING → RESOLVING`.
   2) **권위 재확인** — `can_place(board, piece, anchor)`. 거짓이면 프로그래밍 오류(드래그 중 보드 불변 위반): 디버그 assert, 출시 빌드는 요청 거절 →
      입력 `RETURNING`, 판 상태 `READY`. 상태 변화 없음.
   3) **해석** — `pre_board = board.copy()`; `ctx = context_for_next_placement()`; `result = ChainResolver.resolve(board, piece, anchor, ctx)`.
      미리보기 결과를 재사용하지 않는다(chain-preview 규칙 9) — 디버그 빌드는 마지막으로 표시된 미리보기의 `board_hash`와 비교해 `PREVIEW_MISMATCH`.
   4) **적용** — `board ← result.final_board`, `placement_index += 1`, `board_version += 1`, `placements_used += 1`.
   5) **채점** — `breakdown = ScoreCalculator.score_placement(result.events, scoring_rules)`; `stage_score += breakdown.total`; `best_placement` 갱신.
   6) **목표** — `GoalTracker`에 이번 배치의 `ChainResult`(이벤트·`final_board`·`summary`)와 `ScoreBreakdown`, 갱신된 누계를 넘겨 목표 진행을 갱신한다
      (스테이지 & 목표 소유 — 목표 진행은 **이벤트에서만** 계산, ADR-0001 결정 3).
   7) **트레이** — `consume(slot)`. 트레이가 비었으면 즉시 `refill(board, refill_budget)`(F2) — 구제(tray-supply 규칙 13)는 **해석 후 보드**로 판단한다.
      `pieces_dealt += m`. 새 조각은 **논리적으로 지금 확정**되지만 화면에는 재생 뒤에 나타난다(규칙 11).
   8) **종료 판정** — 규칙 9의 우선순위로 `outcome ∈ {CONTINUE, CLEARED, FAILED(NO_MOVES), FAILED(OUT_OF_PIECES)}`를 정한다.
      종료면 `RoundResult`를 만들고 `attempt_ended(result)`를 **지금** 낸다(세이브·진행이 즉시 기록 — 재생 중 앱이 죽어도 클리어를 잃지 않음).
   9) **연출 요청** — `ChainPlayer.play({pre_board, result, score: breakdown, crew_visuals, settings})` → 판 상태 `PRESENTING`.
8. **한 번에 한 배치** — `PRESENTING`과 `SETTLING` 동안 새 `placement_requested`는 받지 않는다(입력이 `LOCKED`라 오지 않아야 하며, 오면 디버그 assert 후 무시 —
   chain-presentation 규칙 21). 재생 중 다음 조각을 집는 "입력 관통"은 MVP에 없다 (chain-presentation D5·Q3, 이 문서 D7).

**D. 종료 판정 우선순위**

9. 커밋 7-8)단계에서 위에서부터 첫 번째로 성립하는 것:
   1) **`CLEARED`** — 목표가 모두 달성됐다 (`GoalTracker.is_met()`). 같은 배치에서 막힘·조각 소진이 함께 성립해도 클리어가 이긴다
      (board-rules D9 "플레이어가 이룬 것을 실패로 덮지 않는다", 기둥 5). 남은 조각이 있어도 판은 여기서 끝난다 — 남은 조각 수는
      `RoundResult.pieces_left`로 스테이지 & 목표에 넘기며, 이를 별·보너스에 쓸지는 그쪽 소관 (Q1).
   2) **`FAILED(OUT_OF_PIECES)`** — 트레이가 비었고 `refill_budget = 0`(트레이 `EXHAUSTED`)이며 목표 미달성. 제한 조각 소진의 *판정 기준*은
      스테이지 & 목표가 소유하고(board-rules 규칙 15), 판 진행 흐름은 그 질의를 이 시점에 부른다.
   3) **`FAILED(NO_MOVES)`** — `BoardRules.no_moves(board, tray.pieces())`가 참 (재충전 **뒤** 트레이, 빈 목록 = 거짓 — board-rules 규칙 15).
      `PARTIAL` 트레이(제한 조각 끝자락)도 남은 조각으로 평가한다.
   4) **`CONTINUE`** — 위 어느 것도 아니다.
10. **목표 판정 시점은 배치 단위** — 목표는 배치 커밋 사이에서만 평가한다. 연쇄 *도중* 목표가 달성돼도 해석은 끝까지 진행하고(해석기는 목표를 모름),
    그 배치의 점수 전부가 결과에 들어간다.

**E. 재생 뒤 (SETTLING)**

11. `playback_finished(was_skipped)`를 받으면 같은 프레임에: 트레이 표시를 논리 트레이(재충전 포함)로 갱신 → HUD 숫자를 확정값으로 맞춤 →
    `outcome = CONTINUE`면 `READY` + `set_input_enabled(true)`; 종료면 `RESULT_PENDING`으로 가서 `result_reveal_delay_s`(F4) 뒤 결과 화면을 연다.
    `was_skipped`는 결과·타이밍 판정에 영향이 없다.

**F. 결과와 원탭 재시작 (기둥 4)**

12. **`RoundResult`** = {`stage_id`, `team`, `attempt_index`, `outcome`, `fail_reason`(`NO_MOVES` | `OUT_OF_PIECES` | `ABANDONED` | null),
    `stage_score`, `best_placement`, `placements_used`, `pieces_left`(F1), `max_chain_depth`(배치들의 `CHAIN_END.chain_depth` 최댓값), 목표 진행 스냅샷,
    `stars`}. `stars`는 `CLEARED`일 때 스테이지 & 목표의 별 계산(`stars(stage_def, result)` → 1–3)이 채우고, 실패·포기는 0.
13. **"한 판 더" = 원탭** — 결과 화면의 기본 버튼 한 번으로 `retry()`: 같은 `stage_def`, **같은 팀**, `attempt_index + 1`로 규칙 5를 다시 실행한다.
    씬을 다시 불러오지 않고 제자리에서 초기화한다(보드·트레이·누계·목표·연출·미리보기 캐시·HUD 숫자 모두 0으로). `FIXED`면 첫 트레이가 직전 판과 같다
    (tray-supply AC-18) — "아까 그 첫 수를 다르게"가 바로 가능하다. 확인 대화상자 없음.
14. **팀 바꿔 재도전** — 결과 화면의 보조 버튼은 팀 편성 화면으로 간다(화면 흐름 소관). 팀이 바뀐 시작은 `attempt_index = 0`의 새 시작이다.
15. **실패 결과는 다정하게** (기둥 5) — 실패는 비난 문구·감점·재화 손실이 없다. 결과 화면의 "한 판 더"가 실패·클리어 모두에서 가장 큰 버튼이다.
    스태미나·대기 없음(안티 기둥).

**G. 일시정지 · 백그라운드 (타이머 없음)**

16. **게임 시간은 없다** — 판의 어떤 판정도 시간에 의존하지 않는다(안티 기둥 "시간 압박"). 시간이 흐르는 것은 연출·입력 애니메이션뿐이다.
    따라서 일시정지는 **연출을 멈추고 입력을 막는 것**이지 게임 규칙의 상태가 아니다.
17. **일시정지 열기** — 일시정지 버튼(HUD) 또는 Android 뒤로 가기(드래그 중이 아닐 때 — 드래그 중이면 placement-input 규칙 19c대로 드래그 취소에만 쓰임).
    `READY`·`DRAGGING`·`PRESENTING`·`SETTLING`에서 가능, `SETUP`·`RESULT_PENDING`·`RESULT`에서는 불가(결과 화면은 자기 버튼을 가짐).
    열면: 드래그 강제 취소(placement-input 규칙 19d) → `set_input_enabled(false)` → 재생 중이면 연출 타임라인 시각 정지(chain-presentation Edge Cases).
18. **일시정지 메뉴** — `계속`(이전 상태로 복귀, 재생 이어서), `다시 하기`(= 규칙 13 `retry()`; 진행 중 판은 `ABANDONED`로 `attempt_ended`),
    `나가기`(`ABANDONED`로 끝내고 화면 흐름에 스테이지 선택 복귀 요청), 그리고 연출 토글 3종(재생 속도·움직임 줄이기·번쩍임 끄기 — chain-presentation
    규칙 23–26, MVP 임시 위치). `다시 하기`·`나가기`에 확인 대화상자는 없다 — 이미 일시정지 메뉴라는 한 단계를 거쳤다.
19. **백그라운드** (`NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT`) — 상태는 이미 확정돼 있으므로 판 진행 흐름이 하는 일은 셋뿐:
    드래그 강제 취소(placement-input 규칙 19a), 재생 중이면 즉시 플러시(chain-presentation 규칙 24 → `playback_finished(true)` → 규칙 11로 `SETTLING` 처리),
    결과 화면 대기 중이면 지연을 끝내고 결과를 바로 연다. **복귀 시 자동 일시정지 오버레이는 띄우지 않는다** — 잃을 시간이 없으니 막을 이유도 없다 (D9).
20. **앱 종료·강제 종료** — MVP는 진행 중인 판을 저장하지 않는다. 재실행하면 판은 사라지고(보상 없음, `ABANDONED`도 기록되지 않음) 스테이지 선택에서 시작한다.
    종료 판정된 판은 규칙 7-8)에서 이미 `attempt_ended`를 냈으므로 클리어·별은 연출 중 종료돼도 보존된다. 판 중간 이어 하기는 Q2.

**H. 되돌리기 (undo)**

21. **MVP에 되돌리기는 없다** — 미리보기가 놓기 전에 결과를 정확히 보여 주고(기둥 3), 제한 조각 수가 판의 긴장 축이며, 원탭 재시작이 "실수 복구" 역할을 한다(기둥 4).
    되돌리기를 넣으면 제한 조각의 의미가 사라지고 `FIXED` 시드와 결합해 "놓아 보고 무르기"로 미리보기를 대체하는 탐색이 된다 (D6). 튜토리얼 실수 복구가
    필요하면 튜토리얼 GDD가 스크립트 단계 재시작으로 해결한다.

**I. 관찰·기록**

22. 신호(구독자: HUD, 오디오, 화면 흐름, 스테이지 진행, 로컬 분석 로그): `attempt_started(stage_id, team, attempt_index, stage_seed)`,
    `placement_committed(placement_index, result, breakdown, goal_progress)`(7-5·6 뒤, 연출 전), `round_state_changed(from, to)`,
    `attempt_ended(result: RoundResult)`, `retry_requested(from_outcome)`. 로그는 로컬 전용(온라인 없음 — project.yaml) — 가설 지표 F5와 tray-supply
    `TRAY_RESCUED`(F6)를 여기서 모은다.

**J. T0 구현과의 대조 (현재 코드 → 이 설계)**

23. **이미 맞는 것** — `RoundFlow`(RefCounted, Node 없음)가 `RoundCore`·`TrayState`를 보유하고 `context_for_next_placement()`의 유일한 출처다. `commit()`이
    `can_place` 재확인 → `RoundCore.commit`(독립 `resolve` → `final_board` 적용 → `score_placement` → 누계) → `consume` 순으로 실행한다. `GameScreen`은 디버그
    `PREVIEW_MISMATCH` 비교, `playback_finished` 뒤 입력 재개, 결과 패널의 `RetryButton` 원탭 `retry()`(씬 재로드 없음), 백그라운드·뒤로 가기 시 드래그 취소를 한다.
    결정성 통합 테스트가 있다(`tests/integration/round_flow/round_flow_test.gd`).
24. **확장할 것** (스토리 대상 — 순서대로):
    - (a) `StageDef` 입력: T0의 고정 팀·빈 보드·무제한 조각을 `start(stage_def, team)`로 대체. T0 동작은 "자유 플레이 `StageDef`"(목표 없음, `piece_limit = ∞`,
      `PER_ATTEMPT`)로 보존 — 디버그·자동 플레이용.
    - (b) 시드 모드: T0는 `PER_ATTEMPT` 하드코딩 → `stage_def.tray_seed_mode`를 따른다(MVP 스테이지 기본 `FIXED`).
    - (c) 재충전·종료 판정 시점: T0는 `finish_placement()`(재생 뒤)에서 재충전·`no_moves`를 한다 → 커밋 7단계로 앞당기고, 재생 뒤에는 표시 갱신만(규칙 11).
      판정 결과는 같다(같은 보드·같은 시드) — 바뀌는 것은 확정 시점뿐.
    - (d) `Phase {PLAYING, NO_MOVES}` → 아래 States 표의 상태 전체 + `RoundResult`.
    - (e) `GoalTracker` 연동, `refill_budget`(F2), `OUT_OF_PIECES`, `CLEARED` 우선.
    - (f) 일시정지(규칙 17–18) — `ChainPlayer`에 타임라인 정지/재개, 백그라운드 플러시 공개 API가 필요(현재 `_flush`는 비공개이고 `GameScreen._notification`은 드래그
      취소만 함 → chain-presentation 규칙 24 미충족).
    - (g) 신호(규칙 22)와 `attempt_index` 의미(규칙 6: 팀·스테이지가 바뀌면 0).

### States and Transitions

| 상태 | 하는 일 | 들어오는 조건 | 나가는 조건 → 다음 |
|---|---|---|---|
| `IDLE` | 판 없음 | 앱 시작, 나가기 | `start(stage_def, team)` → `SETUP` |
| `SETUP` | 규칙 5 (동기, 한 프레임) | `start` / `retry` | 성공 → `READY`; 로드 오류 → `IDLE` + 오류 보고; 시작 보드 막힘 → `RESULT_PENDING`(`NO_MOVES`) |
| `READY` | 안정 보드, 입력 켬, 미리보기 가능 | `SETUP`; `SETTLING`(`CONTINUE`); 일시정지 해제 | 트레이 조각 집음 → `DRAGGING`; 일시정지 → `PAUSED` |
| `DRAGGING` | 입력·미리보기가 진행, 판 상태는 불변 (placement-input 규칙 20) | 집음 | 유효 놓기(`placement_requested`) → `RESOLVING`; 취소·무효 놓기 → `READY`; 일시정지·백그라운드 → 드래그 취소 후 `PAUSED` / `READY` |
| `RESOLVING` | 커밋 파이프라인 규칙 7 (동기, 같은 프레임) | `placement_requested` | 재확인 실패 → `READY`; 완료 → `PRESENTING` |
| `PRESENTING` | 연출 재생 대기, 입력 `LOCKED`. 게임 상태는 이미 확정 | `RESOLVING` | `playback_finished` → `SETTLING`; 일시정지 → `PAUSED`(재생 정지); 백그라운드 → 플러시 → `playback_finished(true)` |
| `SETTLING` | 규칙 11 (같은 프레임) | `playback_finished` | `CONTINUE` → `READY`; 종료 → `RESULT_PENDING` |
| `RESULT_PENDING` | 마지막 보드를 보여 주며 `result_reveal_delay_s` 대기, 입력 끔 | `SETTLING`(종료) | 지연 끝 / 백그라운드 / 화면 탭 → `RESULT` |
| `RESULT` | 결과 화면 (별·점수·"한 판 더") | `RESULT_PENDING` | "한 판 더" → `SETUP`(`attempt_index + 1`); 팀 바꾸기·나가기 → `IDLE`(화면 흐름) |
| `PAUSED` | 오버레이, 입력 끔, 재생 정지. 직전 상태(`resume_to`)를 기억 | `READY`·`DRAGGING`·`PRESENTING`·`SETTLING`에서 일시정지 | `계속` → `resume_to`(`DRAGGING`이었으면 `READY` — 드래그는 이미 취소됨); `다시 하기` → `SETUP`(`ABANDONED` 기록); `나가기` → `IDLE`(`ABANDONED`) |

- `attempt_ended`는 종료 판정 순간(규칙 7-8, 상태 `RESOLVING` 안) 또는 `ABANDONED`(일시정지 메뉴) 때 **정확히 한 번** 난다.
- `PAUSED`는 규칙 상태가 아니다 — 들어가고 나와도 보드·트레이·점수·`placement_index`·`board_version`은 바뀌지 않는다.
- 결과 화면이 떠 있는 동안 판 상태는 동결된다 (scoring `FINAL`).

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 판 흐름 → 보드 규칙 | `validate_board`(시작 보드), `can_place`(권위 재확인), `no_moves`(재충전 뒤 트레이) | 보드 규칙 (함수) / 판 흐름 (호출 시점, 목표 우선) |
| 연쇄 해석기 | 판 흐름 → 해석기 | `resolve(board, piece, anchor, ctx)` → `ChainResult`; `ctx` 파생(F7) | 해석기 (함수·이벤트) / 판 흐름 (`ctx`·커밋) |
| 점수 & 연쇄 배율 | 판 흐름 → 점수 | `score_placement(events)`, 누계 `ACTIVE`/`FINAL` 전이 (시도 시작·종료) | 점수 (계산·누계 규칙) / 판 흐름 (시점) |
| 트레이 공급 | 판 흐름 → 트레이 | `init_state(team, cfg, stage_seed)`, `refill(board, budget)`, `consume(slot)`, 스냅샷; ← `TRAY_RESCUED` | 트레이 (내용) / 판 흐름 (시점, `budget`, `no_moves`) |
| 스테이지 & 목표 (`stage-goals.md`, 동시 작성 중) | 스테이지 → 판 흐름 (데이터), 판 흐름 → 스테이지 (질의) | `StageDef` 필드(규칙 4); `GoalTracker` 시작·배치별 갱신(`ChainResult` 이벤트 + `ScoreBreakdown` + 누계)·`is_met()`; 제한 조각 소진 판정; `stars(stage_def, RoundResult)` | 스테이지 & 목표 (데이터·목표·별) / 판 흐름 (평가 시점·우선순위) |
| 팀 편성 | 팀 편성 → 판 흐름 | 검증된 `team`(크루 id 1–3, 슬롯 순서) | 팀 편성 (검증) / 판 흐름 (보관·재사용) |
| 드래그 & 배치 입력 | 양방향 신호 (의존: 판 흐름 → 입력) | → `set_input_enabled(bool)`, 보드·트레이 스냅샷; ← `placement_requested(slot, anchor)`, `drag_ended` | 입력 (API) / 판 흐름 (켜고 끄는 시점) |
| 연쇄 미리보기 | 판 흐름 → 미리보기 | 안정 보드·`board_version`·`ctx`; 커밋 후 디버그 비교 | 미리보기 (표시·캐시) / 판 흐름 (`ctx`) |
| 연쇄 연출 재생기 | 판 흐름 → 연출 → 판 흐름 | `play(request)`, 일시정지·재개, 백그라운드 플러시; ← `playback_finished(was_skipped)` | 연출 (재생) / 판 흐름 (호출·입력 재개) |
| 플레이 HUD | 판 흐름 → HUD | `placement_committed`, 남은 조각(F1), 목표 진행, 상태 신호 | HUD GDD |
| 메타 화면 UI (결과) | 판 흐름 → 결과 화면 | `RoundResult`; ← "한 판 더" / 팀 바꾸기 / 나가기 | 메타 화면 UI (표시) / 판 흐름 (`retry`) |
| 화면 흐름 & 내비게이션 | 화면 흐름 → 판 흐름 | `start(stage_def, team)`, 나가기 요청 | 화면 흐름 |
| 스테이지 진행 & 해금 · 재화 & 보상 | 간접 (`attempt_ended` 구독) | `RoundResult` (`CLEARED`·별·점수) | 각 GDD |
| 오디오 SFX | 간접 | 상태 신호(클리어·실패·재시작) — 연쇄 소리는 연출 `cue_fired` | 오디오 GDD |

## Formulas

이 시스템이 *소유*하는 수치 규칙은 F1–F5다. 시드는 소유하지 않고 참조한다: `stage_seed`(tray-supply F3), 해석기 `rng_seed`(chain-resolver F7),
연출 시간(chain-presentation `chain_playback_time`). 모든 값은 정수이거나 연출 타이밍(초, `RoundFlowTuning` 리소스 — 규칙 코어 밖이라 float 허용, ADR-0001은 규칙 코어만 정수 강제).

**F1. 남은 조각 수**

The pieces_left formula is defined as:

`pieces_left = piece_limit − placements_used`  (`piece_limit = ∞`이면 `∞`)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| piece_limit | int \| ∞ | 1–∞ (MVP 스테이지 약 15–40 — 스테이지 & 목표가 정함) | data file (`StageDef`) | 이 판에 놓을 수 있는 조각 수 |
| placements_used | int | 0 – piece_limit | calculated | 커밋된 배치 수 (재확인 실패는 세지 않음) |

**Output Range:** 0 – piece_limit. 음수가 될 수 없다(트레이가 `piece_limit`보다 많이 공급하지 않음 — F2).
**Example:** `piece_limit = 20`, 7번 놓음 → `pieces_left = 13` (HUD "남은 조각 13").

**F2. 재충전 예산**

The refill_budget formula is defined as:

`refill_budget = piece_limit − pieces_dealt`  ;  `m = min(tray_size, refill_budget)` (tray-supply 규칙 3)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| pieces_dealt | int | 0 – piece_limit | calculated | 이 판에서 트레이에 들어간 조각 누계 (구제로 바뀐 조각은 1개로 셈 — 교체이지 추가가 아님) |
| tray_size | int | 3 | constant (registry `tray_size`, tray-supply) | 트레이 칸 수 |

**Output Range:** 0 – piece_limit. 재충전은 트레이가 빌 때만 일어나므로 그 순간 `pieces_dealt = placements_used`이고 `refill_budget = pieces_left`.
`refill_budget = 0` → `EXHAUSTED` → 목표 미달성이면 `OUT_OF_PIECES` (규칙 9-2).
**Example:** `piece_limit = 20`, 6번째 재충전 직전 `pieces_dealt = 18` → `refill_budget = 2` → 조각 2개 + 빈 칸 1개 (`PARTIAL`). 둘 다 놓은 뒤 → 0 → 판 종료.

**F3. 결과 공개 시각**

The t_result formula is defined as:

`t_result = t_commit + T_playback + result_reveal_delay_s`  (백그라운드면 `T_playback`·지연 모두 0으로 잘림)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_playback | float (s) | 0.12 – 4.0 (÷ `speed_pref`) | calculated (chain-presentation `chain_playback_time`, registry) | 마지막 배치의 연출 시간 |
| result_reveal_delay_s | float (s) | 0.3 – 1.2, 시작값 0.6 | data file (`RoundFlowTuning`) | 연쇄가 끝난 판을 한숨 보여 주는 간격 |
| result_input_guard_s | float (s) | 0.15 – 0.4, 시작값 0.25 | data file (`RoundFlowTuning`) | 결과 화면이 열린 뒤 버튼 입력을 무시하는 시간 (`t_result` 이후, 건너뛰기 탭이 "한 판 더"로 새지 않게) |

**Output Range:** 마지막 놓기 후 0.72 s(연쇄 없음) – 4.6 s(6단 연쇄 상한) 뒤 결과 화면. 화면 탭으로 지연을 건너뛸 수 있다.
**Example:** 마지막 배치가 연쇄 3단(T ≈ 2.1 s) → 놓은 뒤 2.7 s에 결과. 프로토타입은 고정 0.9 s였다 — "한 판 더" 템포를 위해 0.6으로 줄이고 탭 건너뛰기를 둔다.
> 근거: 0.3 미만이면 마지막 연쇄의 여운 없이 화면이 바뀌어 기둥 1의 마무리가 잘리고, 1.2 초과면 결과가 늦게 느껴진다(기둥 4).

**F4. 재시작 지연 (목표 예산)**

The t_retry formula is defined as:

`t_retry = t_reset + t_deal ≤ retry_budget_s`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_reset | float (s) | ≤ 0.016 (한 프레임) | calculated (규칙 5, 동기) | 씬 재로드 없는 제자리 초기화 |
| t_deal | float (s) | 0 – 0.3, 시작값 0.25 | data file (트레이 표시 — UX 스펙) | 첫 트레이가 들어오는 표시 애니메이션; 끝나기 전에도 집을 수 있음 |
| retry_budget_s | float (s) | 0.5 | constant (성능 예산, AC) | "한 판 더" 탭 → 조각을 집을 수 있을 때까지 상한 |

**Output Range:** 시작값으로 0.27 s. 0.5 s를 넘으면 성능 버그로 본다 (저가 Android 기준 — 플랫폼 & 화면 GDD).
**Example:** 탭 → 같은 프레임에 `SETUP` 완료(약 2 ms, 64칸 보드 + 트레이 init) → 0.25 s 트레이 등장 → 조작 가능.

**F5. 한 판 더 비율 (가설 지표, 측정용)**

The retry_rate formula is defined as:

`retry_rate = N(retry_from_result) / N(attempts_ended_not_abandoned)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N(retry_from_result) | int | ≥ 0 | calculated (로컬 로그: `retry_requested(from_outcome ∈ {CLEARED, FAILED})`) | 결과 화면에서 "한 판 더"를 누른 수 |
| N(attempts_ended_not_abandoned) | int | ≥ 1 | calculated (로컬 로그: `attempt_ended`, outcome ≠ ABANDONED) | 결과 화면까지 간 판 수 |

**Output Range:** 0.0 – 1.0. 컨셉 가설 기준 3 "첫 판 후 재시작 과반" = 테스터별 첫 판의 `retry_rate > 0.5` 여부를 과반 테스터에서 확인.
**Example:** 테스터 6명 중 4명이 첫 결과에서 "한 판 더" → 67% → 기준 충족.

## Edge Cases

- **If 한 배치로 목표 달성과 `no_moves`가 동시에 성립하면**: `CLEARED` (규칙 9-1, board-rules D9). 실패 연출은 나오지 않는다.
- **If 마지막 조각으로 목표를 달성하면** (`pieces_left = 0`): `CLEARED`. 조각 소진은 목표 미달성일 때만 실패다.
- **If 목표 달성 시 조각이 남아 있으면**: 판은 즉시 `CLEARED`로 끝난다(규칙 9-1). 남은 조각은 `pieces_left`로 넘겨 별·보너스 계산 재료가 된다 — 계속 놓아 점수를 올리는
  "보너스 놓기"는 MVP에 없다 (Q1).
- **If 트레이에 조각이 남아 있는데 `pieces_left = 0`이면**: 일어날 수 없다 — 트레이는 `piece_limit`보다 많이 공급하지 않는다(F2). 일어나면 디버그 assert(장부 불일치), 출시 빌드는
  트레이 내용을 우선해 계속 진행한다.
- **If `PARTIAL` 트레이(예: 1개만 남음)에서 그 조각이 들어갈 곳이 없으면**: `FAILED(NO_MOVES)`. `OUT_OF_PIECES`가 아니다 — 아직 남은 조각이 있다.
- **If 재충전 구제가 일어난 재충전 뒤에도 `no_moves`이면**: 정직한 막힘 → `FAILED(NO_MOVES)` (tray-supply Edge Cases). 구제는 표시되지 않는다.
- **If 시작 보드에서 이미 `no_moves`이거나 시작 보드에 완성 줄이 있으면**: 스테이지 데이터 오류. `validate_board` 실패는 로드 오류(판 시작 안 함, 화면 흐름에 오류 보고, 디버그 assert);
  시작 막힘은 디버그 assert + 출시 빌드 `FAILED(NO_MOVES)` 결과 — 앱이 멈추지 않게. 두 경우 모두 스테이지 & 목표의 데이터 검증(에디터 시점)에서 먼저 잡혀야 한다.
- **If `StageDef`의 `FIXED` 스테이지에 `stage_seed`가 없으면**: 로드 오류 (tray-supply Edge Cases — 대체 시드를 만들지 않음).
- **If `team`이 비었거나 4명 이상이거나 미보유 크루를 포함하면**: 팀 편성의 검증 실패 — 판 진행 흐름은 `start`를 거부하고 오류를 보고한다(재검증하지 않고 형식만 확인).
- **If 권위 재확인 `can_place`가 실패하면**: 프로그래밍 오류(규칙 7-2). 디버그 assert, 출시 빌드는 요청 거절·조각 되돌림, 상태·카운터 불변, `placements_used` 증가 없음.
- **If 커밋 결과가 마지막 미리보기와 다르면** (`PREVIEW_MISMATCH`): 버그(기둥 3). 디버그 assert, 출시 빌드는 오류 로그 후 권위 결과로 진행 (chain-preview Edge Cases).
- **If 재생 중(`PRESENTING`) 앱이 백그라운드로 가면**: 연출 즉시 플러시 → `playback_finished(true)` → `SETTLING`. 종료 판정된 판이면 `RESULT_PENDING` 지연도 건너뛰어,
  복귀 시 결과 화면이 바로 보인다. 상태·점수·목표는 이미 확정(규칙 7)이라 차이 없음.
- **If 재생 중 일시정지했다가 `다시 하기`를 누르면**: 진행 중 재생은 버리고(표시만), 현재 판을 `ABANDONED`로 `attempt_ended` → `SETUP`. 단, 그 배치로 이미 판이 `CLEARED`/`FAILED`
  판정됐다면 `attempt_ended`는 이미 났으므로 `ABANDONED`를 다시 내지 않는다(규칙: 정확히 한 번) — 결과는 보존되고 바로 새 시도가 시작된다.
- **If 일시정지 중 백그라운드로 갔다 오면**: 일시정지 오버레이가 그대로 남는다. 재생은 플러시돼 있으므로 `계속`은 `SETTLING`부터 처리한다.
- **If 드래그 중 백그라운드로 가면**: 드래그 강제 취소(배치 없음), `READY`로 복귀. 복귀 시 자동 일시정지 없음 (규칙 19, D9).
- **If 결과 화면에서 "한 판 더"를 빠르게 두 번 누르면**: 첫 탭에서 `SETUP` → `READY`. 두 번째 탭은 결과 화면이 이미 닫혀 무시된다. 버튼은 탭 1회 후 비활성.
- **If 결과 대기(`RESULT_PENDING`) 중 화면을 탭하면**: 지연을 건너뛰고 결과 화면을 연다. 이 탭은 결과 화면 버튼으로 전달되지 않는다(실수로 "한 판 더"를 누르지 않게 — 결과 화면 버튼은
  열린 뒤 `result_input_guard_s` 0.25 s 동안 입력 무시).
- **If 같은 스테이지를 다른 팀으로 다시 시작하면**: `attempt_index = 0`의 새 시작(규칙 6). `FIXED`여도 크루 가방 내용이 달라 트레이 순서가 달라진다(의도 — 기둥 2, tray-supply Edge Cases).
- **If 자유 플레이 `StageDef`(목표 없음, `piece_limit = ∞`)이면**: `CLEARED`는 일어나지 않고 `NO_MOVES`로만 끝난다 — T0 그레이박스·자동 플레이 동작. 별은 0.
- **If 앱이 판 도중 강제 종료되면**: 진행 중 판은 사라진다(규칙 20). 이미 종료 판정된 판(연출·결과 대기 중 종료)은 `attempt_ended`가 났으므로 보존된다 — 세이브 시스템이 그 신호에서
  저장하는 것이 계약 (로컬 세이브 GDD, provisional).
- **If 점수가 매우 커지면**: 64비트 정수 누계(scoring 규칙 11) — 판 진행 흐름은 합산하지 않고 `StageScoreTally`를 그대로 보관한다.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 종류 | 쓰는 것 | 상태 |
|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | Hard | `validate_board`, `can_place`, `no_moves` (규칙 15 타이밍 계약) | Designed |
| 연쇄 해석기 (`chain-resolver.md`) | Hard | `resolve`, `ChainResult`, F7 `rng_seed` | Designed |
| 점수 & 연쇄 배율 (`scoring.md`) | Hard | `score_placement`, `StageScoreTally`, 상태 `ACTIVE`/`FINAL` | Designed — index Depends On에 없음 (scoring Q5) |
| 트레이 공급 (`tray-supply.md`) | Hard | `init_state`/`refill`/`consume`, 시드 모드, `TRAY_RESCUED` | Designed |
| 스테이지 & 목표 (`stage-goals.md`) | Hard | `StageDef`, `GoalTracker`, 제한 조각 소진 판정, `stars` | 동시 작성 중 — 이 문서의 인터페이스 이름은 provisional (Q3) |
| 팀 편성 (`team-composition.md`) | Hard (데이터) | 검증된 `team` 목록 | 동시 작성 중 |
| 드래그 & 배치 입력 (`placement-input.md`) | Hard | `set_input_enabled`, `placement_requested`, `drag_ended`, 강제 취소 | Designed — index Depends On에 없음 (placement-input Q1) |
| 연쇄 미리보기 (`chain-preview.md`) | Hard (판 흐름이 `ctx` 공급) | 디버그 비교용 마지막 표시 결과 | Designed — index Depends On에 없음 (chain-preview Q4) |
| 연쇄 연출 재생기 (`chain-presentation.md`) | Hard | `play`, `playback_finished`, 정지/재개·플러시 | Designed — index Depends On에 없음 (chain-presentation Q6) |
| 시드 RNG (ADR-0001) | Hard (계약) | `hash32`, `SeedStreams` | Accepted ADR |

**Downstream (이 시스템에 의존)**

| 시스템 | 종류 | 쓰는 것 |
|---|---|---|
| 화면 흐름 & 내비게이션 (`scene-flow.md`) | Hard | `start`, 나가기, `attempt_ended` |
| 플레이 HUD (`gameplay-hud.md`) | Hard | 상태 신호, `placement_committed`, F1, 일시정지 버튼 |
| 메타 화면 UI — 결과 (`meta-screens-ui.md`) | Hard | `RoundResult`, `retry()` |
| 오디오 SFX (`audio.md`) | Soft | 상태 신호 (클리어·실패·재시작) |
| 스테이지 진행 & 해금, 재화 & 보상, 로컬 세이브 | Soft (신호 구독) | `attempt_ended(RoundResult)` |
| 튜토리얼 & 힌트 (VS) | Soft | 상태 신호, 스크립트 단계 재시작 |

**양방향성**: board-rules·chain-resolver·tray-supply·scoring·placement-input·chain-preview·chain-presentation은 모두 이 문서를 Hard downstream(호출자)으로
적고 있어 일치한다. systems-index #11 Depends On(보드 & 조각 규칙, 스테이지 & 목표, 트레이 공급, 연쇄 해석기, 팀 편성)에는 **점수·드래그 & 배치 입력·
연쇄 미리보기·연쇄 연출 재생기가 빠져 있다** — 네 GDD가 각각 제안한 추가(scoring Q5, placement-input Q1, chain-preview Q4, chain-presentation Q6)를 이 GDD 작성과 함께
index에 반영한다 (Phase 5d). index #12·#20·#21·#23은 이미 판 진행 흐름을 Depends On에 적고 있어 일치.

## Visual/Audio Requirements

판 진행 흐름 자체는 그리지 않는다. 아래는 이 시스템의 상태 전이가 요구하는 표현이며, 구체 연출은 소유 GDD·UX 스펙이 정한다.

| 순간 | 요구 | 소유 |
|---|---|---|
| 판 시작 / 재시작 | 보드는 한 번에 나타나고(페이드 ≤ 0.15 s), 트레이가 `t_deal` 동안 미끄러져 들어온다. 재시작은 직전 판과 같은 배치로 "다시 정돈"되는 느낌 — 긴 전환 화면 없음 | 플레이 HUD / UX |
| `CLEARED` | 마지막 연쇄 연출이 끝난 뒤 `result_reveal_delay_s` 동안 보드 위 크루 얼굴들이 함께 웃는 짧은 반응 + 클리어 소리 | 연출 / 오디오 |
| `FAILED` | **귀엽게** (기둥 5): 막힌 트레이 조각이 살짝 흔들리고 크루 얼굴이 머쓱한 표정, 부드러운 "뿅" 소리. 빨간 화면·경고음·화면 흔들림 금지 (움직임 줄이기면 흔들림 대신 페이드) | 연출 / 오디오 |
| 일시정지 | 화면을 흐리게 덮는 오버레이, 재생 중이던 입자도 그 자리에서 정지 | 플레이 HUD / UX |
| 결과 화면 | "한 판 더"가 가장 크고 먼저 눈에 들어옴(엄지 영역) | 메타 화면 UI |

## Game Feel

- **재시작 반응성**: "한 판 더" 탭 → 조각을 집을 수 있을 때까지 ≤ 0.5 s (F4). 로딩 표시가 보이면 실패.
- **놓기 → 다음 조작**: 연쇄 없는 배치는 착지(`place_dur`) 직후 입력이 열린다 — 판 진행 흐름이 추가하는 대기 0 s (재충전·판정은 커밋 프레임에 이미 끝남).
- **결과까지 여운**: 마지막 연쇄가 끝나고 0.6 s(F3) — 연쇄의 마무리를 보고 결과로 넘어간다. 탭하면 즉시.
- **일시정지 정지감**: 일시정지는 다음 프레임에 모든 움직임을 멈춘다(연출·입자·흔들림). 재개 시 이어서 — 되감기 없음.
- **타이머 없음**: 판 안에 시간 제한·시간 점수·유휴 경고가 없다. 생각하는 시간은 공짜다 (안티 기둥 "시간 압박").

## UI Requirements

- **플레이 화면 HUD**: 남은 조각 수(F1; 무제한이면 숨김), 목표 진행(스테이지 & 목표 형식), 점수, 일시정지 버튼(엄지가 닿지 않는 위쪽 구석 — 드래그 중 오터치 방지).
- **일시정지 오버레이**: `계속`(기본) · `다시 하기` · `나가기` + 연출 토글 3종(chain-presentation 규칙 23–26). 확인 대화상자 없음.
- **결과 화면**: 결과(클리어/실패, 실패 이유는 다정한 한 줄: "놓을 곳이 없어졌어!" / "조각을 다 썼어!"), 별 0–3, 점수·한 방 최고점·최장 연쇄, 버튼 "한 판 더"(기본, 최대) ·
  "팀 바꾸기" · "다음 스테이지"(클리어 시) · "나가기". 결과 화면이 열린 뒤 `result_input_guard_s` 동안 버튼 입력 무시.
- 모든 문구는 문자열 테이블 키(`UI_RESULT_*`, `UI_PAUSE_*`) — T0 `UI_RESULT_BEST`/`UI_RESULT_PLACEMENTS` 키를 잇는다.

> **📌 UX Flag — 판 진행 흐름 (Round Flow)**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for
> each screen or HUD element this system contributes to **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`,
> not the GDD directly. (대상: 게임플레이 HUD `design/ux/hud.md`의 일시정지 버튼·남은 조각, 일시정지 오버레이, 결과 화면 `design/ux/result-screen.md`.)

## Cross-References

| 이 문서의 내용 | 참조 문서 § | 관계 | 상태 |
|---|---|---|---|
| `ResolveContext`의 유일한 출처, `RoundFlow`/`RoundCore` 형태 | `docs/architecture/adr-0001-pure-deterministic-rules-core.md` 결정 9, Implementation Guidelines | 상위 계약 | 일치 |
| `no_moves` = 재충전 뒤 트레이, 빈 목록 거짓, 목표 달성 우선 | `board-rules.md` 규칙 15, Edge Cases, D9 | 상위 계약 (provisional 해소) | 일치 — 이 문서 규칙 9 |
| `rng_seed` 파생, `final_board` 커밋, 연출 대기 | `chain-resolver.md` 규칙 23, F7, States 절 | 상위 계약 (provisional 해소) | 일치 |
| 점수 확정 = 커밋 순간, 누계 `ACTIVE`/`FINAL` | `scoring.md` 규칙 11–13, States | 상위 계약 | 일치 |
| 재충전 시점·`budget`·시도 번호·`FIXED`/`PER_ATTEMPT` | `tray-supply.md` 규칙 3·18, F3, AC-18·21 | 상위 계약 (provisional 해소) | **문구 차이 1건**: tray-supply 규칙 3 "연출 후 `refill`" → 이 문서는 커밋 프레임에 논리적 재충전, 표시는 연출 후 (결과 동일 — Q4) |
| 입력 on/off, 권위 재확인, 강제 취소 | `placement-input.md` 규칙 15·19·20, 상태표 | 상위 계약 (provisional 해소) | 일치 |
| 미리보기 결과 재사용 금지, `PREVIEW_MISMATCH` | `chain-preview.md` 규칙 1·9 | 상위 계약 | 일치 |
| 재생 중 입력 잠금, 일시정지 정지, 백그라운드 플러시, 입력 관통 Q3 | `chain-presentation.md` 규칙 21·24, Edge Cases, Q3 | 상위 계약 (provisional 해소) | 일치 — Q3은 MVP "없음"으로 답함 (D7) |
| 원탭 재시작·직전 팀 유지, 시간 압박·스태미나 없음, 실패도 귀엽게 | `game-concept.md` 기둥 4·5, Anti-Pillars, 가설 기준 3 | 기둥 | 일치 |
| `StageDef`, `GoalTracker`, 별, 제한 조각 판정 | `stage-goals.md` (동시 작성 중) | 하위 계약 | provisional (Q3) |
| 팀 목록 형식·검증 | `team-composition.md` (동시 작성 중) | 상위 데이터 | provisional |
| T0 구현 | `src/gameplay/round/round_flow.gd`, `src/core/rules/round/round_core.gd`, `src/game/game_screen.gd`, `tests/integration/round_flow/round_flow_test.gd` | 구현 | 규칙 23–24 대조 |

## Acceptance Criteria

> 테스트 위치: `tests/integration/round_flow/` (판 흐름은 RefCounted라 씬 없이 실행), UI는 `production/qa/evidence/`의 스크린샷.
> `StageDef`·`GoalTracker` 픽스처는 스테이지 & 목표 GDD 확정 전까지 테스트용 대역(목표 "점수 ≥ N")으로 만든다.

- **AC-R01 [Integration] (규칙 5, 세우기)** — **GIVEN** 유효한 `StageDef`(`FIXED`, `piece_limit = 20`)와 팀 3명, **WHEN** `start`, **THEN** 같은 프레임에 상태 `READY`, `stage_score = 0`,
  `placement_index = 0`, 트레이 3칸이 차 있고 `pieces_dealt = 3`, `attempt_started`가 1회 난다.
- **AC-R02 [Integration] (규칙 7, 커밋 순서)** — **GIVEN** `READY`, **WHEN** 유효 `placement_requested`, **THEN** 같은 프레임 안에 `board = result.final_board`, `placement_index`·`board_version`·
  `placements_used`가 각각 +1, `stage_score`가 `breakdown.total`만큼 증가, 슬롯이 비고, 상태 `PRESENTING`, `placement_committed`가 연출 `play`보다 먼저 1회 난다.
- **AC-R03 [Integration] (규칙 3, 미리보기 = 커밋)** — **GIVEN** 같은 보드·조각·앵커, **WHEN** `context_for_next_placement()`로 미리보기 후 커밋, **THEN** 두 결과의 `board_hash`가 같다
  (기존 `test_commit_matches_preview_and_consumes_slot` 유지).
- **AC-R04 [Integration] (규칙 7-2)** — **GIVEN** 앵커가 막힌 요청, **WHEN** 커밋, **THEN** 거절되고 보드·트레이·점수·카운터 불변, 상태 `READY` (기존 `test_illegal_commit_is_refused_without_change`).
- **AC-R05 [Integration] (규칙 9-1, 클리어 우선)** — **GIVEN** 목표 "점수 ≥ N"과 다음 배치로 N을 넘기면서 재충전 뒤 `no_moves`도 참이 되는 픽스처, **WHEN** 커밋, **THEN** `outcome = CLEARED`,
  `attempt_ended` 1회, `fail_reason = null`.
- **AC-R06 [Integration] (규칙 9-2, F2 조각 소진)** — **GIVEN** `piece_limit = 4`, 목표 미달성, **WHEN** 4개를 놓음, **THEN** 두 번째 재충전이 1개(`PARTIAL`), 4번째 커밋에서 `FAILED(OUT_OF_PIECES)`,
  `pieces_left = 0`, 총 `pieces_dealt = 4`.
- **AC-R07 [Integration] (규칙 9-3)** — **GIVEN** 재충전 뒤 남은 조각이 모두 들어가지 않는 픽스처, **WHEN** 커밋, **THEN** `FAILED(NO_MOVES)`. **AND** 트레이가 비어 재충전 대기인 순간에는 실패가 아니다.
- **AC-R08 [Integration] (규칙 7 — 판정은 커밋 프레임)** — **GIVEN** 종료되는 배치, **WHEN** 커밋 직후(연출 시작 전) `RoundResult`를 조회, **THEN** 이미 확정돼 있고, 연출을 건너뛰거나 끝까지 본 경우와
  필드가 모두 같다.
- **AC-R09 [Integration] (규칙 13, 원탭 재시작 · `FIXED`)** — **GIVEN** `FIXED` 스테이지에서 판이 끝남, **WHEN** `retry()`를 3번, **THEN** 매번 팀이 같고 첫 트레이(모양·크루·얼굴)가 같으며
  `attempt_index`가 1·2·3, 점수·보드·목표 진행이 시작 상태.
- **AC-R10 [Integration] (결정성 — 리플레이)** — **GIVEN** 같은 `StageDef`·팀·`attempt_index`와 같은 (slot, anchor) 목록, **WHEN** 두 번 실행, **THEN** 각 배치의 `board_hash`와 최종 `RoundResult`가 같다
  (기존 `test_same_seed_same_attempt_is_deterministic` 확장).
- **AC-R11 [Integration] (규칙 8)** — **GIVEN** `PRESENTING`, **WHEN** `placement_requested`가 또 옴, **THEN** 무시(디버그 assert), 상태·카운터 불변.
- **AC-R12 [Integration] (규칙 17–18, 일시정지)** — **GIVEN** `PRESENTING` 중, **WHEN** 일시정지 → `계속`, **THEN** 일시정지 동안 연출 타임라인 시각이 변하지 않고, 보드·점수·`board_version` 불변,
  재개 후 재생이 이어져 `playback_finished` 뒤 `READY`. **AND** `DRAGGING` 중 일시정지 → `drag_ended(CANCELLED)`, `계속` 후 `READY`.
- **AC-R13 [Integration] (규칙 18, 포기)** — **GIVEN** 진행 중 판, **WHEN** 일시정지 → `다시 하기`, **THEN** `attempt_ended(outcome = ABANDONED)` 1회 후 `attempt_index + 1`로 `READY`.
  **AND** 이미 종료 판정된 판에서 같은 조작 → `attempt_ended`가 추가로 나지 않는다.
- **AC-R14 [Integration] (규칙 19, 백그라운드)** — **GIVEN** 판을 끝내는 배치의 재생 중, **WHEN** `NOTIFICATION_APPLICATION_PAUSED`, **THEN** 같은 프레임에 `playback_finished(true)`,
  상태 `RESULT`(지연 생략), 결과는 AC-R08과 같다. **AND** 복귀 시 일시정지 오버레이가 뜨지 않는다.
- **AC-R15 [Integration] (규칙 11, 입력 재개)** — **GIVEN** 줄을 지우지 않는 배치, **WHEN** 연출이 착지 후 `playback_finished`, **THEN** 같은 프레임에 `set_input_enabled(true)`와 트레이 표시 갱신.
- **AC-R16 [Logic] (F1·F2)** — **GIVEN** `piece_limit = 20`, `placements_used = 18`, 트레이 빈 상태, **WHEN** 재충전, **THEN** `refill_budget = 2`, `pieces_left = 2`, 트레이 `PARTIAL`. **AND** `piece_limit = ∞`면
  `pieces_left`는 ∞이고 HUD 표시는 숨김.
- **AC-R17 [UI] (규칙 13, F4)** — **GIVEN** 저가 Android 기준 기기(플랫폼 & 화면 GDD)의 결과 화면, **WHEN** "한 판 더" 탭, **THEN** 0.5 s 안에 조각을 집을 수 있다 (탭 시각 ↔ 첫 `drag` 수락 로그로 측정).
  스크린샷: 결과 화면(클리어·실패), 일시정지 오버레이 → `production/qa/evidence/`.
- **AC-R18 [Integration] (F3)** — **GIVEN** 종료 배치, **WHEN** `playback_finished`, **THEN** `RESULT_PENDING`이 `result_reveal_delay_s`(0.6) 뒤 `RESULT`로; 그 사이 탭 → 즉시 `RESULT`, 그 탭은 결과 버튼에 전달되지 않음.
- **AC-R19 [Integration] (규칙 22, F5)** — **GIVEN** 판 3개(클리어 1, 실패 1, 포기 1)와 결과 화면 "한 판 더" 2회, **WHEN** 로컬 로그 집계, **THEN** `retry_rate = 2 / 2 = 1.0` (포기는 분모에서 제외).
- **AC-R20 [Integration] (규칙 9 — 자유 플레이)** — **GIVEN** 자유 플레이 `StageDef`(T0 동작), **WHEN** 막힐 때까지 놓음, **THEN** `FAILED(NO_MOVES)`로만 끝나고 결과 패널의 "한 판 더"가 동작
  (기존 `test_play_until_no_moves_then_retry_resets` 유지).

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 목표 달성 후 남은 조각: 즉시 종료(현재) vs 남은 조각을 "보너스 놓기"로 계속 / 남은 조각당 보너스 점수 — 별 기준 설계와 함께 | game-designer · 스테이지 & 목표 GDD | `/design-system stage-goals` |
| Q2 | 판 중간 이어 하기(앱 종료 후 복귀) — 결정성 덕분에 (stage_id, team, attempt, [(slot, anchor)]) 로그 재생으로 싸게 가능. MVP 판 길이(1–3분)에선 불필요하다고 봄 | game-designer · 로컬 세이브 GDD | 첫 외부 플레이테스트 후 |
| Q3 | 스테이지 & 목표와의 인터페이스 이름 확정: `StageDef` 필드, `GoalTracker`(시작·`apply(result, breakdown, tally)`·`is_met()`·진행 스냅샷), 제한 조각 소진 질의, `stars(stage_def, RoundResult)` | 스테이지 & 목표 GDD 작성자 | `stage-goals.md` 완료 시 — 이름이 다르면 이 문서를 맞춘다 |
| Q4 | tray-supply 규칙 3 문구("해석기 종료·연출 후 `refill`")를 "논리적 재충전은 커밋 시, 표시는 연출 후"로 정리할지 — 결과는 같고 확정 시점만 다름 | tray-supply 소유자 · `/consistency-check` | 다음 tray-supply 개정 |
| Q5 | 결과 화면 "다음 스테이지" 버튼을 기본 버튼으로 할지("한 판 더"보다) — 클리어 + 별 3이면 "다음"이 자연스러움. 기둥 4 테스트는 "재시도 원탭"이지 "기본 버튼"이 아님 | ux-designer · 메타 화면 UI | `/ux-design` 결과 화면 |
| Q6 | 결과 화면에서 다른 팀을 바로 고르는 "팀 빠른 교체"(기둥 2 "다른 팀이면 다른 경로")를 원탭에 가깝게 둘지 | ux-designer · 팀 편성 GDD | 메타 화면 UI 설계 시 |

### Decision Log (사용자 위임 — 질문 없이 권장안 채택, automation guided)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(남은 조각·재충전 예산·결과 지연·재시작 예산·가설 지표 = 숫자 규칙)·Edge Cases·Dependencies·AC + 선택 섹션 전부("All of them" 권장 — 의존·UI 있음). Player Fantasy·Tuning Knobs 생략 | Formulas 생략(Core 카테고리) — 섹션 C가 수치를 정하므로 §1 테스트상 필수 |
| D2 | Overview 프레이밍 | `[A]` 기술 프레이밍 권장(Core)이나 플레이어 체감 한 줄 추가 / ADR-0001 인용 / Fantasy 섹션 없음 | 순수 기술 프레이밍 — 기둥 4 연결이 안 보임 |
| D3 | 상태 확정 시점 | **커밋 프레임에 전부 확정**(해석·채점·목표·소비·재충전·종료 판정), 연출은 보여 주기만 | T0처럼 재생 뒤 재충전·판정 — 재생 중 앱 종료 시 클리어 유실, 테스트가 연출에 묶임 |
| D4 | 종료 우선순위 | CLEARED > OUT_OF_PIECES > NO_MOVES > CONTINUE | 실패 우선 — 기둥 5 위반 (board-rules D9) |
| D5 | 목표 달성 시 | 즉시 종료, 남은 조각은 결과로 전달 (Q1) | 남은 조각 끝까지 놓기 — 판 길이↑, "한 판 더" 템포↓ |
| D6 | 되돌리기 | **MVP 없음** — 원탭 재시작이 복구 수단 | 판당 1회 무르기 — 제한 조각 긴장 약화; 무제한 무르기 — 미리보기를 "놓아 보기"로 대체, `FIXED`와 결합해 퍼즐 붕괴 |
| D7 | 재생 중 입력 관통 (chain-presentation Q3) | MVP 없음 — 빨리 감기·건너뛰기로 충분 | 집는 순간 자동 건너뛰기 — 표시 보드와 실제 보드 차이로 기둥 3 위험 |
| D8 | 재시작 범위 | 같은 `StageDef`·같은 팀·`attempt + 1`, 시드는 스테이지 `tray_seed_mode`(MVP `FIXED` = 같은 첫 트레이), 씬 재로드 없음, 확인 없음 | 매 시도 새 시드 — 재도전이 운 시험(tray-supply D6); 확인 대화상자 — 원탭 위반 |
| D9 | 백그라운드 복귀 | 자동 일시정지 없음 (타이머가 없어 잃을 것이 없음), 재생은 플러시 | 복귀 시 일시정지 오버레이 — 탭 한 번 추가, 얻는 것 없음 |
| D10 | 일시정지 메뉴의 다시 하기·나가기 | 확인 없음, 진행 판은 `ABANDONED` 기록 | 확인 대화상자 — 이미 메뉴 한 단계를 거침 |
| D11 | 판 중간 저장 | MVP 없음, 종료 판정된 판만 즉시 기록 | 리플레이 로그 저장 — 가능하지만 범위 밖 (Q2) |
| D12 | 결과 공개 지연 | 0.6 s + 탭 건너뛰기 | 프로토타입 0.9 s 고정 — 반복 시 느림; 0 s — 마지막 연쇄 여운이 잘림 |
| D13 | T0 코드 처리 | 현재 `RoundFlow`를 확장(규칙 24 a–g), 자유 플레이 `StageDef`로 T0 동작 보존 | 새 클래스로 재작성 — 이미 테스트된 커밋 경로·결정성 테스트를 버림 |
| D14 | 스테이지 & 목표 인터페이스 | 이름으로 참조(`StageDef`, `GoalTracker`, `stars`) + provisional 표기, 확정은 stage-goals 쪽 (Q3) | 이 문서가 목표 형식까지 정의 — 동시 작성 중인 문서와 충돌 |

> 상담하지 못한 에이전트 (이 실행에 Agent 도구 없음 / lean): `game-designer`·`systems-designer`(섹션 C — lean 생략), `systems-designer`(섹션 D·E), `qa-lead`(섹션 H),
> `art-director`(Visual/Audio — Core라 선택 섹션), `creative-director`(CD-GDD-ALIGN — lean 생략). Review manually before production.
