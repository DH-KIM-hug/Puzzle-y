# 팀 편성 (Team Composition)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-09 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 4 한 판 더 · 기둥 3 보이는 연쇄

## Summary

팀 편성은 스테이지를 시작하기 전에 보유 크루 중 서로 다른 3인(스테이지가 정하면 1~3인)을 골라 **트레이 조각 풀 + 능력 세트**를 확정하는 시스템이다.
스테이지 제한(인원·고정 크루·금지 크루)을 적용하고, 새 플레이어에게는 기본 보유 3인을, 이후에는 **스테이지별 직전 팀 → 전역 직전 팀 → 기본 3인** 순서로
자동 채운 팀을 내밀어 한 번 탭으로 시작하게 하며, 재도전은 화면 없이 같은 팀으로 시작한다. 궁합은 정답표를 보여주지 않고 각 크루의 사실(능력 도해·조각 모양)과
**플레이어가 실제로 일으킨 연결만 적는 "궁합 노트"**로 알려준다 (기둥 2·3·4).

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `크루 정의 & 능력`, `보유 크루` (upstream), `스테이지 & 목표` (팀 규칙 데이터, soft) — downstream: 판 진행 흐름, 메타 화면 UI, 로컬 세이브, 연쇄 해석기(이벤트 읽기 전용)

## Overview

팀 편성은 컨셉의 "3인 팀 = 트레이에 나오는 조각 풀"을 실제 선택으로 만드는 시스템이다. 데이터 층에서 팀은 **크루 id의 순서 있는 목록**
(`team`, 길이 = 스테이지의 `team_size`, MVP 기본 3)이며, 판 진행 흐름이 이 목록을 트레이 공급 `init(team, …)`에 넘긴다 — 트레이는 팀 편성을 모른다
(systems-index 순환 차단 계약). 팀 편성이 소유하는 것은 (1) **유효한 팀의 규칙**(서로 다른 크루, 보유 또는 스테이지가 빌려준 게스트, 금지 크루 제외,
색 슬롯 중복 금지), (2) **기본 팀 자동 채우기**(새 플레이어 = 기본 보유 3인, 이후 = 직전 팀 기억), (3) **재도전 = 같은 팀 원탭**,
(4) **궁합 노트**(플레이어가 일으킨 A→B 연결의 기록과 표시 규칙), (5) 팀 편성 화면이 보여줘야 할 **정보 목록**이다. 화면 배치·카드 레이아웃은
메타 화면 UI GDD 소관이다.

