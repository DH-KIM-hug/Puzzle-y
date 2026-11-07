# 트레이 공급 (Tray Supply)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 4 한 판 더

## Summary

트레이 공급은 3칸 트레이에 들어갈 조각(모양·크루·얼굴 위치)을 정한다: 3개를 다 놓으면 재충전하며, **크루 가방**으로 매 트레이에 팀 3인이 한 조각씩,
**모양 가방**으로 크루 정의의 가중치를 사이클마다 정확히 지키고, 얼굴 위치는 균등하게 고른다. 모든 뽑기는 `stage_seed`의 트레이 전용 스트림에서 파생해
같은 스테이지·팀·배치면 같은 트레이가 나오고(MVP 기본 `FIXED` 시드), 재충전 즉사는 팀 모양으로 가능한 경우에만 1칸을 바꾸는 최소 구제로 막으며, 보인 조각은
절대 바꾸지 않는다. 튜토리얼·손으로 짠 스테이지는 `tray_script`로 순서를 고정한다 — "트레이 랜덤이 운으로 느껴짐" 위험에 대한 답이다 (기둥 2·3·4).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `보드 & 조각 규칙`, `크루 정의 & 능력`, `시드 RNG` (upstream) — downstream: 판 진행 흐름, 스테이지 & 목표, 드래그 & 배치 입력(데이터 계약), 무한 모드, 튜토리얼

## Overview

트레이 공급은 플레이어 손에 들어오는 조각을 정한다. 데이터 층에서 트레이는 `tray_size`(3)칸의 조각 인스턴스 목록이고
(board-rules 규칙 5: `shape` + `crew_id` + `face_index`), 3개를 모두 놓으면 판 진행 흐름이 재충전을 요청한다. 재충전은
**두 겹의 가방**으로 만든다 — 바깥 *크루 가방*은 팀 3인의 토큰을 한 개씩 넣고 섞어 "트레이마다 팀 3인이 정확히 한 조각씩"을
보장하고, 안쪽 *모양 가방*은 크루 정의의 모양 가중치만큼 모양을 넣어 한 바퀴 안에서 가중치 비율을 정확히 지킨다. 얼굴 위치
(`face_cell = −1`)는 시드 RNG로 균등하게 고른다. 모든 뽑기는 `stage_seed`에서 파생한 트레이 전용 스트림만 쓰므로, 같은 스테이지·
같은 팀·같은 배치면 같은 트레이가 나온다(재도전이 "다시 굴리기"가 아니라 "다시 풀기"가 된다). 재충전된 3조각이 모두 놓을 곳이
없으면 — 팀의 다른 모양으로는 놓을 수 있는 경우에 한해 — **한 칸만** 놓을 수 있는 모양으로 바꾸는 구제 규칙이 있고, 이미 화면에
보인 조각은 절대 바꾸지 않는다. 튜토리얼·손으로 짠 스테이지는 `tray_script`로 트레이 순서를 고정할 수 있다.

