# 보드 & 조각 규칙 (Board & Piece Rules)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 3 보이는 연쇄 (결정적 공유 규칙) · 기둥 1 도미노의 손맛 (연쇄의 바탕) · 기둥 4 한 판 더 (분명한 실패 판정)

## Summary

8×8 퍼즐 판의 칸 상태, 회전 없는 조각 모양(조각마다 얼굴 1칸, 튜토리얼 예외), 그리고 배치 가능·줄 완성·칸 비우기/채우기·
"놓을 곳 없음"을 판정하는 순수 결정적 함수들을 정의한다. 플레이어에게는 "어디에 붙일 수 있고 무엇이 줄을 채우며 언제 판이
막히는가"라는 판의 법칙이고, 연쇄 해석기·미리보기·입력·트레이·방해물·스테이지가 모두 이 한 벌의 규칙을 호출하기 때문에
미리보기가 실제 결과와 일치할 수 있다 (기둥 3).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (upstream) — downstream: 연쇄 해석기, 크루 정의, 트레이 공급, 드래그 & 배치 입력, 칸 종류 & 방해물, 스테이지 & 목표, 판 진행 흐름

## Overview

보드 & 조각 규칙은 말랑 크루의 퍼즐 판 그 자체를 정의한다. 데이터 층에서는 8×8 칸 격자의 칸 상태,
조각 모양 데이터(회전 없음), 조각마다 정확히 한 칸인 얼굴 칸, 그리고 이 상태를 읽는 순수 판정 함수들 —
배치 가능 판정, 가로·세로 줄 완성 판정, 칸 비우기·채우기 원시 연산, "놓을 곳 없음" 판정 — 을 소유한다.
플레이어 쪽에서 보면 이 시스템은 "어디에 붙일 수 있고, 무엇이 줄을 채우며, 언제 판이 막혔는가"라는
판의 물리 법칙이다. 플레이어는 이 규칙을 직접 조작하지 않지만 매 배치마다 그 결과를 읽고 계획한다.
연쇄 해석기, 연쇄 미리보기, 트레이 공급, 입력, 방해물, 스테이지가 모두 **같은 함수**를 호출하므로
(기둥 3 보이는 연쇄 — "미리보기와 실제 결과가 다르면 버그"), 이 시스템이 결정적이지 않거나 두 벌로
구현되면 미리보기가 거짓말을 하게 된다. 연쇄 순서, 점수, 트레이 뽑기, 드래그 입력은 이 시스템의 경계
밖이다 — 이 문서는 그 시스템들이 부를 규칙과 원시 연산만 정한다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing; Layer
`Foundation`과 충돌 시 Category 우선) · ADR ref `[B] No` (`docs/architecture/adr-*.md` 없음) ·
Fantasy `[B] No` (Foundation layer; standard tier라 Player Fantasy 섹션 자체도 생략).
구현 방식(순수 함수 모듈의 형태, 보드 복제 방식)은 → ADR 대상 (연쇄 해석기 critical ADR과 함께).

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` (systems-index의 지정 에이전트) not consulted —
> Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**보드**

1. **격자** — 보드는 `board_width` × `board_height` 칸 격자다 (시작값 8×8, 데이터). 좌표는 `(row, col)`,
   `(0, 0)`이 좌상단, row는 아래로, col은 오른쪽으로 증가한다. MVP에서 보드 크기는 전역 데이터 값 하나이며
   스테이지별로 바꾸지 않는다 (Decision Log D3).
2. **칸 = 칸 종류 + 내용물** — 모든 칸은 정확히 하나의 칸 종류를 가진다. 보드 규칙은 칸 종류의 *이름*이
   아니라 아래 세 **규칙 플래그**만 읽는다. 그래서 방해물 GDD가 새 칸 종류를 추가해도 이 문서의 함수는
   바뀌지 않는다 (systems-index의 순환 차단 계약: "칸 종류 열거형과 훅 지점은 보드 규칙/해석기가 정의").

   | 칸 종류 | `blocks_placement` | `counts_for_line` | `removable_by_clear` | 내용물 |
   |---|---|---|---|---|
   | `EMPTY` | false | false | — | 없음 |
   | `TILE` (조각 칸) | true | true | true | `crew_id`(nullable), `is_face`, `origin`(`PIECE` \| `EGG`), `placement_id`, `modifiers[]` |
   | *(방해물 GDD가 추가)* | 데이터 | 데이터 | 데이터 | 방해물 GDD 정의 |

   - `TILE.origin = EGG`는 능력(예: 삐약)이 만든 알 칸이다. 알은 `is_face = false`이며 줄 판정에서 일반 조각
     칸과 똑같이 취급된다 (알이 줄을 채워 연쇄를 다시 점화할 수 있다 — 컨셉 Core Mechanics 2).
   - `modifiers[]`는 보드 규칙이 **해석하지 않고 보존만 하는** 슬롯이다 (예: 방해물 GDD의 "얼어붙은 얼굴").
     의미는 방해물 GDD와 연쇄 해석기 GDD가 정한다.
   - `placement_id`는 몇 번째 배치에서 온 칸인지 기록한다 (연출·디버그용; 규칙 판정에는 쓰지 않는다).

**조각**

3. **조각 모양 (PieceShape, 데이터)** — 오프셋 `(dr, dc)` 목록. 유효 조건:
   (a) 칸 수 1 ~ `max_piece_cells` (시작값 6 — 프로토타입 최대 모양 2×3),
   (b) 중복 오프셋 없음,
   (c) 정규화: `min(dr) = 0`, `min(dc) = 0`,
   (d) 4방향 연결(상하좌우로 이어진 한 덩어리) — `require_connected_shapes` (시작값 true, Decision Log D4),
   (e) 바운딩 박스 `h × w`가 보드보다 크지 않음.
   모양의 소유·목록(어느 크루가 어떤 모양을 갖는가)은 크루 정의 GDD가 정한다. 이 문서는 모양 *형식*과 유효성만 정한다.
4. **회전·뒤집기 없음** — 조각은 데이터에 적힌 방향 그대로만 놓인다. 다른 방향이 필요하면 별도 모양으로
   정의한다 (프로토타입의 가로 3칸 / 세로 3칸이 각각 별도 모양인 것과 같다).
5. **조각 인스턴스** — 트레이에 들어가는 실체 = `shape` + `crew_id` + `face_index`.
   - **얼굴 칸은 정확히 1칸**: `face_index ∈ [0, 칸 수 − 1]`.
   - **예외 — 얼굴 없는 조각**: `face_index = null`, `crew_id`는 null 허용. 스테이지 데이터가
     `allow_faceless_pieces = true`를 지정한 스테이지(튜토리얼 1-1 등)에서만 유효하다. 그 밖의 스테이지에서
     얼굴 없는 인스턴스는 데이터 오류다.
   - 얼굴 위치 결정: 모양 데이터에 `face_cell`(고정 인덱스)이 있으면 그 값, 없으면 트레이 공급이 시드 RNG로
     고른다 (프로토타입은 무작위). 보드 규칙은 결정 방식을 소유하지 않고 결과의 유효성만 검사한다 (D5).

**배치**

6. **앵커** — 앵커 `(r0, c0)`는 모양 오프셋 `(0, 0)`이 놓이는 보드 좌표(바운딩 박스 좌상단)다. 각 칸의 목표
   좌표는 `(r0 + dr, c0 + dc)`. 손가락 위치 → 앵커 변환은 드래그 & 배치 입력 GDD 소관이다.
7. **배치 가능 판정 `can_place(board, piece, anchor)`** — 모든 목표 칸이 보드 안이고, 그 칸의 칸 종류가
   `blocks_placement = false`일 때만 참. 부분 배치, 보드 밖 걸침, 겹치기는 없다.
8. **배치 적용 `place(board, piece, anchor)`** — 새 보드를 반환한다. 각 목표 칸은
   `TILE(origin = PIECE, crew_id, is_face = (i == face_index), placement_id)`이 된다. 입력 보드는 바뀌지 않는다.
   전제 조건은 `can_place = true`이며, 위반은 게임플레이가 아니라 프로그래밍 오류(assert)다.
   배치 직후 줄 판정 → 지우기 → 얼굴 발동 → … 의 순서는 연쇄 해석기가 정한다.

**줄**

9. **줄 완성 판정 `full_lines(board)`** — 가로 줄 r이 완성 ⇔ 그 줄의 모든 칸이 `counts_for_line = true`.
   세로 줄도 같다. 반환값 = 완성된 행 번호 목록(오름차순) + 열 번호 목록(오름차순), **행이 먼저**. 이 순서는
   고정이다 — 해석기·미리보기가 같은 순서를 본다.
10. **줄 칸 집합 `line_cells(lines)`** — 완성 줄들의 칸 합집합. 행·열 교차 칸은 한 번만 들어간다. 정렬은
    row-major (row 오름차순, 같은 row에서 col 오름차순).
11. **칸 비우기 원시 연산 `clear_cells(board, cells)`** — 주어진 칸 중 `removable_by_clear = true`인 칸만
    `EMPTY`로 바꾼 새 보드와, 실제로 비워진 칸 목록(각 칸의 `is_face`, `crew_id`, `origin` 포함, row-major)을
    반환한다. 비워진 얼굴 칸을 어떻게 발동시킬지, 같은 단계 얼굴들의 처리 순서는 연쇄 해석기 GDD가 정한다.
    이미 `EMPTY`인 칸과 `removable_by_clear = false`인 칸은 조용히 건너뛴다 (능력 범위가 빈칸을 덮는 것은 정상).
12. **칸 채우기 원시 연산 `fill_cells(board, cells, tile)`** — 지정한 칸을 주어진 `TILE`(예: 알)로 채운 새
    보드를 반환한다. 대상 칸은 반드시 `blocks_placement = false`(비어 있음)여야 하며, 위반은 assert다.
    어느 칸을 고를지(삐약: 더 꽉 찬 줄의 빈칸, 얼굴에 가까운 순)는 연쇄 해석기/크루 정의 GDD 소관이다.
    선택을 돕는 조회 함수 `line_fill_count`(F5)와 `empty_cells_in_line`은 이 문서가 제공한다.
13. **안정 보드 불변식** — 플레이어가 다음 조각을 놓을 수 있는 시점(해석기 종료 후)의 보드에는 완성 줄이
    없다. 해석기는 완성 줄이 없어질 때까지 줄 지우기를 계속하거나, 깊이 상한에 도달해도 남은 완성 줄을
    마저 지운다는 규칙을 해석기 GDD에서 보장해야 한다 (provisional 계약 — 해석기 GDD에서 확정).
    스테이지 초기 보드도 이 불변식을 만족해야 한다 (규칙 16).

**막힘 판정**

14. **`any_fit(board, piece)`** — 어떤 앵커에서든 `can_place`가 참이면 참. 앵커는 row-major 순서로 훑고 첫
    성공에서 멈춘다 (결과는 순서와 무관하지만 비용·디버그를 위해 고정).
15. **`no_moves(board, pieces)`** — `pieces`(트레이에 **아직 남은** 조각)가 비어 있지 않고, 모든 조각이
    `any_fit = false`일 때만 참. 빈 목록이면 거짓이다 — 빈 트레이는 "막힘"이 아니라 "재충전 대기"다.
    *언제* 호출하는지는 판 진행 흐름 소관이며, 이 문서의 제안 계약은 "해석기 종료 후, 트레이 재충전이
    끝난 뒤의 트레이로 평가"다 (프로토타입 동작과 같음; provisional).
    **실패 조건 두 가지 중 이 시스템은 "놓을 곳 없음"만 판정한다.** "제한 조각 수 소진 + 목표 미달성"은
    스테이지 & 목표 GDD가 판정한다.

**스테이지 초기 보드**

16. **초기 보드 검증 `validate_board(board)`** — 스테이지 데이터가 미리 깐 조각·알·방해물로 시작하는 보드는
    로드 시 검증한다: 크기 일치, 모든 칸 종류가 등록됨, 완성 줄 0개(불변식 13), `TILE`의 `is_face` 칸은
    `crew_id`가 있음. 실패 시 스테이지 로드 오류(개발 중 에러 표시, 출시 빌드에는 검증된 데이터만 포함).

**결정성**

17. 모든 함수는 순수 함수다: 랜덤 없음, 시간·프레임 무관, 입력 보드를 바꾸지 않음, 같은 입력 → 같은 출력과
    같은 순서. 보드 규칙은 RNG를 쓰지 않는다. 연쇄 해석기, 연쇄 미리보기, 자동 플레이 테스트가 **같은 한 벌의
    구현**을 호출한다 (구현 형태 → ADR).

**데이터 기반 값** (standard tier라 Tuning Knobs 섹션은 생략 — 값의 범위와 근거는 여기와 Formulas 변수표에 둔다)

| 값 | 시작값 | 안전 범위 | 소유 | 근거 · 너무 크거나 작으면 |
|---|---|---|---|---|
| `board_width` / `board_height` | 8 / 8 | 7 ~ 10 | 이 문서 (전역 데이터) | 프로토타입 검증값·장르 관례. 작으면 막힘이 잦아 판이 짧아지고, 크면 줄 하나 채우기가 느려져 연쇄가 드물어진다. 바꾸면 모든 스테이지 데이터를 다시 검증해야 한다 |
| `max_piece_cells` | 6 | 1 ~ 9 | 이 문서 | 프로토타입 최대 모양(곰곰 2×3). 크면 막힘 판정이 급격히 늘고, 작으면 크루 모양 개성이 줄어든다 (기둥 2) |
| `require_connected_shapes` | true | true / false | 이 문서 | 떨어진 칸 조각은 "스티커 한 장" 은유를 깨고 읽기 어렵다 (D4) |
| `allow_faceless_pieces` | false | 스테이지별 bool | 스테이지 & 목표 (스테이지 데이터) | 튜토리얼 전용 예외 |
| 칸 종류별 규칙 플래그 3종 | 위 표 | bool | 이 문서 (`EMPTY`, `TILE`) · 방해물 GDD (그 외) | 새 칸 종류를 코드 수정 없이 추가하기 위함 |
| *(참조)* 트레이 칸 수 | 3 | — | 트레이 공급 GDD | 이 문서는 소유하지 않는다; `no_moves`는 개수와 무관하게 동작한다 |

### States and Transitions

보드 규칙 자체는 상태를 들고 있지 않다 (보드 값을 받아 새 보드 값을 돌려줄 뿐). 상태 전이는 **칸 단위**로 정의한다.

| 현재 칸 | 연산 | 다음 칸 | 호출 주체 | 조건 |
|---|---|---|---|---|
| `EMPTY` | `place` | `TILE(origin=PIECE)` | 판 진행 흐름 → 해석기 진입 직전 | `can_place` 참 |
| `EMPTY` | `fill_cells` | `TILE(origin=EGG)` 등 | 연쇄 해석기 (능력) | 대상이 비어 있음 |
| `TILE` | `clear_cells` (줄 지우기·능력 범위) | `EMPTY` | 연쇄 해석기 | `removable_by_clear` 참 |
| `TILE` | `place` / `fill_cells` | — (불가) | — | assert |
| 방해물 칸 | 각 연산 | 방해물 GDD 정의 | 해석기 훅 | 플래그에 따름 |

보드 전체 관점의 두 시점(규칙 13·15에서 사용):

| 보드 시점 | 의미 | 다음 |
|---|---|---|
| **안정 (Stable)** | 완성 줄 0개, 플레이어 입력 대기 | 배치 → 해결 중 |
| **해결 중 (Resolving)** | 해석기가 줄 판정·지우기·채우기를 반복 중. 입력·막힘 판정 금지 | 해석기 종료 → 안정 (→ 막힘 판정) |

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 | 해석기 → 보드 규칙 호출 | `full_lines`, `line_cells`, `clear_cells`(비워진 칸 + 얼굴 정보), `fill_cells`, `line_fill_count`, `empty_cells_in_line` | 보드 규칙 (함수 계약) / 해석기 (호출 순서) |
| 연쇄 미리보기 | 미리보기 → 해석기 → 보드 규칙 | 보드 사본 + 가상 배치. 보드 규칙을 직접 다시 구현하지 않는다 | 해석기 |
| 드래그 & 배치 입력 | 입력 → 보드 규칙 | 앵커 후보에 대한 `can_place` (스냅 표시용) | 보드 규칙 |
| 트레이 공급 | 트레이 → 보드 규칙 | 조각 인스턴스(모양·crew_id·face_index) 유효성 검사; 막힘 판정에 남은 조각 목록 제공 | 보드 규칙 (형식) / 트레이 (선택) |
| 크루 정의 & 능력 | 크루 → 보드 규칙 | 크루별 모양 목록, 선택적 `face_cell` | 보드 규칙 (모양 형식) / 크루 정의 (목록) |
| 칸 종류 & 방해물 | 방해물 → 보드 규칙 | 새 칸 종류 + 규칙 플래그 3종, `modifiers` 의미 | 보드 규칙 (플래그 스키마) / 방해물 (값) |
| 스테이지 & 목표 | 스테이지 → 보드 규칙 | 초기 보드(`validate_board`), `allow_faceless_pieces`; 제한 조각 수 실패는 스테이지가 판정 | 스테이지 |
| 판 진행 흐름 | 판 흐름 → 보드 규칙 | `place` 호출, 해석기 종료·재충전 후 `no_moves` 호출 → 실패 처리 | 판 진행 흐름 (타이밍) |
| 점수 & 연쇄 배율 | 간접 (해석기 이벤트 경유) | 지워진 칸 수·줄 수 (F4) | 점수 GDD |
| 연쇄 연출 재생기 / 플레이 HUD | 간접 (해석기 이벤트 경유) | 칸 상태 표시만, 규칙 판정 안 함 | 각 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는
> Agent 도구가 없어 생략. Review manually before production. 이 시스템의 식은 균형 곡선이 아니라 판정·계수
> 식이며, 시작값은 모두 프로토타입 검증값이다.

**F1. 앵커 범위**

The anchor_count formula is defined as:

`anchor_count = max(0, H − h + 1) × max(0, W − w + 1)`, 유효 앵커 `r0 ∈ [0, H − h]`, `c0 ∈ [0, W − w]`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| H | int | 7–10 (시작 8) | data file (`board_height`) | 보드 행 수 |
| W | int | 7–10 (시작 8) | data file (`board_width`) | 보드 열 수 |
| h | int | 1–`max_piece_cells` | calculated (`max(dr) + 1`) | 조각 바운딩 박스 높이 |
| w | int | 1–`max_piece_cells` | calculated (`max(dc) + 1`) | 조각 바운딩 박스 너비 |

**Output Range:** 1 ~ 64 (8×8, 1칸 조각이면 64). h > H 또는 w > W면 0 — 모양 검증(규칙 3e)이 이를 막는다.
**Example:** 8×8 보드, 곰곰 2×3 조각 → (8 − 2 + 1) × (8 − 3 + 1) = 7 × 6 = **42**개 앵커.

**F2. 배치 가능 판정**

The can_place formula is defined as:

`can_place(P, r0, c0) = ∀ (dr, dc) ∈ P : 0 ≤ r0+dr < H ∧ 0 ≤ c0+dc < W ∧ ¬blocks_placement(cell(r0+dr, c0+dc))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| P | 오프셋 목록 | 1–`max_piece_cells`칸 | data file (크루 정의의 모양) | 조각 모양 |
| r0, c0 | int | F1 범위 (범위 밖이면 거짓) | calculated (입력 GDD의 앵커) | 앵커 |
| blocks_placement | bool | — | data file (칸 종류 플래그) | 칸이 배치를 막는가 |