플레이어 쪽에서 팀 편성은 "이 스테이지를 누구로 풀까"를 고르는 짧고 즐거운 결정이다 (art-bible 2절: 애착, 고르는 즐거움). 기둥 2의
design test(같은 스테이지에서 팀이 다르면 경로가 달라지는가)를 플레이어가 *직접 시험해 볼 수 있는* 유일한 지점이고, 기둥 4(재시도 시 직전 팀
유지 원탭)를 지키기 위해 팀 변경은 항상 **선택**이지 강요가 아니다. 이 시스템이 없으면 크루 6명은 있어도 트레이는 항상 같다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No` (ADR-0001은 Rules Core 일반 원칙 —
팀 편성 전용 ADR 없음; 팀 선택 로직은 ADR-0001의 Rules Core에 순수 함수로 둔다) · Fantasy `[A] Yes`이지만 standard tier라 Player Fantasy 섹션은 생략하고
의도는 이 Overview와 Game Feel에 둔다. 구현 형태(팀 상태를 Autoload에 둘지, 저장 키 형식)는 → ADR / 로컬 세이브 GDD.

*기술 타당성 (Godot 4.7, domain Scripting)*: `docs/engine-reference/godot/modules/`에 `scripting.md`가 없어 고정 엔진 대비 타당성은 확인하지 않았다
(NOT SOURCEABLE). 이 시스템은 크루 id 배열·집합 연산과 저장 데이터 읽기/쓰기뿐이라 엔진 버전 위험은 낮다. ADR-0001(순수 결정적 Rules Core)이
"규칙 계산은 Node 없는 `static func`"을 요구하므로 F1~F4는 모두 그 형태로 구현 가능하게 정의했다.

## Detailed Design

> *Specialist note*: `game-designer` · `art-director` · `narrative-director` · `systems-designer` (Section 6 라우팅: Gameplay → Character systems) not consulted —
> Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 팀의 모양**

1. **팀 = 순서 있는 크루 id 목록** — `team: Array[StringName]`, 길이 = `N` (스테이지 `team_rule.team_size`, 기본 `default_team_size` = 3, 허용 1–3).
   목록 순서 = **팀 슬롯 순서** `team_slot` 0..N−1. 슬롯 순서는 트레이 공급의 `tray_script`(`team_slot` 지정)와 크루 가방 순서에 쓰이므로
   팀의 일부로 저장·재현한다 (tray-supply 규칙 7, F3).
2. **유효한 팀 (F1)** — 다음을 모두 만족해야 시작 버튼이 켜진다:
   1. 길이 = `N`, 빈 슬롯 없음.
   2. **서로 다른 크루** — 같은 id 두 번 금지.
   3. 모든 id가 크루 레지스트리(`CrewRegistry.get`)에 있다.
   4. 각 크루는 **보유**(`is_owned(id)`)이거나 스테이지가 그 슬롯에 고정한 **게스트**다 (규칙 7).
   5. 스테이지 `team_rule.banned`에 있는 크루가 없다.
   6. 스테이지 `team_rule.locked`의 각 (슬롯, 크루)가 그대로 있다.
   7. **팀 안 `colour_slot`이 모두 다르다** (F3). MVP는 레지스트리 전체에서 색 슬롯이 유일하므로(crew-definition 규칙 12) 항상 참이고,
      크루가 6명을 넘는 T2+에서 실제로 작동한다.
3. **팀 크기 1–2** — 튜토리얼·특수 스테이지만 쓴다. 화면에는 `N`개 슬롯만 보인다. 1–2인 팀의 트레이 동작은 tray-supply 규칙 8이 이미 정의한다.
4. **팀은 판 도중 바뀌지 않는다** — 확정(`CONFIRMED`) 이후 그 판이 끝날 때까지 불변. 판 도중 팀 교체·크루 교대 기능은 없다 (재도전 경로로만 바꾼다).

**B. 스테이지 팀 규칙 (스테이지 & 목표 GDD의 `StageDef` 필드 — provisional, 이 문서가 제안)**

5. `StageDef.team_rule` = { `team_size`: int 1–3 (기본 3), `locked`: Array[{ `slot`: int, `crew_id`: StringName }] (기본 빈 목록),
   `banned`: Array[StringName] (기본 빈 목록) }. 필드가 없으면 "3인, 제한 없음". tray-supply가 말한 "팀 고정 여부"는 `locked`가 `team_size`개의
   슬롯을 모두 채운 경우다.
6. **스테이지 데이터 검증 (실패 = 스테이지 로드 오류)** — `locked` 슬롯 번호 < `team_size`, 같은 슬롯 두 번 금지, 같은 크루 두 번 금지, `locked` 크루가
   `banned`에 있으면 오류, `locked` 크루끼리 `colour_slot` 중복이면 오류, 모든 id가 레지스트리에 있음. **린트 (오류는 아님)**: 기본 보유 3인(`starter_ids()`)과
   게스트만으로 유효한 팀을 만들 수 없는 스테이지 — MVP 10스테이지는 반드시 통과해야 한다 (crew-definition 규칙 10 "기본 3인으로 별 1개"의 전제).
7. **게스트 크루** — `locked` 크루가 보유하지 않은 크루면 그 판에만 빌려 쓰는 **게스트**다. 게스트는 보유로 바뀌지 않고, 플레이어가 빼거나 바꿀 수 없으며,
   전역 직전 팀 기억에 들어가지 않는다 (규칙 11). 고정 슬롯은 보유 크루여도 플레이어가 바꿀 수 없다.
8. **금지 크루** — 로스터에서 선택 불가로 보이고 사유("이 스테이지에서는 쉬어요")를 표시한다. 기억된 팀에 금지 크루가 있으면 자동 채우기가 대체한다 (F2).

**C. 기본 팀과 기억**

9. **새 플레이어** — 보유 크루 = `starter_ids()`(냥이·곰곰·삐약, 보유 크루 GDD가 새 세이브에 넣음)이므로 첫 기본 팀은 **[냥이, 곰곰, 삐약]**
   (레지스트리 순서). crew-definition 규칙 17의 "정석 도미노" 팀과 같다.
10. **두 겹 기억** — 팀 편성은 두 기억을 저장 요청한다 (저장 형식은 로컬 세이브 GDD):
    - `last_team_by_stage[stage_id]` — 그 스테이지에서 마지막으로 **시작한** 팀 (게스트 포함, 슬롯 순서 그대로).
    - `last_team_global` — 마지막으로 시작한 팀 중 **3인이고 게스트가 없는** 팀 (규칙 11).
11. **기억 갱신 시점** — 시작 버튼으로 팀이 `CONFIRMED`될 때만 쓴다. 화면을 그냥 나가면(뒤로 가기) 편집 중인 초안은 버리고 기억도 바뀌지 않는다.
    게스트가 있거나 `N` < 3인 팀은 `last_team_by_stage`에만 기록한다 — 튜토리얼 2인 팀이나 빌린 크루가 다음 스테이지의 기본 팀을 오염시키지 않게.
12. **기본 팀 해석 (F2)** — 팀 편성 화면을 열 때마다 기억을 *후보 목록*으로 읽고 현재 스테이지 규칙·현재 보유 상태에 맞춰 다시 계산한다:
    `last_team_by_stage[stage]` → `last_team_global` → `starter_ids()` → 보유 크루(레지스트리 순서). 기억은 "그대로 복원"이 아니라 "우선순위"다 —
    스테이지 규칙이 업데이트되거나 크루가 은퇴해도 깨지지 않는다.
13. **재도전 (원탭, 기둥 4)** — 결과 화면·실패 화면의 재시작은 팀 편성 화면을 거치지 않고 **방금 판의 `team`을 슬롯 순서까지 그대로** 다시 넘긴다
    (`team_for_retry`). F2로 다시 계산하지 않는다 — 같은 팀·같은 `FIXED` 시드면 같은 트레이 순서(tray-supply 규칙 17)라 재도전이 "다시 풀기"가 된다.
    팀 변경은 결과 화면의 보조 버튼("팀 바꾸기")으로 팀 편성 화면을 여는 **선택**이다.
14. **다음 스테이지 / 스테이지 선택에서 진입** — 팀 편성 화면을 F2로 미리 채운 상태로 연다. 화면을 건너뛰지 않는 이유: 스테이지 목표·제한 조각 수·
    팀 제한을 시작 전에 보여줄 곳이 여기뿐이다. 대신 시작 버튼은 미리 채운 팀으로 **바로 누를 수 있어야** 한다 (탭 1회 = 시작).

**D. 편집 조작 (규칙 — 화면 배치는 메타 화면 UI 소관)**

15. 로스터의 보유 크루를 고르면 **첫 빈 슬롯**에 들어간다. 빈 슬롯이 없으면 선택한 슬롯을 교체한다(슬롯을 먼저 고른 경우) — 정확한 제스처는 UX 스펙이 정한다.
16. 팀 슬롯을 고르면 그 크루를 뺀다 (고정 슬롯 제외). 두 슬롯 교환으로 순서를 바꿀 수 있다 (고정 슬롯 제외).
17. 이미 팀에 있는 크루를 다시 고르면 아무 일도 없이 그 슬롯을 강조한다 (중복 금지, 규칙 2.2).
18. 무효한 팀(F1 거짓)이면 시작 버튼은 비활성이고, **왜 안 되는지 한 줄**을 보인다 (빈 슬롯 / 색 겹침 / 금지 크루). 무효 상태로 저장되는 일은 없다.

**E. 궁합 힌트 — "정답표"가 아니라 "사실 + 내가 찾은 연결"**

19. **보여주는 것 (항상)** — 각 크루의 **능력 도해**(얼굴 중심 미니 격자에 대상 칸)와 **조각 모양 미리보기**("자주/가끔" 2단계), 능력 이름·한 줄 설명
    (crew-definition UI Requirements). 플레이어는 이 사실만으로 "냥이 십자가 곰곰 얼굴에 닿겠다"를 스스로 추론할 수 있다 — 기둥 3의 "보이는"은
    배치 순간의 연쇄 미리보기가 책임지고, 팀 편성은 추론 재료를 준다.
20. **보여주지 않는 것** — crew-definition 규칙 16의 방향 궁합표(◎/○/△), 팀 점수·별점·"추천 팀"의 수치 평가, 스테이지별 "이 팀이면 깰 수 있다" 판정,
    배치 위치 힌트. 이유: (a) 궁합표는 T0 자동 플레이로 검증 전인 **가설**이다(crew-definition D14), (b) 정답표를 주면 팀 편성이 "◎ 많은 조합 고르기"로
    퇴화해 기둥 2의 실험이 사라진다, (c) 연쇄 미리보기가 "최고 숫자 찾기"로 퇴화하는 위험(systems-index High-Risk)과 같은 실패를 팀 단계에서 되풀이하지 않는다.
21. **궁합 노트 (발견 기록)** — 플레이어가 **실제로 확정한 배치**에서 크루 A의 능력(또는 A가 낳은 알/털뭉치로 완성된 줄)이 크루 B의 얼굴을 깨운 일을
    순서쌍 (A → B)로 기록한다 (F4). 팀 편성 화면은 **현재 팀 안의** 기록된 쌍을 "냥이 → 곰곰 이어졌어요" 형태로 보여주고, 현재 팀의 나머지 쌍은
    "아직 모르는 연결 N개"로 개수만 보인다 (F5). 미리보기에서만 본 연쇄는 기록하지 않는다 — 노트는 "해 봤다"의 기록이다.
22. 궁합 노트는 **크루 쌍의 사실**만 적는다 — 어떤 스테이지에서 일어났는지, 몇 번인지(표시용 횟수 제외), 점수는 적지 않는다. 같은 크루 쌍 (A → A)도
    기록한다 (보드에 같은 크루 얼굴이 여럿일 수 있음).
23. **튜토리얼 예외** — 튜토리얼 & 힌트 GDD(VS)는 궁합 노트와 별개로 특정 연결을 가르칠 수 있다. 그 경우에도 가르친 연결은 플레이어가 실제로 일으켰을 때
    노트에 기록된다 (튜토리얼이 노트를 직접 쓰지 않는다).

**F. 크루 균형 경고 없음**

24. 팀의 기대 조각 크기 E_T(crew-definition F2, tray-supply F1)나 등급 구성으로 플레이어에게 경고하지 않는다. 모든 유효한 팀은 정당한 선택이다 —
    E_T 범위 관리는 스테이지 설계(스테이지 & 목표)와 `/balance-check`의 일이다. crew-definition Dependencies의 "팀 E_T 경고 여부" 질문에 대한 답: **없음**.

### States and Transitions

팀 편성 세션 (스테이지 1회 진입 단위):

| 상태 | 의미 | 다음 | 조건 |
|---|---|---|---|
| `CLOSED` | 팀 편성 화면 밖 | `EDITING` | 스테이지 선택·다음 스테이지·"팀 바꾸기"로 진입 → F2로 초안 생성 |
| `CLOSED` | — | `CONFIRMED` | 재도전(규칙 13): 직전 판 `team` 그대로, 화면 없음 |
| `EDITING` | 초안 `draft` 편집 중. F1을 매 변경마다 재평가 | `CONFIRMED` / `CLOSED` | 시작 버튼(F1 참) / 뒤로 가기(초안 폐기, 기억 불변) |
| `CONFIRMED` | `team` 확정 — 기억 갱신(규칙 10·11) 후 판 진행 흐름에 전달 | `IN_ROUND` | 판 진행 흐름이 `init` 완료 |
| `IN_ROUND` | 판 진행 중, 팀 불변. 연쇄 이벤트에서 궁합 노트 갱신(F4) | `CLOSED` | 판 종료(클리어·실패·포기) → 결과 화면 |

`EDITING` 안에서 무효(F1 거짓) ↔ 유효는 하위 상태가 아니라 시작 버튼 활성 여부로만 드러난다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 보유 크루 (`crew-ownership.md`, 미작성) | 보유 → 팀 | **최소 계약 (provisional)**: `owned_crew_ids() -> Array[StringName]`(레지스트리 순서), `is_owned(id) -> bool`, 보유 변경 알림 1개. 새 세이브의 보유 = `starter_ids()` | 보유 크루. 팀 편성은 보유를 **쓰지 않는다** |
| 크루 정의 & 능력 | 크루 → 팀 | `CrewRegistry.get/all/starter_ids()`, `colour_slot`, `rarity`, 이름·능력 키, 모양 세트(미리보기용) | 크루 정의 |
| 스테이지 & 목표 (`stage-goals.md`, 작성 중) | 스테이지 → 팀 | `StageDef.team_rule` {`team_size`, `locked`, `banned`} (규칙 5, provisional), 목표 요약·제한 조각 수·별 기준(표시용) | 스테이지 (필드) / 팀 편성 (의미·검증) |
| 판 진행 흐름 (`round-flow.md`, 미작성) | 팀 → 판 흐름 | `CONFIRMED` 시 `team`(슬롯 순서) + `guests` 목록; 재도전 시 `team_for_retry()`; 판 흐름이 트레이 `init(team, …)` 호출 | 판 진행 흐름 (호출 타이밍) / 팀 편성 (내용) |
| 트레이 공급 | 간접 | 트레이는 `team` 목록만 받는다 (tray-supply 규칙 7) — 직접 의존 없음 | 트레이 공급 |
| 연쇄 해석기 | 해석기 → 팀 (읽기 전용) | 확정 배치의 이벤트 목록 `FACE_ACTIVATED`·`CELLS_CLEARED`·`ABILITY_EFFECT`(F4 입력). 미리보기 실행 결과는 받지 않는다 | 해석기 (이벤트 스키마, chain-resolver 규칙 19) |
| 로컬 세이브 (`save-system.md`, 미작성) | 팀 → 세이브 | `last_team_by_stage`, `last_team_global`, `discovered_links` (+ 쌍별 횟수) | 세이브 (형식·버전) / 팀 편성 (의미) |
| 메타 화면 UI (`meta-screens-ui.md`, 미작성) | 팀 → UI | 초안·유효성·무효 사유·로스터 상태(보유/미보유/금지/게스트)·궁합 노트 (UI Requirements 정보 목록) | 메타 화면 UI (배치·제스처) |
| 가챠 | 간접 | 가챠가 보유를 바꾸면 보유 크루 알림 → 다음 팀 편성 화면에 반영. 새 크루는 자동으로 팀에 넣지 않는다 | 보유 크루 |
| 튜토리얼 & 힌트 (VS) | 튜토리얼 → 팀 | 튜토리얼 스테이지는 `team_rule`(인원·고정)로 팀을 정한다 — 별도 API 없음 | 스테이지 데이터 |

## Formulas

> *Specialist note*: `systems-designer` not consulted — 이 실행에는 Agent 도구가 없어 lean mode의 Section D 필수 spawn을 수행하지 못했다. Review manually before production.
> 이 시스템의 "공식"은 수치 곡선이 아니라 결정적 판정·해석 규칙이다. 숫자 규칙은 팀 크기(1–3)와 궁합 노트 개수뿐이다.

**F1. 팀 유효성**

The team_valid formula is defined as:

`team_valid(T, S) = (|T| = N) ∧ distinct(T) ∧ ∀c∈T: [c ∈ R ∧ (owned(c) ∨ c ∈ L_S) ∧ c ∉ B_S] ∧ ∀(i,c)∈L_S: T[i] = c ∧ distinct({slot_colour(c) : c ∈ T})`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T | Array[StringName] | 길이 0–3 | calculated (편집 초안) | 슬롯 순서 팀 (빈 슬롯은 아직 없는 원소) |
| S | StageDef | — | data file (스테이지 & 목표) | 현재 스테이지 |
| N | int | 1–3 | data file (`team_rule.team_size`, 기본 `default_team_size` 3) | 필요한 팀 인원 |
| R | Set[StringName] | MVP 6 | data file (`CrewRegistry`) | 레지스트리 전체 id |
| owned(c) | bool | — | calculated (보유 크루 `is_owned`) | 보유 여부 |
| L_S | Array[(int, StringName)] | 0–N개 | data file (`team_rule.locked`) | 고정 슬롯 (보유 아니면 게스트) |
| B_S | Set[StringName] | 0–(|R|−N)개 | data file (`team_rule.banned`) | 금지 크루 |
| slot_colour(c) | int | 1–`palette_slot_count` (MVP 6) | data file (`CrewDef.colour_slot`) | 크루 색 슬롯 |

**Output Range:** bool. 거짓이면 실패한 첫 조건을 사유 코드로 함께 돌려준다 — 우선순위 `INCOMPLETE` > `DUPLICATE` > `UNKNOWN_CREW` > `NOT_OWNED` > `BANNED` >
`LOCK_MISMATCH` > `COLOUR_CLASH` (UI 문구 1줄, 규칙 18).
**Example:** 스테이지 3 (`team_size` 3, `banned` = [곰곰]), 기억된 팀 [냥이, 곰곰, 삐약] → `BANNED`로 거짓 → F2가 곰곰 자리를 대체.

**F2. 기본 팀 해석 (자동 채우기)**

The resolve_default_team formula is defined as:

`resolve(S) = fill(lock(S), dedupe(M_stage(S) ⧺ M_global ⧺ starter_ids() ⧺ owned_ids()))`

절차 (결정적, 같은 입력 → 같은 팀):
1. `T` = 길이 N의 빈 슬롯. `L_S`의 각 (i, c)를 `T[i]`에 넣는다 (`lock`).
2. 후보 목록 `C` = 기억 스테이지 팀 ⧺ 전역 팀 ⧺ 기본 보유 ⧺ 보유 전체(레지스트리 순서), 앞에서부터 첫 등장만 남김 (`dedupe`).
3. **1차 — 자리 유지**: 기억 스테이지 팀(없으면 전역 팀)의 원래 슬롯 i가 비어 있고 그 크루가 *허용*이면 `T[i]`에 넣는다.
4. **2차 — 빈 슬롯 채우기**: 남은 빈 슬롯을 낮은 번호부터, `C`의 앞에서부터 *허용*이고 아직 `T`에 없는 첫 크루로 채운다.
5. *허용* = `c ∈ R ∧ owned(c) ∧ c ∉ B_S ∧ slot_colour(c) ∉ {slot_colour(x) : x ∈ T}`.
6. 다 채우지 못하면 빈 슬롯을 남긴 채 돌려준다 (F1 = `INCOMPLETE`, 시작 비활성). MVP 데이터에서는 규칙 6 린트가 이를 막는다.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| M_stage(S) | Array[StringName] | 0–3 | calculated (세이브 `last_team_by_stage[S.id]`) | 이 스테이지 직전 팀 |
| M_global | Array[StringName] | 0 또는 3 | calculated (세이브 `last_team_global`) | 전역 직전 팀 (3인·게스트 없음) |
| starter_ids() | Array[StringName] | MVP 3 | data file (`CrewDef.starter`) | 기본 보유 3인, 레지스트리 순서 |
| owned_ids() | Array[StringName] | 3–\|R\| | calculated (보유 크루) | 보유 전체, 레지스트리 순서 |
| N, L_S, B_S, R | — | F1과 같음 | — | — |

**Output Range:** 길이 N의 팀(빈 슬롯 0–N개). 기억이 유효하면 기억과 같은 팀·같은 순서.
**Example:** 기억 스테이지 팀 없음, 전역 [개굴, 냥이, 삐약], 스테이지 `banned` = [냥이] → 1차: 슬롯0 개굴, 슬롯2 삐약 → 2차: 슬롯1에 후보 순서
(개굴, 냥이✗금지, 삐약, 곰곰…)에서 곰곰 → **[개굴, 곰곰, 삐약]**.

**F3. 색 겹침 판정**

The colour_clash formula is defined as:

`colour_clash(T) = ∃ a≠b ∈ T : slot_colour(a) = slot_colour(b)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| slot_colour(c) | int | 1–`palette_slot_count` | data file (`CrewDef.colour_slot`) | art-bible 4절 크루 색 표의 행 |
| palette_slot_count | int | MVP 6 | data file (팔레트 리소스, art-bible 소유) | 색 슬롯 수 |

