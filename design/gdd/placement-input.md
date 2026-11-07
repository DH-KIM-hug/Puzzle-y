# 드래그 & 배치 입력 (Drag & Placement Input)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 3 보이는 연쇄 (놓기 전에 결과를 보게 하는 입구) · 기둥 5 다정한 세계 (실수에 벌이 없음) · 기둥 4 한 판 더 (빠른 손맛)

## Summary

트레이의 조각을 손가락으로 집어 판에 붙이는 유일한 퍼즐 조작을 정의한다: 입력 상태 머신(LOCKED·READY·PRESSED·DRAGGING·RETURNING·COMMITTING),
손가락 0.6칸 위에 그리는 조각 위치, 반올림 + 히스테리시스 스냅으로 얻는 앵커, 유효할 때만 보이는 고스트, 벌 없는 무효 놓기 되돌림,
한 손가락 소유와 강제 취소. 유효 앵커가 바뀔 때만 연쇄 미리보기에 재계산을 요청하고, 놓으면 마지막으로 보인 앵커를 판 진행 흐름에
넘긴다 — 그래서 "보인 대로 놓인다" (기둥 3).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `보드 & 조각 규칙` (upstream) — downstream: 연쇄 미리보기, 판 진행 흐름 (트레이 스냅샷은 판 흐름이 주입)

## Overview

드래그 & 배치 입력은 플레이어가 말랑 크루에서 하는 **유일한 퍼즐 조작** — 트레이의 조각을 손가락으로 집어 판 위로
끌고 가 놓는 동작 — 을 정의한다. 데이터 층에서는 터치(에디터·데스크톱에서는 마우스가 터치를 흉내 냄) 포인터 하나를
받아 **입력 상태 머신**(대기 → 눌림 → 드래그 → 확정/되돌림)을 돌리고, 손가락 위치를 조각의 화면 위치로, 다시
board-rules 규칙 6의 **앵커 `(r0, c0)`**로 바꾼다(스냅). 앵커가 바뀔 때마다 board-rules `can_place`로 유효성을 묻고,
유효한 앵커가 **바뀌었을 때만** 연쇄 미리보기에 재계산을 요청한다 (chain-resolver 규칙 25, TD 조건). 손을 떼면 유효
앵커는 판 진행 흐름에 배치 요청으로 넘기고, 유효하지 않으면 조각을 벌 없이 트레이로 되돌린다. 플레이어 쪽에서 보면
이 시스템은 "집으면 바로 떠오르고, 손가락에 가리지 않고, 놓을 수 있는 곳에서만 자리가 보이고, 잘못 놓아도 아무 일
없이 돌아오는" 손맛이다. 이 시스템이 없으면 미리보기를 볼 방법(드래그 중 앵커)도, 배치를 확정할 방법도 없다.
배치 가능 판정·연쇄 해석·미리보기 표시 내용·트레이 재충전은 경계 밖이다 — 이 문서는 포인터 → 앵커 변환, 상태 머신,
그리고 다른 시스템에 넘기는 신호 세 가지(앵커 변경, 배치 요청, 드래그 종료)만 소유한다.

*프레이밍 결정 (guided, 권장안)*: Category `Core` → Framing `[A]` 권장이지만 입력은 플레이어가 직접 만지는 시스템이라
`[C] Both`로 상향 (Decision Log D1) · ADR ref `[B] No` (`docs/architecture/adr-*.md` 없음) · Fantasy — standard
tier라 Player Fantasy 섹션 생략. 구현 방식(어느 노드가 `_unhandled_input`/`_gui_input`을 받는가, 마우스→터치 에뮬레이션
설정, 그림자 스프라이트 레이어)은 → ADR 대상.

## Detailed Design

> *Specialist note*: `game-designer` · `ux-designer` · `gameplay-programmer` (Section 6 routing: Camera/input/controls)
> not consulted — Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 단위와 좌표**

1. **기준 단위** — 화면 거리는 두 단위로만 정의한다. (a) **칸 단위**: `s` = 판 위 칸 한 변의 화면 길이 (board-rules UI
   Requirements: 1080px 폭에서 ≈ 130px). 조각 오프셋·스냅·히스테리시스는 칸 단위라 해상도와 무관하다. (b) **기준 px**:
   1080px 폭 기준 픽셀 `px@1080`. 실제 픽셀 = `px@1080 × (화면 폭 / 1080)` (F5). 터치 슬롭·그림자처럼 손가락·눈 기준인
   값만 기준 px로 쓴다.
2. **좌표계** — 포인터 좌표는 게임 화면(세이프 영역 적용 후의 캔버스) 좌표다. 판의 좌상단 화면 좌표 `(board_x, board_y)`와
   `s`는 레이아웃(플랫폼 & 화면 GDD)이 주고, 이 시스템은 읽기만 한다.

**B. 집기 (Press)**

3. **입력 소스** — 터치 포인터만 처리한다. 마우스는 엔진의 "마우스로 터치 흉내" 설정으로 터치 이벤트가 되어 같은 경로를
   탄다 (technical-preferences: "mouse emulates touch"). 같은 동작이 마우스 이벤트와 터치 이벤트로 두 번 들어오지 않게 한
   경로만 듣는다 (구현 → ADR). 키보드·게임패드 입력은 MVP에 없다 (`gamepad_support: None`).
4. **히트 영역** — 트레이 칸 i의 히트 영역은 그 칸의 **사각형 전체**(트레이 폭 / 트레이 칸 수 × 트레이 높이)이며 조각
   픽셀 모양이 아니다. 1칸짜리 작은 조각도 같은 크기로 잡힌다. 히트 영역은 최소 64 × 64 px@1080 (art bible §UI, F6).
5. **집을 수 있는 조건** — 입력이 `READY`이고, 눌린 칸에 조각이 있으면 집는다. **어디에도 놓을 수 없는 조각(`any_fit =
   false`)도 집을 수 있다** — 판을 둘러보며 확인하는 것은 정상 행동이고, 그런 조각은 고스트가 끝내 뜨지 않을 뿐이다.
   빈 트레이 칸, 트레이 밖(판·HUD) 누름은 무시한다 (판 위 탭은 연출 스킵 등 다른 시스템이 쓸 수 있도록 소비하지 않는다).
6. **즉시 들어 올림** — 누른 그 프레임에 조각이 트레이 크기(`tray_piece_scale` × `s`, 시작값 0.72)에서 판 크기(`s`)로
   커지며 손가락 위로 떠오른다 (F1 위치, `lift_anim_s` 0.08s). 트레이 칸에는 빈 "스티커 자리"가 남는다. 이 시점은
   `PRESSED`라 아직 앵커를 계산하지 않는다 (규칙 8).

**C. 끌기 (Drag)와 스냅**

7. **손가락 오프셋** — 끌리는 조각의 바운딩 박스는 손가락 x에 **가로 중앙**, 아래 변이 손가락보다 `lift_offset_cells`
   (시작값 0.6칸) 위에 오도록 그린다 (F1, 프로토타입 검증값). 손가락이 조각을 가리지 않는다. 오른손·왼손 무관하게 같은
   위치다 (가로 중앙이므로).