**Output Range:** bool. **Example:** 빈 보드에 냥이 ㄴ자 `[(0,0),(1,0),(1,1)]`을 (7, 0)에 → (8,0)이 보드 밖 → **거짓**; (6, 0)에 → **참**.

**F3. 줄 완성**

The line_full formula is defined as:

`row_full(r) = ∀ c ∈ [0, W) : counts_for_line(cell(r, c))`, `col_full(c) = ∀ r ∈ [0, H) : counts_for_line(cell(r, c))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| counts_for_line | bool | — | data file (칸 종류 플래그) | 칸이 줄을 채운 것으로 치는가 (`TILE`·알 = 참) |
| R | int | 0–H | calculated | 완성 행 수 |
| C | int | 0–W | calculated | 완성 열 수 |

**Output Range:** 한 번의 배치 직후(안정 보드에서 출발) `R ≤ h`, `C ≤ w` — 새로 놓인 칸이 지나는 줄만 새로 찰 수 있다.
능력의 `fill_cells` 직후에는 `R ≤ H`, `C ≤ W`. **Example:** 7번 행에 7칸이 차 있고 빈 (7, 3)에 1칸 조각 → R = 1, 같은 3번 열도 7칸 차 있었다면 C = 1.

**F4. 줄 지우기 칸 수** (점수 GDD의 입력)

The line_cell_count formula is defined as:

`line_cell_count = W × R + H × C − R × C`; 실제 비워지는 수 `cleared = line_cell_count − kept`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| R, C | int | F3 | calculated | 완성 행·열 수 |
| W, H | int | 7–10 | data file | 보드 크기 |
| kept | int | 0 ~ line_cell_count | calculated | 줄 칸 중 `removable_by_clear = false`인 칸 수 (MVP 기본 칸 종류에서는 0) |

**Output Range:** 0 ~ W × H (R = H이면 판 전체 64). 일반 플레이 8 ~ 22.
**Example:** R = 1, C = 1 → 8 + 8 − 1 = **15**칸. R = 2, C = 1 → 16 + 8 − 2 = **22**칸.
점수 환산(칸당 점수, 연쇄 배율)은 점수 & 연쇄 배율 GDD 소관이다.

**F5. 줄 채움 수** (능력 범위 선택용 조회)

The line_fill_count formula is defined as:

`line_fill_count(line) = |{ cell ∈ line : counts_for_line(cell) }|`, `empty_cells_in_line(line) = { cell ∈ line : ¬blocks_placement(cell) }` (row-major)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| line | 행 r 또는 열 c | 0–H−1 / 0–W−1 | calculated (능력 얼굴 위치) | 조회할 줄 |

**Output Range:** 0 ~ W (행) / 0 ~ H (열). 안정 보드에서는 최대 W − 1 (불변식 13).
**Example:** 삐약 얼굴이 (3, 5)에서 지워졌을 때 3번 행 6칸, 5번 열 4칸이 차 있으면 6 > 4 → 해석기는 3번 행의 빈칸
2개에 알을 둔다 (이 선택 규칙 자체는 크루 정의/해석기 GDD 소관; 보드 규칙은 6과 4를 돌려줄 뿐).

**F6. 막힘 판정 비용** (성능 예산의 근거)

The no_moves_cost formula is defined as:

`cell_reads_max = Σ_{p ∈ pieces} anchor_count(p) × n_p`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| pieces | 목록 | 1–3개 (트레이 칸 수) | calculated (트레이 공급) | 아직 남은 트레이 조각 |
| n_p | int | 1–`max_piece_cells` | calculated | 조각 p의 칸 수 |

**Output Range:** 최악 3 × 64 × 6 → 실제로는 큰 조각일수록 앵커가 줄어 ≈ 3 × 42 × 6 = **756**회 칸 읽기 (8×8, 6칸).
`max_piece_cells`를 9, 보드를 10×10으로 올려도 수천 회 수준 — 매 배치 1회 호출에 충분히 작다 (AC-15 예산).
**Example:** 남은 조각 2개(3칸 직선 가로 1×3, 1칸) → 1×3: 8 × 6 × 3 = 144, 1칸: 64 × 1 = 64 → 최대 208회.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 배치 한 번으로 가로·세로 줄이 동시에 완성되면**: `full_lines`는 둘 다 반환하고(행 먼저), `line_cells`는 교차 칸을
  한 번만 담는다 (F4: 15칸, 16칸 아님). 동시 완성은 한 번의 지우기 단계다 — 단계 구분은 해석기 소관.
- **If 조각의 일부 칸만 보드 안에 들어가면**: `can_place` 거짓. 부분 배치나 "밀어 넣기"는 없다.
- **If 남은 트레이 조각이 0개(3개 모두 놓아 재충전 대기)이면**: `no_moves`는 거짓 — 막힘이 아니다. 재충전 후 다시 평가한다.
- **If 남은 조각 중 하나라도 놓을 곳이 있으면**: `no_moves` 거짓. 나머지 조각이 하나도 안 들어가도 실패가 아니다 (프로토타입과 같음).
- **If 마지막 배치가 줄을 지워 공간이 생기면**: 막힘 판정은 해석기 종료 *후* 보드로 하므로 실패하지 않는다. 해결 중 보드로 판정하지 않는다.
- **If 마지막 배치로 트레이가 비어 재충전되었고 새 조각 3개가 모두 안 들어가면**: 재충전된 트레이로 `no_moves` 참 → 실패.
  재충전 조각을 놓을 수 있도록 고르는 보정이 있는지는 트레이 공급 GDD 소관 (Open Question Q3).
- **If 같은 배치에서 "놓을 곳 없음"과 "목표 달성"이 함께 성립하면**: 목표 달성이 우선한다 (판 진행 흐름 GDD로의 provisional 계약 —
  플레이어가 이룬 것을 실패로 덮지 않는다, 기둥 5).
- **If 제한 조각 수가 0이 되었는데 보드에 놓을 곳이 있으면**: 이 시스템은 실패를 판정하지 않는다. 스테이지 & 목표가 판정한다.
- **If 알 채우기(`fill_cells`) 대상에 이미 칸이 있으면**: assert (프로그래밍 오류). 해석기는 `empty_cells_in_line`에서만 고른다.
- **If 능력 범위(`clear_cells`)가 빈칸이나 지울 수 없는 칸을 덮으면**: 그 칸은 건너뛰고 오류가 아니다. 반환 목록에는 실제로 비워진 칸만 있다.
- **If 알이 줄을 완성하면**: 알은 `counts_for_line = true`라 일반 조각 칸처럼 줄을 완성한다. 지워질 때 얼굴이 아니므로 능력은 없다.
- **If 얼굴 없는 조각(튜토리얼)이 줄로 지워지면**: 일반 칸처럼 지워지고 발동은 없다. `allow_faceless_pieces = false`인 스테이지에서 이런
  조각이 공급되면 데이터 오류로 로드를 막는다.
- **If 모양 데이터가 무효(빈 목록, 중복 오프셋, 비정규화, 떨어진 칸, `max_piece_cells` 초과, 보드보다 큼, `face_cell` 범위 밖)이면**:
  데이터 로드 시 거부하고 어떤 모양인지 명시한 오류를 낸다. 런타임 중 자동 보정(정규화 등)은 하지 않는다 — 데이터가 곧 진실.
- **If 스테이지 초기 보드에 완성 줄이 있으면**: `validate_board` 실패로 스테이지 로드 거부 (시작하자마자 무료 연쇄가 터지는 것을 막는다).
- **If 보드가 꽉 차서(64칸) 빈칸이 0이면**: 안정 보드 불변식상 불가능하다 (꽉 찬 보드는 모든 줄이 완성). 발생하면 해석기 버그다.
- **If 방해물 칸이 `counts_for_line = true`, `removable_by_clear = false`이면**: 그 칸은 줄을 채우는 데 기여하지만 줄이 지워져도 남는다
  (F4의 `kept`). 그 결과 줄이 지워진 직후에도 해당 칸은 차 있다. 구체 칸 종류는 방해물 GDD가 정한다.
- **If 한 앵커에서 여러 조각을 동시에 놓으려 하면**: 불가능 — 배치는 한 번에 한 조각, `place`는 조각 하나를 받는다.

## Dependencies

**Upstream (이 시스템이 의존)**: 없음. 보드 규칙은 Foundation 최하단이며 RNG도 쓰지 않는다.

**Downstream (이 시스템에 의존)** — 모두 아직 GDD 없음. 아래 인터페이스는 이 문서가 제안하는 계약이며,
각 GDD 작성 시 확인한다 (provisional).

| 시스템 | 강도 | 이 문서에서 쓰는 것 | 이 문서가 기대하는 것 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 (`chain-resolver.md`) | Hard | `full_lines`, `line_cells`, `clear_cells`, `fill_cells`, `line_fill_count`, `empty_cells_in_line` | 해석기 종료 시 완성 줄 0개 보장 (불변식 13); 얼굴 발동 순서 정의 |
| 크루 정의 & 능력 (`crew-definition.md`) | Hard | 조각 모양 형식(규칙 3), `face_cell` | 모든 크루 모양이 규칙 3을 만족 |
| 트레이 공급 (`tray-supply.md`) | Hard | 조각 인스턴스 형식(규칙 5), `no_moves` 입력 목록 | 트레이 칸 수·재충전 규칙 소유; `face_index` 결정 |
| 드래그 & 배치 입력 (`placement-input.md`) | Hard | 앵커(규칙 6), `can_place` | 손가락 → 앵커 변환 소유 |
| 연쇄 미리보기 (`chain-preview.md`) | Hard (해석기 경유) | 보드 사본 + `place` | 보드 규칙을 재구현하지 않음 |
| 칸 종류 & 방해물 (`obstacles.md`) | Hard | 칸 종류 플래그 스키마(규칙 2), `modifiers` 슬롯 | 새 칸 종류는 플래그 3종으로만 규칙에 영향 |
| 스테이지 & 목표 (`stage-goals.md`) | Hard | `validate_board`, `allow_faceless_pieces` | 제한 조각 수 실패 판정 소유 |
| 판 진행 흐름 (`round-flow.md`) | Hard | `place`, `no_moves` | 호출 타이밍(해석기 종료·재충전 후), 목표 달성 우선 |
| 점수 & 연쇄 배율 (`scoring.md`) | Soft | F4 칸 수·줄 수 (해석기 이벤트 경유) | 칸당 점수·배율 소유 |
| 무한 모드 (Full Vision) | Soft | 보드 규칙 전체 | — |

**양방향성**: systems-index의 Depends On 열에서 해석기·크루 정의·트레이·입력·방해물·스테이지·무한 모드는 이 시스템을
직접 의존으로 적고 있어 일치한다. 미리보기·점수는 해석기를 경유하는 간접 의존이라 index에 없는 것이 맞다.
**불일치 1건**: 판 진행 흐름은 `place`·`no_moves`를 직접 호출하지만 index의 Depends On에 "보드 & 조각 규칙"이 없다 →
판 진행 흐름 GDD 작성 시(또는 `/map-systems` 갱신 시) 추가 필요 (Open Question Q6).
각 하위 GDD는 Dependencies에 이 문서를 upstream으로 적어야 한다.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — lean에서는 시각 피드백이 핵심인 Gameplay 시스템이라 spawn 대상이지만
> 이 실행에는 Agent 도구가 없어 생략. Art bible 미작성. Review manually before production.
> 이 문서는 **보드·칸 상태가 무엇을 읽히게 해야 하는가**만 정한다. 연쇄 연출(떼어짐·컷인·파티클)은 연쇄 연출 재생기 GDD,
> 미리보기 표시(지워질 칸·발동 순서 번호·예상 알)는 연쇄 미리보기 GDD 소관.

| 요소 | 요구 사항 | 근거 |
|---|---|---|
| 보드 바탕 | 따뜻한 저채도 크라프트지 판, 빈칸은 옅은 "스티커 자리" 홈. 조각이 항상 판보다 먼저 보인다 | 컨셉 색 철학 |
| 조각 칸 (`TILE`, PIECE) | 크루 색 + 구운 흰 테두리 스티커. 같은 `placement_id` 칸끼리 테두리가 이어져 "한 장"으로 보인다 | 비주얼 규칙 "모든 것은 오려 붙인 스티커" |
| 얼굴 칸 | 몸통 칸보다 크게, 반짝이는 테두리(은은한 맥동). **판 위 모든 얼굴을 1초 안에 찾을 수 있어야** 한다. 색만으로 구분하지 않는다(크루별 얼굴 실루엣) | 지원 원칙 2, 프로토타입 교훈 "얼굴=스위치"가 범례로는 안 읽힘, 색약 대응 |
| 알 칸 (`TILE`, EGG) | 조각 칸과 실루엣이 확연히 다름(둥근 알 + 점무늬). 얼굴 반짝임 없음 — 스위치가 아님이 보여야 함 | 기둥 3 |
| 얼굴 없는 조각 (튜토리얼) | 크루 색 없이 중립색 스티커 — 얼굴 칸과 혼동 없음 | 1-1 온보딩 |
| 방해물 칸 | 방해물 GDD 정의. 단, 조각·알과 실루엣으로 구분되어야 한다 | — |
| 배치 가능 고스트 | 스냅된 앵커 위에 반투명 조각. 불가 상태는 붉은 경고 대신 부드러운 회색 + 살짝 흔들림 (다정한 세계) | 기둥 5 |
| 오디오 | 배치 성공 "착" 붙는 SFX, 배치 불가 놓기 시 부드러운 "통" 되돌림 SFX, 막힘 시 "꽉 찼다" 귀여운 신호. 실제 사운드 명세·지연 대응은 오디오 GDD | 기둥 5, 컨셉 Audio Needs |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:board-rules`
to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