**Output Range:** bool. 참이면 F1 거짓(`COLOUR_CLASH`, 차단). **명도 띠만 같은 두 크루**(예: 냥이·깡총 = 중간 띠)는 판정하지 않는다 — art-bible 4절은 색약
충돌 쌍을 이미 서로 다른 띠에 두었고, 같은 띠의 쌍은 색상·무늬·윤곽 돌출로 구분된다. 같은 *색 계열*(예: 빨강 두 개) 경고는 팔레트에 `hue_family`가
생기는 T2+에서 Q2로 다룬다.
**Example:** MVP 6명은 색 슬롯 1–6이 모두 달라 어떤 팀도 거짓 (항상 통과). T2에 슬롯 1(빨강)을 공유하는 7번째 크루가 생기면 냥이와 같은 팀 불가.

**F4. 궁합 연결 추출 (판 1회 확정 배치마다)**

The link_extract formula is defined as:

`links(E) = { (crew(o), b.crew_id) : b ∈ cleared_faces(E), b.by ∈ {ABILITY, BOTH}, o = b.source_order ≠ null }`
`        ∪ { (f, b.crew_id) : b ∈ cleared_faces(E), b.by ∈ {LINE, BOTH}, f ∈ egg_crews(line(b), E) }`

- `cleared_faces(E)` = 이벤트 목록 E의 모든 `CELLS_CLEARED.cells` 중 `is_face = true`이고 그 얼굴이 이어서 `FACE_ACTIVATED`된 칸 (깊이 상한으로 `FACE_FIZZLED`된 얼굴 제외).
- `crew(o)` = 같은 판의 `FACE_ACTIVATED` 중 `order_index = o`인 이벤트의 `crew_id`.
- `egg_crews(line(b), E)` = b가 속한 완성 줄(같은 웨이브 `WAVE_BEGIN.rows/cols`) 안에서 같은 `CELLS_CLEARED`에 함께 지워진 `origin = EGG` 칸들의 `crew_id` 집합 — 채우기 크루(삐약·몽실)가 줄을 완성해 깨운 연결 (crew-definition S2).
- 웨이브 0의 줄 지우기(플레이어 배치로 완성)는 알이 없으면 연결을 만들지 않는다 — "플레이어 → B"는 크루 쌍이 아니다.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| E | Array[Event] | — | calculated (연쇄 해석기, 확정 배치 1회) | chain-resolver 규칙 19 이벤트 목록 |
| b.by | enum | `LINE`/`ABILITY`/`BOTH` | calculated | 그 칸을 지운 원인 |
| b.source_order | int \| null | 0– | calculated | 그 칸을 대상으로 삼은 가장 앞 얼굴 |