8. **드래그 시작 슬롭** — 누른 점에서 포인터가 `drag_slop_px` (시작값 20 px@1080) 이상 움직이면 `DRAGGING`으로 넘어가고
   그때부터 앵커를 계산한다 (F4). 슬롭 안에서 떼면 탭으로 보고 되돌린다. 이유: 트레이가 판 바로 아래라, 슬롭이 없으면
   트레이를 **탭만 해도** 들어 올린 조각이 판 아래쪽 줄에 스냅되어 실수로 놓인다 (Edge Cases 참고).
9. **후보 앵커** — 매 포인터 이동마다 조각 화면 위치에서 원시 앵커(실수)를 계산하고 반올림해 **후보 앵커**를 얻는다
   (F2, `floor(x + 0.5)` — 엔진 `round()`의 0.5 처리에 기대지 않는다). 후보는 판 밖 좌표일 수도 있다. **클램프하지
   않는다**: 반올림이 이미 반 칸까지 걸친 위치를 흡수하며, 그보다 먼 위치를 가장 가까운 유효 앵커로 끌어당기면 고스트가
   손과 다른 곳으로 튀어 의도를 숨긴다 (Decision Log D4).
10. **히스테리시스** — 현재 앵커가 있으면, 원시 앵커가 그 앵커에서 축마다 `0.5 + snap_hysteresis_cells` (시작값 0.12칸)
    이내인 동안 현재 앵커를 유지한다 (F3). 칸 경계에서 손가락 떨림으로 앵커가 깜빡이며 미리보기를 연달아 다시 계산하는
    일을 막는다. 가로·세로 축은 독립이다.
11. **유효성** — 후보 앵커가 바뀌면 그 앵커에 대해 board-rules `can_place(board, piece, anchor)`를 1회 부른다. 결과는
    `(앵커, 유효)` 쌍으로 보관한다. 같은 앵커에서는 다시 묻지 않는다 (보드는 드래그 중 바뀌지 않는다 — 규칙 20).
12. **고스트는 유효할 때만** — 유효 앵커에서만 판 위 그 자리에 반투명 고스트를 그린다. 유효하지 않으면 고스트·미리보기가
    없고, 끌리는 조각이 부드러운 회색 톤으로 바뀐다 (빨간 경고 없음 — 기둥 5; 색만이 아니라 고스트의 **유무**가 신호다).
13. **미리보기 트리거** — **유효 앵커가 바뀐 프레임에만** `anchor_changed(piece_ref, anchor)`를 낸다. 유효 → 무효로 바뀌면
    `anchor_changed(piece_ref, null)` 1회(미리보기 지우기). 같은 앵커에 머무는 동안, 무효 → 무효 이동 동안은 아무것도
    내지 않는다 (chain-resolver 규칙 25·AC-16). 이 시스템은 `resolve`를 직접 부르지 않는다.

**D. 놓기 (Release)**

14. **놓을 앵커 = 마지막으로 보인 앵커** — 떼는 순간의 포인터 좌표로 다시 계산하지 않는다. 마지막 이동 이벤트에서 확정된
    `(앵커, 유효)`를 쓴다 — 손가락이 떨어지는 순간의 미끄러짐으로 고스트와 다른 곳에 놓이는 일이 없다 ("보인 대로 놓인다",
    기둥 3).
15. **유효 놓기 → 배치 요청** — `placement_requested(slot, anchor)`를 판 진행 흐름에 1회 내고 `COMMITTING`으로 간다.
    조각은 고스트 자리로 0.06s 안에 붙는다(연출은 연출/보드 표시 소관). 판 진행 흐름이 `can_place`를 다시 확인하고(권위
    판정) `resolve`를 부른다. 입력은 판 진행 흐름이 다시 켤 때까지 `LOCKED`.
16. **무효 놓기 → 되돌림** — 유효 앵커 없이 떼면(판 밖, 겹침, 탭, 슬롭 안) 조각을 원래 트레이 칸으로 `return_anim_s`
    (시작값 0.15s, board-rules Game Feel 0.12~0.18s) ease-out으로 되돌린다. 무효 앵커가 판 위였다면 되돌리기 전에 작은
    좌우 흔들림(0.1s)으로 "여긴 안 돼"를 보인다. **벌 없음**: 조각 수·점수·제한 조각 수·턴은 바뀌지 않는다 (기둥 5).
    되돌림은 입력을 막지 않는다 — 되돌아가는 중에 다른 칸(또는 같은 칸)을 누르면 되돌림이 즉시 끝나고 새 집기가 시작된다.
17. **명시적 취소 제스처는 따로 없다** — 취소 = 유효 자리 없이 떼기. 가장 쉬운 취소는 조각을 트레이 쪽으로 끌어내려
    (조각 아래 변이 판 아래로 반 칸 이상 나가면 후보가 판 밖 → 무효) 떼는 것이다. 판 아래쪽 줄에 놓기 위해 손가락이 트레이
    영역 위에 있을 수 있으므로 "손가락이 트레이 위면 취소" 규칙은 **두지 않는다** (Edge Cases).

**E. 멀티터치와 중단**

18. **한 번에 한 손가락** — 첫 포인터가 드래그를 소유한다 (포인터 index 기억). 드래그 중 다른 손가락의 누름·이동·떼기는
    무시한다 — 두 번째 조각을 집거나, 드래그를 넘겨받거나, 취소하지 않는다. 소유 포인터의 떼기만 놓기로 처리한다.
    `READY`에서 두 손가락이 같은 프레임에 닿으면 index가 작은 포인터(동률 없음 — 엔진이 순서를 줌)가 소유한다.
19. **강제 취소** — 아래 경우 드래그는 규칙 16과 같이 되돌림(흔들림 없음)으로 끝나며 배치 요청은 나가지 않는다:
    (a) 앱이 백그라운드로 가거나 포커스를 잃음, (b) OS가 터치를 취소함(시스템 제스처·알림 끌어내림), (c) Android 뒤로 가기
    — 이 경우 뒤로 가기는 **드래그 취소에만 쓰이고** 일시정지·화면 이동을 열지 않는다(소비), (d) 판 진행 흐름이 입력을
    끔(일시정지 오버레이 등), (e) 화면 크기·세이프 영역 변경(세로 고정이라 드묾). 취소 시 `drag_ended(CANCELLED)`를 낸다.
20. **드래그 중 보드 불변** — 드래그는 `READY` 상태(안정 보드, board-rules 시점 Stable)에서만 시작되므로 드래그 중
    보드·트레이는 바뀌지 않는다. 판 진행 흐름이 드래그 중 보드를 바꾸어야 한다면 먼저 입력을 끄고(규칙 19d) 바꾼다.

**F. 데이터 기반 값** (standard tier라 Tuning Knobs 섹션은 생략 — 범위와 근거는 여기와 Formulas 변수표)