| 목표 | 기준 | 소유 |
|---|---|---|
| 스냅 반응 | 앵커가 바뀐 그 프레임에 고스트·`can_place` 결과 갱신 (≤ 1프레임, 60fps 기준 16.7ms) | 입력 GDD (트리거), 이 문서 (판정 비용 F6·AC-15) |
| 붙는 느낌 | 놓기 → 조각 칸이 판에 나타나기까지 ≤ 1프레임; 이후 0.1~0.15s "꾹 눌러 붙는" 스케일 연출 | 연출 재생기 (연출), 이 문서 (`place` 즉시 반환) |
| 불가 놓기 | 판정 즉시 트레이 칸으로 되돌림, 0.12~0.18s ease-out (튜닝 값) | 입력 GDD |
| 막힘 인지 | 해석기 종료 직후 판정 → 실패 연출 시작까지 지연 없음 (프로토타입은 0.9s 후 결과 — 연출 시간은 판 진행 흐름 소관) | 판 진행 흐름 |
| 결정성 체감 | 같은 판 같은 배치는 언제나 같은 결과 — 미리보기와 결과가 다르면 버그 | 이 문서 규칙 17 |

턴 기반이라 시간 압박 피드백(타이머·카운트다운)은 없다 (안티 기둥 "시간 압박 아님").

