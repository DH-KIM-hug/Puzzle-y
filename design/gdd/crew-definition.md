# 크루 정의 & 능력 (Crew Definition & Abilities)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 1 도미노의 손맛

## Summary

[To be designed]

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `[To be designed]`

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
