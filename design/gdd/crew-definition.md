# 크루 정의 & 능력 (Crew Definition & Abilities)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Creative Director Review (CD-GDD-ALIGN)**: NOT ASSESSED 2026-11-07 — skipped (review_mode lean; not a PHASE-GATE)
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛

## Summary

크루 한 명을 코드 없는 데이터 리소스 `CrewDef` 한 장(id·이름·색 슬롯·등급·조각 모양 세트와 가중치·연쇄 해석기 프리미티브로 조합한 얼굴 능력·아트 식별자)으로
정의하고, 로드 시 검증 규칙과 MVP 크루 6명 — 냥이(십자), 곰곰(3×3), 삐약(자기 줄에 알 3개), 개굴(X자 대각선), 깡총(두 칸 건너 8방향), 몽실(십자 털뭉치 채우기) — 및
궁합표를 정한다. 플레이어에게 크루는 "팀에 넣으면 트레이에 나오는 조각 모양 + 얼굴이 지워질 때 터지는 능력"이며, 등급은 수치가 아니라 동작의 독특함이다 (기둥 2·3).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `연쇄 해석기 & 능력 프리미티브`, `보드 & 조각 규칙` (upstream) — downstream: 트레이 공급, 팀 편성, 보유 크루, 가챠, 스테이지 & 목표, 크루 레벨업, 스티커 앨범

## Overview

크루 정의는 말랑 크루의 **크루 한 명 = 데이터 한 장**을 정한다. 데이터 층에서 크루는 Custom Resource `CrewDef` 하나로,
고정 id·이름·색 슬롯·등급·**조각 모양 세트와 가중치**·**얼굴 능력(연쇄 해석기의 능력 프리미티브 호출 목록)**·아트 식별자
(얼굴 윤곽 돌출, 몸통 무늬)를 담는다. 크루는 코드를 갖지 않는다 — 능력은 chain-resolver가 소유한 프리미티브 7종을
조합한 데이터일 뿐이고, 모양은 board-rules의 `PieceShape` 형식을 따른다. 그래서 새 크루 추가는 리소스 파일 1장 + 아트이며
해석기·미리보기·보드 규칙은 바뀌지 않는다. 플레이어 쪽에서 크루는 **팀에 넣으면 트레이에 나오는 조각 모양과,
그 얼굴이 지워질 때 터지는 능력의 묶음**이다 (컨셉: "3인 팀 = 트레이에 나오는 조각 풀"). 이 문서는 MVP 크루 6명
— 냥이(십자), 곰곰(3×3), 삐약(자기 줄에 알), 개굴(X자 대각선), 깡총(두 칸 건너 뛰기), 몽실(십자 모양 털뭉치 채우기) — 과
그들의 조합 궁합을 정한다. 이 시스템이 없으면 "크루가 곧 전략"(기둥 2)의 재료가 없다: 팀이 바뀌어도 트레이와 연쇄가 같다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing) · ADR ref `[B] No`
(`docs/architecture/adr-*.md` 없음 — 컨셉 Next Steps의 "데이터 기반 크루 정의 ADR" 후보) · Fantasy `[A] Yes`이지만 standard
tier라 Player Fantasy 섹션은 생략하고 의도는 Overview·Visual/Audio에 둔다. 구현 형태(`CrewDef`의 하위 리소스 분할, 능력 단계를
Custom Resource로 둘지 Dictionary로 둘지, 레지스트리 로딩 방식)는 → ADR 대상 (chain-resolver Q7과 같은 ADR에서 결정 권장).

*기술 타당성 (Godot 4.7, domain Scripting)*: `docs/engine-reference/godot/modules/`에 `scripting.md`가 없어 고정 엔진 대비 타당성은 확인하지 않았다.
관련 참고: 4.5 `Resource.duplicate_deep()` 추가(중첩 리소스 복제 — 런타임 불변 보장 방식에 영향), 4.7 typed-return override 규칙(ADR에서 확인).
Custom Resource + `@export` 타입 배열은 4.x 기본 기능이라 위험 낮음.

## Detailed Design

> *Specialist note*: `game-designer` · `art-director` · `narrative-director` · `systems-designer` (Section 6 라우팅:
> Gameplay → Character systems) not consulted — Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 크루 데이터 스키마 (`CrewDef`, Custom Resource)**

1. **크루 = 리소스 1장** — 크루마다 `CrewDef` 리소스 파일 하나(`assets/data/crew/<id>.tres`, 경로는 ADR 확정). 크루는 코드를 갖지 않는다.
   필드 (논리 스키마 — 리소스 분할·타입 표현은 ADR):

   | 필드 | 타입 | 제약 | 의미 / 소비자 |
   |---|---|---|---|
   | `id` | StringName | 소문자 snake, 레지스트리 내 유일, **영구 불변** | 세이브·보드 칸 `crew_id`·가챠·로그의 키. 이름을 바꿔도 id는 그대로 |
   | `schema_version` | int | ≥ 1 (MVP 1) | 데이터 마이그레이션 (로컬 세이브 GDD와 같은 원칙) |
   | `name_key` | String | 로컬라이즈 키 (`CREW_<ID>_NAME`) | UI 표시 이름 (한국어 원문: 냥이 등) |
   | `species` | StringName | 자유 태그 | 아트·도감 분류 (규칙 판정에 쓰지 않음) |
   | `colour_slot` | int | 1 – `palette_slot_count` (MVP 6) | art-bible 4절 크루 색 표의 행. hex는 팔레트 리소스가 소유 — 크루 데이터에 hex를 쓰지 않는다 |
   | `rarity` | enum `COMMON` \| `RARE` \| `SPECIAL` | 규칙 10 | 가챠 확률 구간·앨범 홀로 테두리. **수치에 영향 없음** |
   | `shapes` | Array[`CrewShapeEntry`] | 1 – `max_shapes_per_crew` (8)개, 규칙 4 | 이 크루가 트레이에 내는 조각 모양 풀 |
   | `ability` | `CrewAbility` | 규칙 6 | 얼굴이 지워질 때 실행되는 프리미티브 호출 목록 |
   | `ability_name_key` / `ability_desc_key` | String | 로컬라이즈 키 | 팀 편성·도감·컷인 텍스트 |
   | `silhouette_feature` | StringName | 레지스트리 내 유일 (규칙 12) | 얼굴 윤곽 돌출 1개 (art-bible 3절) |
   | `body_pattern` | StringName | 레지스트리 내 유일 (규칙 12) | 몸통 무늬 (art-bible 4절 색약 백업 2) |
   | `fill_visual` | StringName \| null | FILL 프리미티브가 있으면 필수 | 이 크루가 낳은 `TILE(origin = EGG)` 칸의 그림 (`egg`, `wool_puff` …) — 규칙 판정과 무관 |
   | `starter` | bool | — | 새 세이브에서 기본 보유 (보유 크루 GDD가 읽음) |
   | `obtainable` | bool | 기본 true | 가챠 풀 포함 여부. false여도 레지스트리에는 남는다 (규칙 15) |

2. **`CrewShapeEntry`** = { `shape`: board-rules `PieceShape`(오프셋 목록, 아래 카탈로그 id로 참조), `weight`: int ≥ 1, `face_cell`: int (−1 = 트레이가 고름, 0 ~ 칸 수−1 = 고정) }.
3. **`CrewAbility`** = { `ability_id`: StringName(유일), `steps`: Array[{ `primitive`: StringName, `params`: Dictionary }] (1개 이상, 실행 순서 = 배열 순서) }.
   `primitive`는 chain-resolver 규칙 14의 어휘 7종 중 하나여야 하며, 파라미터 의미·범위·검증은 chain-resolver 규칙 14·18이 소유한다.
   이 문서는 **어떤 크루가 어떤 조합과 값을 쓰는가**만 정한다.

**B. 조각 모양 세트**

4. **모양 규칙** — 모든 모양은 board-rules 규칙 3(1 ~ `max_piece_cells` = 6칸, 정규화, 4방향 연결, 보드 안)을 만족한다. 회전이 없으므로
   방향이 다른 모양은 별개 카탈로그 항목이다 (board-rules 규칙 4). 같은 모양을 여러 크루가 공유해도 되지만, 크루마다 **다른 어떤 크루도
   쓰지 않는 시그니처 모양을 2개 이상** 가진다 (`min_signature_shapes`, 데이터 린트 경고 — 기둥 2 "팀이 다르면 트레이가 다르다", art-bible
   색약 백업 3 "조각 모양").