## UI Requirements

- 세로 화면에서 보드는 화면 폭 − 좌우 여백 16px(최소)을 차지하는 정사각형. 칸 크기 = (보드 폭) / `board_width`.
  1080px 폭 기준 칸 ≈ 130px — 칸은 직접 탭 대상이 아니라 드래그 목적지라 64px 터치 타깃 규칙의 대상은 아니지만,
  최소 칸 크기는 64px 이상을 유지한다 (작은 화면에서 얼굴 판독성).
- 보드는 HUD(목표·남은 조각·점수)와 트레이 사이에 둔다. 드래그 중 손가락이 조각을 가리지 않도록 하는 오프셋은 입력 GDD 소관.
- 세이프 영역·노치 처리는 플랫폼 & 화면 GDD를 따른다.
- 보드 규칙 자체는 텍스트를 표시하지 않는다 (현지화 문자열 없음).

> **📌 UX Flag — 보드 & 조각 규칙**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create
> a UX spec for the gameplay screen (board + tray + HUD layout) **before** writing epics. Stories that reference UI should cite
> `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 이 문서가 참조하는 것 | 대상 문서 | 종류 | 상태 |
|---|---|---|---|
| 배치 보드 8×8, 트레이 3개, 회전 없음, 실패 조건 2종 | `design/gdd/game-concept.md` § Core Mechanics 1 | 규칙 출처 | 일치 |
| 얼굴 1칸/조각, 얼굴 없는 튜토리얼 조각, 알이 줄을 채움 | `design/gdd/game-concept.md` § Core Mechanics 2 | 규칙 출처 | 일치 |
| 판정 함수 형태 (`fits`, `anyFit`, `fullLines`, `lineCells`), 모양 목록, 최대 6칸 | `prototypes/sticker-place-concept/prototype.html`, `REPORT.md` | 검증된 시작값 | 일치 (프로토타입은 throwaway — 코드 재사용 금지) |
| 칸 종류 열거형·훅 지점 소유, 순환 차단 계약 | `design/gdd/systems-index.md` § Circular Dependencies | 경계 | 일치 |
| 줄 지우기 → 얼굴 발동 순서, 깊이 상한 6, 불변식 13 보장 | `design/gdd/chain-resolver.md` (미작성) | 하위 계약 | provisional |
| 크루 모양 목록, `face_cell` | `design/gdd/crew-definition.md` (미작성) | 하위 계약 | provisional |
| 트레이 칸 수 3, 재충전, `face_index` 선택 | `design/gdd/tray-supply.md` (미작성) | 하위 계약 | provisional |
| 앵커 변환, 스냅 트리거 | `design/gdd/placement-input.md` (미작성) | 하위 계약 | provisional |
| 칸 종류 추가, `modifiers` 의미 | `design/gdd/obstacles.md` (미작성) | 하위 계약 | provisional |
| 초기 보드, `allow_faceless_pieces`, 제한 조각 수 실패 | `design/gdd/stage-goals.md` (미작성) | 하위 계약 | provisional |
| `no_moves` 호출 타이밍, 목표 달성 우선 | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| 칸당 점수 (F4 입력) | `design/gdd/scoring.md` (미작성) | 하위 계약 | provisional |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. Story type: **Logic** → 자동 단위 테스트 `tests/unit/board_rules/` (BLOCKING).
> 픽스처는 보드 문자열 팩토리(예: `"........"` 8행, `#` = 조각 칸, `F` = 얼굴, `E` = 알)로 만들고 인라인 매직 넘버를 쓰지 않는다.