| 값 | 시작값 | 안전 범위 | 근거 · 너무 크거나 작으면 |
|---|---|---|---|
| `lift_offset_cells` | 0.6칸 | 0.4 ~ 1.0 | 프로토타입 검증값. 작으면 손가락(약 9mm ≈ 0.7칸)이 조각 아래 줄을 가리고, 크면 손과 조각이 따로 노는 느낌·위쪽 줄 놓기 불편. 설정(VS)에서 사용자 조절 후보 |
| `drag_slop_px` | 20 px@1080 | 12 ~ 32 | 약 8dp(일반 터치 슬롭). 작으면 탭이 판 아래 줄 배치가 되고, 크면 집은 뒤 조각이 늦게 따라와 끈적함 |
| `snap_hysteresis_cells` | 0.12칸 | 0 ~ 0.25 | 0이면 경계 떨림으로 미리보기 깜빡임, 크면 고스트가 손보다 늦게 따라와 "자석에 걸린" 느낌 |
| `tray_piece_scale` | 0.72 | 0.5 ~ 0.85 | 프로토타입값. 트레이 칸에 2×3 조각이 들어가야 함 (F6) |
| `lift_anim_s` | 0.08s | 0 ~ 0.12 | 0 = 즉시 (모션 줄이기). 크면 집기 반응이 둔함 |
| `return_anim_s` | 0.15s | 0.12 ~ 0.18 | board-rules Game Feel 범위. 너무 짧으면 어디로 갔는지 놓치고, 길면 다음 집기를 기다리게 함(단, 규칙 16으로 막지는 않음) |
| `invalid_wiggle_s` | 0.10s | 0 ~ 0.15 | 0 = 흔들림 없음 (모션 줄이기) |
| `drag_shadow_px` | 8 px@1080 | 6 ~ 10 | art bible 원칙 3 (드래그 중 6–10px) |

### States and Transitions

| 상태 | 의미 | 들어오는 조건 | 나가는 전이 |
|---|---|---|---|
| `LOCKED` | 입력 꺼짐. 트레이 누름 무시 | 시작 상태; 판 진행 흐름 `set_input_enabled(false)`; 배치 요청 직후 | 판 진행 흐름 `set_input_enabled(true)` → `READY` |
| `READY` | 안정 보드, 집기 대기 | `LOCKED`에서 켜짐; 되돌림 시작 직후 | 조각 있는 트레이 칸 누름 → `PRESSED`; 꺼짐 → `LOCKED` |
| `PRESSED` | 조각이 들려 손가락을 따라오지만 앵커 미계산 | `READY`에서 누름 | 슬롭 초과 이동 → `DRAGGING`; 떼기 → `RETURNING`(탭); 강제 취소 → `RETURNING` |
| `DRAGGING` | 앵커 추적·고스트·미리보기 트리거 | `PRESSED`에서 슬롭 초과 | 유효 앵커에서 떼기 → `COMMITTING`; 무효에서 떼기 → `RETURNING`; 강제 취소 → `RETURNING` |
| `RETURNING` | 조각이 트레이로 돌아가는 연출 중. **입력은 열려 있음** | 무효 놓기·탭·취소 | 연출 끝 → (상태 표시만 해제, 이미 `READY`처럼 동작); 새 누름 → 연출 즉시 완료 후 `PRESSED`; 꺼짐 → 연출 즉시 완료 후 `LOCKED` |
| `COMMITTING` | 배치 요청을 보냄, 판 진행 흐름의 처리 대기 | 유효 놓기 | 즉시 `LOCKED` (판 진행 흐름이 해석·연출·재충전 뒤 다시 켬). 판 진행 흐름이 요청을 거절하면(`can_place` 재확인 실패 — 버그) `RETURNING` |

`RETURNING`은 논리적으로 `READY`의 하위 표시 상태다 — 표에 분리한 이유는 "되돌림 중 누름" 규칙(16)을 명확히 하기 위해서다.
신호: `PRESSED`/`DRAGGING`에서 나갈 때 항상 `drag_ended(reason ∈ {COMMITTED, RETURNED, CANCELLED})`를 정확히 1회 낸다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 입력 → 보드 규칙 | 후보 앵커마다 `can_place(board, piece, anchor)` 1회; 앵커 정의(규칙 6)와 F1 앵커 범위 | 보드 규칙 (판정) / 이 문서 (언제 묻는가) |
| 연쇄 미리보기 | 입력 → 미리보기 | `anchor_changed(piece_ref, anchor \| null)` — 유효 앵커가 바뀔 때만; `drag_ended(reason)` → 미리보기 지움. 미리보기는 보드·`ctx`(rng_seed 포함)를 판 진행 흐름에서 받아 `resolve`를 부른다 | 이 문서 (트리거·신호 형식) / 미리보기 GDD (표시·캐시) |
| 판 진행 흐름 | 판 흐름이 입력을 호출·구독 (의존 방향: 판 흐름 → 입력) | 판 흐름 → 입력: `set_input_enabled(bool)`, 현재 보드·트레이 스냅샷 주입. 입력 → 판 흐름: `placement_requested(slot, anchor)` 1회 (신호) | 이 문서 (API·신호 형식) / 판 진행 흐름 (권위 판정·타이밍) |
| 트레이 공급 | 판 흐름이 넘기는 데이터 | 트레이 칸별 조각 인스턴스(또는 빈 칸), 칸 수. 입력은 조각을 소비하지 않는다 — 소비는 배치가 커밋될 때 판 흐름/트레이가 함 | 트레이 공급 (형식) |
| 플랫폼 & 화면 | 플랫폼 → 입력 | 세이프 영역 적용 캔버스, 판 좌상단·`s`, 트레이 사각형, 화면 폭(F5 배율), 포커스 잃음·뒤로 가기 알림 | 플랫폼 & 화면 GDD |
| 화면 흐름 & 내비게이션 | 입력이 뒤로 가기를 먼저 소비 | 드래그 중 뒤로 가기 → 드래그 취소만 (규칙 19c), 아니면 화면 흐름으로 통과 | 화면 흐름 (평상시 뒤로 가기) |
| 연쇄 연출 재생기 / 보드 표시 | 입력 → 표시 | 끌리는 조각 위치·스케일·그림자·회색 톤, 고스트 위치, 되돌림 연출 | 이 문서 (요구) / 연출 GDD (붙는 연출) |
| 오디오 SFX | 입력 → 오디오 | 집기 "슥", 유효 앵커 진입 틱(선택), 무효 놓기 "통" 되돌림 | 오디오 GDD |
| 설정 & 접근성 (VS) | 설정 → 입력 | `lift_offset_cells`, 모션 줄이기(애니 0), 진동 on/off | 설정 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — lean에서 Section D는 spawn 대상이지만 이 실행에는 Agent 도구가 없어
> 생략. 값은 프로토타입 검증값과 art bible·board-rules 범위에서 가져왔다. Review manually before production.

**F1. 끌리는 조각 위치**

The drag_piece_rect formula is defined as:

`piece_left = fx − (w × s) / 2`, `piece_top = fy − (h × s) − (L × s)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| fx, fy | float | 캔버스 좌표 | calculated (포인터) | 소유 포인터 위치 |
| w, h | int | 1 ~ `max_piece_cells` (board-rules) | data file (조각 모양 바운딩 박스) | 조각 폭·높이(칸) |
| s | float | ≥ 64 px@1080 (board-rules UI; 1080 폭 ≈ 130) | calculated (레이아웃) | 칸 한 변 화면 길이 |
| L | float | 0.4 ~ 1.0 | data file (`lift_offset_cells`) | 손가락 위 오프셋(칸) |

**Output Range:** 조각 아래 변은 항상 손가락보다 `L × s` 위 (1080 폭에서 0.6 × 130 ≈ 78px). 판 위쪽 줄에 놓을 때 조각이 판 밖
(HUD 위)으로 그려질 수 있다 — 끌리는 조각은 최상위 레이어에 그린다.
**Example:** s = 131, 손가락 (400, 900), 2×3 조각 → left = 400 − 196.5 = **203.5**, top = 900 − 262 − 78.6 = **559.4**.

**F2. 원시 앵커와 후보 앵커**

The candidate_anchor formula is defined as:

`c_raw = (piece_left − board_x) / s`, `r_raw = (piece_top − board_y) / s`, `candidate = (floor(r_raw + 0.5), floor(c_raw + 0.5))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| piece_left, piece_top | float | F1 | calculated | 끌리는 조각 좌상단 |
| board_x, board_y | float | 캔버스 좌표 | calculated (레이아웃) | 판 좌상단 |
| s | float | F1 | calculated | 칸 크기 |
| r_raw, c_raw | float | 제한 없음 (판 밖 가능) | calculated | 실수 앵커 |