5. **가중치** — 크루 안에서 모양이 뽑힐 상대 비율 (F1). 크루 *사이*의 비율(팀 3인 중 누구의 조각이 나오나)은 트레이 공급 GDD가 정한다.
   얼굴 위치는 `face_cell = −1`이면 트레이 공급이 시드 RNG로 정한다 (board-rules D5). **MVP는 모든 모양이 −1** — 프로토타입에서 검증된
   "얼굴 위치가 매번 달라 같은 모양도 다른 수가 된다"를 유지하고, 트레이에 얼굴이 보이므로 계획성(기둥 3)은 유지된다 (board-rules Q2 해소, D4).

**모양 카탈로그 (MVP)** — 오프셋 `(dr, dc)`. 그림은 `■` = 칸.

| id | 오프셋 | 칸 | 그림 | 쓰는 크루 |
|---|---|---|---|---|
| `D1` | (0,0) | 1 | ■ | 삐약 |
| `D2_H` | (0,0)(0,1) | 2 | ■■ | 삐약, 몽실 |
| `D2_V` | (0,0)(1,0) | 2 | 세로 ■■ | 삐약 |
| `I3_H` | (0,0)(0,1)(0,2) | 3 | ■■■ | 냥이, 몽실 |
| `I3_V` | (0,0)(1,0)(2,0) | 3 | 세로 ■■■ | 냥이, 깡총 |
| `I4_H` | (0,0)(0,1)(0,2)(0,3) | 4 | ■■■■ | 냥이 |
| `I4_V` | (0,0)(1,0)(2,0)(3,0) | 4 | 세로 ■■■■ | 깡총 |
| `L3_A` | (0,0)(1,0)(1,1) | 3 | ■□ / ■■ | 냥이 |
| `L3_B` | (0,0)(0,1)(1,0) | 3 | ■■ / ■□ | 삐약, 몽실 |
| `L3_C` | (0,0)(0,1)(1,1) | 3 | ■■ / □■ | 삐약 |
| `L3_D` | (0,1)(1,0)(1,1) | 3 | □■ / ■■ | 개굴 |
| `L4_A` | (0,0)(1,0)(2,0)(2,1) | 4 | L | 냥이 |
| `J4_A` | (0,1)(1,1)(2,1)(2,0) | 4 | J | 냥이 |
| `O4` | (0,0)(0,1)(1,0)(1,1) | 4 | 2×2 | 곰곰 |
| `T4_D` | (0,0)(0,1)(0,2)(1,1) | 4 | ■■■ / □■□ | 곰곰 |
| `T4_U` | (0,1)(1,0)(1,1)(1,2) | 4 | □■□ / ■■■ | 깡총 |
| `S4_H` | (0,1)(0,2)(1,0)(1,1) | 4 | □■■ / ■■□ | 개굴 |
| `Z4_H` | (0,0)(0,1)(1,1)(1,2) | 4 | ■■□ / □■■ | 개굴 |
| `S4_V` | (0,0)(1,0)(1,1)(2,1) | 4 | 세로 S | 개굴 |
| `Z4_V` | (0,1)(1,0)(1,1)(2,0) | 4 | 세로 Z | 개굴 |
| `U5` | (0,0)(0,2)(1,0)(1,1)(1,2) | 5 | ■□■ / ■■■ (토끼 귀) | 깡총 |
| `X5` | (0,1)(1,0)(1,1)(1,2)(2,1) | 5 | 십자 | 몽실 |
| `P5_A` | (0,0)(0,1)(1,0)(1,1)(2,0) | 5 | ■■ / ■■ / ■□ | 몽실 |
| `R6_H` | 2×3 직사각 | 6 | 2×3 | 곰곰 |
| `R6_V` | 3×2 직사각 | 6 | 3×2 | 곰곰 |

**C. 능력**

6. **능력 = 프리미티브 조합** — `ability.steps`는 chain-resolver 어휘(`clear_cross`, `clear_line`, `clear_area`, `clear_diagonals`, `clear_pattern`,
   `lay_eggs_in_own_line`, `lay_eggs_pattern`)만 쓴다. 새 런타임 동작이 필요하면 크루 데이터가 아니라 chain-resolver에 새 프리미티브를
   추가 요청한다 (chain-resolver 규칙 17 계약 + "미리보기로 정확히 보일 것"). **MVP 6명은 기존 7종만으로 구성되며 새 프리미티브를
   요구하지 않는다** (chain-resolver Q3 해소). MVP 능력은 모두 단일 단계이며 RNG를 쓰지 않는다 (chain-resolver 규칙 24).
7. **"새 동작" 원칙 (기둥 2)** — 두 크루의 능력은 (a) 프리미티브 id 순서가 다르거나 (b) *모양 파라미터*(`axis`, `offsets`, `prefer`, `order`)가
   달라야 한다. **크기 파라미터**(`reach`, `radius`, `count`)만 다른 두 크루는 데이터 린트 경고이며, 등급이 다르면 로드 오류다 (규칙 10 —
   "희귀 = 더 센 같은 능력"을 데이터 차원에서 막는다).
8. **능력 표 제공** — 크루 레지스트리는 `crew_abilities`(crew_id → `steps`) 표를 **레지스트리 전체**에 대해 만들어 해석기 `ctx`에 넘긴다
   (팀 3명만이 아님 — chain-resolver D11; 스테이지 초기 보드가 팀 밖 크루 얼굴을 깔 수 있다).
9. **레벨과 무관** — `CrewDef`에는 레벨에 따라 바뀌는 필드가 없다. T2 레벨업은 모양·가중치·능력 파라미터를 바꾸지 않고, 점수 쪽
   보너스(최대 +20%, 컨셉 기둥 2)로만 작용한다 (provisional — 크루 레벨업 GDD 소관, F6). 같은 보드·같은 배치는 레벨과 무관하게 같은 연쇄를 낸다 —
   미리보기 = 결과가 레벨 때문에 깨지지 않는다.

**D. 등급 (rarity)**

10. **등급은 수치가 아니라 독특함** (안티 기둥 "과금 = 수치 우위 아님") — `COMMON`(일반) / `RARE`(희귀) / `SPECIAL`(특별). 등급은 가챠 확률 구간과
    앨범 홀로 테두리만 바꾼다. 상위 등급 크루는 하위 등급 크루와 규칙 7(b)의 의미에서 **다른 동작**이어야 한다. 기본 보유 3인은 모두 `COMMON`이며,
    MVP 10스테이지는 기본 보유 3인만으로 별 1개 클리어가 가능해야 한다 (스테이지 & 목표 GDD 수용 기준으로 넘김 — 컨셉 Design Risks).

**E. 레지스트리와 로드 시 검증**

11. **`CrewRegistry`** — 모든 `CrewDef`의 목록 리소스 1개. 게임 시작 시 1회 로드·검증하고 이후 읽기 전용. 제공: `get(id)`, `all()`, `crew_abilities`,
    `starter_ids()`, `obtainable_ids()`.
12. **검증 (실패 = 데이터 로드 오류, 개발 중 에러 표시 / 출시 빌드에는 검증된 데이터만)** — id 유일·형식, `ability_id` 유일, 모양 board-rules 규칙 3 통과,
    `weight ≥ 1`, `face_cell ∈ {−1} ∪ [0, 칸 수 − 1]`, `shapes` 1 ~ 8개, 같은 크루 안 중복 모양 없음, 능력은 chain-resolver 규칙 18 통과,
    FILL 프리미티브가 있으면 `fill_visual` 필수, `colour_slot` 범위 안, **MVP 레지스트리에서** `colour_slot`·`silhouette_feature`·`body_pattern` 유일
    (art-bible: 흑백 실루엣만으로 6명 구분; T2+ 색 중복은 "팀 안에서만 유일" 규칙으로 팀 편성 GDD가 처리), 규칙 7 등급 위반.
    **린트 경고 (로드는 됨)**: 시그니처 모양 < 2 (규칙 4), 크기 파라미터만 다른 같은 등급 크루 (규칙 7), 기대 조각 크기 E가 안전 범위 밖 (F2).
13. **크루는 실행 중 바뀌지 않는다** — 판 도중·판 사이 모두 `CrewDef`는 불변. 이벤트·보드 칸은 `crew_id`만 들고 정의는 레지스트리에서 찾는다.

**F. MVP 크루 6명**