**규칙 (Section C)**

- **AC-01 (규칙 1, 데이터)** — **GIVEN** 데이터 `board_width = 8`, `board_height = 8`, **WHEN** 빈 보드를 만들면,
  **THEN** 64칸 모두 `EMPTY`이고 데이터를 7×9로 바꾸면 코드 수정 없이 63칸 보드가 만들어진다.
- **AC-02 (규칙 3, 모양 검증)** — **GIVEN** 빈 목록·중복 오프셋·`min(dr) ≠ 0`·떨어진 두 칸·7칸(`max_piece_cells = 6`)·9×1 모양 각각,
  **WHEN** 모양 데이터를 로드하면, **THEN** 6개 모두 거부되고 오류에 모양 id와 위반 조건이 적힌다. 프로토타입의 15개 모양은 모두 통과한다.
- **AC-03 (규칙 4, 회전 없음)** — **GIVEN** 가로 1×3 모양만 가진 조각, **WHEN** 세로로만 3칸 비어 있는 보드에서 `any_fit`을 부르면, **THEN** 거짓.
- **AC-04 (규칙 5, 얼굴 1칸)** — **GIVEN** `face_index`가 null인 조각 인스턴스, **WHEN** `allow_faceless_pieces = false` 스테이지에서
  검증하면 **THEN** 거부되고, `true` 스테이지에서는 **THEN** 통과한다. `face_index = 칸 수`인 인스턴스는 항상 거부된다.