**Output Range:** 정수 쌍, 판 밖 포함. 유효 범위 `r0 ∈ [0, H − h]`, `c0 ∈ [0, W − w]` (board-rules F1) 밖이면 `can_place = false`.
`floor(x + 0.5)`로 고정 — 정확히 .5에서 항상 큰 쪽(음수 포함)으로 가므로 플랫폼·엔진 `round()` 구현 차이와 무관하다.
**Example:** F1 예에 board (16, 300) → c_raw = (203.5 − 16)/131 = 1.431 → **1**, r_raw = (559.4 − 300)/131 = 1.980 → **2**. 후보 (2, 1).

**F3. 스냅 히스테리시스**

The snapped_anchor formula is defined as (축마다 독립, 현재 앵커 `a`가 있을 때):

`a_axis' = a_axis if |raw_axis − a_axis| ≤ 0.5 + Hy else floor(raw_axis + 0.5)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| a_axis | int | 판 밖 포함 | calculated (직전 후보) | 현재 앵커의 행 또는 열 |
| raw_axis | float | F2 | calculated | 원시 앵커의 같은 축 |
| Hy | float | 0 ~ 0.25 | data file (`snap_hysteresis_cells`) | 히스테리시스 폭(칸) |

**Output Range:** 앵커가 바뀌려면 경계(.5)를 Hy만큼 넘어야 한다 → 칸 사이 "끈적한 띠" 폭 = 2 × Hy = 0.24칸 ≈ 31px@1080.
첫 후보(직전 앵커 없음)는 F2 그대로. `PRESSED → DRAGGING` 전이 프레임이 첫 후보다.
**Example:** a_c = 1, Hy = 0.12. c_raw = 1.55 → |0.55| ≤ 0.62 → **1 유지**. c_raw = 1.63 → 0.63 > 0.62 → floor(2.13) = **2**.
되돌아올 때 c_raw = 1.40 → |−0.60| ≤ 0.62 → **2 유지**, 1.37 → **1**.

**F4. 드래그 시작 슬롭**

The drag_start formula is defined as:

`start_drag ⇔ distance(p, p0) ≥ drag_slop_px × k`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| p0, p | Vector2 | 캔버스 좌표 | calculated | 누른 점, 현재 점 |
| drag_slop_px | float | 12 ~ 32 px@1080 | data file | 슬롭 |
| k | float | > 0 | calculated (F5) | 기준 px → 캔버스 배율 |

**Output Range:** 720 폭 캔버스(프로젝트 기본 720×1280)에서 20 × 0.667 = **13.3** 캔버스 단위. 한 번 넘으면 다시 `PRESSED`로 돌아가지 않는다.
**Example:** 누름 (300, 1100), 현재 (308, 1090) → 거리 12.8 < 13.3 → 아직 `PRESSED`. (310, 1088) → 15.6 → `DRAGGING`.

**F5. 기준 px 배율**

The ref_px_scale formula is defined as:

`k = canvas_width / 1080`, `canvas_px = px@1080 × k`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| canvas_width | float | 720 (프로젝트 기본) | calculated (플랫폼 & 화면) | 세로 캔버스 논리 폭 |
| px@1080 | float | 값마다 | data file | 1080 폭 기준 길이 |

**Output Range:** 캔버스 폭 720 → k = 0.667. 기기 해상도가 아니라 **캔버스 논리 폭** 기준이다 (stretch 모드가 기기 배율을 처리).
**Example:** 그림자 8 px@1080 → 5.3 캔버스 단위.

**F6. 트레이 히트 영역과 조각 축소 검증**

The tray_fit formula is defined as:

`slot_w = tray_w / N_tray`, `fits_slot ⇔ tray_piece_scale × w × s ≤ slot_w − 2m  ∧  tray_piece_scale × h × s ≤ tray_h − 2m`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tray_w, tray_h | float | 1080 폭: ≈ 1048 × 445 | calculated (레이아웃) | 트레이 영역 |
| N_tray | int | 3 | data file (트레이 공급 GDD) | 트레이 칸 수 |
| tray_piece_scale | float | 0.5 ~ 0.85 | data file | 트레이 축소 비율 |
| w, h, s | — | F1 | — | 조각 크기·칸 크기 |
| m | float | 12 px@1080 | constant | 칸 안 여백 |

**Output Range:** 1080 폭에서 slot_w ≈ 349 ≥ 64 (히트 영역 기준 충족). 0.72 배율에서 조각 폭 ≤ 3칸(283px), 높이 ≤ 4칸(377px)이 들어간다.
`fits_slot = false`인 조각(예: 1×4 가로 막대)은 그 조각만 들어갈 때까지 트레이 배율을 줄인다 (`min(scale, (slot_w − 2m)/(w·s))`); 히트 영역은 그대로.
**Example:** 2×3 곰곰 조각: 0.72 × 3 × 131 = 283 ≤ 325, 0.72 × 2 × 131 = 189 ≤ 421 → 들어감.

**F7. 미리보기 재계산 횟수**

The preview_requests formula is defined as:

`preview_requests(drag) = count of frames where valid_anchor_t ≠ valid_anchor_(t−1) ∧ valid_anchor_t ≠ null`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| valid_anchor_t | (int,int) \| null | board-rules F1 범위 | calculated | 프레임 t의 유효 앵커 (무효면 null) |

**Output Range:** 프레임당 ≤ 1회. 한 앵커에 머무는 동안 0회. 무효 → 무효 이동 0회. 히스테리시스로 경계 떨림 중 0회.
`anchor_changed(null)`(지우기)은 재계산이 아니라 세지 않는다. 비용 상한은 chain-resolver F8 (앵커 변경 1회 = `can_place` + `resolve` 1회).
**Example:** 판 위로 끌어 (2,1) → (2,2) → 겹침(무효) → (3,2) → 떼기: 재계산 3회, 지우기 1회.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E는 lean에서 생략). Review manually before production.

- **If 트레이를 탭만 하고 떼면** (슬롭 안): 조각이 들렸다가 되돌아간다. 들어 올린 조각이 판 아래 줄 위치에 겹쳐 그려져도 `PRESSED`라
  앵커가 없어 배치되지 않는다 (규칙 8). 흔들림·"통" SFX 없음 — 탭은 실수가 아니다.
- **If 판 맨 아래 줄에 놓으려 하면**: 손가락은 판 아래(트레이 영역 위, F1에서 판 아래 변 + 0.6칸)에 있게 된다. 정상 동작이다 —
  판정은 손가락이 아니라 **조각 위치**로 한다. 그래서 "손가락이 트레이 위면 취소" 규칙은 없다 (규칙 17).
- **If 판 맨 위 줄에 놓으려 하면**: 조각이 HUD 위로 겹쳐 그려진다. 끌리는 조각은 최상위 레이어이고, HUD는 드래그 중 터치를 받지 않는다.
  손가락은 판 위쪽 변에서 `(h + 0.6)`칸 아래에 있으므로 화면 밖으로 나가지 않는다 (h ≤ 판 높이).
- **If 후보 앵커가 판 밖이면** (조각 일부가 반 칸 넘게 걸침): 무효 — 고스트 없음, 조각 회색 톤. 클램프하지 않는다 (규칙 9, D4).
- **If 후보 앵커가 정확히 .5 경계면**: F2 `floor(x + 0.5)` → 큰 쪽. 직전 앵커가 있으면 F3 히스테리시스가 먼저 적용되어 유지된다.
- **If 손가락이 칸 경계에서 떨리면**: F3 히스테리시스 띠(0.24칸) 안의 떨림은 앵커를 바꾸지 않아 미리보기 재계산 0회.
- **If 떼는 프레임에 포인터가 다른 칸으로 미끄러지면**: 무시 — 놓을 앵커는 마지막 이동 이벤트의 앵커다 (규칙 14).
- **If 이동 이벤트 없이 바로 떼면** (눌렀다 바로 뗌, 또는 슬롭 직후 첫 이동이 곧 떼기): 마지막으로 확정된 앵커가 없으면 되돌림.
  슬롭을 넘긴 이동 이벤트가 있었다면 그 이벤트의 앵커가 마지막 앵커다.
- **If 어디에도 놓을 수 없는 조각을 집으면** (`any_fit = false`): 집기·끌기는 되지만 고스트는 끝내 뜨지 않고 떼면 되돌아간다.
  트레이에서 그 조각을 흐리게 표시하는 것은 트레이/HUD 표시 소관 (프로토타입: 35% 불투명). 막힘 판정은 판 진행 흐름 소관.
- **If 드래그 중 두 번째 손가락이 닿거나 떨어지면**: 무시 (규칙 18). 두 번째 손가락으로 다른 조각을 집을 수 없다.
- **If 소유 포인터가 OS에 의해 취소되면** (알림 끌어내림, 제스처 내비게이션): 강제 취소 → 되돌림 (규칙 19b). 배치되지 않는다.
- **If 드래그 중 앱이 백그라운드로 가면**: 강제 취소 (규칙 19a). 복귀했을 때 조각은 트레이에 있고 입력은 `READY`(판 흐름이 잠그지 않았다면).
- **If 드래그 중 Android 뒤로 가기를 누르면**: 드래그만 취소되고 뒤로 가기는 소비된다 (규칙 19c). 다음 뒤로 가기는 평소대로 화면 흐름으로.
- **If 되돌림 연출 중에 다시 누르면**: 연출을 즉시 끝내고(조각이 트레이 칸에 도착한 상태) 새 집기를 시작한다 (규칙 16). 같은 조각이든
  다른 조각이든 같다. 다른 칸을 눌렀다면 되돌아가던 조각은 자기 칸에 즉시 놓인다.
- **If 유효 놓기 후 판 진행 흐름이 `can_place` 재확인에 실패하면**: 프로그래밍 오류(드래그 중 보드 불변 규칙 20 위반). 개발 빌드는 assert,
  출시 빌드는 되돌림으로 복구하고 오류를 기록한다. 배치·턴 소모 없음.
- **If 입력이 `LOCKED`인 동안 트레이를 누르면** (연쇄 연출 중): 무시. 연출 스킵 탭은 연출 재생기·판 진행 흐름 소관이며 입력 시스템은 그
  터치를 소비하지 않는다.
- **If 판 진행 흐름이 드래그 중 입력을 끄면** (일시정지 등): 강제 취소 (규칙 19d) 후 `LOCKED`.
- **If 조각이 트레이 칸에 들어가지 않을 만큼 크면** (폭 4칸 이상 등): F6에 따라 그 조각만 더 작게 그린다. 히트 영역은 칸 사각형 그대로.
  들어 올리면 판 크기(`s`)로 커진다.
- **If 화면이 작아 칸 크기가 64 px@1080 미만이 되면**: board-rules UI Requirements가 최소 칸 크기를 보장한다 — 이 시스템은 계산을 바꾸지
  않는다 (모든 값이 칸 단위이거나 F5 배율).
- **If 마우스로 조작하면** (에디터·데스크톱): 터치 흉내로 같은 경로. 오른쪽·가운데 버튼은 무시, 휠 무시. 마우스 커서가 창 밖으로 나가 버튼을
  떼면 OS가 주는 떼기 이벤트로 처리하고, 이벤트가 오지 않으면 포커스 잃음(규칙 19a)으로 취소된다.

## Dependencies

| 시스템 | 종류 | 이 문서가 받는 것 | 이 문서가 주는 것 |
|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | **Hard** (upstream) | 앵커 정의(규칙 6), `can_place`(F2), 앵커 범위(F1), 칸 크기 최소값(UI Req) | 언제 `can_place`를 묻는가 (후보 앵커 변경 시 1회) |
| 판 진행 흐름 (`round-flow.md`, 미작성) | **Hard** (downstream — 판 흐름이 이 시스템에 의존) | 호출로 주입받음: `set_input_enabled(bool)`, 현재 보드·트레이 스냅샷 | `placement_requested(slot, anchor)`, `drag_ended` |
| 트레이 공급 (`tray-supply.md`, 미작성) | 데이터 계약 (의존 아님) | 판 흐름이 넘겨주는 트레이 스냅샷(칸별 조각 인스턴스 \| 빈 칸, `N_tray`)의 **형식** | — (조각 소비는 하지 않음) |
| 연쇄 미리보기 (`chain-preview.md`, 미작성) | **Hard** (downstream) | — | `anchor_changed(piece_ref, anchor\|null)`, `drag_ended(reason)` |
| 연쇄 해석기 (`chain-resolver.md`) | 간접 (미리보기 경유) | 규칙 25 "앵커 변경 시에만 재계산", F8 비용 | 재계산 트리거 계약 이행 (F7) |
| 플랫폼 & 화면 (`platform-display.md`, 미작성) | Soft (upstream) | 캔버스·세이프 영역·레이아웃 사각형, 포커스·뒤로 가기 알림 | — |
| 화면 흐름 & 내비게이션 (`scene-flow.md`, 미작성) | Soft | — | 드래그 중 뒤로 가기 소비 |
| 오디오 SFX (`audio.md`, 미작성) | Soft (downstream) | — | 집기·무효 놓기 SFX 큐 |
| 연쇄 연출 재생기 (`chain-presentation.md`, 미작성) | Soft | — | 붙는 연출의 시작 위치(고스트 자리) |
| 설정 & 접근성 (`settings-accessibility.md`, VS) | Soft (upstream) | `lift_offset_cells` 사용자값, 모션 줄이기, 진동 | — |
| 튜토리얼 & 힌트 (VS) | Soft (downstream) | — | 드래그 상태 신호 (첫 드래그 안내용) |

**양방향성**: systems-index #7 Depends On = 보드 & 조각 규칙 — board-rules Dependencies에 `placement-input.md`가 Hard로 이미 있음(일치).
systems-index #8 연쇄 미리보기 Depends On에 이 시스템이 있음(일치). **순환 차단**: 입력 ↔ 판 진행 흐름은 서로 신호를 주고받지만,
의존 방향은 **판 흐름 → 입력** 하나로 고정한다 — 입력은 `set_input_enabled`와 보드·트레이 스냅샷을 *주입받는* API를 소유하고
판 흐름을 모른다 (트레이 공급이 조각 풀을 입력 목록으로 받는 것과 같은 패턴). 그래서 systems-index #7 Depends On(보드 & 조각 규칙만)은
그대로 맞다. **누락**: 판 진행 흐름 #11 Depends On에 드래그 & 배치 입력이 없다 — Open Question Q1 (systems-index 갱신 제안).
chain-resolver Interactions 표에 이미 "드래그 & 배치 입력 → 미리보기 → 해석기"가 있음(일치).

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Category `Core`라 이 섹션은 선택이지만 드래그 시각 피드백이 핵심이라 작성.
> Agent 도구 없음. Review manually before production. 미리보기 표시(지워질 칸·번호·예상 알)는 연쇄 미리보기 GDD 소관.

| 요소 | 요구 사항 | 근거 |
|---|---|---|
| 들어 올린 조각 | 트레이 크기 → 판 크기로 확대(`lift_anim_s`), **접지 그림자 1–2px → 6–10px**(`drag_shadow_px` 8), 우하단 방향. 그림자는 미리 블러한 실루엣 스프라이트의 오프셋·불투명도만 변경 | art bible 원칙 3 "그림자 높이가 곧 상태", AD 검토(그림자 구현) |
| 트레이 빈 자리 | 집은 조각의 칸에 옅은 "스티커 자리" 윤곽이 남아 어디로 돌아갈지 보인다 | 되돌림 예측 가능성 |
| 고스트 (유효 앵커) | 판 위 앵커 자리에 반투명(시작값 35%) 조각, 낮은 그림자 없음 — "아직 안 붙음". 무효면 고스트 없음 | 프로토타입, 브리프 "ghost only when valid" |
| 끌리는 조각 (무효 위치) | 채도·명도를 낮춘 부드러운 회색 톤 (빨강 금지). 그림자 높이는 유지 | board-rules V/A "붉은 경고 대신 부드러운 회색 + 살짝 흔들림", 기둥 5 |
| 무효 놓기 | 판 위였다면 작은 좌우 흔들림(`invalid_wiggle_s`) 후 트레이로 ease-out 되돌림, 도착하며 그림자 1–2px로 내려앉음 | board-rules V/A·Game Feel |
| 유효 놓기 | 조각이 고스트 자리로 붙으며 그림자 0→1px "꾹". 이후 붙는 연출·연쇄 연출은 연출 재생기 | art bible 원칙 3 |
| 오디오 | 집기: 종이 "슥"(짧게). 유효 앵커 진입: 아주 작은 "톡" 틱 (선택, 기본 on — 소리 없이도 고스트로 읽힘). 무효 놓기: 부드러운 "통". 붙기 "착"은 보드 표시/오디오 GDD | board-rules V/A 오디오 행, 컨셉 Audio Needs |
| 진동 (Android) | 유효 놓기 시 짧은 진동 1회(≈10ms, 설정에서 끄기). 앵커 변경마다 진동은 하지 않는다 (피로) | 터치 확정감 |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:placement-input`
to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