14. **크루 표** (모든 캐릭터는 이 프로젝트의 오리지널. 색 슬롯 4~6 hex는 art-bible의 잠정값, 무늬·돌출 4~6은 이 문서의 제안 — art-director 확정 대상)

    | id | 이름 | 동물 | 색 슬롯 (띠) | 등급 | 능력 (`ability_id` · steps) | 한 줄 설명 | 모양 (가중치) | E (F2) |
    |---|---|---|---|---|---|---|---|---|
    | `nyangi` | 냥이 | 고양이 | 1 빨강 `#e8574a` (중간) | COMMON · starter | `nyangi_cross_scratch` · `clear_cross{reach: −1}` | **십자 할퀴기** — 얼굴의 가로·세로 줄 전체 | I3_H 3, I3_V 3, I4_H 2, L3_A 2, L4_A 1, J4_A 1 (프로토타입 세트) | 3.33 |
    | `gomgom` | 곰곰 | 곰 | 2 파랑 `#2e6bc6` (어두움) | COMMON · starter | `gomgom_bear_hug` · `clear_area{radius: 1}` | **곰 포옹** — 얼굴 둘레 3×3 | O4 3, R6_H 2, T4_D 2, R6_V 1 (프로토타입 세트) | 4.75 |
    | `piyak` | 삐약 | 병아리 | 3 노랑 `#f2c230` (밝음) | COMMON · starter | `piyak_lay_eggs` · `lay_eggs_in_own_line{count: 3, prefer: fuller, order: nearest}` | **알 낳기** — 자기 가로·세로 중 더 꽉 찬 줄의 빈칸에 가까운 순으로 알 3개 | D1 2, D2_H 2, D2_V 2, L3_B 1, L3_C 1 (프로토타입 세트) | 2.00 |
    | `gaegul` | 개굴 | 개구리 | 4 초록 `#2a7a45` (어두움) | RARE | `gaegul_x_leap` · `clear_diagonals{reach: −1}` | **엑스 폴짝** — 얼굴을 지나는 두 대각선 전체 | S4_H 2, Z4_H 2, L3_D 2, S4_V 1, Z4_V 1 (계단 모양 = 대각선) | 3.75 |
    | `kkangchong` | 깡총 | 토끼 | 5 보라 `#9a72d4` (중간) | SPECIAL | `kkangchong_double_hop` · `clear_pattern{offsets: [(−2,−2),(−2,0),(−2,2),(0,−2),(0,2),(2,−2),(2,0),(2,2)]}` | **두 칸 깡총** — 8방향으로 두 칸 떨어진 칸만 (바로 옆은 건너뜀) | I4_V 2, T4_U 2, U5 1, I3_V 1 (세로로 긴 = 귀) | 4.00 |
    | `mongsil` | 몽실 | 양 | 6 분홍 `#f29cc0` (밝음) | RARE | `mongsil_wool_cushion` · `lay_eggs_pattern{offsets: [(−1,0),(0,−1),(0,0),(0,1),(1,0)]}` | **털뭉치 쿠션** — 얼굴 자리와 상하좌우 빈칸을 털뭉치로 채움 | X5 1, P5_A 1, L3_B 2, I3_H 2, D2_H 2 | 3.25 |

    - 크루 1~3은 컨셉·프로토타입 그대로(T0 그레이박스 3인 = 기본 보유 3인). 곰곰 색은 art-bible의 변경값을 따른다.
    - 능력 종류 축: **넓게 지우기**(냥이 직교, 개굴 대각) · **가까이 지우기**(곰곰 붙은 칸, 깡총 건너뛴 칸) · **채우기**(삐약 줄, 몽실 십자).
      각 축 안의 두 크루는 대상 칸이 **서로 겹치지 않는다**(F5) — 같은 축의 두 크루가 "더 센 버전"이 아니라 "다른 쪽 절반"이다.
    - 몽실의 털뭉치는 해석기 입장에서 삐약의 알과 같은 `TILE(origin = EGG, crew_id = mongsil)`이다. 다른 것은 그림(`fill_visual = wool_puff`)뿐이다.
    - `lay_eggs_pattern` 순서 = offsets 목록 순서(row-major로 적음). 얼굴 칸(0,0)은 이미 비어 있어 최소 1칸은 항상 채운다 (같은 웨이브 앞선 FILL이 채우지 않은 한).

**G. 궁합 (synergy) — 가설, T0 시뮬레이션으로 검증 (F4·AC-17)**

15. **궁합 원리** — 연쇄는 "A의 능력 대상에 B의 얼굴이 있다"(도달) × "A가 지운 뒤의 보드에서 B의 능력이 할 일이 남았다"(이어감)이다.
    - **S1 겹치지 않는 범위는 서로를 넓힌다**: 냥이∩개굴 = 0칸, 곰곰∩깡총 = 0칸 (F5). 냥이+개굴 = 8방향 전체, 곰곰+깡총 = 5×5 전체.
    - **S2 구멍 파기 → 채우기는 상생**: 가까이 지우는 크루(곰곰·개굴)가 거의 찬 줄에 구멍을 내면 채우기 크루(삐약·몽실)가 그 구멍을 메워 줄을 다시 완성 → 재점화.
    - **S3 같은 자리를 또 지우면 약하다**: 곰곰→곰곰, 깡총→깡총은 B의 대상이 A가 비운 칸과 많이 겹친다. 채우기→채우기는 둘 다 줄 완성을 기다려야 해 느리다.
16. **방향 궁합표** (행 A가 먼저 발동해 열 B의 얼굴을 깨움; ◎ 강함 · ○ 보통 · △ 약함)

    | A ↓ / B → | 냥이 | 곰곰 | 삐약 | 개굴 | 깡총 | 몽실 |
    |---|---|---|---|---|---|---|
    | **냥이** | ○ | ◎ | ○ | ◎ | ○ | △ |
    | **곰곰** | ◎ | △ | ◎ | ○ | ○ | ◎ |
    | **삐약** | ○ | ○ | △ | ○ | ○ | △ |
    | **개굴** | ◎ | ○ | ◎ | ○ | ○ | △ |
    | **깡총** | ○ | ◎ | ○ | ○ | △ | △ |
    | **몽실** | ○ | ○ | △ | ○ | ○ | △ |

    근거 (◎·△만): 냥이→곰곰 — 냥이의 15칸 십자가 멀리 있는 곰곰을 깨우고, 곰곰 3×3 중 냥이가 비운 칸은 한 줄 3칸뿐. 곰곰→냥이 — 붙은 냥이를 깨우면
    십자 14칸 중 곰곰이 비운 칸은 2~3칸. 냥이↔개굴 — 대상이 겹치지 않음(S1). 곰곰→삐약·개굴→삐약 — 구멍 1~3개가 삐약의 줄에 생겨 알 3개가 그 줄을
    완성하기 쉬움(S2). 곰곰→몽실 — 몽실 십자 채우기가 곰곰이 판 3×3 구멍에 정확히 들어감(S2). 깡총→곰곰 — 두 칸 떨어진 곰곰의 3×3은 깡총 대상과 겹치지 않음(S1).
    냥이→몽실 — 몽실이 냥이 줄 위에 있으면 그 줄은 이미 비어 털뭉치가 빈 줄을 채울 뿐. 개굴·깡총→몽실 — 몽실 상하좌우가 아직 차 있어 자기 칸만 채움.
    채우기 크루의 행(삐약·몽실 → B)이 ○ 이하인 것은 의도다: 채우기는 *줄 완성*을 거쳐서만 깨우므로 확률은 낮지만, 깨우면 줄 하나(최대 8칸)의 얼굴을 한꺼번에 깨운다.
17. **추천 팀 (팀 편성·튜토리얼·스테이지 설계 참고)** — **정석 도미노** 냥이+곰곰+삐약 (기본 보유 — 냥이→곰곰→삐약, 곰곰→냥이 ◎) ·
    **8방향** 냥이+개굴+삐약 (냥이↔개굴 ◎, 개굴→삐약 ◎) · **파고 메우기** 곰곰+깡총+몽실 (깡총→곰곰 ◎, 곰곰→몽실 ◎). 세 팀은 같은 스테이지에서
    다른 경로를 만든다 — 넓은 줄 연쇄 / 대각 연쇄 / 국소 파기·메우기 (기둥 2 design test 1).

### States and Transitions

`CrewDef` 자체는 실행 중 상태가 없다 (규칙 13). 아래는 **크루 데이터의 수명 주기**다. 플레이어별 보유·샤드 상태는 보유 크루 GDD가 소유한다.