**Output Range:** 순서쌍 집합, 크기 0 – |R|² (MVP 36). 노트 = 판마다 `discovered_links ∪= links(E)`, 쌍별 횟수 +1 (표시용 상한 `link_count_display_cap` 99).
**Example:** 냥이 얼굴의 십자가 (2,5)의 곰곰 얼굴을 지우고 곰곰이 발동 → `CELLS_CLEARED`의 곰곰 칸 `by = ABILITY`, `source_order` = 냥이의 `order_index` → (냥이 → 곰곰) 기록.

**F5. 궁합 노트 표시 개수**

The note_progress formula is defined as:

`known(T) = |{ (a,b) ∈ T×T : (a,b) ∈ D }|`, `unknown(T) = N² − known(T)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T | Array[StringName] | 길이 N | calculated | 현재 초안 팀 |
| D | Set[(StringName, StringName)] | 0–36 | calculated (세이브 `discovered_links`) | 지금까지 발견한 순서쌍 |
| N | int | 1–3 | data file | 팀 인원 |

**Output Range:** known 0–9, unknown 0–9 (3인 팀). 표시: "궁합 노트 known/N²" + 기록된 쌍 목록 + "아직 모르는 연결 unknown개".
**Example:** 팀 [냥이, 곰곰, 삐약], D = {(냥이→곰곰), (곰곰→삐약), (냥이→개굴)} → known 2 (냥이→개굴은 팀 밖), unknown 7.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 새 세이브로 처음 팀 편성 화면을 열면**: 기억이 없으므로 F2가 `starter_ids()`로 [냥이, 곰곰, 삐약]을 채운다. 보유 크루 GDD가 새 세이브에 기본 3인을 넣지 않았다면(데이터 오류) `INCOMPLETE` + 개발 빌드 에러 로그.
- **If 기억된 팀의 크루가 레지스트리에서 사라졌거나 보유 목록에 없으면** (세이브 손상·다운그레이드): 그 크루는 *허용*이 아니므로 F2가 건너뛰고 다른 후보로 채운다. 기억 자체는 다음 `CONFIRMED`까지 그대로 둔다 (조용히 지우지 않음).
- **If `RETIRED` 크루를 보유하고 있으면**: 정상적으로 고를 수 있다 (crew-definition: 은퇴는 가챠에서만 빠짐).
- **If 스테이지가 기억된 팀의 크루를 금지하면**: F2가 그 자리를 대체한다 (F2 예시). 다른 스테이지에서는 기억대로 돌아온다 — 전역 기억은 금지 때문에 바뀌지 않는다 (대체 팀으로 시작하면 그 3인이 새 전역 기억이 된다).
- **If 스테이지 고정 크루를 보유하지 않았으면**: 게스트로 그 슬롯에 들어간다. 판이 끝나도 보유가 되지 않고, `last_team_global`에 들어가지 않는다.
- **If 고정 크루가 기억된 팀의 다른 슬롯에 있으면**: 고정이 우선 — F2 1단계가 고정 슬롯을 먼저 채우고, 같은 크루는 dedupe로 원래 슬롯에서 빠진다.
- **If 고정 크루(게스트 포함)와 보유 크루가 같은 `colour_slot`이면** (T2+): 보유 크루를 그 판에 넣을 수 없다 (`COLOUR_CLASH`). 스테이지 린트가 고정끼리의 충돌만 오류로 잡고, 이 경우는 F2가 다른 후보로 피한다.
- **If 보유 크루 + 게스트로 N명을 채울 수 없으면**: 시작 비활성 + "크루가 더 필요해요" 사유. MVP 10스테이지는 규칙 6 린트로 불가능해야 한다.
- **If `team_size`가 1–2인 스테이지에서 3인 기억이 있으면**: F2가 기억 순서 앞에서부터 N명만 쓴다. 이 판의 팀은 `last_team_global`을 바꾸지 않는다 (규칙 11).
- **If 플레이어가 팀을 바꾸다 뒤로 가기를 누르면**: 초안 폐기, 기억 불변. 다음 진입에서 F2가 같은 기본 팀을 다시 만든다.
- **If 재도전 직전에 가챠로 새 크루를 얻었으면** (결과 화면 → 가챠 → 재도전 경로가 있다면): 재도전은 직전 판 팀 그대로다. 새 크루는 자동으로 팀에 들어가지 않는다 — "팀 바꾸기"로 넣는다.
- **If 재도전인데 그 사이 보유가 바뀌어 직전 팀이 무효가 됐으면** (MVP에서는 보유가 줄지 않으므로 손상 시에만): `team_for_retry`가 F1을 검사해 거짓이면 재도전 대신 팀 편성 화면을 F2 초안으로 연다.
- **If 같은 팀을 슬롯 순서만 바꿔 시작하면**: 다른 팀으로 취급해 기억을 갱신한다. 트레이 첫 순서가 달라질 수 있다 (tray-supply F3: 크루 가방 순서만 변함, 크루별 모양 순서는 같음).
- **If 판이 포기(중단)로 끝나면**: `CONFIRMED` 때 이미 기억했으므로 기억은 그 팀이다. 궁합 노트는 포기 전까지 확정된 배치의 연결만 남는다.
- **If 깊이 상한으로 B 얼굴이 `FACE_FIZZLED`되면**: (A → B)를 기록하지 않는다 — 깨웠지만 이어지지 않았다. 다음 웨이브가 없으므로 연결이 플레이어에게 보이지 않았다.
- **If 한 칸이 줄과 능력에 동시에 지워지면** (`by = BOTH`): F4의 두 분기 모두 적용 — 능력 원인 A와 줄 안 알의 크루가 모두 B와 연결된다.
- **If 팀 밖 크루가 연결에 끼면** (스테이지 초기 보드의 얼굴): 정상 기록. 노트 표시는 현재 팀 안의 쌍만 세지만(F5), 데이터는 남아 그 크루를 팀에 넣으면 보인다.
- **If 튜토리얼 스크립트 판에서 연결이 생기면**: 일반 판과 같이 기록한다 (규칙 23).
- **If 미리보기로만 연결을 보고 배치를 취소하면**: 기록하지 않는다 (규칙 21).
- **If 플레이어가 궁합 노트를 "공략" 삼아 모든 쌍을 채우려 하면**: 의도된 수집 동기다 (36쌍 중 실제 불가능한 쌍이 있으면 Q3).

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 크루 정의 & 능력 (`crew-definition.md`) | Hard | 레지스트리 id, `starter_ids()`, `colour_slot`(규칙 12 — MVP 유일, T2+ 팀 안 유일은 이 문서가 처리), 표시 데이터 | Designed |
| 보유 크루 (`crew-ownership.md`) | Hard | `owned_crew_ids()`, `is_owned()`, 변경 알림, 새 세이브 = 기본 3인 | **미작성 — 최소 계약 provisional** (Interactions 표) |
| 스테이지 & 목표 (`stage-goals.md`) | Soft (없으면 "3인·제한 없음") | `StageDef.team_rule` 필드, 표시용 목표 요약 | **작성 중 — 필드 제안 provisional** |
| 연쇄 해석기 (`chain-resolver.md`) | Soft (궁합 노트만) | 이벤트 스키마 `CELLS_CLEARED.by/source_order/origin`, `FACE_ACTIVATED.order_index` | Designed |

**Downstream (이 시스템에 의존)**

| 시스템 | 강도 | 쓰는 것 | 이 문서가 기대하는 것 |
|---|---|---|---|
| 판 진행 흐름 (`round-flow.md`) | Hard | 확정 `team`, `guests`, `team_for_retry()` | 재도전은 팀 편성 화면을 거치지 않음; `team`을 트레이 `init`에 그대로 전달 |
| 메타 화면 UI (`meta-screens-ui.md`) | Hard | UI Requirements의 정보 목록, F1 사유 코드, F5 개수 | 시작 버튼 탭 1회로 기본 팀 시작 가능 |
| 로컬 세이브 (`save-system.md`) | Hard | `last_team_by_stage`, `last_team_global`, `discovered_links`(+횟수) | 버전 필드, 알 수 없는 crew id는 무시 |
| 화면 흐름 (`scene-flow.md`) | Soft | 팀 편성 화면 진입 경로 3개(스테이지 선택·다음 스테이지·팀 바꾸기), 재도전 경로는 화면 생략 | Android 뒤로 가기 = 초안 폐기 |
| 튜토리얼 & 힌트 (VS) | Soft | `team_rule`로 튜토리얼 팀 고정 | 노트를 직접 쓰지 않음 |
| 스티커 앨범 (T2) | Soft | `discovered_links` (도감에 궁합 페이지를 둘 경우) | 선택 사항 |

**양방향성**: systems-index #14 Depends On "크루 정의, 보유 크루"와 일치. #11 판 진행 흐름·#21 메타 화면 UI가 팀 편성을 Depends On에 적어 일치.
**불일치 2건 (index 갱신 제안, 이 문서에서 처리)**: (1) 팀 편성은 스테이지 & 목표의 `team_rule`을 soft로 읽는다 — #14 Depends On에 "스테이지 & 목표 (soft)" 추가 권장.
스테이지 & 목표는 팀 편성에 의존하지 않으므로 순환 없음. (2) 궁합 노트가 해석기 이벤트를 읽는다 — 이벤트는 판 진행 흐름 경유로 받으므로 index 변경은 불필요(판 흐름이 이미 해석기에 의존).
crew-definition Dependencies의 "팀 편성: T2+ 색 중복 경고 규칙, 팀 E_T 경고 여부" → 이 문서 F3(차단, 경고 아님)·규칙 24(E_T 경고 없음)로 응답.

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Lean mode (팀 편성 화면은 판 판독의 핵심 시각이 아님). art-bible 2절 "팀 편성 / 앨범" 무드를 따른다. Review manually before production.

- **무드** (art-bible 2절): 중성~따뜻, 저대비, 앨범 페이지 크림색, 차분한·소중한·정리된. 비닐 포켓에 스티커를 꽂는 느낌 — 슬롯 = 비닐 포켓 3칸.
- **크루 카드**: 크루 색 본색 테두리 + 몸통 무늬 + 윤곽 돌출이 그대로 보여야 한다 (색약 백업 세 겹, art-bible 3·4절). 희귀 이상은 홀로 테두리(UI 전용).
- **팀 슬롯에 넣기**: 스티커가 포켓에 "착" 꽂히는 짧은 동작 + 종이 마찰음. 빼기는 반대로 "쏙".
- **게스트 크루**: 다른 질감의 "빌린 스티커" 표시(예: 마스킹테이프 띠 + "게스트" 잉크 글씨). 자물쇠 아이콘은 고정 슬롯에만.
- **금지 크루**: 채도만 낮추고(어둡게 하지 않음, art-bible 2절 "실패도 어두워지지 않는다"와 같은 원칙) "쉬는 중" 졸린 표정 스티커.
- **미보유 크루**: 실루엣(흑백 윤곽) + "스티커 팩에서 만날 수 있어요". 실루엣만으로도 크루가 구분되는 것은 art-bible 3절이 보장한다.
- **궁합 노트**: 메모지 스티커에 손글씨풍 잉크로 "냥이 → 곰곰". 새 연결이 기록된 직후 첫 진입에서는 해당 줄에 금색 `#ffe278` 별 스티커 하나(보상 색 — art-bible 4절).
- **색 겹침 (T2+)**: 빨강 경고색 금지(art-bible 4절 — 빨강은 냥이 색). 두 카드 사이에 잉크 점선 + 한 줄 사유.
- **오디오**: 크루를 슬롯에 넣으면 그 크루의 짧은 의성어(crew-definition: 냥 / 웅 / 삐약 / 개굴 / 깡 / 몽)를 작게. 시작 버튼 = 스티커북 덮는 소리.
- 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:team-composition` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

- **기본 경로는 탭 1회**: 팀 편성 화면이 열리면 기본 팀이 이미 슬롯에 있고 시작 버튼이 활성 — 바꾸지 않을 사람은 생각 없이 넘어간다 (기둥 4).
  재도전은 화면 자체가 없다 — 결과 화면 재시작 → 판 시작까지 팀 편성이 추가하는 시간 0 s.
- **바꾸는 사람에게는 즉시 반응**: 카드 탭 → 슬롯에 들어가는 동작 ≤ 0.2 s, 유효성·궁합 노트 개수 갱신은 같은 프레임. 시작 버튼이 켜지고 꺼지는 것이 보여야 한다.
- **고르는 즐거움** (art-bible 2절 "애착"): 슬롯에 들어간 크루가 짧은 발동 표정을 짓는다 — 크루가 "나 데려가?"에 답하는 느낌. 3인이 다 차면 세 크루가 서로를 본다(작은 연출).
- **정답을 주지 않는 다정함**: 무효 팀 사유는 혼내는 말투가 아니라 안내("빈 자리가 하나 있어요"). 궁합 노트의 "아직 모르는 연결 N개"는 숙제가 아니라 호기심 문구.

## UI Requirements

이 섹션은 팀 편성 화면이 **무엇을 보여줘야 하는가**만 정한다. 배치·크기·제스처·전환은 메타 화면 UI GDD와 `/ux-design` 스펙 소관이다.

**정보 요구 (우선순위 순)**

| # | 정보 | 출처 | 필수 여부 |
|---|---|---|---|
| I1 | 팀 슬롯 N개 — 크루 얼굴·이름, 고정(자물쇠)·게스트 표시 | 이 문서 규칙 1·7 | 필수 |
| I2 | 시작 버튼 (활성/비활성) + 무효 사유 한 줄 | F1 사유 코드 | 필수 |
| I3 | 스테이지 요약 — 스테이지 이름, 목표 요약, 제한 조각 수, 별 기준, 현재 별 | 스테이지 & 목표 / 스테이지 진행 | 필수 |
| I4 | 스테이지 팀 제한 — 인원, 고정 크루, 금지 크루 (있을 때만) | `team_rule` | 조건부 필수 |
| I5 | 로스터 — 보유 크루 카드 (상태: 팀에 있음 / 선택 가능 / 금지 / 색 겹침). 미보유는 실루엣 | 보유 크루, F1 | 필수 |
| I6 | 크루 상세 — 능력 도해(미니 격자), 능력 이름·한 줄 설명, 조각 모양 미리보기("자주/가끔"), 등급 | crew-definition UI Requirements | 필수 (카드 길게 누르기 또는 선택 시 패널) |
| I7 | 궁합 노트 — 현재 팀 안의 기록된 연결 목록, "known/N²", "아직 모르는 연결 N개" | F5 | 필수 (접을 수 있어도 됨) |
| I8 | "직전 팀" 표시 — 지금 슬롯이 기억에서 왔음을 작게 | F2 | 선택 |

**금지 표시**: 궁합표 기호(◎/○/△), 팀 점수·추천 별점, "이 팀으로 클리어 가능" 판정, E_T·가중치 숫자 (규칙 20·24).
**접근성**: 카드·슬롯 터치 대상 ≥ 64px (art-bible 3절). 상태(금지·게스트·색 겹침)는 색만으로 구분하지 않는다 — 아이콘 + 텍스트.

> **📌 UX Flag — 팀 편성 (Team Composition)**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the
> team-select screen (`design/ux/team-select.md`) — it shares the crew card with crew-definition's UX Flag — **before** writing epics. Stories that reference UI
> should cite `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 이 문서의 참조 | 대상 GDD / 문서 | 대상 섹션 | 관계 |
|---|---|---|---|
| 3인 팀 = 조각 풀, 재시도 = 직전 팀 원탭 | `design/gdd/game-concept.md` | Pillar 2·4, Core Loop Short-Term, MVP Required 3 | 일치 |
| 기본 보유 3인, 색 슬롯 유일(MVP), T2+ 팀 안 유일 위임 | `design/gdd/crew-definition.md` | 규칙 10·12·17, Edge Cases(colour_slot) | F3로 응답 |
| 궁합표는 가설 | `design/gdd/crew-definition.md` | 규칙 15–16, Decision Log D14 | UI에 노출하지 않음 (규칙 20) |
| 팀 E_T 경고 여부 | `design/gdd/crew-definition.md` | Dependencies(팀 편성 행), F2 | 경고 없음 (규칙 24) |
| 크루 카드 정보 | `design/gdd/crew-definition.md` | UI Requirements | I6이 그대로 사용 |
| 트레이 입력 `team`, 슬롯 순서, 1–2인 팀 | `design/gdd/tray-supply.md` | 규칙 7·8·22, F3, Edge Cases | 일치 — 팀은 목록으로만 전달 |
| "팀 고정 여부" 스테이지 필드 | `design/gdd/tray-supply.md` | Interactions(스테이지 행), 규칙 22 | `team_rule.locked`로 구체화 (provisional) |
| 같은 팀 + FIXED 시드 = 같은 트레이 | `design/gdd/tray-supply.md` | 규칙 17, Edge Cases(재도전) | 재도전이 F2를 거치지 않는 근거 |
| 이벤트 스키마 | `design/gdd/chain-resolver.md` | 규칙 19 | F4 입력 |
| 팀 편성 무드, 홀로 테두리, 같은 팀 색 경고 제안 | `design/art/art-bible.md` | 2절 무드 표, 4절 Color System | 색 슬롯 동일 = 차단, 명도 띠만 같음 = 판정 안 함 (F3, D6) |
| Rules Core 순수 함수 | `docs/architecture/adr-0001-pure-deterministic-rules-core.md` | Decision | F1–F5는 static func로 구현 |
| `team_rule` 필드 | `design/gdd/stage-goals.md` (작성 중) | — | 제안 계약 |
| 보유 계약 | `design/gdd/crew-ownership.md` (미작성) | — | 제안 계약 |
| 재도전·init 호출 | `design/gdd/round-flow.md` (미작성) | — | 제안 계약 |
| 화면 배치 | `design/gdd/meta-screens-ui.md` (미작성) | — | 정보 목록만 넘김 |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — 이 실행에는 Agent 도구가 없어 lean mode의 Section H 필수 spawn을 수행하지 못했다. Review manually before production.