| 목표 | 기준 | 소유 |
|---|---|---|
| 집기 반응 | 누른 프레임에 조각이 떠오르기 시작 (입력 → 첫 표시 ≤ 1프레임, 60fps 16.7ms). 확대 `lift_anim_s` 0.08s | 이 문서 |
| 따라옴 | 끌리는 조각은 매 프레임 마지막 포인터 위치에 그린다 — 스무딩·지연 보간 없음 (손에 붙은 느낌) | 이 문서 |
| 스냅 반응 | 앵커가 바뀐 그 프레임에 고스트·회색 톤 갱신 (≤ 1프레임). 미리보기 갱신은 같은 프레임 목표 (chain-resolver F8 비용) | 이 문서 (트리거) / 미리보기 GDD (표시) |
| 경계 안정 | 경계 떨림으로 고스트가 깜빡이지 않음 (F3 히스테리시스 0.24칸 띠) | 이 문서 |
| 보인 대로 놓임 | 놓인 위치 = 떼기 직전 고스트 위치 100% (규칙 14) | 이 문서 |
| 무효 되돌림 | 0.12~0.18s ease-out, 다음 집기를 막지 않음 | 이 문서 (board-rules Game Feel 위임) |
| 압박 없음 | 드래그에 시간 제한·자동 놓기 없음. 손가락을 판 위에 오래 두어도 아무 일도 일어나지 않는다 | 안티 기둥 "시간 압박 아님" |