| 상태 | 의미 | 다음 | 조건 |
|---|---|---|---|
| `DRAFT` | 리소스 작성 중, 레지스트리 목록에 없음 | `REGISTERED` | 레지스트리에 추가 + 규칙 12 검증 통과 |
| `REGISTERED` | 로드됨. 해석기 능력 표·스테이지 초기 보드에서 사용 가능 | `OBTAINABLE` / `RETIRED` | `obtainable = true` / false |
| `OBTAINABLE` | 가챠 풀에 들어감 (가챠 GDD가 등급별 확률 적용) | `RETIRED` | `obtainable = false`로 데이터 변경 (업데이트) |
| `RETIRED` | 가챠에서 빠졌지만 레지스트리에 남음 — 이미 보유한 세이브·스테이지 보드는 계속 동작 | `OBTAINABLE` | 재개방 |

**삭제 상태는 없다** — 한 번 출시된 `id`는 레지스트리에서 지우지 않는다 (세이브 손상 방지; 엔티티 레지스트리의 "삭제 대신 deprecated"와 같은 원칙).

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 | 크루 → 해석기 | `crew_abilities` 표 (레지스트리 전체, 규칙 8) | 해석기 (어휘·계약·검증) / 크루 (조합·값) |
| 보드 & 조각 규칙 | 크루 → 보드 규칙 | `PieceShape` 목록, `face_cell` | 보드 규칙 (모양 형식·검증) / 크루 (목록) |
| 트레이 공급 | 크루 → 트레이 | 팀 3인의 `shapes`(모양·가중치·`face_cell`) | 크루 (크루 안 가중치, F1) / 트레이 (크루 사이 비율·얼굴 위치 뽑기·재충전) |
| 팀 편성 | 크루 → 팀 | `id`, 이름, 등급, `colour_slot`, 모양·능력 표시 데이터 | 팀 편성 (선택 규칙, T2 색 중복 경고) |
| 보유 크루 | 크루 → 보유 | 유효 `id` 집합, `starter_ids()` | 보유 크루 |
| 가챠 | 크루 → 가챠 | `obtainable_ids()`, `rarity` | 가챠 (등급별 확률·천장·샤드) |
| 스테이지 & 목표 | 크루 → 스테이지 | 초기 보드 얼굴의 `crew_id` 유효성, "기본 보유 3인으로 클리어 가능" 수용 기준 | 스테이지 |
| 연쇄 미리보기 / 연출 재생기 / HUD | 크루 → 표시 | `crew_id` → 색 슬롯·실루엣·무늬·`fill_visual`·능력 이름 | 각 표시 GDD (해석기 이벤트에는 `crew_id`만 실림) |
| 로컬 세이브 | 간접 | 세이브는 `id`만 저장 — `CrewDef` 자체는 저장하지 않음 | 세이브 GDD |
| 크루 레벨업 (T2) | 레벨업 → 점수 | 레벨은 `CrewDef`를 바꾸지 않음 (규칙 9) | 레벨업 GDD |
| 스티커 앨범 (T2) | 크루 → 앨범 | 등급(홀로 테두리), 이름, 도감 순서 = 레지스트리 순서 | 앨범 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. 이 시스템의 식은 균형 *지표*(조각 크기·능력 범위·궁합)이며, 점수·확률 곡선은 점수 / 트레이 / 가챠 GDD
> 소유다. F3·F5의 값은 8×8 빈 판 기준으로 전수 계산했다 (64개 얼굴 위치).

**F1. 크루 안 모양 확률**

The shape_probability formula is defined as:

`p(s | c) = w_s / Σ_{s' ∈ S_c} w_s'`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| c | crew id | 레지스트리 | data file | 크루 |
| S_c | 모양 목록 | 1–8개 | data file (`shapes`) | 크루 c의 모양 풀 |
| w_s | int | 1–10 | data file (`weight`) | 모양 s의 가중치 |

**Output Range:** (0, 1], 크루 안 합 = 1. 모양 1개뿐이면 1.0. 크루 사이 비율과 실제 뽑기(가방/독립 추첨)는 트레이 공급 GDD 소관 —
팀 3인이 같은 비율이라면(트레이 GDD 가정, provisional) 팀 단위 확률은 `p(c, s) = (1/3) · p(s | c)`.
**Example:** 냥이 Σw = 12 → I3_H = 3/12 = **0.25**, L4_A = 1/12 ≈ 0.083. 팀 단위(1/3 가정) I3_H ≈ 0.083.

**F2. 기대 조각 크기 (balance 지표)**

The expected_piece_cells formula is defined as:

`E_c = Σ_{s ∈ S_c} w_s · |s| / Σ_{s ∈ S_c} w_s`, 팀 `E_T = Σ_{c ∈ T} share_c · E_c`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| \|s\| | int | 1–6 | calculated (board-rules `max_piece_cells`) | 모양 s의 칸 수 |
| w_s | int | 1–10 | data file | F1 |
| share_c | float | 0–1, 팀 합 1 | 트레이 공급 GDD (가정 1/3) | 팀 안 크루 c의 조각 비율 |
| E_c 안전 범위 | float | 2.0–5.0 | data file (`expected_cells_lint_range`) | 벗어나면 린트 경고 (규칙 12) |

**Output Range:** 1.0 ~ 6.0 가능, MVP 크루 2.00(삐약) ~ 4.75(곰곰). 큰 E = 줄은 빨리 차지만 막힘(`no_moves`) 위험이 크다; 작은 E = 구멍 메우기 쉽지만
줄 완성이 느리다. 팀 E_T 권장 2.5–4.5 (팀 편성 GDD가 경고 여부 결정).
**Example:** 기본 팀 냥이+곰곰+삐약 → (3.33 + 4.75 + 2.00) / 3 = **3.36** (프로토타입 체감과 같음). 파고 메우기 팀 곰곰+깡총+몽실 → (4.75 + 4.00 + 3.25)/3 = 4.00.

**F3. 능력 범위 (footprint)**

The ability_footprint formula is defined as:

`R_c = (1 / (W·H)) · Σ_{(fr,fc)} |T_c(fr, fc) \ {(fr, fc)}|` — 빈 판에서 얼굴 자리를 뺀 대상 칸 수의 평균 (CLEAR); FILL은 채울 수 있는 칸 수의 상한

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_c(fr, fc) | 칸 집합 | chain-resolver F4 | calculated | 얼굴 (fr, fc)에서 크루 c 능력의 대상 칸 (보드 밖 잘림) |
| W, H | int | 8 | data file (board-rules) | 보드 크기 |

**Output Range (8×8, 최소 / 최대 / 평균):**

| 크루 | 프리미티브 | 최소 | 최대 | 평균 R_c |
|---|---|---|---|---|
| 냥이 | `clear_cross(−1)` | 14 | 14 | **14.0** |
| 개굴 | `clear_diagonals(−1)` | 7 | 13 | **8.75** |
| 곰곰 | `clear_area(1)` | 3 | 8 | **6.56** |
| 깡총 | `clear_pattern`(두 칸 8방향) | 3 | 8 | **5.25** |
| 몽실 | `lay_eggs_pattern`(십자 5) | 3 (얼굴 포함) | 5 | 4.5 (빈칸일 때만 채움) |
| 삐약 | `lay_eggs_in_own_line(3)` | 1 | 3 | ≤ 3 |

**Example:** 개굴 얼굴 (3,3) → 주대각선 8칸 + 반대각선(r+c = 6) 7칸 − 교차 1 − 얼굴 1 = **13**. 모서리 (0,0) → 주대각선 7칸.

**F4. 연결률 (link rate) — 추정치와 측정치**

The link_rate formula is defined as:

`L̂_A = R_A / (W·H − 1)` (추정 — B의 얼굴이 무작위 위치일 때 A의 대상 안에 있을 확률), 측정 `λ(A→B) = N(A가 B를 깨움) / N(A 발동)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| R_A | float | F3 | calculated | A의 평균 범위 |
| N(A가 B를 깨움) | int | ≥ 0 | calculated (자동 플레이 로그: `FACE_ACTIVATED`의 웨이브 k+1 얼굴 중 `CELLS_CLEARED.source_order`가 A인 것) | 실제 연쇄 횟수 |
| N(A 발동) | int | ≥ 1 | calculated (자동 플레이 로그) | A 발동 횟수 |

**Output Range:** L̂ — 냥이 0.222, 개굴 0.139, 곰곰 0.104, 깡총 0.083 (얼굴 1개당; 보드 위 얼굴이 n개면 대략 `1 − (1 − L̂)^n`). 채우기 크루는 줄 완성을
거쳐야 하므로 L̂ 식을 쓰지 않고 λ만 측정한다. **목표**: 모든 MVP 크루의 평균 λ(A→·)가 가장 높은 크루의 **40% 이상** (`min_link_ratio` 0.4) — 그보다
낮은 크루는 "연쇄에 안 끼는 크루"로 보고 모양·파라미터를 조정한다 (Open Question Q1: 깡총).
**Example:** 보드에 다른 얼굴 4개 → 냥이가 하나 이상 깨울 추정 확률 1 − 0.778⁴ ≈ **0.63**, 깡총 1 − 0.917⁴ ≈ 0.29.

**F5. 범위 겹침 (궁합 S1)**

The coverage_overlap formula is defined as:

`O(A, B) = |(T_A(3,3) ∩ T_B(3,3)) \ {(3,3)}|` — 같은 얼굴 자리(판 가운데)에서 두 능력의 대상 겹침

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_A, T_B | 칸 집합 | F3 | calculated | 두 크루의 대상 |

**Output Range:** 0 ~ min(R_A, R_B). MVP CLEAR 크루 쌍: 냥이·개굴 **0**, 곰곰·깡총 **0**, 냥이·곰곰 4, 냥이·깡총 4, 곰곰·개굴 4, 개굴·깡총 4.
0인 쌍이 "상보 쌍"이다 — 한 팀에 넣으면 8방향(냥이+개굴) / 5×5(곰곰+깡총)를 빈틈없이 덮는다. 새 크루 추가 시 기존 크루와 O = R인(완전 포함) 쌍은
"더 센/약한 같은 능력"이므로 규칙 7 린트로 걸러진다.
**Example:** 곰곰 3×3(8칸)과 깡총 두 칸 고리(8칸)는 거리 1과 거리 2로 나뉘어 겹침 0 → 합쳐 5×5 − 1 = 24칸.

**F6. 레벨업 보너스 상한 — 참조 (소유: 크루 레벨업 GDD, T2, provisional)**

The level_bonus formula is defined as:

`level_bonus(c) ≤ level_bonus_cap`, `level_bonus_cap = 0.20`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| level_bonus(c) | float | 0 – 0.20 | 크루 레벨업 GDD | 크루 c의 능력이 지운 칸의 점수 가산 비율 (점수 GDD가 적용) |
| level_bonus_cap | float | 0.20 고정 | constant (컨셉 기둥 2) | 상한 |

**Output Range:** 0 ~ +20%. 모양·가중치·능력 파라미터에는 적용하지 않는다 (규칙 9). **이 문서는 이 식을 계산하지 않는다** — `CrewDef`에 레벨 필드가 없음을 보장할 뿐이다.
**Example:** 최대 레벨 곰곰이 9칸 지움 → 점수 GDD 공식 결과 × 1.20. 연쇄 깊이·대상 칸은 레벨 1과 같다.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 크루 리소스의 프리미티브 id가 chain-resolver 어휘에 없으면**: 로드 오류 (chain-resolver 규칙 18). 크루 데이터로 새 동작을 "몰래" 넣을 수 없다.
- **If 모양이 board-rules 규칙 3을 어기면** (7칸, 끊긴 모양, 정규화 안 됨): 그 크루 전체가 로드 오류. 부분 로드(나쁜 모양만 빼기)는 하지 않는다 — 가중치 분포가 조용히 바뀌기 때문.
- **If 같은 크루 안에 같은 모양이 두 번 있으면**: 로드 오류. 비율을 올리려면 `weight`를 쓴다.
- **If `face_cell`이 칸 수 이상이거나 −1 미만이면**: 로드 오류.
- **If 두 크루가 같은 모양을 공유하면**: 정상 (냥이·몽실 I3_H 등). 트레이 조각 인스턴스는 `crew_id`로 구분되고 색·무늬가 다르다. 단 시그니처 모양 < 2면 린트 경고.
- **If 팀 3인이 모두 같은 모양을 공유하는 모양이 생기면** (T2+ 크루 증가 시): 그 모양의 팀 단위 확률이 합산된다 (F1). 트레이 공급 GDD가 동일 모양 연속 제한 여부를 정한다.
- **If 팀이 1~2명뿐이면** (튜토리얼 스테이지): 크루 정의는 상관없다 — 풀 구성은 팀 편성 / 스테이지 데이터, 비율은 트레이 공급 소관.
- **If 스테이지 초기 보드에 팀 밖 크루의 얼굴이 있으면**: 정상 — 능력 표가 레지스트리 전체라 발동한다 (규칙 8). 보유하지 않은 크루여도 같다(스테이지 장치). 레지스트리에 없는 id면 스테이지 로드 오류.
- **If `RETIRED` 크루를 플레이어가 보유하고 있으면**: 팀 편성·플레이 모두 정상. 가챠에서만 빠진다.
- **If 세이브에 레지스트리에 없는 `crew_id`가 있으면** (다운그레이드·손상): 세이브 GDD가 처리 (제안: 그 항목을 무시하고 로그, 세이브는 지우지 않음). 크루 정의는 id 삭제를 금지해 이 상황을 업데이트로는 만들지 않는다.
- **If 몽실의 십자 칸 일부가 보드 밖이면** (모서리·변 얼굴): 보드 밖 칸은 버린다 (chain-resolver 규칙 14). 모서리에서는 3칸.
- **If 몽실 십자 칸이 이미 차 있으면**: 그 칸은 건너뛴다 — 빈칸에만 채운다. 냥이 줄 위에서 깨워진 몽실은 빈 줄을 채우게 되어 연쇄가 약하다 (궁합표 △, 의도된 상극).
- **If 같은 웨이브에 삐약과 몽실이 함께 발동하면**: row-major 순서로 FILL이 순차 적용되고 뒤 얼굴은 앞이 채운 칸을 빈칸으로 보지 않는다 (chain-resolver 규칙 16).
- **If 깡총의 두 칸 거리 대상이 모두 빈칸이면**: 발동은 했지만 "헛뜀" — `ABILITY_EFFECT.cells = []`, 연쇄 깊이에는 센다 (chain-resolver D12).
- **If 깡총과 곰곰이 같은 웨이브에서 발동하면**: 대상 합집합 (chain-resolver 규칙 15) — 겹침 0이므로 서로 손해가 없다.
- **If 크기 파라미터만 다른 같은 등급 크루를 추가하면** (예: `clear_cross{reach: 2}` 일반 크루): 로드는 되고 린트 경고. 다른 등급이면 로드 오류 (규칙 7·10).
- **If 상위 등급 크루가 실제 플레이에서 확실히 더 강하면** (λ·클리어율): 데이터 오류는 아니지만 안티 기둥 위반 신호 — `/balance-check`에서 등급별 λ·별 획득률을 비교하고, 수치가 아니라 모양·가중치로 조정한다.
- **If `colour_slot`이 두 MVP 크루에서 같으면**: 로드 오류 (MVP 레지스트리 유일). T2+에 슬롯이 6개를 넘으면 이 검사는 "팀 안 유일"로 바뀐다 (팀 편성 GDD) — 바꾸는 시점은 이 문서 개정으로 기록.
- **If 레벨업 데이터가 크루 능력 파라미터를 바꾸려 하면** (T2 설계 실수): 스키마상 불가능 — `CrewDef`는 레벨 필드가 없고 레벨업은 점수 보너스만 갖는다 (규칙 9).
- **If 얼굴 없는 조각(`crew_id = null`)이 트레이에 나오면** (튜토리얼): 크루 정의를 거치지 않는다 — 모양은 스테이지 데이터가 board-rules 카탈로그에서 직접 지정한다 (provisional, 스테이지 GDD).

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 연쇄 해석기 & 능력 프리미티브 (`chain-resolver.md`) | Hard | 프리미티브 어휘 7종(규칙 14), 계약(규칙 17), 검증(규칙 18), 능력 표 범위 = 레지스트리 전체(D11) | Designed — 어휘 안에서 6명 구성, 새 프리미티브 요청 없음 (Q3 해소) |
| 보드 & 조각 규칙 (`board-rules.md`) | Hard | `PieceShape` 형식·유효성(규칙 3·4), `max_piece_cells` 6, 조각 인스턴스 `face_index`(규칙 5), `TILE(origin = EGG)` | Designed — 얼굴 위치 Q2 해소 (D4) |
| 아트 바이블 (`design/art/art-bible.md`) | Soft (표시 데이터) | 4절 크루 색 슬롯·명도 띠, 3절 윤곽 돌출 규칙, 몸통 무늬 | 섹션 1~4 작성, 5절 미작성 — 슬롯 4~6 크루 확정을 이 문서가 제안 |

**Downstream (이 시스템에 의존)** — 모두 아직 GDD 없음, 아래는 이 문서가 제안하는 계약 (provisional).

| 시스템 | 강도 | 쓰는 것 | 이 문서가 기대하는 것 |
|---|---|---|---|
| 트레이 공급 (`tray-supply.md`) | Hard | `shapes`·`weight`·`face_cell` | 크루 사이 비율·뽑기 방식·얼굴 위치 RNG 소유; 크루 안 비율은 F1 그대로 |
| 팀 편성 (`team-composition.md`) | Hard | 크루 목록·표시 데이터·등급·색 슬롯 | T2+ 색 중복 경고 규칙, 팀 E_T 경고 여부 |
| 보유 크루 (`crew-ownership.md`) | Hard | 유효 id, `starter_ids()` | id만 저장, 레지스트리에 없는 id 처리 |
| 가챠 (`gacha.md`) | Hard | `obtainable_ids()`, `rarity` | 등급별 확률·천장; 등급 = 수치 아님 원칙 유지 |
| 연쇄 해석기 (`chain-resolver.md`) | Hard (데이터) | `crew_abilities` | — (양방향: chain-resolver Dependencies가 이 문서를 upstream·downstream 양쪽에 적음) |
| 스테이지 & 목표 (`stage-goals.md`) | Soft | 초기 보드 `crew_id` 검증, 기본 보유 3인 클리어 가능 기준 | 10스테이지 모두 기본 3인으로 별 1개 가능 (규칙 10) |
| 연쇄 미리보기 · 연출 재생기 · HUD · 오디오 | Soft | `crew_id` → 시각/청각 식별자 | 해석기 이벤트에 크루 정보를 더 싣지 않음 |
| 크루 레벨업 (T2) · 스티커 앨범 (T2) | Hard / Soft | 크루 id, 등급 / 불변 `CrewDef` | 레벨업은 점수 보너스만 (F6) |

**양방향성**: systems-index #5 Depends On "연쇄 해석기, 보드 & 조각 규칙"과 일치. chain-resolver Dependencies는 이 문서를 upstream(데이터)·downstream(어휘) 양쪽에,
board-rules Interactions는 "크루 → 보드 규칙: 크루별 모양 목록, 선택적 `face_cell`"로 적어 일치. systems-index의 트레이(#6)·보유(#13)·팀(#14)·가챠(#17)·
레벨업(#27)·앨범(#28)이 이 시스템을 Depends On에 적어 일치. **불일치 0건.**

## Visual/Audio Requirements

> *Specialist note*: `art-director` not consulted — Lean mode에서도 이 시스템의 시각 식별은 플레이 판독의 핵심이라 spawn 대상이지만,
> 이 실행에는 Agent 도구가 없어 생략. 슬롯 4~6의 돌출·무늬는 **제안**이며 art-director가 art-bible 5절 작성 시 확정한다.

**크루별 시각 식별자** (art-bible 3·4절 — 색약 백업 세 겹: 윤곽 돌출 / 몸통 무늬 / 조각 모양)

| 크루 | 본색 / 그늘 (띠) | 윤곽 돌출 1개 (`silhouette_feature`) | 몸통 무늬 (`body_pattern`) | 채우기 그림 | 발동 표정 · 효과 방향 |
|---|---|---|---|---|---|
| 냥이 | `#e8574a` / `#b83a30` (중간) | 끝이 둥근 삼각 귀 두 개 (`tri_ears`) | 줄무늬 (`stripes`) | — | 눈 감고 앞발 — 얼굴에서 가로·세로 네 방향 할퀴기 자국이 줄 끝까지 |
| 곰곰 | `#2e6bc6` / `#1f4b8f` (어두움) | 작은 반원 귀 두 개, art-bible 곰곰 귀 제한 준수 (`round_ears`) | 민무늬 + 둥근 얼룩 1개 (`spot`) | — | 팔 벌린 포옹 — 3×3을 감싸 안는 원형 압축 |
| 삐약 | `#f2c230` / `#c99a10` (밝음) | 머리 위 깃털 한 가닥 + 부리 (`feather_tuft`) | 물방울 (`dots`) | `egg` (크림색 알, 삐약 노랑 테두리) | 엉덩이 들썩 — 알이 가까운 순으로 통통 떨어짐 |
| 개굴 *(제안)* | `#2a7a45` / `#1c5530` (어두움) | 머리 위 작은 연잎 모자 (`lily_pad`, 잎 유형) | 물결 무늬 (`waves`) | — | 볼 부풀림 — 네 대각선 방향으로 폴짝 발자국 |
| 깡총 *(제안)* | `#9a72d4` / `#7150a8` (중간) | 위로 길게 선 타원 귀 두 개, 머리 높이 이상 (`long_ears`) | 체크 무늬 (`checks`) | — | 귀 쫑긋 — 두 칸 떨어진 8칸에 착지 먼지, 사이 칸은 건드리지 않음이 보여야 함 |
| 몽실 *(제안)* | `#f29cc0` / `#c56f95` (밝음) | 머리 둘레 곱슬 털 구름 (물결 윤곽, `wool_curl`) | 소용돌이 컬 (`curls`) | `wool_puff` (스티커 백 털뭉치, 분홍 그늘) | 몸 부풀림 — 십자 다섯 칸에 털뭉치가 퐁퐁 |