- **AC-05 (규칙 7, 배치 판정)** — **GIVEN** 빈 8×8 보드와 ㄴ자 `[(0,0),(1,0),(1,1)]`, **WHEN** 앵커 (6,0), (7,0), (6,7)로 `can_place`,
  **THEN** 참, 거짓, 거짓. **AND** (6,0)의 한 칸에 `TILE`이 있으면 거짓.
- **AC-06 (규칙 8, 배치 적용·순수성)** — **GIVEN** 보드 B와 얼굴 인덱스 2인 3칸 조각, **WHEN** `place(B, piece, (0,0))`,
  **THEN** 반환 보드의 3칸이 `TILE(PIECE)`이고 정확히 오프셋 2의 칸만 `is_face = true`이며, **AND** B는 호출 전과 칸 단위로 같다.
- **AC-07 (규칙 9·10, 줄 판정·합집합)** — **GIVEN** 7번 행과 3번 열이 (7,3)만 빠진 보드, **WHEN** 1칸 조각을 (7,3)에 놓고 `full_lines`·`line_cells`,
  **THEN** 행 [7], 열 [3] 순서로 반환되고 칸 집합은 15칸(F4), row-major로 정렬된다.
- **AC-08 (규칙 11, 비우기)** — **GIVEN** 얼굴 칸 1개를 포함한 완성 행, **WHEN** `clear_cells`, **THEN** 8칸이 `EMPTY`가 되고 반환 목록에
  `is_face = true`인 칸이 정확히 1개, `crew_id`가 그 조각의 크루다. **AND** 빈칸을 포함한 범위를 넘겨도 오류 없이 실제 비워진 칸만 반환된다.