## UI Requirements

- **트레이 칸 히트 영역** ≥ 64 × 64 px@1080 (실제 ≈ 349 × 445, F6). 조각이 작아도 칸 사각형 전체가 히트 영역.
- 트레이는 판 바로 아래(프로토타입: 판 아래 0.2칸 간격). 판 아래 줄 놓기 때 손가락이 트레이 위에 오므로 트레이 칸은 드래그 중 터치를 받지 않는다.
- 끌리는 조각은 HUD·판·트레이 위 최상위 레이어. 드래그 중 HUD 버튼(일시정지 등)은 눌리지 않는다 (소유 포인터만 처리; 다른 손가락은 무시 — 규칙 18).
- 세이프 영역(노치·제스처 바) 안에서만 트레이를 배치 — 시스템 제스처 영역 근처에서 집기가 OS 제스처로 취소되는 일을 줄인다 (플랫폼 & 화면 GDD).
- 텍스트 없음 (현지화 문자열 없음).
- **접근성 (MVP)**: 한 손가락·한 번의 연속 동작만 요구, 동시 터치·길게 누르기·시간 제한 없음; 유효/무효는 색이 아니라 고스트 유무로 구분(색약 대응);
  실수 놓기에 벌 없음. **접근성 (VS, 설정 & 접근성 GDD로 넘김)**: `lift_offset_cells` 사용자 조절(0.4~1.0), 모션 줄이기(확대·흔들림·되돌림 애니 0),
  진동 끄기, **탭-탭 배치 대안**(조각 탭으로 선택 → 판 칸 탭으로 앵커 지정 → 다시 탭으로 확정 — 드래그가 어려운 사용자용, Q3).