- **실루엣 판독 위험 1건**: 냥이·곰곰·깡총이 모두 "귀" 계열이다. art-bible 3절은 "같은 돌출 *유형* 공유 금지"라 삼각/반원/긴 타원을 다른 유형으로 본다고
  해석했다 — art-director 확인 필요 (Open Question Q4). 대안: 깡총 대신 뿔 유형 동물(예: 아기 염소)로 교체.
- 효과 입자·컷인 테두리는 해당 크루 색 (art-bible 4절 예외). 미리보기 점선·번호 배지는 크루 색이 아니라 잉크 (art-bible 4절).
- 얼굴 1명당 표정 3장(기본 / 발동 / 머쓱)은 art-bible 3절 그대로. 채우기 크루는 낳은 칸 그림 1장 추가.
- **오디오**: 크루마다 발동 SFX 1개(짧은 의성어 톤 — 냥 / 웅 / 삐약 / 개굴 / 깡 / 몽), 채우기 크루는 "퐁" 착지음 공용 + 크루 톤. 같은 웨이브 다중 발동 시 겹침 규칙은 오디오 GDD 소관.
- 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:crew-definition` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

- **능력은 모양으로 읽혀야 한다**: 발동 효과는 반드시 대상 칸 위로 그려진다 (냥이 = 십자 선, 곰곰 = 정사각, 개굴 = X, 깡총 = 점 8개 고리, 삐약 = 한 줄, 몽실 = 작은 십자).
  처음 보는 크루도 첫 발동 1회로 범위 모양을 말할 수 있어야 한다 (AC-16 플레이테스트 질문).
- **크루 정체성 = 조각 손맛**: 트레이에서 크루를 조각 모양만 보고 맞힐 수 있어야 한다 — 곰곰은 묵직한 덩어리, 삐약은 작은 알갱이, 냥이는 길쭉, 개굴은 계단, 깡총은 세로로 긴 것.
  드래그 중 조각 무게감(그림자 높이·스냅 속도)은 입력 GDD 소관이며 크루별 차이를 두지 않는다 (판독 일관성).
- **타이밍 목표 (provisional, 연출 재생기 GDD가 확정)**: 얼굴 발동 → 효과 시작 ≤ 0.15 s, 한 능력의 효과 퍼짐 ≤ 0.35 s (웨이브당 ≈ 0.5 s 예산 — chain-resolver `depth_cap` 근거와 일치).
  CLEAR는 얼굴에서 거리 순으로 퍼지고, FILL은 낳는 순서(`ABILITY_EFFECT.cells` 순서)대로 떨어진다.
- **헛손질도 귀엽게** (기둥 5): 대상이 모두 빈칸인 발동은 머쓱 표정 + 짧은 효과로 0.2 s 안에 끝낸다.

## UI Requirements

- **팀 편성 크루 카드**: 얼굴 · 이름 · 등급 테두리(희귀 이상 홀로 — UI 전용 셰이더) · **능력 도해**(얼굴 중심 5×5 미니 격자에 대상 칸 표시; 냥이·개굴처럼 줄 끝까지 가는 능력은 화살표) · **모양 미리보기**(가중치 순 아이콘, "자주 / 가끔" 2단계 표기 — 숫자 가중치는 노출하지 않음) · 능력 이름·한 줄 설명(`ability_desc_key`).
- **플레이 중**: 크루 정보는 별도 HUD가 아니라 조각 자체(색·무늬·얼굴)로 전달. 트레이 조각 길게 누르기 → 그 크루의 능력 도해 툴팁 (진한 잉크 바탕, art-bible 4절).
- **가챠 / 앨범**: 등급 표시, 픽업 크루의 모양·능력 힌트(컨셉 Retention Hooks).
- 모든 카드 터치 대상 ≥ 64px (art-bible 3절).

> **📌 UX Flag — 크루 정의 & 능력**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or
> HUD element this system contributes to (팀 편성 크루 카드, 능력 도해 툴팁, 가챠 픽업 카드) **before** writing epics. Stories that reference UI should cite
> `design/ux/[screen].md`, not the GDD directly.

## Cross-References

| 이 문서의 참조 | 대상 GDD / 문서 | 대상 섹션 | 관계 |
|---|---|---|---|
| 능력 프리미티브 어휘 7종·파라미터 | `design/gdd/chain-resolver.md` | Core Rules D (규칙 13–18) | 이 문서는 조합·값만, 의미는 해석기 소유 |
| 능력 표 = 레지스트리 전체 | `design/gdd/chain-resolver.md` | Decision Log D11, Edge Cases | 일치 |
| MVP 프리미티브 RNG 미사용 | `design/gdd/chain-resolver.md` | 규칙 24 | 6명 모두 RNG 없음 |
| 새 프리미티브 필요 여부 | `design/gdd/chain-resolver.md` | Open Question Q3 | **해소** — 필요 없음 |
| 범위 크기 | `design/gdd/chain-resolver.md` | F4 | F3이 평균·최소값을 추가 |
| `PieceShape` 형식·`max_piece_cells` 6 | `design/gdd/board-rules.md` | 규칙 3·4, 데이터 값 표 | 카탈로그 25개 모두 통과 |
| 얼굴 위치 결정 | `design/gdd/board-rules.md` | 규칙 5, D5, Open Question Q2 | **해소** — `face_cell = −1`(트레이 RNG), 고정 선택 가능 |
| 알 칸 표현 | `design/gdd/board-rules.md` | 규칙 2 (`TILE.origin = EGG`), D7 | 몽실 털뭉치도 같은 칸, 그림만 다름 |
| 크루 색·명도 띠·윤곽 돌출·무늬 | `design/art/art-bible.md` | 3절 Shape Language, 4절 Color System | 슬롯 4~6 크루 제안 |
| MVP 6명, 희귀 = 독특함, 레벨업 +20% | `design/gdd/game-concept.md` | Pillar 2, Anti-Pillars, MVP Definition | 일치 |
| 크루 사이 비율·얼굴 위치 뽑기 | `design/gdd/tray-supply.md` (미작성) | — | 제안 계약 (F1 1/3 가정) |
| 등급별 확률 | `design/gdd/gacha.md` (미작성) | — | 제안 계약 |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — Section H는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략. Review manually before production.
> AC-01–15·19·20은 `tests/unit/crew_definition/`·`tests/integration/crew_definition/` 자동 테스트(Logic/Integration, BLOCKING), AC-16은 플레이테스트 + 흑백 스크린샷, AC-17은 자동 플레이 시뮬레이션(T0), AC-18은 UI 스크린샷 증거.

**스키마 & 검증 (규칙 1–5, 11–13)**
- **AC-01** — **GIVEN** MVP 레지스트리(6명), **WHEN** 로드, **THEN** 오류 0건·린트 경고 0건이고 `all()`이 6개, `starter_ids()` = {nyangi, gomgom, piyak}을 반환한다.
- **AC-02** — **GIVEN** `primitive: "clear_spiral"`(어휘 밖)인 테스트 크루, **WHEN** 로드, **THEN** 데이터 로드 오류이며 그 크루의 id와 필드 이름을 메시지에 포함한다.
- **AC-03** — **GIVEN** 7칸 모양 / 끊긴 모양 / 정규화 안 된 모양을 가진 테스트 크루 각각, **WHEN** 로드, **THEN** 셋 모두 로드 오류 (board-rules 규칙 3).
- **AC-04** — **GIVEN** 같은 크루에 같은 모양 2회, 또는 `weight = 0`, 또는 `face_cell = 칸 수`, **WHEN** 로드, **THEN** 각각 로드 오류.
- **AC-05** — **GIVEN** 두 크루의 `id`·`colour_slot`·`silhouette_feature`·`body_pattern` 중 하나가 같은 MVP 레지스트리, **WHEN** 로드, **THEN** 로드 오류 (항목별 4케이스).
- **AC-06** — **GIVEN** `lay_eggs_*` 단계가 있고 `fill_visual = null`인 크루, **WHEN** 로드, **THEN** 로드 오류.
- **AC-07** — **GIVEN** 일반 등급 `clear_cross{reach: −1}` 크루와 희귀 등급 `clear_cross{reach: 2}` 크루, **WHEN** 로드, **THEN** 로드 오류(규칙 7·10); 둘 다 일반 등급이면 로드는 되고 린트 경고 1건.
- **AC-08** — **GIVEN** 시그니처 모양이 1개뿐인 테스트 크루, **WHEN** 로드, **THEN** 로드 성공 + 린트 경고 "signature shapes < 2".
- **AC-09** — **GIVEN** 로드된 레지스트리, **WHEN** `crew_abilities`를 만든다, **THEN** 팀 구성과 무관하게 6개 id 모두의 `steps`를 담는다 (규칙 8).
- **AC-10** — **GIVEN** 판 진행 중, **WHEN** 어떤 코드가 `CrewDef` 필드를 쓰려 한다, **THEN** 실패한다 (읽기 전용 — 구현 방식은 ADR; 테스트는 로드 후 리소스 해시가 판 전후 동일함을 확인).

**MVP 크루 6명 (규칙 14) — chain-resolver `resolve`로 검증**
- **AC-11** — **GIVEN** 얼굴 (3,3) 하나만 비어 있고 나머지 63칸이 찬 8×8 스냅샷 보드, **WHEN** 각 CLEAR 크루 능력의 대상 계산(chain-resolver 프리미티브 함수)을 직접 호출, **THEN** 다음 웨이브 대상 수가 냥이 14 · 개굴 13 · 곰곰 8 · 깡총 8이고, 깡총 대상에 (3,2)(2,3)(4,4) 같은 거리 1 칸이 하나도 없다.
- **AC-12** — **GIVEN** 몽실 얼굴 (0,0)이 지워지고 (0,1)·(1,0)이 빈칸, **WHEN** 발동, **THEN** 털뭉치가 offsets 순서대로 (0,0)·(0,1)·(1,0) 3칸에 놓이고(`ABILITY_EFFECT.cells` 순서 동일) 각 칸은 `TILE(origin = EGG, crew_id = mongsil)`이며, (−1,0)·(0,−1)은 보드 밖이라 버려진다.
- **AC-13** — **GIVEN** 삐약 프로토타입 시나리오(chain-resolver F5 예시: 얼굴 (3,5), 3번 행 빈칸 2개), **WHEN** 발동, **THEN** 알 2개가 (3,5)·(3,1) 순서로 놓이고 다음 웨이브에 3번 행이 지워진다.
- **AC-14** — **GIVEN** 같은 보드·같은 배치, **WHEN** `rng_seed`를 1000개 다른 값으로 바꿔 6명 각각 해석, **THEN** 모든 결과(`events`, `final_board`)가 같다 (MVP 크루 RNG 미사용).

**지표 (F1–F5)**
- **AC-15** — **GIVEN** MVP 데이터, **WHEN** 검증 도구가 F1·F2·F3·F5를 계산, **THEN** 냥이 p(I3_H) = 0.25, E = {냥이 3.33, 곰곰 4.75, 삐약 2.00, 개굴 3.75, 깡총 4.00, 몽실 3.25} (±0.01), 모든 E가 2.0–5.0 안, R_c 평균이 F3 표와 같고(±0.01), O(냥이, 개굴) = O(곰곰, 깡총) = 0.

**플레이어 판독 (기둥 2·3)**
- **AC-16** — **GIVEN** 처음 보는 플레이테스터 5명, **WHEN** 각 크루 능력이 한 번 발동하는 것을 본 직후 "이 크루는 어디를 지우나/채우나?"를 묻는다, **THEN** 6명 각각에 대해 5명 중 4명 이상이 범위 모양을 맞힌다. 그리고 **흑백 스크린샷**에서 판 위 6명을 모두 구분한다 (art-bible 4절 검수 기준 — `production/qa/evidence/` 보관).
- **AC-18** — **GIVEN** 팀 편성 화면, **WHEN** 6명의 크루 카드를 표시, **THEN** 카드마다 능력 도해 대상 칸이 해당 크루의 AC-11/12 대상 모양과 일치하고(스크린샷 증거), 숫자 가중치가 화면에 나오지 않는다.

**시뮬레이션 (궁합 가설)**
- **AC-17** — **GIVEN** T0 자동 플레이 봇(같은 시드 세트 200판 × 추천 팀 3개), **WHEN** λ(A→B)를 F4로 집계, **THEN** 모든 크루의 평균 λ(A→·)가 최고 크루의 40% 이상이다. 미달 크루는 Open Question Q1의 조정 대상으로 기록하고, 궁합표 ◎ 칸이 같은 행의 △ 칸보다 λ가 높은지 보고한다 (가설 검증 — 결과는 이 문서 개정으로 반영).

**교차 시스템**
- **AC-19** — **GIVEN** 스테이지 초기 보드에 팀 밖 크루(개굴) 얼굴이 있고 팀은 기본 3인, **WHEN** 그 얼굴이 줄 지우기로 지워진다, **THEN** 개굴 능력이 발동한다 (규칙 8).
- **AC-20** — **GIVEN** 레벨 데이터가 있는 T2 빌드(또는 레벨 값을 주입한 테스트), **WHEN** 같은 보드·배치를 레벨 1과 최대 레벨로 해석, **THEN** `events`의 대상 칸·깊이가 같다 (규칙 9).

## Open Questions

| # | 질문 | 담당 | 해결 시점 |
|---|---|---|---|
| Q1 | 깡총의 연결률(L̂ 0.083, 궁합 ◎ 1칸)이 낮아 "연쇄에 안 끼는 특별 크루"가 될 위험 — AC-17 미달 시 조정 순서: 모양 가중치(작은 조각 추가) → offsets(거리 2 고리 16칸 등). 크기만 키우는 조정은 규칙 7 위반 아님(단일 크루)이나 기둥 2 정신에 비춰 검토 | game-designer · systems-designer | T0 자동 플레이 (AC-17) |
| Q2 | 냥이 지배 위험: 평균 범위 14로 최대, 조각도 작음(E 3.33). 기본 팀에서 냥이만 노리는 단조로운 플레이가 나오면 `reach` 하향 대신 모양 가중치(I4_H↑)로 조정할지 | systems-designer | T0 플레이테스트 + `/balance-check` |
| Q3 | 크루 사이 비율을 균등(1/3)으로 둘지, 크루별 `pool_share`를 크루 데이터에 둘지 — 지금은 트레이 공급 소관으로 두고 크루 데이터에 필드를 만들지 않음 | systems-designer · 트레이 공급 GDD | `/design-system tray-supply` |
| Q4 | 냥이·곰곰·깡총 세 크루가 "귀" 계열 돌출 — art-bible 3절 "같은 돌출 유형 공유 금지" 위반인가. 위반이면 깡총을 뿔 유형 동물로 교체 (능력·모양은 유지) | art-director | art-bible 5절 작성 시 |
| Q5 | 몽실 털뭉치를 플레이어 용어로 "알"이라 부를지 "털뭉치"라 부를지 — 규칙상 같은 칸이라 튜토리얼 문구 통일 필요 | writer · ux-designer | 튜토리얼 / UX 스펙 |
| Q6 | 등급 3단계(COMMON/RARE/SPECIAL)와 MVP 배정(일반 3 · 희귀 2 · 특별 1)이 가챠 확률·천장 설계에 맞는가 | economy-designer · 가챠 GDD | `/design-system gacha` |
| Q7 | `CrewDef` 리소스 분할(하위 리소스 vs 인라인), `steps`를 Custom Resource로 둘지 Dictionary로 둘지, 런타임 불변 보장 방식, 4.7 typed-return override 영향 | technical-director | `/architecture-decision` (chain-resolver Q7과 같은 ADR) |

### Decision Log (사용자 위임 "진행부탁 알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 기각한 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier) | Summary·Overview·Detailed Design·Formulas(가중치·지표 = 숫자 규칙)·Edge Cases·Dependencies·AC + Visual/Audio·Game Feel(Gameplay 필수)·Cross-References(의존 있음)·UI Requirements·Open Questions ("All of them" 권장안). Player Fantasy·Tuning Knobs 생략 | Tuning Knobs 섹션 추가 — tier 규칙 위반; 데이터 값은 규칙·변수표에 둠 |
| D2 | Overview 프레이밍 | Both / ADR 인용 안 함(ADR 없음) / Fantasy 있음이나 tier상 섹션 생략 | 기술 프레이밍만 — Gameplay라 player-facing 우선 |
| D3 | 크루 표현 | 크루 = 데이터 리소스 1장, 코드 없음, 능력 = 해석기 프리미티브 조합 | 크루별 스크립트 — 순환 의존·미리보기 불일치 위험 (chain-resolver D8) |
| D4 | 얼굴 위치 (board-rules Q2) | `face_cell = −1` 기본(트레이가 시드 RNG로), 모양별 고정 선택 가능; MVP 전부 −1 | 모양별 고정 얼굴 — 계획성 ↑이지만 같은 모양이 매번 같은 수가 되어 트레이 다양성 ↓, 프로토타입 검증과 다름 |
| D5 | 크루 1~3 | 컨셉·프로토타입의 능력과 모양 세트 그대로 (곰곰 색만 art-bible 변경값) | 모양 재설계 — 검증된 손맛을 버릴 이유 없음 |
| D6 | 새 크루 3명 | 개굴 `clear_diagonals` · 깡총 `clear_pattern`(두 칸 고리) · 몽실 `lay_eggs_pattern`(십자) — 남은 프리미티브를 각각 다른 동작으로 사용, 축마다 대상 겹침 0 짝 | `clear_line` 크루(한 축만 지우는 고양이 하위 호환 — "더 약한 냥이"), 랜덤 대상 크루(안티 기둥), 새 프리미티브(`clear_crew_tiles` 등 — 해석기 변경 필요, MVP 범위 밖) |
| D7 | 동물 선택 | 개구리·토끼·양 — 3절 돌출 규칙(잎·긴 귀·곱슬 윤곽), 슬롯 4~6 색(초록·보라·분홍)과 자연스러운 짝 | 부엉이(깃털 귀 — 삐약 깃털과 같은 유형), 고슴도치(가시 — 3절 "날카로운 형태 금지"), 문어(머리 돌출 없음) |
| D8 | 등급 | 3단계, 수치 영향 없음, 상위 등급은 다른 동작 필수(규칙 7); 기본 3인 일반 · 개굴·몽실 희귀 · 깡총 특별(가장 낯선 동작) | 등급 = 범위 크기 — 안티 기둥 위반; 등급 없음 — 가챠 확률 표시 구간이 필요 |
| D9 | 모양 공유 | 허용 + 크루당 시그니처 ≥ 2 린트 | 공유 금지 — 24명 확장 시 작은 모양 고갈, 삐약·몽실 같은 작은 조각 크루가 불리 |
| D10 | 크루 사이 비율 | 트레이 공급 소관, 크루 데이터에 필드 없음 (Q3) | `pool_share` 필드 — 크루가 트레이 규칙을 알게 됨 |
| D11 | 레벨업 | `CrewDef`에 레벨 필드 없음, 레벨업은 점수 보너스만(≤ +20%) | 레벨업으로 `reach`/`radius` 증가 — 미리보기 학습이 레벨마다 바뀌고 "과금 = 수치 우위" |
| D12 | id 수명 | 영구 불변, 삭제 없음, `obtainable = false`로 은퇴 | 삭제 허용 — 세이브·스테이지 보드 손상 |
| D13 | 색 데이터 | 크루는 `colour_slot`만, hex는 팔레트 리소스 | 크루에 hex 직접 — art-bible 개정 시 6곳 수정, 명도 띠 검증 불가 |
| D14 | 궁합 | 원리 3개 + 방향 궁합표를 **가설**로 두고 자동 플레이 λ로 검증 | 확정 수치표 — 시뮬레이션 전에는 근거 없음 |