플레이어 쪽에서 이 시스템은 "내 팀이 매번 다 나온다, 그리고 막힌 건 운이 아니라 내 배치 탓이다"라는 감각이다. 컨셉의 위험
"트레이 랜덤이 운으로 느껴짐"과 Open Question "완전 랜덤 vs 스테이지 고정 시드 vs 가방"을 이 문서가 닫는다 — 답은
**가방 + 스테이지 고정 시드 + 최소 구제**다. 이 시스템이 없으면 팀 편성(기둥 2)이 트레이에 보이지 않고, 재도전(기둥 4)이 운 시험이 된다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No`
(`docs/architecture/adr-*.md` 없음 — 해시·스트림 태그는 시드 RNG ADR 대상) · Fantasy `[A] Yes`이지만 standard tier라 Player Fantasy 섹션은
생략하고 의도는 이 Overview와 Game Feel에 둔다. 구현 형태(가방 상태 객체, 해시 함수 선택, Godot `RandomNumberGenerator` 인스턴스 수명)는 → ADR.

*기술 타당성 (Godot 4.7, domain Scripting)*: `docs/engine-reference/godot/modules/`에 `scripting.md`가 없어 고정 엔진 대비 타당성은
확인하지 않았다 (NOT SOURCEABLE — scripting 도메인은 `docs/engine-reference/godot/modules/`에 없음). 의존하는 것은 시드 지정
`RandomNumberGenerator` 인스턴스와 정수 해시뿐이며, `RandomNumberGenerator`의 시드→수열이 Godot 버전 간 같다는 보장은 확인하지
않았다 — 리플레이를 버전 사이에 유지하려면 ADR에서 자체 PRNG/해시를 고정할지 결정한다 (Open Question Q6).

## Detailed Design

> *Specialist note*: `game-designer` · `systems-designer` (Section 6 라우팅: Gameplay → 규칙 시스템; index 권장 에이전트 systems-designer,
> game-designer) not consulted — Lean mode (Section C는 lean에서 생략) 및 이 실행에 Agent 도구 없음. Review manually before production.

### Core Rules

**A. 트레이 구조**

1. **트레이 = `tray_size`칸** (MVP 3). 각 칸은 조각 인스턴스(board-rules 규칙 5) 또는 빈 칸. 칸 순서(왼쪽→오른쪽)는 표시 순서일 뿐 규칙 의미가 없다.
2. **소비** — 배치가 커밋되면 판 진행 흐름이 `consume(slot)`을 불러 그 칸을 빈 칸으로 만든다. 남은 조각은 **자리를 옮기지 않는다**
   (당겨 채우기 없음 — 입력 GDD의 슬롯 인덱스가 드래그 중 안정적이고, 손이 기억한 위치가 유지된다).
3. **재충전** — 모든 칸이 빈 칸일 때만, 판 진행 흐름이 해석기 종료·연출 후 `refill(board, budget)`을 부른다. 부분 재충전은 없다.
   채우는 수 `m = min(tray_size, budget)` — `budget`은 스테이지의 남은 제한 조각 수(제한 없음 = ∞, 판 진행 흐름이 전달). `m < tray_size`면
   나머지 칸은 빈 칸으로 남는다. `m = 0`이면 재충전하지 않는다 (제한 조각 소진 판정은 스테이지 & 목표 소관).
   재충전 직후 `no_moves` 평가는 판 진행 흐름이 한다 (board-rules 규칙 15 계약).
4. **정직성 불변식 — 보인 조각은 바뀌지 않는다.** 트레이에 표시된 조각 인스턴스는 소비될 때까지 모양·크루·얼굴 위치가 절대 바뀌지 않는다.
   구제(규칙 13)를 포함한 모든 보정은 재충전 *순간*, 표시 *전*에만 일어난다 (기둥 3: 보이는 것이 곧 사실).
5. **플레이어 조작 없음 (MVP)** — 보관(hold)·교체·리롤·회전이 없다. 리롤을 재화로 사는 아이템은 만들지 않는다 (안티 기둥 "과금 = 수치 우위 아님").
6. **다음 트레이는 보여 주지 않는다 (MVP)** — 지금 트레이 3칸만 보인다. "다음 조각 미리보기"는 Open Question Q1.

**B. 생성 (generated 모드 — 스크립트가 없거나 소진된 뒤)**

7. **입력** — `team`: 크루 id 목록 1–3개 (판 진행 흐름이 팀 편성에서 받아 넘김; 순서 = 팀 슬롯 순서 `team_slot` 0..n−1),
   크루 레지스트리(`CrewDef.shapes`), 스테이지 트레이 설정(규칙 18–22), `stage_seed`. 트레이는 팀 편성을 직접 모른다 (systems-index 순환 차단 계약).
8. **크루 가방** — 토큰 = 팀의 각 크루 × `crew_bag_copies`(MVP 1)개. 조각 하나 = 토큰 하나를 꺼냄. 가방이 비면 같은 구성으로 새 가방을 만들어
   섞는다 (`crew_bag_index` +1, 시드는 F3). 팀 3인 · `crew_bag_copies = 1` · `m = 3`이면 **모든 트레이에 팀 3인이 정확히 한 조각씩** 나온다 (F1).
   팀이 1–2명이면(튜토리얼) 같은 규칙으로 가방이 트레이 경계를 넘어 이어진다.
9. **모양 가방 (크루별)** — 크루 c의 모양 s를 `weight` w_s개씩 넣은 가방. 크루 c의 조각을 만들 때 하나를 꺼내고, 비면 새 사이클로 다시 채워
   섞는다 (`shape_cycle_index[c]` +1). 한 사이클(Σw_s번) 안에서 모양 s는 **정확히** w_s번 나온다 — 크루 정의 F1의 확률이 장기 평균이 아니라
   사이클마다 지켜진다 (F2).
10. **얼굴 위치** — 모양의 `face_cell ≥ 0`이면 그 값, `−1`이면 모양의 칸 0..|s|−1 중 균등하게 하나 (F4). MVP 모든 모양이 −1 (crew-definition D4).
11. **얼굴 없는 조각** — 스테이지가 `allow_faceless_pieces = true`이고 `faceless_share > 0`일 때만, 생성된 조각마다 확률 `faceless_share`로
    `face_index = null`, `crew_id = null`이 된다 (모양은 그 크루 토큰에서 뽑은 것 그대로; 크루 토큰은 소비됨). 그 밖의 스테이지에서는
    `faceless_share`가 무시된다 (board-rules 규칙 5 — 얼굴 없는 인스턴스는 허용 스테이지에서만 유효).
12. **생성 순서** — 재충전 시 칸 0 → m−1 순으로 조각마다 [크루 토큰 → 모양 → 얼굴 위치 → 얼굴 없음 판정]을 한다. 그 다음 규칙 13을 검사한다.

**C. 구제 (anti-frustration) — "즉사 재충전" 방지 (board-rules Q3 해소)**

13. **최소 구제** (`rescue_enabled`, generated 모드 기본 true) — 재충전 후보 m개가 **모두** `any_fit(board, piece) = false`이면(= 이대로면 재충전 직후
    `no_moves`로 실패):
    1. 후보 칸마다 그 칸 크루의 모양 중 지금 보드에 놓을 수 있는 것 `F(c) = { s ∈ S_c : any_fit(board, s) }`를 구한다 (얼굴 없는 후보는
       원래 토큰의 크루 기준).
    2. `F(c) ≠ ∅`인 칸 집합 R이 비면 **구제하지 않는다** — 팀 누구의 어떤 모양도 들어갈 곳이 없으므로 실패는 정직하다.
    3. R이 있으면 구제 스트림(F3)으로 R에서 칸 하나를 균등하게 고르고, 그 칸을 `F(c)`에서 가중치 비례(F5)로 고른 모양으로 바꾼다.
       얼굴 위치는 규칙 10으로 새로 뽑고(구제 스트림), 얼굴 없음 여부는 원래 후보를 따른다.
    4. **교체는 재충전당 최대 1칸.** 보장은 "적어도 1개는 놓을 수 있다"뿐이고 나머지는 그대로다 — 트레이 전체가 아니라 *다음 한 수*만 지킨다.
    5. 구제는 모양 가방·크루 가방을 건드리지 않는다 (원래 토큰은 소비된 것으로 둔다) — 이후 순서가 구제 여부와 무관하게 같다 (규칙 16).
14. **구제는 표시하지 않는다** — 플레이어 화면에 별도 표시·연출이 없다 (구제된 조각도 보통 조각과 같다; 불변식 4를 어기지 않으므로 거짓말이 아니다).
    판 진행 흐름 로그에는 `TRAY_RESCUED { refill_index, slot, from_shape, to_shape }`를 남겨 튜닝 지표 F6에 쓴다.
15. **구제는 스크립트 트레이에 적용하지 않는다** (규칙 21) — 손으로 짠 순서는 설계자 의도이며, 그 판의 해법을 바꾸지 않는다.

**D. 결정성과 재현**

16. **트레이 전용 스트림만** — 트레이는 시드 RNG 서비스의 트레이 스트림(`STREAM_TRAY_CREW`, `STREAM_TRAY_SHAPE`, `STREAM_TRAY_FACE`,
    `STREAM_TRAY_RESCUE`, `STREAM_TRAY_FACELESS`)만 쓴다. 전역 랜덤 금지, 해석기 스트림 소비 금지 (chain-resolver 규칙 23). 모든 뽑기는
    (`stage_seed`, 스트림 태그, 인덱스)에서 파생한 시드로 만든 지역 RNG로 한다 (F3) — 그래서 구제가 없는 한 트레이 순서는
    `stage_seed` + `team` + 스테이지 설정만으로 판 시작 시 확정되며 플레이어 배치와 무관하다. 구제는 해당 재충전의 해당 칸만 바꾼다.
17. **재현** — (`stage_seed`, `team`, 스테이지 트레이 설정, 크루 레지스트리 버전, 배치 목록)이 같으면 판 전체의 트레이 순서가 같다.
    리플레이·버그 재현·자동 플레이 테스트(crew-definition AC-17)가 이것을 쓴다.
18. **시드 정책 `tray_seed_mode`** (스테이지 데이터 필드 — 스테이지 & 목표 GDD에 제안):
    - `FIXED` (**MVP 기본**) — `stage_seed`는 스테이지 데이터 값. 재도전마다 같은 팀이면 같은 첫 트레이·같은 순서. "운"을 "학습 가능한 퍼즐"로 바꾼다 (기둥 3·4).
    - `PER_ATTEMPT` — `stage_seed = hash32(stage_base_seed, STREAM_ATTEMPT, attempt_index)` (F3). 무한 모드(T3)·반복 연습용.
    해석기의 `rng_seed`(chain-resolver F7)도 같은 `stage_seed`에서 파생되므로 두 시스템이 한 판에 같은 `stage_seed`를 쓴다.

**E. 스테이지 오버라이드 (`tray_script`)**

19. **스크립트 트레이** — 스테이지 데이터의 `tray_script`: 재충전 순서대로의 트레이 목록. 항목 하나 = 조각 지정 1 – `tray_size`개, 각 지정은
    { `shape`: 모양 카탈로그 id 또는 `*`(그 크루의 모양 가방에서 뽑기), `crew`: `team_slot`(정수) | `crew_id` | `null`(얼굴 없음),
    `face_index`: 정수 | `−1`(RNG, 규칙 10) | `null`(얼굴 없음) }. `refill_index < len(tray_script)`인 재충전은 그 항목 그대로 채운다
    (항목의 조각 수 < `tray_size`면 나머지 칸은 빈 칸 — 튜토리얼 "하나씩 놓아 보기"). `budget`이 항목보다 작으면 앞에서부터 `budget`개만.
20. **스크립트 소진 후** `after_script`: `GENERATE`(기본 — 규칙 7–13으로 이어감; 스크립트는 크루 가방을 소비하지 않으므로 크루 가방은 처음 상태에서 시작, 모양 가방은 `shape = *` 지정이
소비한 만큼 진행된 상태에서 이어감)
    | `LOOP`(스크립트를 처음부터 반복 — 고정 순서 퍼즐 스테이지).
21. **스크립트에는 구제가 없다** — 해법이 막히는 스크립트는 레벨 데이터 버그이며 자동 플레이 검증(AC-15)으로 잡는다.
22. **스크립트 로드 검증 (실패 = 스테이지 로드 오류)** — 모양 id가 카탈로그에 있음 · `team_slot < 팀 크기` · `crew_id` 직접 지정은 스테이지가
    팀을 고정한 경우(스테이지 & 목표 GDD 필드, provisional)에만 · `face_index`가 모양 칸 범위 안 · `null` 얼굴/크루는 `allow_faceless_pieces = true`
    스테이지에서만 · `shape = *`는 크루가 정해진 지정에서만. **린트 경고**: `team_slot` 지정의 모양이 그 크루의 `shapes`에 없음 (가능하지만
    "팀 = 조각 풀" 약속을 깨므로 의도 확인).

**F. 데이터 값 (Tuning Knobs 섹션은 standard tier라 생략 — 값과 안전 범위를 여기 둔다)**

| 값 | 기본 | 안전 범위 | 소유 / 위치 | 너무 크면 / 작으면 |
|---|---|---|---|---|
| `tray_size` | 3 | 2–4 | 이 문서 (전역 데이터) | 크면 선택지↑·막힘↓·미리보기 부담↑ / 작으면 운 비중↑. 3은 컨셉·프로토타입 값 |
| `crew_bag_copies` | 1 | 1–3 | 이 문서 (전역 데이터) | 크면 한 트레이에 같은 크루 2–3개 가능(변동↑) / 1 = 트레이마다 팀 전원 |
| `rescue_enabled` | true | bool | 스테이지 데이터 (generated 모드) | false = 순수 공급 (도전 스테이지) |
| `faceless_share` | 0.0 | 0.0–1.0 | 스테이지 데이터 | `allow_faceless_pieces = false`면 무시 |
| `tray_seed_mode` | `FIXED` | `FIXED` \| `PER_ATTEMPT` | 스테이지 데이터 | — |
| `tray_script` / `after_script` | 없음 / `GENERATE` | 규칙 19–22 | 스테이지 데이터 | — |
| `rescue_rate_alert` | 0.10 | 0.02–0.25 | 이 문서 (밸런스 지표 임계, F6) | 지표 경고선일 뿐 런타임 동작 없음 |

### States and Transitions

트레이 칸 상태(판 하나 동안):

| 상태 | 의미 | 다음 | 조건 |
|---|---|---|---|
| `AWAITING_REFILL` | 모든 칸 빈 칸 (판 시작 직후 포함) | `FULL` / `PARTIAL` / `EXHAUSTED` | 판 진행 흐름이 `refill` 호출: `m = tray_size` → `FULL`, `0 < m < tray_size`(budget 끝 또는 짧은 스크립트 항목) → `PARTIAL`, `m = 0` → `EXHAUSTED` |
| `FULL` | 모든 칸에 조각 | `PARTIAL` | `consume(slot)` |
| `PARTIAL` | 1개 이상 조각, 1개 이상 빈 칸 | `PARTIAL` / `AWAITING_REFILL` | `consume` 후 남은 조각 ≥1 / 0 |
| `EXHAUSTED` | 더 채울 조각 없음 (budget 0) | — (판 종료) | 스테이지 & 목표가 제한 조각 소진 판정 |

공급원 상태(판 하나 동안): `SCRIPT` (`refill_index < len(tray_script)`) → 소진 시 `after_script`에 따라 `GENERATE` 또는 `SCRIPT`(LOOP, `refill_index`를
스크립트 길이로 나눈 나머지). 스크립트 없는 스테이지는 처음부터 `GENERATE`. 판 재시작은 모든 가방·인덱스를 초기화한다 (`FIXED`면 같은 순서 재생).

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보드 & 조각 규칙 | 트레이 → 보드 규칙 | 조각 인스턴스 형식 검증(규칙 5), 구제 판정에 `any_fit(board, piece)` | 보드 규칙 (형식·판정) / 트레이 (선택) |
| 크루 정의 & 능력 | 크루 → 트레이 | 팀 크루의 `shapes`(모양·`weight`·`face_cell`) | 크루 (크루 안 가중치, crew-definition F1) / 트레이 (크루 사이 비율 = 크루 가방, 얼굴 위치, 재충전) |
| 시드 RNG (ADR) | RNG → 트레이 | `hash32`, 트레이 스트림 태그 5종, 지역 RNG 생성 | 시드 RNG ADR / 트레이 (스트림 사용 규칙 16) |
| 판 진행 흐름 | 판 흐름 → 트레이 | 판 시작 `init(team, stage_tray_config, stage_seed)`, `refill(board, budget)`, `consume(slot)`, 트레이 스냅샷 조회; 트레이 → 판 흐름: 스냅샷, `TRAY_RESCUED` 로그 | 판 진행 흐름 (호출 타이밍, `no_moves` 평가) / 트레이 (내용) |
| 스테이지 & 목표 | 스테이지 → 트레이 | `stage_seed`/`stage_base_seed`, `tray_seed_mode`, `tray_script`, `after_script`, `rescue_enabled`, `allow_faceless_pieces`, `faceless_share`, 팀 고정 여부, 남은 제한 조각 수(판 흐름 경유) | 스테이지 (데이터 필드) / 트레이 (의미·검증) |
| 드래그 & 배치 입력 | 트레이 → 입력 (판 흐름 경유) | 트레이 스냅샷 (칸별 조각 인스턴스 \| 빈 칸, `tray_size` = 입력의 `N_tray`) | 트레이 (형식) |
| 연쇄 미리보기 | 간접 | 미리보기는 끌고 있는 트레이 조각을 입력으로 쓸 뿐; 트레이 상태를 바꾸지 않음 | — |
| 플레이 HUD / 트레이 표시 | 트레이 → 표시 | 칸별 조각(모양·크루 색·얼굴 위치), 재충전 이벤트 | 표시 GDD / UX 스펙 |
| 무한 모드 (T3) | 무한 모드 → 트레이 | `PER_ATTEMPT`, `budget = ∞`, 스크립트 없음 | 무한 모드 GDD |
| 튜토리얼 (VS) | 튜토리얼 → 트레이 | `tray_script`, 얼굴 없는 조각 | 튜토리얼 / 스테이지 데이터 |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. 크루 안 모양 확률 p(s|c)와 기대 조각 크기 E_c는 crew-definition F1·F2 소유이며 여기서는 참조만 한다.
> 모양 가중치 합 C_c (crew-definition 규칙 14): 냥이 12 · 곰곰 8 · 삐약 8 · 개굴 8 · 깡총 6 · 몽실 8.

**F1. 크루 비율과 팀 단위 조각 확률**

The crew_share formula is defined as:

`share_c = k / (n · k) = 1 / n`,  `p(c, s) = share_c · p(s | c)`,  `G_c ≤ 2k(n − 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n | int | 1–3 | calculated (팀 크기, 판 진행 흐름이 전달) | 팀의 크루 수 |
| k | int | 1–3 | data file (`crew_bag_copies`) | 가방 하나에 크루당 토큰 수 |
| p(s \| c) | float | (0, 1] | calculated (crew-definition F1) | 크루 안 모양 확률 |
| G_c | int | ≥ 0 | calculated | 같은 크루 c의 두 조각 사이에 끼는 다른 조각 수의 최댓값 |

**Output Range:** share_c = 1/3 (팀 3인), 1/2, 1. 가방 크기 `B = n·k`. `B = tray_size`이고 모든 재충전이 꽉 차면(m = 3) 가방 경계와 트레이 경계가
일치해 **트레이마다 크루당 정확히 k개** — MVP 기본(n = 3, k = 1)에서 G_c ≤ 4이고 실제로는 "매 트레이에 팀 전원". 이 값이 crew-definition F2의
`share_c` 가정(1/3)을 확정한다.
**Example:** 기본 팀 냥이+곰곰+삐약 → 냥이 I3_H의 팀 단위 확률 = 1/3 · 3/12 = **0.083**. k = 2이면 B = 6, 한 트레이에 같은 크루 2개도 가능, G_c ≤ 8.

**F2. 모양 가방 사이클과 최대 가뭄**

The shape_drought formula is defined as:

`C_c = Σ_{s ∈ S_c} w_s`,  `D_s ≤ 2 (C_c − w_s)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| w_s | int | 1–10 | data file (`CrewShapeEntry.weight`) | 모양 s의 가중치 = 사이클 안 출현 수 |
| C_c | int | 1–80 | calculated | 크루 c의 사이클 길이 (크루 c 조각 수 기준) |
| D_s | int | ≥ 0 | calculated | 크루 c의 조각 중, 모양 s가 연속 두 번 나오는 사이에 끼는 다른 모양 조각 수의 최댓값 |

**Output Range:** 사이클 안에서 s는 정확히 w_s번 (편차 0). D_s 최악 = 앞 사이클 처음 + 다음 사이클 끝. 순수 독립 추첨이면 D_s에 상한이 없다 (기하분포).
기본 팀(k = 1)은 크루 조각이 트레이당 1개이므로 D_s는 곧 "트레이 수"다.
**Example:** 곰곰 O4 (w 3, C 8) → D ≤ 2·5 = **10** 트레이. 냥이 L4_A (w 1, C 12) → D ≤ 22 트레이 (희귀 모양이라 의도). 삐약 D1 (w 2, C 8) → D ≤ 12.

**F3. 트레이 시드 파생** (provisional — 해시·스트림 태그 값은 시드 RNG ADR에서 확정)

The tray_seed formula is defined as:

`seed_crew(j) = hash32(stage_seed, STREAM_TRAY_CREW, j)`
`seed_shape(c, q) = hash32(stage_seed, STREAM_TRAY_SHAPE, crew_key(c), q)`
`seed_face(i) = hash32(stage_seed, STREAM_TRAY_FACE, i)` · `seed_faceless(i) = hash32(stage_seed, STREAM_TRAY_FACELESS, i)`
`seed_rescue(r) = hash32(stage_seed, STREAM_TRAY_RESCUE, r)` · (`PER_ATTEMPT`) `stage_seed = hash32(stage_base_seed, STREAM_ATTEMPT, a)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stage_seed | int | 0 – 2³¹−1 | data file (스테이지) 또는 `PER_ATTEMPT` 파생 | 판 단위 시드 (해석기 F7과 같은 값) |
| STREAM_* | int const | 고정, 서로 다름, `STREAM_RESOLVER`와 다름 | constant (ADR) | 스트림 분리 태그 |
| j | int | ≥ 0 | calculated | 크루 가방 번호 (`crew_bag_index`) |
| crew_key(c) | int | 32비트 | calculated (crew id 문자열의 고정 해시, ADR) | 팀 슬롯 순서와 무관한 크루 키 |
| q | int | ≥ 0 | calculated | 크루 c의 모양 사이클 번호 |
| i | int | ≥ 0 | calculated | 이 판에서 트레이에 들어간 조각 순번 (`piece_index`, 스크립트 조각 포함, 구제 교체는 증가시키지 않음) |
| r | int | ≥ 0 | calculated | 재충전 순번 (`refill_index`) |
| a | int | ≥ 0 | calculated (판 진행 흐름의 시도 횟수) | `PER_ATTEMPT`의 시도 번호 |

**Output Range:** 32비트 정수. 각 시드로 지역 RNG를 만들어 Fisher–Yates 셔플(가방) 또는 균등 정수 1회(얼굴·구제·얼굴 없음)에 쓴다.
같은 입력 → 같은 시드 → 같은 트레이. 모양 시드를 `crew_key`로 잡아 팀 슬롯 순서를 바꿔도 크루별 모양 순서는 같다(크루 가방 순서만 바뀜).
**Example:** `stage_seed = 1201`, 기본 팀 → 1번째 재충전은 `seed_crew(0)`로 [곰곰, 삐약, 냥이] 순서, 각 크루의 `seed_shape(c, 0)` 가방 첫 모양,
`seed_face(0..2)` 얼굴. 같은 스테이지 재도전(`FIXED`) → 완전히 같은 첫 트레이.

**F4. 얼굴 위치 확률**

The face_index formula is defined as:

`P(face_index = i | s) = 1 / |s|` (i ∈ 0..|s|−1, `face_cell = −1`일 때), `face_cell ≥ 0`이면 1 (그 칸)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| \|s\| | int | 1–6 | calculated (board-rules `max_piece_cells`) | 모양 칸 수 |
| face_cell | int | −1, 0..\|s\|−1 | data file (crew-definition) | 고정 얼굴 칸 |

**Output Range:** 1/6 ~ 1. 1칸 모양(D1)은 항상 그 칸.
**Example:** 몽실 X5 → 칸마다 **0.2** (가운데 칸 얼굴이면 십자 채우기가 판 위 자기 조각 주변이 된다 — 같은 모양도 다른 수).

**F5. 구제 선택**

The rescue_pick formula is defined as:

`P(slot = x) = 1 / |R|` (x ∈ R),  `P(s | c, rescue) = w_s / Σ_{s' ∈ F(c)} w_s'` (s ∈ F(c))

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| F(c) | 모양 집합 | ⊆ S_c | calculated (`any_fit`, board-rules 규칙 14) | 지금 보드에 놓을 수 있는 크루 c의 모양 |
| R | 칸 집합 | 0 – m칸 | calculated | F(c) ≠ ∅인 후보 칸 |
| w_s | int | 1–10 | data file | 크루 정의 가중치 |

**Output Range:** |R| = 0이면 구제 없음(정직한 실패). 아니면 교체 정확히 1칸.
**Example:** 빈 자리가 가로로 이어진 3칸 틈 하나와 서로 떨어진 외톨이 빈칸들뿐인 보드(안정 보드는 모든 행·열에 빈칸이 있어야 하므로 "빈칸 3개뿐"은 불가 — systems-designer 리뷰, D14), 기본 팀 후보 [냥이 I4_H, 곰곰 O4, 삐약 D2_V] — 모두 불가.
F(냥이) = {I3_H}, F(곰곰) = ∅, F(삐약) = {D1, D2_H} → R = {냥이 칸, 삐약 칸}, 각 **0.5**. 삐약 칸이 뽑히면 D1 = 2/4, D2_H = 2/4.
곰곰 칸과 뽑히지 않은 칸은 그대로 (불가 조각 2개가 남는다 — 보장은 "다음 한 수"뿐).

**F6. 구제율 지표 (밸런스 지표 — 런타임 동작 없음)**

The rescue_rate formula is defined as:

`ρ = N(TRAY_RESCUED) / N(generated refills)`,  `φ = N(refill with all candidates unfit ∧ R = ∅) / N(generated refills)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N(TRAY_RESCUED) | int | ≥ 0 | calculated (판 진행 흐름 로그) | 구제가 일어난 재충전 수 |
| N(generated refills) | int | ≥ 1 | calculated | 생성 모드 재충전 수 (스크립트 제외) |
| rescue_rate_alert | float | 0.02–0.25 | data file (기본 0.10) | 경고선 |

**Output Range:** 0 ~ 1. **목표**: 자동 플레이(T0)에서 팀·스테이지별 ρ ≤ `rescue_rate_alert` (0.10). 넘으면 구제가 "숨은 손"이 되어 판의 실제 난이도를
가린다는 신호 — 스테이지 시작 보드를 넓히거나 팀 E_T(crew-definition F2)를 낮춘다. φ는 "재충전 즉사"의 실제 실패 비율이다.
**Example:** 200회 재충전 중 구제 12회 → ρ = **0.06** (정상). 곰곰+깡총+몽실(E_T 4.00)에서 ρ = 0.14 → 경고.

**F7. 스테이지 안 크루별 조각 수 (스테이지 설계용)**

The crew_piece_count formula is defined as:

`N_c(N) ∈ [k·⌊N / B⌋, k·⌊N / B⌋ + min(k, N mod B)]`,  `B = n · k`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N | int | 1–∞ | data file (스테이지 제한 조각 수) | 이 판에서 공급되는 조각 수 (생성 모드분) |
| B | int | 1–9 | calculated | 크루 가방 크기 |

**Output Range:** 크루별 조각 수의 편차가 최대 k (기본 1) — 독립 추첨(이항 20, 1/3)이었다면 제한 20조각에서 특정 크루가 2개 이하일 확률 ≈ 1.8%, 3개 이하 ≈ 6.0%다.
스테이지 & 목표 GDD는 "삐약 알로만 풀리는 목표" 같은 설계에서 이 하한을 근거로 쓴다.
**Example:** 제한 20조각, 팀 3인, k = 1 → B = 3, ⌊20/3⌋ = 6, 20 mod 3 = 2 → 크루마다 **6 또는 7개**.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 재충전 후보 3개가 모두 놓을 곳이 없지만 팀의 다른 모양 하나는 들어가면**: 구제가 1칸을 바꾼다 (규칙 13). 플레이어는 보통 트레이로 본다.
- **If 팀 누구의 어떤 모양도 들어갈 곳이 없으면**: 구제하지 않는다. 판 진행 흐름이 재충전 직후 `no_moves = true`로 실패 처리한다 — 정직한 막힘이다.
- **If 트레이 중간(조각 1–2개 남음)에 남은 조각이 모두 놓을 곳이 없어지면**: 바꾸지 않는다 (불변식 4). `no_moves` 실패는 플레이어 배치의 결과다.
- **If 구제로 바뀐 조각을 놓은 뒤 나머지 2개가 여전히 안 들어가면**: 정상. 그 시점 `no_moves` 평가는 판 진행 흐름 소관이며 실패할 수 있다. 구제는 재충전당 1회뿐이다.
- **If `budget < tray_size`(제한 조각 끝)이면**: `m = budget`개만 채우고 나머지는 빈 칸 (`PARTIAL`). `budget = 0`이면 재충전하지 않는다 (`EXHAUSTED`).
- **If 팀이 1명이면**: 크루 가방이 한 크루 토큰뿐 — 모든 조각이 그 크루. 모양 가방은 정상. 팀이 2명이면 가방(크기 2)이 트레이 경계를 넘어 이어져 트레이 구성이 2+1 / 1+2로 번갈아 난다.
- **If 팀이 비었으면** (데이터 오류): 생성 모드 `init` 오류 — 스크립트가 모든 조각을 `crew = null`/`crew_id`로 지정한 스테이지만 팀 0명이 허용된다 (스크립트 + `after_script = LOOP`일 때만).
- **If 크루의 모양이 1개뿐이면**: 모양 가방 사이클 = w_s, 항상 그 모양. 정상.
- **If 한 모양을 팀의 두 크루가 공유하면** (냥이·몽실 I3_H): 크루별 가방이 따로라 서로 영향 없음. 같은 트레이에 같은 모양 2개(색·얼굴 다름)가 나올 수 있다 — 정상.
- **If 스테이지 데이터 `stage_seed`가 없으면**: 스테이지 로드 오류 (`FIXED`). 대체 시드를 조용히 만들지 않는다 — 재현성이 깨지기 때문.
- **If 재도전(원탭 재시작)에서 팀이 같고 `FIXED`이면**: 첫 트레이부터 같은 순서. 팀을 바꾸면 크루 가방 내용이 달라져 순서가 달라진다 (의도 — 기둥 2).
- **If 판 도중 앱이 종료되고 판을 이어 하면** (세이브 범위 밖일 수 있음): 트레이 상태는 (`stage_seed`, team, 배치 목록)을 다시 재생해 복원할 수 있다 (규칙 17). 판 중 저장 여부는 로컬 세이브 GDD 소관.
- **If 크루 데이터(`weight`, `shapes`)가 업데이트로 바뀌면**: 같은 시드라도 순서가 달라진다. 리플레이는 크루 레지스트리 버전을 함께 기록해야 한다 (규칙 17).
- **If `faceless_share > 0`인데 `allow_faceless_pieces = false`이면**: `faceless_share`를 무시하고 린트 경고. 얼굴 없는 조각은 만들지 않는다.
- **If `faceless_share = 1.0`이면**: 모든 생성 조각이 얼굴 없음 — 순수 블록 퍼즐 튜토리얼. 크루 가방은 여전히 모양 풀을 정한다.
- **If 얼굴 없는 후보가 구제 대상 칸으로 뽑히면**: 원래 토큰 크루의 F(c)에서 모양을 고르고 얼굴 없음은 유지한다.
- **If 스크립트 항목이 지금 보드에 하나도 안 들어가면**: 구제 없음 → 실패. 레벨 데이터 버그로 보고 자동 플레이 검증(AC-15)이 잡는다.
- **If `shape = *`인 스크립트 지정이 모양 가방을 쓰면**: 스크립트 구간에서도 그 크루의 모양 가방을 소비한다 (규칙 20의 "처음 상태"는 `*`를 쓰지 않은 크루에만 해당). 순서는 여전히 결정적이다.
- **If `after_script = LOOP`인데 스크립트가 비었으면**: 스테이지 로드 오류.
- **If 시드 RNG ADR이 해시 함수를 바꾸면** (버전 업): 기존 리플레이 무효. `FIXED` 스테이지의 체감 순서가 바뀌므로 해시 변경은 스테이지 재검증과 함께 한다.
- **If 플레이어가 같은 판을 반복해 순서를 외우면** (`FIXED`): 의도된 학습이다 (기둥 3 "운이 아니라 설계"). 해법 공유·식상함 위험은 Open Question Q4.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 종류 | 쓰는 것 | 상태 |
|---|---|---|---|
| 보드 & 조각 규칙 (`board-rules.md`) | Hard | 조각 인스턴스 형식(규칙 5), `any_fit`(규칙 14), 모양 형식(규칙 3–4), `allow_faceless_pieces` 의미 | Designed |
| 크루 정의 & 능력 (`crew-definition.md`) | Hard | `CrewDef.shapes`(모양·`weight`·`face_cell`), 크루 레지스트리 `get(id)` | Designed |
| 시드 RNG (#3, ADR only) | Hard (계약) | `hash32`, 스트림 태그, 지역 RNG | 미작성 — 규칙 16·F3이 provisional 계약 (chain-resolver 규칙 G와 같은 서비스) |

**Downstream (이 시스템에 의존)** — 아래는 이 문서가 제안하는 계약 (provisional).

| 시스템 | 종류 | 쓰는 것 | 이 문서에 기대하는 것 |
|---|---|---|---|
| 판 진행 흐름 (`round-flow.md`, 미작성) | Hard | `init`, `refill(board, budget)`, `consume(slot)`, 스냅샷, `TRAY_RESCUED` | 재충전은 해석·연출 뒤, `no_moves`는 재충전 뒤 (board-rules 계약 그대로) |
| 스테이지 & 목표 (`stage-goals.md`, 미작성) | Hard | 스테이지 트레이 필드 (규칙 18–22, F 표) | 필드 추가 제안: `tray_seed_mode`, `stage_base_seed`, `tray_script`, `after_script`, `rescue_enabled`, `faceless_share`, 팀 고정 여부. F7을 목표 설계 근거로 사용 |
| 드래그 & 배치 입력 (`placement-input.md`) | 데이터 계약 | 트레이 스냅샷 형식, `N_tray = tray_size` | 슬롯 인덱스 안정 (규칙 2) |
| 무한 모드 (T3) | Hard | `PER_ATTEMPT`, 무제한 budget | — |
| 튜토리얼 & 힌트 (VS) | Soft | `tray_script`, 얼굴 없는 조각 | — |
| 플레이 HUD / 메타 화면 UI | Soft | 트레이 표시 데이터 | — |

**팀 편성은 의존이 아니다** — 트레이는 팀을 `team` 목록 입력으로 받는다 (systems-index Circular Dependencies 계약). 팀 편성 → 판 진행 흐름 → 트레이.

**양방향성**: board-rules Dependencies는 트레이 공급을 Hard downstream으로 적고 있다 (`tray-supply.md` 행 — 트레이 칸 수·재충전 규칙·`face_index` 결정
소유) — 일치. crew-definition Interactions는 트레이를 downstream으로 적는다 — 일치 (Q3 해소: 크루 사이 비율은 크루 가방, 크루 데이터에 필드 없음).
placement-input은 트레이를 "데이터 계약(의존 아님)"으로 적는다 — 일치. systems-index #6 Depends On(보드 & 조각 규칙, 크루 정의, 시드 RNG)과 일치하며, index의 #10 스테이지 & 목표·#11 판 진행 흐름·#30 무한 모드가 트레이 공급을 Depends On에 이미 갖고 있다. 수정 필요 없음.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Lean mode 판단상 트레이 표시가 플레이어가 읽는 핵심 피드백이라 spawn 대상이지만 이 실행에 Agent 도구가 없어 생략.
> Review manually before production.

| 이벤트 | 시각 | 소리 | 비고 |
|---|---|---|---|
| 재충전 | 빈 칸 3개에 조각이 왼쪽→오른쪽 순서로 "톡" 붙음 (스티커 붙이기 — 살짝 눌렸다 펴짐) | 붙이기 SFX 3회, 음높이 조금씩 상승 | 순서는 칸 순서 — 생성 순서와 같아 의미 없는 정보를 만들지 않음 |
| 조각 표시 | 크루 색 슬롯 + 몸통 무늬 + 얼굴 칸에 크루 얼굴 (crew-definition 규칙 1 아트 식별자) | — | 얼굴 위치가 트레이에서 바로 보여야 함 (기둥 3) |
| 얼굴 없는 조각 | 중립색 스티커, 얼굴 없음 (board-rules Visual 표) | — | 튜토리얼 |
| 구제 | **별도 연출 없음** (규칙 14) | 없음 | 숨은 보정이 "선물"처럼 보이면 플레이어가 기대·의존하게 됨 |
| 빈 칸 | 옅은 점선 윤곽 (트레이 자리 유지) | — | 규칙 2: 자리 이동 없음 |
| 마지막 조각 소진 (`PARTIAL` 끝) | 남은 칸이 빈 윤곽으로 남고 재충전 없음 | — | 스테이지 남은 조각 수 HUD와 짝 |

art-bible 원칙: 스티커북 질감, 색약 백업(무늬·모양) — 트레이 조각도 판 위 조각과 같은 그림을 쓴다. 트레이 표시 크기는 UI Requirements.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:tray-supply` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

- **재충전 타이밍**: 연출 재생기 종료 → 재충전 연출 총 `0.30 s` 안 (칸당 0.08 s 간격, 튜닝 값) → 입력 다시 켜짐. 재충전 연출 중 입력은 잠김
  (판 진행 흐름 소관) — 그러나 연출은 `no_moves` 결과를 기다리지 않는다 (판정은 즉시, 실패 연출은 재충전 연출 뒤).
- **"내 팀이 다 나왔다"**: 기본 설정에서 모든 트레이에 팀 3인 색이 하나씩 — 플레이어가 "이번엔 곰곰 조각이 없네"를 겪지 않는다 (기둥 2). 같은 크루가
  두 번 나오는 일이 없어 트레이를 한눈에 읽는다.
- **"막힌 건 내 탓"**: 재충전 즉사가 (팀으로 놓을 수 있는 한) 없고, 보인 조각은 바뀌지 않으며, 재도전이 같은 순서라 실패 원인이 배치로 귀결된다 (기둥 3·4).
- **원탭 재시작 체감**: `FIXED`라 재시작 첫 트레이가 직전 판과 같다 — "아까 그 첫 수를 다르게"가 바로 가능하다.
- 성능: 재충전 1회 = 조각 3개 생성 + 최악 구제 시 `any_fit` 최대 3 + Σ|S_c| ≤ 3 + 24회 (board-rules F6 기준 수천 칸 읽기 이하) — 프레임 예산에 영향 없음.

## UI Requirements

- 트레이 영역: 보드 아래 3칸, 각 칸 터치 타깃 ≥ 64 px (플랫폼 & 화면 규칙), 조각은 칸 안에 맞게 축소 표시 (최대 6칸 모양의 바운딩 박스 3×3 기준).
- 얼굴 칸은 축소 상태에서도 식별 가능해야 한다 (최소 얼굴 크기는 UX 스펙에서 정함).
- 빈 칸은 자리를 유지한다 (규칙 2). 재충전 대기·`EXHAUSTED`에서도 3칸 틀이 보인다.
- 다음 트레이 미리보기 UI는 MVP에 없다 (Q1).
- 트레이 조각을 집는 동작·오프셋은 드래그 & 배치 입력 GDD 소관.

> **📌 UX Flag — 트레이 공급**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the gameplay
> screen tray area (board + tray + HUD layout, 이미 board-rules UX Flag와 같은 화면) **before** writing epics. Stories that reference UI should cite
> `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 이 문서의 내용 | 참조 문서 § | 관계 | 상태 |
|---|---|---|---|
| 트레이 3칸, 3개 모두 놓으면 재충전, 회전 없음 | `design/gdd/game-concept.md` § Core Mechanics 1 · `board-rules.md` 규칙 4 | 규칙 출처 | 일치 |
| 조각 인스턴스 형식, 얼굴 없는 조각 허용 조건 | `design/gdd/board-rules.md` 규칙 5 | 상위 계약 | 일치 |
| `any_fit`, `no_moves`(빈 목록 = 거짓, 재충전 뒤 평가) | `design/gdd/board-rules.md` 규칙 14–15, D8, AC-16 | 상위 계약 | 일치 |
| 즉사 재충전 보정 | `design/gdd/board-rules.md` Q3 | 질문 해소 | 이 문서 규칙 13 (최소 구제) |
| 크루 모양·가중치·`face_cell = −1` | `design/gdd/crew-definition.md` 규칙 2·5·14, F1, D4 | 상위 데이터 | 일치 |
| 크루 사이 비율 `share_c` | `design/gdd/crew-definition.md` F2, Q3, D10 | 질문 해소 | 1/n (크루 가방, F1) — 가정과 일치 |
| 트레이·가챠는 해석기와 다른 스트림 | `design/gdd/chain-resolver.md` 규칙 22–23, F7 | 상위 계약 | 일치 (스트림 태그 5종 추가 제안) |
| 트레이 스냅샷, `N_tray = 3` | `design/gdd/placement-input.md` Interactions, Formulas | 하위 계약 | 일치 |
| 트레이 랜덤 = 운 위험, 랜덤 방식 Open Question | `design/gdd/game-concept.md` § Design Risks, Open Questions | 질문 해소 | 가방 + `FIXED` 시드 + 최소 구제 |
| 조각 풀 = 입력 목록 (순환 차단) | `design/gdd/systems-index.md` § Circular Dependencies | 경계 | 일치 |
| 스테이지 트레이 필드, 팀 고정, 제한 조각 수 | `design/gdd/stage-goals.md` (미작성) | 하위 계약 | provisional |
| 재충전·`no_moves` 타이밍, 시도 번호 | `design/gdd/round-flow.md` (미작성) | 하위 계약 | provisional |
| `hash32`, 스트림 태그 값 | 시드 RNG ADR (미작성) | 상위 계약 | provisional |

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
> 이 GDD의 테스트 파일: `tests/unit/tray_supply/tray_supply_{structure,generation,rescue,script,determinism}_test.gd`,
> `tests/integration/tray_supply/tray_supply_{refill_flow,script_stages}_test.gd`. 모든 테스트는 픽스처에 적힌 고정 `stage_seed`를 쓰고,
> 시드에 따라 달라지는 결과는 골든 파일(`tests/fixtures/tray/*.golden.json`)과 비교한다.

**구조 (규칙 1–6)**

- **AC-01 [Logic] (규칙 2)** — **GIVEN** 꽉 찬 트레이 [A, B, C], **WHEN** `consume(1)`, **THEN** 스냅샷은 [A, 빈 칸, C]이고 A·C의 칸 인덱스·인스턴스가 그대로다.
- **AC-02 [Logic] (규칙 3)** — **GIVEN** 조각 1개 남은 트레이, **WHEN** `refill`을 부르면, **THEN** debug assert가 나고 트레이 스냅샷은 바뀌지 않는다.
  **AND** 빈 트레이에 `budget ≥ 3`으로 `refill` → 정확히 3개, 상태 `FULL`.
- **AC-03 [Logic] (규칙 3, budget 경계)** — **GIVEN** 빈 트레이, **WHEN** `budget = 2`로 `refill`, **THEN** 조각 2개 + 빈 칸 1개, 상태 `PARTIAL`. **AND** `budget = 0` → 변화 없음, 상태 `EXHAUSTED`.
- **AC-04 [Logic] (규칙 4, 정직성)** — **GIVEN** 재충전된 트레이에서 조각 1개를 놓아 남은 2개가 모두 `any_fit = false`가 된 보드, **WHEN** 기록된 배치를 이어 가면,
  **THEN** 남은 2개 인스턴스(모양·crew_id·face_index)는 소비될 때까지 필드 단위로 같다.

**생성 (규칙 7–12, F1·F2·F4)**

- **AC-05 [Logic] (규칙 8, F1)** — **GIVEN** 팀 3인, `crew_bag_copies = 1`, 구제가 일어나지 않는 빈 보드, **WHEN** 재충전 100회, **THEN** 모든 트레이에 세 크루가 정확히 1개씩.
- **AC-06 [Logic] (F1, k = 2)** — **GIVEN** `crew_bag_copies = 2`, **WHEN** 재충전 100회(조각 300개), **THEN** 가방 경계에 맞춘 연속 6조각 구간마다 크루당 정확히 2개이고,
  같은 크루 사이 다른 조각 수 ≤ 8.
- **AC-07 [Logic] (규칙 9, F2)** — **GIVEN** 냥이 단독 팀(모양 가중치 합 12), **WHEN** 조각 120개 생성, **THEN** 12개 단위 구간마다 I3_H 3·I3_V 3·I4_H 2·L3_A 2·L4_A 1·J4_A 1개.
- **AC-08 [Logic] (규칙 10, F4)** — **GIVEN** `face_cell = −1`인 5칸 모양만 가진 테스트 크루, **WHEN** 고정 시드 0–999로 조각 1개씩 생성, **THEN** 각 얼굴 칸 빈도가 200 ± 50.
  **AND** `face_cell = 2`로 바꾸면 1,000개 모두 `face_index = 2`.
- **AC-09 [Logic] (규칙 11)** — **GIVEN** `allow_faceless_pieces = false`, `faceless_share = 1.0`, **WHEN** 재충전 10회, **THEN** 얼굴 없는 조각 0개 + 린트 경고 1회.
  **AND** `allow_faceless_pieces = true`면 30개 모두 `face_index = null`, `crew_id = null`.
- **AC-10 [Logic] (F7)** — **GIVEN** 제한 20조각, 팀 3인, k = 1, 구제 없음, **WHEN** 판 전체 공급, **THEN** 크루별 조각 수가 각각 6 또는 7이고 합이 20, 마지막 재충전은 `PARTIAL`(조각 2개).

**구제 (규칙 13–15, F5·F6)**

- **AC-11 [Logic] (규칙 13)** — **GIVEN** F5 예시 보드(가로 3칸 빈 줄만)와 후보가 [냥이 I4_H, 곰곰 O4, 삐약 D2_V]가 되는 고정 시드, **WHEN** `refill`, **THEN** 정확히 1칸이 바뀌고
  그 칸은 냥이 칸 또는 삐약 칸이며 바뀐 조각은 `any_fit = true`, 곰곰 칸은 O4 그대로, `TRAY_RESCUED` 1건. 어느 칸·모양으로 바뀌는지는 골든 `rescue_f5.golden.json`과 같다.
- **AC-12 [Logic] (규칙 13.2, 구제 실패 → 막힘)** — **GIVEN** 빈칸이 서로 떨어진 1칸뿐이고 팀(냥이+곰곰+개굴)에 1칸 모양이 없는 보드, **WHEN** `refill`, **THEN** 교체 0칸,
  `TRAY_RESCUED` 없음, 재충전된 트레이로 `no_moves = true` (board-rules AC-16 (b)).
- **AC-13 [Logic] (규칙 13.5, 결정성)** — **GIVEN** 같은 `stage_seed`·팀으로 두 판을 돌리되 한 판만 3번째 재충전에서 구제가 일어나도록 보드를 만든다, **WHEN** 4번째 이후 재충전을 비교하면, **THEN** 같다.
- **AC-14 [Logic] (규칙 15·21)** — **GIVEN** `tray_script` 항목이 지금 보드에 하나도 안 들어가는 상황, **WHEN** 그 항목으로 재충전, **THEN** 교체 없이 스크립트 그대로 채운다.

**스테이지 오버라이드 (규칙 19–22)**

- **AC-15 [Logic] (규칙 19–20)** — **GIVEN** 튜토리얼 스크립트 [[D1 얼굴 없음], [I3_H team_slot 0 face 1], [`*` team_slot 1, `*` team_slot 2]] + `after_script = GENERATE`,
  **WHEN** 4번 재충전, **THEN** 1–3번은 스크립트 그대로(1번은 조각 1개 + 빈 칸 2개), 4번은 생성 모드 크루 가방 0번(`seed_crew(0)`)으로 채워진다.
- **AC-15b [Integration] (레벨 데이터 회귀)** — **GIVEN** 각 MVP 스크립트 스테이지와 커밋된 해법 배치 목록, **WHEN** 자동 재생하면, **THEN** 모든 배치가 `can_place = true`이고 막힘 없이 끝난다.
  (스테이지 & 목표 GDD의 스테이지 데이터가 생기면 활성화.)
- **AC-16 [Logic] (규칙 22)** — **GIVEN** `team_slot = 3`(팀 3인)인 스크립트 / `allow_faceless_pieces = false` 스테이지의 `crew = null` 지정 / 카탈로그에 없는 모양 id, **WHEN** 스테이지 로드,
  **THEN** 각각 로드 오류.

**결정성·재현 (규칙 16–18, F3)**

- **AC-17 [Logic] (규칙 17)** — **GIVEN** 같은 (`stage_seed`, 팀, 설정, 배치 목록), **WHEN** 판을 두 번 재생, **THEN** 모든 재충전의 스냅샷이 같다.
  **AND** 해석기 `rng_seed`를 바꿔도 트레이 순서는 같다 (스트림 분리).
- **AC-18 [Logic] (규칙 18, `FIXED`)** — **GIVEN** `FIXED` 스테이지, **WHEN** 원탭 재시작을 3번, **THEN** 첫 트레이가 매번 같다.
  **AND** 팀 슬롯 순서만 바꾼 같은 3인 팀이면, 크루마다 받는 모양 순서열이 원래 팀과 같다 (칸 위치는 비교하지 않는다).
- **AC-19 [Logic] (규칙 18, `PER_ATTEMPT`)** — **GIVEN** `PER_ATTEMPT` 스테이지, **WHEN** 시도 0·1·2, **THEN** `stage_seed`가 서로 다르고 같은 시도 번호면 같다.
- **AC-20 [Logic] (규칙 16)** — **GIVEN** 트레이 모듈 소스, **WHEN** 정적 검사, **THEN** 전역 `randi`/`randf`/`randomize` 호출이 없다.

**교차 시스템 / 지표**

- **AC-21 [Integration] (재충전 후 막힘 — board-rules AC-16 호출 시점 소유)** — **GIVEN** 마지막 트레이 조각으로 줄을 지운 직후(판 진행 흐름 또는 그 커밋 하네스), **WHEN** 해석·연출이 끝나고
  재충전되면, **THEN** `no_moves`는 해석·연출 중 0회, 재충전(구제 적용 후) 트레이로 정확히 1회 호출된다. **AND** 그 3조각이 모두 안 들어가는 픽스처(AC-12)에서는 판이 실패로 끝나고,
  1개라도 들어가는 픽스처에서는 판이 계속된다.
- **AC-22 [Playtest]** (튜닝 입력 — 게이트 아님) — **GIVEN** MVP 10스테이지 × 추천 팀 3종 × 고정 시드 50, **WHEN** 자동 플레이 로그 집계, **THEN** 팀·스테이지별 ρ를 보고하고
  ρ > 0.10인 조합은 스테이지 & 목표 / 크루 정의에 조정 요청으로 기록한다.
- **AC-23 [Perf]** — **GIVEN** 최악 근사 보드(빈칸 10개 흩어짐)와 6칸 모양만 가진 팀, **WHEN** headless 데스크톱에서 `refill`(구제 포함) 1,000회, **THEN** 1회 평균 < 0.5 ms.

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | "다음 트레이" 미리보기(다음 3조각 또는 다음 1조각)를 보여 줄까 — 계획성(기둥 3)↑ vs 정보 과부하·미리보기 퇴화 위험(systems-index 고위험) | game-designer · ux-designer | T0 플레이테스트 후 |
| Q2 | `crew_bag_copies` 1(매 트레이 팀 전원) vs 2(가끔 같은 크루 2개 — 변화↑) — 1이 단조로우면 2로 | game-designer · systems-designer | T0 플레이테스트 |
| Q3 | 구제 보장을 "1개"에서 더 넓힐지(예: 2개), 또는 도전 스테이지에서 끌지 — ρ 측정(F6) 결과에 따름. 숨김이 정직성 문제로 지적되면 결과 화면 등에 공개할지 | systems-designer · creative-director | AC-22 집계 후 |
| Q4 | `FIXED` 시드의 해법 외우기·공유·식상함 — 별 3 획득 후 `PER_ATTEMPT`로 바꾸는 "연습 모드"를 둘지 | game-designer | 스테이지 & 목표 / 메타 화면 설계 시 |
| Q5 | 모양 가방 사이클이 긴 크루(냥이 C 12)에서 희귀 모양 가뭄(F2, 최대 22트레이)이 체감상 너무 긴가 — 사이클 대신 "같은 모양 연속 금지 + 가중 추첨"이 나은가 | systems-designer | T0 자동 플레이 |
| Q6 | `hash32`·스트림 태그 값, `crew_key`, 시드 RNG를 Godot `RandomNumberGenerator`로 할지 자체 PRNG(버전 간 수열 고정)로 할지 | technical-director | 시드 RNG ADR (`/architecture-decision`, chain-resolver Q7과 같은 ADR 권장) |
| Q7 | 스테이지의 "팀 고정"(튜토리얼) 필드와 스크립트의 `crew_id` 직접 지정 허용 범위 | level-designer · 스테이지 & 목표 GDD | `/design-system stage-goals` |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(가중치·확률·시드 = 숫자 규칙)·Edge Cases·Dependencies·AC + Visual/Audio·Game Feel(Gameplay 필수)·UI Requirements·Cross-References(의존 있음)·Open Questions ("All of them" 권장안). Player Fantasy·Tuning Knobs 생략 (값은 규칙 F 표) | Tuning Knobs 섹션 추가 — tier 규칙 위반 |
| D2 | Overview 프레이밍 | Both / ADR 인용 안 함 / Fantasy 있음이나 섹션 생략 | 기술 프레이밍만 |
| D3 | 크루 사이 비율 (컨셉 Open Question "가방") | **크루 가방** k = 1 — 매 트레이 팀 3인 각 1조각 | 독립 추첨(1/3씩) — 한 크루 가뭄이 운으로 느껴짐(F7: 20조각 중 ≤2개 1.8%); k = 2 가방 — 변화↑이지만 "내 팀이 다 나온다" 약화 (Q2) |
| D4 | 크루 안 모양 | **모양 가방**(가중치 = 사이클 안 출현 수) — crew-definition F1을 사이클마다 정확히 | 가중 독립 추첨 — 가뭄 상한 없음; 가중 추첨 + 연속 금지 — 대안으로 Q5에 남김 |
| D5 | 얼굴 위치 (crew-definition D4의 "트레이가 고름") | 모양 칸 중 균등, 얼굴 전용 스트림 | 가장자리/가운데 가중 — 근거 없음, 크루 개성은 모양으로 충분; 줄 완성에 유리한 위치 보정 — 숨은 도움 확대 |
| D6 | 시드 정책 (컨셉 "스테이지 고정 시드") | `FIXED` MVP 기본, `PER_ATTEMPT` 선택 | 매 시도 새 시드 — 재도전이 운 시험, 기둥 3·4 약화; 전역 단일 시드 — 스테이지 설계 불가 |
| D7 | 즉사 재충전 (board-rules Q3) | **최소 구제**: 후보 전부 불가일 때만, 팀 모양으로 가능한 경우만, 1칸, 표시 전, 가방 비소비 | 구제 없음 — 순수하지만 가장 큰 "운 패배"가 남음; 3개 모두 놓을 수 있게 보장 — 난이도 상실·숨은 손 과다; 항상 놓을 수 있는 모양 우선 추첨 — 가중치 왜곡 |
| D8 | 정직성 (preview honesty) | 보인 조각은 절대 바꾸지 않음, 미래 트레이 비공개(MVP) | 트레이 중간 구제 — 보이는 것이 바뀌어 기둥 3 위반 |
| D9 | 구제 표시 | 표시 안 함, 로그만 | "도움" 연출 — 의존·기대 유발; 결과 화면 공개 — Q3 |
| D10 | 시드 파생 | (stage_seed, 스트림, 인덱스) 해시로 뽑기마다 독립 시드 → 구제가 이후 순서를 흔들지 않음 | 판당 RNG 1개 순차 소비 — 구제·스크립트 여부로 이후 전체가 달라져 재현·테스트 어려움 |
| D11 | 스테이지 오버라이드 | `tray_script`(모양 id 또는 `*`, team_slot/crew_id/null, 얼굴 고정/RNG/없음) + `after_script` GENERATE/LOOP, 스크립트엔 구제 없음 | 스테이지별 고정 시드만으로 튜토리얼 — 원하는 순서를 시드 탐색으로 찾아야 함; 스크립트에도 구제 — 설계 의도 훼손 |
| D12 | 플레이어 조작 | MVP에 보관·리롤 없음, 유료 리롤 영구 금지 | 보관 칸 — 범위 증가·재검증 필요 (T2 이후 재검토 가능); 유료 리롤 — 안티 기둥 |
| D14 | F5 예시 보드 (systems-designer 리뷰) | "빈칸 3칸 한 줄뿐" → "3칸 틈 + 외톨이 빈칸들" (결과 동일: F(냥이) = {I3_H}, F(삐약) = {D1, D2_H}) | 원래 문구 — 불변식 13(완성 줄 0)과 모순되는 보드 |
| D13 | 재충전 크기 | `min(tray_size, budget)`, 남는 칸 빈 칸 | 제한 조각을 넘겨 3개 채우고 쓰지 못하게 — 놓을 수 없는 조각 표시는 혼란 |