> **📌 UX Flag — 드래그 & 배치 입력**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the
> gameplay screen (board + tray + HUD — shared with board-rules' flag) and the interaction pattern "drag sticker to board" in `design/ux/interaction-patterns.md`
> **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 이 문서가 참조하는 것 | 대상 문서 | 종류 | 상태 |
|---|---|---|---|
| 앵커 = 바운딩 박스 좌상단(규칙 6), `can_place`(F2), 앵커 범위(F1), 칸 ≈ 130px·최소 64px | `design/gdd/board-rules.md` § Core Rules 6–7, Formulas F1–F2, UI Requirements | 상위 계약 | 일치 |
| 무효 상태 "부드러운 회색 + 살짝 흔들림", 되돌림 0.12~0.18s, 스냅 ≤ 1프레임 | `design/gdd/board-rules.md` § Visual/Audio, Game Feel | 상위 계약 | 일치 — 회색은 끌리는 조각에, 흔들림은 무효 놓기 순간에 둔다 (고스트는 유효할 때만이므로 "회색 고스트"는 두지 않음, D5) |
| 미리보기는 앵커가 바뀔 때만 `resolve` 재호출, 무효 앵커에선 부르지 않음 (규칙 25, AC-16, F8) | `design/gdd/chain-resolver.md` | 상위 계약 | 일치 (F7) |
| 드래그 조각 손가락 위 0.6칸, 가로 중앙, 반올림 스냅, 고스트는 유효할 때만, 무효 놓기 = 트레이로 | `prototypes/sticker-place-concept/prototype.html` (`snapFor`, pointer 핸들러) | 검증된 시작값 | 일치 + 추가(슬롭·히스테리시스·마지막 앵커 놓기 — 프로토타입에 없던 실수 방지) |
| 터치 대상 ≥ 약 64px @1080, 드래그 중 그림자 6–10px + 약간 확대 | `design/art/art-bible.md` § 원칙 3, UI 문법 | 시각 규칙 | 일치 |
| 세로 화면, 터치 주 입력, 마우스는 터치 흉내 | `project.yaml` § platform, `.claude/docs/technical-preferences.md` § Input & Platform | 플랫폼 | 일치. *주의*: technical-preferences의 "swipe to swap, tap crew icon", "60s timer"는 피벗 전 매치-3 안의 잔재 — Q4 |
| 시간 압박 없음, 다정한 세계 | `design/gdd/game-concept.md` § Pillars, Anti-Pillars | 기둥 | 일치 |
| 트레이 칸 수 3, 조각 인스턴스 형식 | `design/gdd/tray-supply.md` (미작성), board-rules 규칙 5 | 데이터 계약 | provisional |
| 미리보기 표시·캐시, `anchor_changed` 구독 | `design/gdd/chain-preview.md` (미작성) | 하위 계약 | provisional |
| 입력 on/off 타이밍, 권위 `can_place` 재확인, 배치 커밋 | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| 세이프 영역·레이아웃 사각형·뒤로 가기 | `design/gdd/platform-display.md`, `design/gdd/scene-flow.md` (미작성) | 상위/측면 계약 | provisional |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — lean에서 Section H는 spawn 대상이지만 Agent 도구가 없어 생략. Review manually before production.
> 상태 머신·스냅 계산은 포인터 이벤트를 주입하는 **Logic** 단위 테스트(`tests/unit/placement_input/`), 시각 항목은 **UI/Visual** 증거
> (`production/qa/evidence/` 스크린샷)로 검증한다. 픽셀 값은 1080 폭 기준 레이아웃 고정 픽스처(s = 131, board (16, 300))를 쓴다.

- **AC-01 (규칙 5–6, 집기)** — **GIVEN** `READY`, 트레이 칸 1에 조각, **WHEN** 칸 1 사각형 안(조각 픽셀 밖 여백 포함)을 누르면,
  **THEN** 상태 `PRESSED`, 끌리는 조각이 그 프레임에 표시되고 트레이 칸 1에는 빈 자리 윤곽만 남는다. 빈 칸·판 위 누름은 상태를 바꾸지 않는다.
- **AC-02 (규칙 8·F4, 탭은 배치 아님)** — **GIVEN** 판 아래 줄 위치에 들어 올린 조각이 겹쳐 그려지는 레이아웃, **WHEN** 누른 뒤 12 px@1080 이내만
  움직이고 떼면, **THEN** `placement_requested`는 0회, `drag_ended(RETURNED)` 1회, 조각은 트레이로 돌아간다.
- **AC-03 (F1·F2, 스냅)** — **GIVEN** 픽스처, 2×3 조각, **WHEN** 슬롭을 넘긴 뒤 손가락이 (400, 900)이면, **THEN** 조각 좌상단 (203.5, 559.4), 후보 앵커 (2, 1).
- **AC-04 (F2, .5 경계)** — **GIVEN** 직전 앵커 없음, **WHEN** c_raw = 2.5, r_raw = −0.5이면, **THEN** 후보 = (0, 3) (`floor(x + 0.5)`).
- **AC-05 (규칙 10·F3, 히스테리시스)** — **GIVEN** 현재 앵커 열 1, Hy = 0.12, **WHEN** c_raw가 1.55 → 1.63 → 1.40 → 1.37 순으로 바뀌면,
  **THEN** 앵커 열은 1 → 2 → 2 → 1.
- **AC-06 (규칙 12, 고스트는 유효할 때만)** — **GIVEN** 판 (3,3)이 차 있음, 1×1 조각, **WHEN** 후보 앵커가 (3,2) → (3,3) → (8,0)이면,
  **THEN** 고스트는 (3,2)에서만 보이고 (3,3)·(8,0)에서는 없으며 끌리는 조각이 회색 톤이다. (UI 증거: 유효·무효 각 스크린샷 1장)
- **AC-07 (규칙 13·F7, 미리보기 트리거)** — **GIVEN** 드래그 중, **WHEN** 같은 유효 앵커에서 60프레임 이동(히스테리시스 안)하면, **THEN** `anchor_changed` 0회.
  **AND WHEN** 유효 (2,1) → (2,2) → 무효 → 무효(다른 칸) → (3,2)로 움직이면, **THEN** `anchor_changed(앵커)` 3회, `anchor_changed(null)` 1회. (chain-resolver AC-16과 공동)
- **AC-08 (규칙 11, can_place 호출 수)** — **GIVEN** 드래그 중, **WHEN** 후보 앵커가 5번 바뀌고 각 앵커에 여러 프레임 머물면, **THEN** `can_place` 호출은 정확히 5회.
- **AC-09 (규칙 14, 보인 대로 놓임)** — **GIVEN** 마지막 이동 이벤트 앵커 (4,4) 유효, **WHEN** 떼기 이벤트 좌표가 (4,5)에 해당하면, **THEN** `placement_requested(slot, (4,4))`.
- **AC-10 (규칙 15, 유효 놓기)** — **GIVEN** 유효 앵커, **WHEN** 떼면, **THEN** `placement_requested` 정확히 1회, `drag_ended(COMMITTED)` 1회, 상태 `LOCKED`,
  `set_input_enabled(true)` 전까지 트레이 누름 무시.
- **AC-11 (규칙 16, 무효 놓기 무벌)** — **GIVEN** 무효 앵커(판 위 겹침), 남은 조각 수 N·점수 S, **WHEN** 떼면, **THEN** `placement_requested` 0회,
  조각은 `return_anim_s` ± 1프레임 안에 원래 칸에 도착, N·S·보드·트레이 불변, 흔들림 1회와 "통" SFX 큐 1회.
- **AC-12 (규칙 16, 되돌림 중 집기)** — **GIVEN** 칸 0 조각이 되돌아가는 중, **WHEN** 칸 2를 누르면, **THEN** 칸 0 조각은 그 프레임에 칸 0에 놓이고 칸 2가 `PRESSED`.
- **AC-13 (규칙 18, 멀티터치)** — **GIVEN** 포인터 0으로 드래그 중, **WHEN** 포인터 1이 다른 트레이 칸을 누르고 움직이고 떼면, **THEN** 상태·앵커·신호 변화 없음.
  **AND WHEN** 포인터 0을 유효 앵커에서 떼면, **THEN** 정상 배치 요청 1회.
- **AC-14 (규칙 19, 강제 취소)** — **GIVEN** 유효 앵커에서 `DRAGGING`, **WHEN** (a) 앱 포커스 잃음 (b) 터치 취소 (c) 뒤로 가기 (d) `set_input_enabled(false)` 중 하나가 오면,
  **THEN** 각각 `placement_requested` 0회, `drag_ended(CANCELLED)` 1회, 조각은 트레이로. (c)에서는 화면 흐름이 뒤로 가기를 받지 않는다.
- **AC-15 (규칙 3, 마우스)** — **GIVEN** 에디터 데스크톱 실행 (`commands.run`), **WHEN** 마우스 왼쪽 버튼으로 같은 드래그를 하면, **THEN** AC-03·AC-10과 같은 결과이고
  신호가 두 번 나지 않는다. 오른쪽 버튼은 무시.
- **AC-16 (F6·UI, 히트 영역)** — **GIVEN** 720×1280 캔버스, **WHEN** 트레이 칸 사각형을 측정하면, **THEN** 각 칸 ≥ 64 px@1080 (≥ 42.7 캔버스 단위) 양 변. 폭 4칸 조각은 칸 안에 들어가게 축소된다.
- **AC-17 (Game Feel, 반응)** — **GIVEN** T0 그레이박스 Android 실기기, **WHEN** 집기·앵커 변경을 고속 카메라 또는 프레임 로그로 측정하면, **THEN** 입력 → 끌리는 조각 표시,
  앵커 변경 → 고스트 갱신이 각각 ≤ 1프레임 (60fps). 미리보기 포함 앵커 변경 프레임 시간 ≤ 16.7ms (chain-resolver AC 성능 기준과 공동).
- **AC-18 (V/A, 그림자)** — **GIVEN** 실행 중 화면, **WHEN** 조각을 들어 올리면, **THEN** 스크린샷에서 그림자 오프셋이 6–10 px@1080이고 트레이 정지 조각은 1–2px. (UI/Visual 증거)

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | systems-index #11 판 진행 흐름 Depends On에 드래그 & 배치 입력 추가 (판 흐름이 입력 API를 호출·구독) | producer · `/map-systems` | `/design-system round-flow` 전 |
| Q2 | `lift_offset_cells` 0.6이 실제 Android 화면(작은 폰 ~5.5″)에서 충분한가, 엄지 vs 검지에서 차이 — 0.8로 올릴지 | ux-designer | T0 그레이박스 플레이테스트 |
| Q3 | 탭-탭 배치 대안(접근성)을 VS 설정에 넣을지, MVP 상태 머신에 미리 자리(`SELECTED` 상태)를 둘지 | ux-designer · accessibility-specialist | `/design-system settings-accessibility` |
| Q4 | `.claude/docs/technical-preferences.md` Primary Input 문구("swipe to swap, tap crew icon to fire skill", "pause the 60s timer")가 피벗 전 매치-3 안 — "drag piece from tray to board"로 갱신 필요 | technical-director · `/setup-engine` 또는 수동 | 다음 설정 정리 때 |
| Q5 | 유효 앵커 진입 "톡" 틱 SFX가 드래그 중 너무 잦아 거슬리지 않는가 (히스테리시스로 줄었지만) — 기본 on/off | sound-designer · 오디오 GDD | `/design-system audio` + T0 |
| Q6 | 구현: 입력 노드 위치(`_unhandled_input` vs 트레이 Control `_gui_input`), `emulate_touch_from_mouse`/`emulate_mouse_from_touch` 조합, 4.6 이중 포커스 영향 | gameplay-programmer · technical-director | ADR (입력 처리) |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성·프레이밍 (standard tier) | Summary·Overview(Both)·Detailed Design·Formulas(슬롭·오프셋·히스테리시스 등 숫자 규칙 있음)·Edge Cases·Dependencies·AC + Cross-References(의존 있음) + Visual/Audio·Game Feel·UI Requirements·Open Questions ("All of them" 권장안 — UI 표면·플레이어 피드백 있음). Player Fantasy·Tuning Knobs 생략 | Framing `[A]`(Core 권장값) — 플레이어가 직접 만지는 손맛이라 기각; Tuning Knobs 섹션 — tier 위반, 값 표는 Core Rules F |
| D2 | 손가락 오프셋 | 가로 중앙, 아래 변이 손가락 0.6칸 위 (프로토타입) | 잡은 지점 유지(조각을 잡은 상대 위치 그대로) — 손가락이 조각을 가림; 대각선 오프셋 — 손잡이 방향마다 다름 |
| D3 | 드래그 시작 | 즉시 들어 올림 + 20px 슬롭 넘어야 앵커 계산 | 슬롭 없음(프로토타입) — 트레이 탭이 판 아래 줄 배치가 됨; 길게 누르기 후 집기 — 느리고 접근성 나쁨 |
| D4 | 스냅 | `floor(x + 0.5)` 반올림, 클램프·최근접 유효 앵커 탐색 없음 | 최근접 유효 앵커로 끌어당김 — 고스트가 손과 다른 곳에 떠 의도를 숨기고, 미리보기 트리거가 예측 불가 |
| D5 | 무효 표시 | 고스트 없음 + 끌리는 조각 회색 톤 + 무효 놓기 시 흔들림 | 회색 고스트 표시 (board-rules V/A 문구의 다른 해석) — 브리프·프로토타입 "고스트는 유효할 때만"과 충돌, 유효/무효가 색으로만 구분됨 |
| D6 | 경계 떨림 | 히스테리시스 0.12칸 | 없음 — 미리보기 깜빡임·재계산 폭증; 시간 디바운스 — 반응 지연(Game Feel ≤ 1프레임 위반) |
| D7 | 놓을 앵커 | 마지막 이동 이벤트의 앵커 ("보인 대로") | 떼기 좌표 재계산 — 손 떼는 순간 미끄러짐으로 고스트와 다른 자리 |
| D8 | 취소 | 유효 자리 없이 떼기 = 취소, 별도 취소 영역 없음 | 트레이 위 손가락 = 취소 — 판 아래 줄 배치와 충돌; 취소 버튼 — 두 손 필요 |
| D9 | 멀티터치 | 첫 포인터 소유, 나머지 무시 | 두 번째 손가락 = 취소 — 의도치 않은 손바닥 접촉에 취약; 두 조각 동시 — 배치는 한 번에 하나(board-rules) |
| D10 | 되돌림 중 입력 | 막지 않음 (새 누름이 연출을 즉시 완료) | 연출 끝까지 잠금 — "한 판 더" 템포 저해 |
| D11 | 의존 방향 | 판 흐름 → 입력 (입력은 API 소유, 보드·트레이 주입) | 입력이 판 흐름·트레이에 의존 — Core가 Feature에 의존하는 역방향·순환 |
| D12 | 놓을 수 없는 조각 | 집기 허용, 고스트 없음 | 집기 금지 — "왜 안 집히지?" 혼란, 판 둘러보기 불가 |