- **AC-T01 [Logic] (규칙 9, F2)** — **GIVEN** 새 세이브(보유 = 기본 3인, 기억 없음), 제한 없는 스테이지, **WHEN** `resolve`, **THEN** 팀 = [nyangi, gomgom, piyak]이고 F1 참.
- **AC-T02 [Logic] (규칙 2.2)** — **GIVEN** 초안 [nyangi, gomgom, —], **WHEN** nyangi를 다시 선택, **THEN** 초안 불변, F1 = `INCOMPLETE`.
- **AC-T03 [Logic] (규칙 2.4)** — **GIVEN** 보유 = 기본 3인, **WHEN** 초안에 gaegul(미보유, 고정 아님)을 넣으려 함, **THEN** 거부되고 F1을 직접 호출하면 `NOT_OWNED`.
- **AC-T04 [Logic] (규칙 2.5, F2)** — **GIVEN** 전역 기억 [gaegul, nyangi, piyak], 보유 6명, 스테이지 `banned = [nyangi]`, **WHEN** `resolve`, **THEN** [gaegul, gomgom, piyak].
- **AC-T05 [Logic] (규칙 7, F2)** — **GIVEN** 보유 = 기본 3인, 스테이지 `locked = [{slot: 0, crew_id: mongsil}]`, **WHEN** `resolve`, **THEN** 팀 = [mongsil, nyangi, gomgom] (슬롯 0 게스트, 슬롯 1·2는 후보 목록 앞에서부터), F1 참, `guests = [mongsil]`.
- **AC-T06 [Logic] (규칙 11)** — **GIVEN** AC-T05의 팀으로 시작(`CONFIRMED`), **WHEN** 이어서 제한 없는 다른 스테이지의 `resolve`, **THEN** mongsil은 팀에 없고 `last_team_global`은 시작 전 값과 같다; 같은 스테이지 재진입 시에는 [mongsil, …]이 복원된다.
- **AC-T07 [Logic] (규칙 10, F2 1차)** — **GIVEN** `last_team_by_stage[s3] = [piyak, gaegul, nyangi]`, `last_team_global = [nyangi, gomgom, piyak]`, **WHEN** s3 `resolve`, **THEN** [piyak, gaegul, nyangi] (스테이지 기억 우선, 슬롯 순서 유지); s4(기억 없음)는 [nyangi, gomgom, piyak].
- **AC-T08 [Logic] (규칙 11)** — **GIVEN** `EDITING`에서 초안을 바꿈, **WHEN** 뒤로 가기, **THEN** 두 기억 모두 바뀌지 않고 다음 `resolve` 결과가 이전과 같다.
- **AC-T09 [Logic] (규칙 13)** — **GIVEN** 팀 [gomgom, piyak, nyangi]로 판을 마침, 그 사이 `last_team_by_stage`를 다른 값으로 덮어쓴 테스트 더블, **WHEN** `team_for_retry`, **THEN** [gomgom, piyak, nyangi] 순서 그대로(F2 미사용).
- **AC-T10 [Integration] (규칙 13, tray-supply 규칙 17)** — **GIVEN** `FIXED` 시드 스테이지에서 판 1을 마침, **WHEN** 결과 화면 재시작, **THEN** 팀 편성 화면이 나타나지 않고 판 2의 첫 3번 재충전 스냅샷이 판 1과 같다.
- **AC-T11 [Logic] (규칙 3, F2)** — **GIVEN** 전역 기억 3인, 스테이지 `team_size = 2`, **WHEN** `resolve`, **THEN** 기억의 앞 2명; 그 팀으로 시작 후 `last_team_global` 불변.
- **AC-T12 [Logic] (F3)** — **GIVEN** 테스트 레지스트리에 `colour_slot` 1인 크루 X(보유) 추가, **WHEN** 초안 [nyangi, X, piyak], **THEN** F1 = `COLOUR_CLASH`; MVP 레지스트리의 모든 3인 조합 20개는 F3 거짓.
- **AC-T13 [Logic] (규칙 6)** — **GIVEN** `locked` 크루가 `banned`에도 있는 스테이지 / `locked.slot ≥ team_size` / 고정 크루 둘의 색 슬롯이 같은 스테이지, **WHEN** 스테이지 로드, **THEN** 각각 로드 오류; MVP 10스테이지는 모두 "기본 3인 + 게스트로 유효 팀" 린트 통과.
- **AC-T14 [Logic] (F4, 능력 분기)** — **GIVEN** 냥이 얼굴의 십자에 곰곰 얼굴이 있는 고정 보드, **WHEN** 확정 배치로 냥이 발동 → 곰곰 발동, **THEN** `discovered_links`에 (nyangi → gomgom) 추가, 횟수 1.
- **AC-T15 [Logic] (F4, 알 분기)** — **GIVEN** 삐약 알이 마지막 빈칸을 채워 완성한 줄에 개굴 얼굴이 있는 보드, **WHEN** 연쇄 해석, **THEN** (piyak → gaegul) 추가.
- **AC-T16 [Logic] (F4 제외 조건)** — **GIVEN** (a) 미리보기만 하고 취소한 배치, (b) 깊이 상한으로 `FACE_FIZZLED`된 얼굴, (c) 알 없이 플레이어 배치로 완성된 웨이브 0 줄의 얼굴, **WHEN** 각각 처리, **THEN** 연결 추가 0건.
- **AC-T17 [Logic] (F5)** — **GIVEN** D = {(nyangi→gomgom), (gomgom→piyak), (nyangi→gaegul)}, **WHEN** 팀 [nyangi, gomgom, piyak]의 노트 계산, **THEN** known 2, unknown 7.
- **AC-T18 [UI] (규칙 14, Game Feel)** — **GIVEN** 다음 스테이지 진입, **WHEN** 팀 편성 화면이 열림, **THEN** 기본 팀이 채워져 있고 시작 버튼이 활성이며 탭 1회로 판이 시작된다 — 스크린샷 `production/qa/evidence/`.
- **AC-T19 [UI] (규칙 20, UI Requirements)** — **GIVEN** 어떤 팀 초안이든, **WHEN** 팀 편성 화면을 검사, **THEN** ◎/○/△ 기호·팀 점수·추천 판정·가중치 숫자가 없고, I1–I7이 모두 보인다 — 스크린샷.
- **AC-T20 [Playtest] (기둥 2 design test 1, 튜닝 입력 — 게이트 아님)** — **GIVEN** 외부 테스터 5명 이상, 크루 6명 보유 세이브, **WHEN** 같은 스테이지를 2회 이상 플레이, **THEN** 팀을 한 번 이상 바꾼 테스터 비율과 "팀이 달라서 다르게 풀었다"고 말한 비율을 보고 (`/playtest-report`).

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 보유 크루 최소 계약(`owned_crew_ids`, `is_owned`, 변경 알림, 새 세이브 = 기본 3인)을 보유 크루 GDD가 그대로 채택하는가 | systems-designer · 보유 크루 GDD | `/design-system crew-ownership` |
| Q2 | T2+ 같은 *색 계열*(다른 슬롯이지만 비슷한 hue) 경고가 필요한가 — 팔레트에 `hue_family`를 둘지, 아니면 "슬롯 동일 = 차단"만으로 충분한가 | art-director · game-designer | T2 크루 7번째 추가 시 |
| Q3 | 궁합 노트 36쌍 중 규칙상 불가능하거나 극히 드문 쌍(예: 몽실 → X)이 있으면 "모르는 연결"이 영원히 남아 좌절이 될 수 있다 — 불가능 쌍을 분모에서 뺄지, 노트를 팀 안 9쌍 표시로만 둘지(현재) | game-designer · systems-designer | T0 자동 플레이 (crew-definition AC-17과 같은 로그) |
| Q4 | 궁합 노트가 너무 숨겨져 새 플레이어가 팀을 바꿀 이유를 못 찾으면, 튜토리얼에서 연결 1개를 시연할지 / 스테이지 선택에 "추천 팀" 프리셋(crew-definition 규칙 17)을 수치 평가 없이 노출할지 | game-designer · ux-designer | 첫 외부 플레이테스트 (AC-T20) |
| Q5 | `StageDef.team_rule` 필드 이름·형태가 스테이지 & 목표 GDD와 일치하는가 (tray-supply 규칙 22의 `crew_id` 직접 지정 조건 = `locked`가 그 슬롯을 고정한 경우로 해석) | 스테이지 & 목표 GDD 작성자 | `/design-system stage-goals` 완료 시 `/consistency-check` |
| Q6 | 궁합 노트의 소유자 — 팀 편성(현재)인가, 기록/통계 시스템(T3 월드맵 & 기록)인가. T3에서 이관하면 세이브 마이그레이션 필요 | producer · systems-designer | T3 설계 시 |
| Q7 | 결과 화면에서 가챠로 갔다 돌아온 뒤 "재도전"이 가능한 흐름인지 (Edge Case) — 화면 흐름이 결과 화면 상태를 유지하는가 | 화면 흐름 GDD | `/design-system scene-flow` |