- **AC-09 (규칙 12, 채우기)** — **GIVEN** 빈칸 2개를 가진 행, **WHEN** 그 2칸에 알을 `fill_cells`, **THEN** 두 칸이 `TILE(EGG, is_face=false)`이고
  그 행이 `full_lines`에 나타난다. **AND** 차 있는 칸을 대상으로 넘기면 debug 빌드에서 assert가 발생한다.
- **AC-10 (규칙 15, 막힘)** — **GIVEN** 체크무늬로 빈칸이 떨어져 있는 보드와 남은 조각 [1×2, 2×2], **WHEN** `no_moves`, **THEN** 참.
  **AND** 남은 조각에 1칸 조각을 추가하면 거짓. **AND** 빈 목록이면 거짓.
- **AC-11 (규칙 16, 초기 보드)** — **GIVEN** 행 0이 꽉 찬 스테이지 초기 보드 데이터, **WHEN** 스테이지를 로드하면, **THEN** 로드가 거부되고 오류에 행 번호가 적힌다.
- **AC-12 (규칙 2, 칸 종류 플래그)** — **GIVEN** 테스트용 칸 종류 `TEST_STONE (blocks=true, counts=true, removable=false)`를 데이터로만 등록,
  **WHEN** 그 칸을 포함한 행이 완성되어 `clear_cells`, **THEN** 그 칸만 남고 7칸이 비워진다 — 보드 규칙 코드 변경 없음.
- **AC-13 (규칙 17, 결정성)** — **GIVEN** 고정 보드·조각 픽스처 100개, **WHEN** 모든 함수를 두 번씩 호출하면, **THEN** 결과와 반환 순서가 바이트 단위로 같다.
  (해석기 단계: 미리보기 예측 = 실제 결과 테스트는 연쇄 해석기 GDD의 AC.)

**공식 (Section D)**

- **AC-14 (F1·F4·F5)** — **GIVEN** 8×8 보드, **WHEN** 2×3 조각의 `anchor_count`, R=2·C=1의 `line_cell_count`, 6칸 찬 행의 `line_fill_count`를 계산하면,
  **THEN** 42, 22, 6.
- **AC-15 (F6, 성능 예산)** — **GIVEN** 빈칸 10개가 흩어진 최악 근사 보드와 6칸 조각 3개, **WHEN** headless 데스크톱에서 `no_moves`를 1,000회 반복하면,
  **THEN** 평균 ≤ 0.2ms/회. 저가 Android 실기기 측정은 T0 그레이박스에서 (목표: 매 앵커 변경 `can_place` + 미리보기 합계가 프레임 예산 안).

**시스템 간 (provisional — 하위 GDD 작성 시 확정)**

- **AC-16 (판 진행 흐름)** — **GIVEN** 마지막 트레이 조각으로 줄을 지운 직후, **WHEN** 해석기가 끝나고 트레이가 재충전되면,
  **THEN** `no_moves`는 재충전된 3조각으로 정확히 1회 평가된다 (해결 중에는 0회).
- **AC-17 (스테이지 & 목표)** — **GIVEN** 같은 배치에서 목표 달성과 `no_moves = true`가 함께 성립, **WHEN** 판이 끝나면, **THEN** 결과는 클리어다.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 깊이 상한 도달 시 남은 완성 줄을 어떻게 처리하나 (불변식 13 보장 방식) | systems-designer · 연쇄 해석기 GDD | `/design-system chain-resolver` |
| Q2 | 얼굴 위치: 모양별 고정(`face_cell`) vs 트레이 무작위 — 크루 개성(기둥 2)과 계획성(기둥 3) 중 무엇에 무게를 두나 | game-designer · 크루 정의 / 트레이 공급 GDD | `/design-system crew-definition` |
| Q3 | 재충전 조각이 하나도 안 들어가는 "즉사 재충전"을 트레이 공급이 보정하나 | systems-designer · 트레이 공급 GDD | `/design-system tray-supply` |
| Q4 | 스테이지별 보드 크기(예: 6×6 튜토리얼)가 필요한가 — MVP는 전역 8×8 (D3) | level-designer · 스테이지 & 목표 GDD | 10스테이지 데이터 작성 시 |
| Q5 | 떨어진 칸 모양(D4)을 풀 비전 크루에서 허용할 가치가 있나 | game-designer | T2 크루 확장 시 |
| Q6 | systems-index에 판 진행 흐름 → 보드 & 조각 규칙 직접 의존 추가 | producer · `/map-systems` | 판 진행 흐름 GDD 작성 전 |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(숫자 규칙 있음)·Edge Cases·Dependencies·AC + 필수 선택 섹션(Visual/Audio·Game Feel — Gameplay 필수, Cross-References — 의존 있음) + UI Requirements·Open Questions("All of them" 권장안). Player Fantasy·Tuning Knobs 생략 | Tuning Knobs 섹션 추가 — tier 규칙 위반; 대신 데이터 기반 값 표를 Core Rules에 둠 |
| D2 | Overview 프레이밍 | Both / ADR 인용 안 함 / Fantasy 없음 | 기술 프레이밍만 — Gameplay category라 player-facing 우선 |
| D3 | 보드 크기 | 전역 데이터 1개 (8×8), 스테이지별 변경 없음 | 스테이지별 보드 크기 — 데이터·UI 레이아웃 복잡도 증가, MVP 가설과 무관 (Q4) |
| D4 | 모양 연결성 | 4방향 연결 필수 (데이터 플래그) | 떨어진 칸 허용 — 스티커 한 장 은유와 판독성 훼손 (Q5) |
| D5 | 얼굴 위치 결정 주체 | 모양 데이터 `face_cell` 선택적, 없으면 트레이 공급이 시드 RNG로 결정; 보드 규칙은 검증만 | 보드 규칙이 결정 — RNG 의존이 생겨 순수성 훼손 |
| D6 | 칸 종류 확장 방식 | 규칙 플래그 3종 + 보존 전용 `modifiers` | 칸 종류별 분기 코드 — 방해물 추가마다 보드 규칙 수정 (순환 의존 재발) |
| D7 | 알의 표현 | `TILE(origin=EGG)` — 줄 판정상 조각 칸과 같음 | 별도 칸 종류 — 플래그가 TILE과 같아 중복 |
| D8 | `no_moves` 빈 목록 | 거짓 (재충전 대기) | 참 — 재충전 직전 오판정 |
| D9 | 실패·클리어 동시 성립 | 클리어 우선 (provisional, 판 진행 흐름에 계약 제안) | 실패 우선 — 기둥 5 위반 |
| D10 | 초기 보드에 완성 줄 | 로드 거부 | 시작 시 자동 해결 — 무료 연쇄, 스테이지 의도 왜곡 |
| D11 | 반환 순서 | 행 먼저·오름차순, row-major | 정렬 없음 — 미리보기/해석기 순서 불일치 위험 |
| D12 | 실패 조건 경계 | "놓을 곳 없음"만 이 시스템; 제한 조각 수 소진은 스테이지 & 목표 | 두 조건 모두 보드 규칙 — 스테이지 데이터 의존 발생 |