### Decision Log (사용자 위임 — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(팀 크기·판정·노트 개수 = 숫자 규칙)·Edge Cases·Dependencies·AC + Visual/Audio·Game Feel(Gameplay 필수)·UI Requirements·Cross-References·Open Questions. Player Fantasy·Tuning Knobs 생략 | Formulas 생략 — 팀 크기 1–3과 노트 개수가 숫자 규칙이라 §1 기준상 필요 |
| D2 | Overview 프레이밍 | Both / ADR 미인용(전용 ADR 없음, ADR-0001은 Cross-References에) / Fantasy 있음이나 tier상 섹션 생략 | 기술 프레이밍만 — Gameplay라 player-facing 우선 |
| D3 | 팀 유효 조건 | 서로 다른 3인 + 보유 또는 게스트 + 금지 아님 + 고정 일치 + 색 슬롯 중복 금지 | 같은 크루 2명 허용 — 크루 가방 "트레이마다 팀 전원"(tray-supply)과 "팀이 다르면 트레이가 다르다"가 흐려짐; 3인 미만 자유 허용 — 쉬운 길(큰 조각 크루 1명)로 퇴화 가능 |
| D4 | 스테이지 제한 형태 | `team_rule` {`team_size`, `locked`, `banned`} — 고정 크루가 미보유면 게스트 | 필수 크루 "중 1명 포함"식 조건 — 판정·자동 채우기 복잡, MVP 불필요; 게스트 불허(고정은 보유 크루만) — 튜토리얼·신규 크루 시연 스테이지 불가 |
| D5 | 기억 범위 | 스테이지별 + 전역 두 겹, 열 때마다 F2로 재해석 | 전역만 — 스테이지마다 팀을 바꾸는 플레이어가 매번 다시 고름; 스테이지별만 — 처음 가는 스테이지에 직전 팀이 안 따라옴 |
| D6 | 색 겹침 (art-bible 제안 "같은 색 계열 또는 같은 명도 띠면 경고만") | 색 슬롯 동일 = **차단**, 명도 띠만 같음 = 판정 안 함, 색 계열 경고는 T2 Q2 | 경고만 — 같은 색 두 크루면 트레이·연출에서 크루 판독(기둥 3)이 깨져 경고로 부족; 명도 띠 경고 — MVP 15쌍 중 3쌍(삐약·몽실, 냥이·깡총, 곰곰·개굴)에서 상시 경고 = 소음, 이 쌍들은 art-bible이 이미 안전하게 배치 |
| D7 | 재도전 | 화면 생략, 직전 판 팀·순서 그대로, F2 미사용; 팀 변경은 결과 화면 보조 버튼 | 재도전 때도 팀 편성 화면 표시 — 기둥 4 design test 위반 |
| D8 | 다음 스테이지 진입 | 팀 편성 화면을 미리 채워 표시 (탭 1회 시작) | 화면 건너뛰기 — 스테이지 목표·팀 제한을 보여줄 곳이 없음 |
| D9 | 궁합 힌트 | 사실(능력 도해·모양)은 항상 + 궁합표 미노출 + 실제로 일으킨 연결만 기록하는 궁합 노트 | 궁합표(◎/○/△) 노출 — 검증 전 가설이고 "◎ 많은 팀 고르기"로 퇴화; 추천 팀·팀 점수 — 스테이지를 대신 풀어 줌; 힌트 없음 — 6명·연쇄 규칙을 처음 보는 플레이어가 바꿀 이유를 못 찾음 (Q4로 추적) |
| D10 | 노트 기록 기준 | 확정 배치만, 능력 원인 + 알이 완성한 줄 원인, 깊이 상한 소멸 제외 | 미리보기 포함 — 드래그로 쓸어 보기만 해도 노트가 차서 "해 봤다"가 아님; 능력 원인만 — 채우기 크루(삐약·몽실)의 연결이 영원히 기록되지 않음 |
| D11 | 팀 균형 경고 | 없음 (E_T·등급 경고 모두 안 함) | E_T 범위 밖 경고 — 정당한 실험을 말림, 수치 노출은 안티 기둥("과금 = 수치") 쪽 사고를 부름 |
| D12 | 기억 갱신 시점 | 시작(`CONFIRMED`) 때만; 게스트·3인 미만은 스테이지 기억에만 | 편집할 때마다 저장 — 뒤로 가기로 취소해도 바뀜; 결과 후 저장 — 포기·크래시 때 기억 손실 |
| D13 | 보유 크루 인터페이스 | 최소 계약 3개(목록·조회·알림), 팀 편성은 읽기만 | 팀 편성이 기본 3인 지급 — 소유 책임 분산 |
| D14 | 미보유 크루 표시 | 로스터에 실루엣으로 표시 (선택 불가) | 숨김 — 가챠 동기(컨셉 Retention Curiosity) 상실; 정보 전부 공개 — 실루엣 정도가 기대감에 맞음, 최종은 UX 스펙 |
