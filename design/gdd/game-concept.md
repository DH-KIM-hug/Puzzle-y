# Game Concept: 작은 섬 개척 (가제: Tiny Isle)

*Created: 2026-11-21*
*Status: Draft*
*Previous project "말랑 크루" archived in `archive/mallang-crew/`.*

> **2026-11-21 개정**: 핵심 규칙을 "무리 크기 = 자원 수치"에서 **"무리 크기 = 일꾼 행동 횟수(선택이 있는 반복 행동) + 길목 보너스 연쇄"**로 바꿨다(사용자 결정: 행동 5종 — 배 항해·길 놓기·수확·양떼 몰기·주민 파견, 건물 4종). 최신 규칙은 `design/tiny-isle-design-doc.md`가 우선한다. 아래 Core Mechanics·Core Loop의 자원 트랙 서술은 v1 기준.


---

## Elevator Pitch

> 빈 육각 섬에 밭·숲·목장·물·집이 그려진 2칸 타일을 한 장씩 붙이는 1인용 퍼즐 개척 게임.
> 붙인 칸이 맞닿은 같은 종류 무리가 클수록 큰 일이 일어나고, 그 일이 자원 트랙을 넘겨 다음
> 보너스를 깨우는 연쇄로 — 장난감 디오라마 같은 섬이 내 손에서 자라난다.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 1인용 타일 배치 퍼즐 + 가벼운 개척(농장·마을) 경영 |
| **Platform** | PC (Steam) + Mobile (iOS/Android). 개발 중 테스트는 웹 빌드 링크 |
| **Target Audience** | 계획형 퍼즐러, 보드게임 애호가 (아래 Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 섬 한 판 20~30분 (계절 단위로 끊어 쉬기 가능), 세션 15~60분 |
| **Monetization** | 무료 + 광고/소액결제 (구체 모델은 MVP 재미 검증 후 결정 — 아래 Risks) |
| **Estimated Scope** | Medium (6개월+, solo). MVP는 그 안의 첫 3~4개월 |
| **Comparable Titles** | Dorfromantik, Islanders, Townscaper(시각화) · 보드게임 Ingenious, Witchstone(메커니즘 계열) |

---

## Core Fantasy

**빈 섬이 내 손에서 작은 왕국으로.** 타일 한 장을 고민 끝에 붙이면 밀밭이 이어지고, 수확이 곡식
트랙을 넘겨 풍년 보너스가 터지고, 그 보너스가 목장을 키워 주민이 늘고 — 섬 위에서는 나무가
솟고 집에 불이 켜지고 양이 돌아다닌다. "내가 설계한 연쇄가 그대로 섬을 키웠다."

---

## Unique Hook

**"Dorfromantik처럼 타일을 이어 섬을 만드는데, 타일 한 장이 맞닿은 무리 크기만큼 일을 일으키고 그 일이 다음 일을 깨우는 보드게임식 연쇄가 있다."**

- 타일 연결 게임(Dorfromantik, Islanders)은 대부분 "인접 점수"에서 끝난다. 이 게임은 보드게임
  Witchstone 계열의 **무리 크기 → 행동 → 트랙 문턱 → 보너스 행동** 연쇄로 한 장의 배치가 여러 단계로 번진다.
- 기본 평가는 **합산 점수**, 섬마다 **다른 숙제**(균형 평가, 특정 타일 금지, 물 2배 등)가 붙어 같은
  규칙이 섬마다 다른 퍼즐이 된다.
- 메커니즘 계열만 같고 이름·아트·트랙 구성·점수판은 오리지널이다.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** | 1 | 손패 3장 중 선택, 연쇄 설계, 섬 숙제, 별 1~3 |
| **Sensation** | 2 | 디오라마 섬이 자라는 모습, 연쇄 연출 |
| **Discovery** | 3 | 새 타일·건물 해금, 섬 숙제 변주, 무작위 섬 모드 |
| **Expression** | 4 | 섬 모양 꾸미기(같은 점수라도 다른 모양) |
| **Submission** | 5 | 턴제·시간 압박 없음, 포근한 섬 |
| **Fantasy** | 6 | 개척자/섬 주인 |
| **Narrative** | N/A | 섬 소개 한두 줄 외 스토리 없음 |
| **Fellowship** | N/A | (T3에서 일일 섬 공유 점수판 검토) |

### Key Dynamics (Emergent player behaviors)
- 손패를 보며 "이 장을 여기 두면 곡식 트랙이 문턱을 넘고 풍년 보너스로 한 장 더"를 계산한다.
- 무리를 일부러 키워 두었다가 한 장으로 크게 발동시킨다.
- 섬 숙제에 따라 평소와 다른 배치 전략을 찾는다(균형 섬 vs 합산 섬).
- 별 3개를 위해 같은 섬을 다른 순서로 다시 한다.

### Core Mechanics (Systems we build)
1. **육각 섬 & 2칸 타일 배치** — 손패 3장, 배치 후 1장 보충, 회전 가능(6방향), 지형 제약(바다·산).
2. **무리 발동** — 놓인 두 칸이 각각 맞닿은 같은 종류 무리 크기만큼 그 종류의 행동(자원 획득 등) 발동.
3. **자원 트랙 & 연쇄** — 자원이 트랙을 오르고 문턱마다 보너스(타일 업그레이드, 추가 배치, 다른 트랙 +N…)가 터져 연쇄. 놓기 전 미리보기.
4. **계절 진행** — 계절마다 정해진 장수, 계절 끝에 주민 식량 소비, 인구에 따라 새 타일 해금.
5. **섬 캠페인 & 숙제** — 섬별 지형·목표·숙제·별 기준; 캠페인 클리어 후 무작위 섬 도전 모드.
6. **디오라마 시각화** — 무리 크기·단계에 따라 섬 위 오브젝트가 자라고(나무, 집, 동물, 주민) 연쇄 연출.

---

## Player Motivation Profile

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 손패 선택, 배치·회전, 섬 모양 | Core |
| **Competence** | 연쇄 설계 성공, 별 3개, 숙제 클리어 | Core |
| **Relatedness** | 내 섬에 사는 주민·동물 | Supporting |

- [x] **Achievers** — 별 3개, 캠페인 완주, 무작위 모드 최고 점수
- [x] **Explorers** — 연쇄 조합·숙제별 전략 발견
- [ ] **Socializers** — (T3 공유 점수판 검토)
- [ ] **Killers/Competitors** — 해당 없음

### Flow State Design
- **Onboarding curve**: 섬 1 밭·숲 2종만, 무리 발동 체험 → 섬 2 트랙 문턱 보너스 → 섬 3 연쇄 → 섬 4 계절·식량 → 섬 5+ 숙제 변주.
- **Difficulty scaling**: 섬 지형 제약 ↑, 장수 ↓, 숙제 조합, 별 기준 ↑.
- **Feedback clarity**: 놓기 전 미리보기(발동 행동·트랙 변화·연쇄 단계), 섬 위 성장 연출.
- **Recovery from failure**: 계절 단위 되감기 없이 즉시 재도전, 실패해도 별 1개 기준은 넉넉하게.

---

## Core Loop

### Moment-to-Moment (30 seconds)
손패 3장 중 하나를 고르고, 섬 위로 끌며 회전 → 미리보기로 발동·연쇄 확인 → 붙임 → 무리 발동, 트랙
상승, 문턱 보너스 연쇄가 섬 위에 연출됨 → 1장 보충.

### Short-Term (5-15 minutes)
계절 하나 = 정해진 장수 배치 → 계절 끝 식량 소비·인구 정산 → 새 타일 해금 → 다음 계절.

### Session-Level (30-120 minutes)
섬 하나(4계절)를 끝내고 점수·숙제·별 정산 → 다음 섬 또는 별 3개 재도전. 섬 클리어가 자연스러운 정지점.

### Long-Term Progression
캠페인 섬 진행(MVP 10개 → 풀 비전 20개+), 새 타일·건물 해금, 캠페인 후 무작위 섬 도전 모드(최고 점수).

### Retention Hooks
- **Curiosity**: 다음 섬의 숙제, 해금될 건물
- **Investment**: 키워 온 캠페인 진행, 해금한 타일
- **Mastery**: 별 3개 못 받은 섬, 무작위 모드 최고 점수

---

## Game Pillars

### Pillar 1: 한 장의 연쇄 (One-Tile Cascade)
타일 한 장이 여러 행동을 연달아 깨워야 한다.

*Design test*: 새 규칙이 연쇄를 늘리는가, 장부 정리만 늘리는가 → **연쇄를 늘리는 쪽**.

### Pillar 2: 섬마다 다른 숙제 (Every Isle Its Own Rule)
기본 평가는 합산 점수, 섬마다 조건(숙제)이 달라 같은 규칙이 다른 퍼즐이 된다. 균형 평가(가장 약한 지표)는 숙제 중 하나.

*Design test*: 새 섬을 만들 때 지형만 바꿀지, 숙제를 붙일지 → **숙제가 전략을 바꾸는가**로 판단. 전략이 안 바뀌면 숙제를 바꾼다.

### Pillar 3: 살아 있는 섬 (A Living Island)
모든 숫자는 섬 위에서 보인다.

*Design test*: 상태를 UI 숫자로 보여줄지 섬 모습으로 보여줄지 → **섬 먼저**, UI는 보조.

### Pillar 4: 보이는 결과 (Readable Moves)
놓기 전에 발동과 연쇄를 알 수 있다 (이전 프로젝트 교훈: 미리보기 없이는 규칙이 안 읽힘).

*Design test*: 무작위 효과와 예측 가능한 효과 중 → **예측 가능한 효과**. 미리보기와 실제 결과가 다르면 버그.

### Anti-Pillars (What This Game Is NOT)
- **NOT 실시간·시간 압박**: 계획 퍼즐을 반사신경 게임으로 바꾼다.
- **NOT 복잡한 경제 시뮬레이션**: 자원 6종 이하, 가격 변동·물류 없음 — '한 장의 연쇄'가 장부에 묻힌다.
- **NOT 전투·재해로 인한 파괴**: 포근한 개척 톤을 깬다.
- **NOT 처리 중 무작위(주사위 등)**: '보이는 결과'를 깬다. 무작위는 손패 뽑기에만.
- **NOT 결제 = 점수**: 소액결제는 꾸미기·편의·콘텐츠 팩으로, 점수와 별에 영향 없음.

---

## Visual Identity Anchor

**방향: 보드게임 디오라마 (Board-Game Diorama)** — 사용자 선택 (B 수채 지도, C 픽셀 아일랜드 기각).

**비주얼 규칙**: "섬은 탁자 위의 장난감 보드게임이다."

**지원 원칙**
1. **나무 타일 + 장난감 오브젝트** — 육각 타일은 두께 있는 나무판, 그 위 오브젝트(나무·집·양·배)는 둥근 장난감 형태.
   *Design test*: 새 에셋이 탁자 위 장난감으로 읽히지 않으면 반려.
2. **놓으면 톡 솟는다** — 배치·발동 시 오브젝트가 아래에서 튀어오르고, 무리가 커지면 오브젝트가 업그레이드(묘목→나무→숲).
   *Design test*: 상태 변화가 오브젝트 변화로 보이는가(Pillar 3).
3. **타일 종류는 색 + 실루엣 + 오브젝트로 3중 구분** — 색만으로 구분하지 않는다(색약).
   *Design test*: 흑백 스크린샷에서 타일 종류를 구분할 수 있는가.

**색 철학**: 따뜻한 원목 탁자 배경, 바다는 차분한 청록, 타일은 중채도 자연색(밀 금색, 숲 초록, 목장 연두, 물 하늘, 집 테라코타). 연쇄 강조는 밝은 빛·반짝임으로.

*Technical decision (2026-11-21, 사용자)*: **스프라이트 스태킹** — 2D 단면 이미지를 층층이 쌓아 복셀 장난감 같은 입체감을 내는 기법. 2D 프로젝트(Compatibility 렌더러), 카메라는 좌우 회전(yaw)만, 기울기 고정. 오브젝트는 MagicaVoxel 단면 또는 코드 생성, 성장 단계는 층 구성 변경. 3D 로우폴리는 기각(아트·성능 비용).

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Ingenious (보드게임) | 육각 판 + 2칸 타일, 같은 종류 연결로 점수 | 1인 퍼즐, 무리 발동·연쇄, 합산 기본 + 균형은 섬 숙제 | 단순하고 깊은 배치 규칙의 검증 |
| Witchstone (보드게임) | 같은 색 무리 크기만큼 행동 → 콤보 | 테마를 개척으로, 트랙·행동은 오리지널, 미리보기 | 콤보 쾌감의 핵심 |
| Dorfromantik / Islanders | 타일로 지형을 넓히는 아늑한 진행, 시각적 만족 | 보드게임식 연쇄와 섬별 숙제 | 시장성과 톤 |
| Townscaper | 놓으면 자라는 시각화의 기쁨 | 점수·퍼즐 목적 | Pillar 3 |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 15~40 |
| **Gaming experience** | Casual ~ Mid-core |
| **Time availability** | 평일 20~30분 한 섬, 주말 몰아서 |
| **Platform preference** | PC(Steam) 및 스마트폰 |
| **Current games they play** | Dorfromantik, Islanders, 보드게임 앱 |
| **What they're looking for** | 머리 쓴 만큼 터지는 연쇄 + 자라는 섬 구경 |
| **What would turn them away** | 시간 압박, 과도한 광고, 결제 = 점수, 장부 같은 경제 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | Godot 4.7 (사용자 선택; 이전 프로젝트에서 설치·웹 빌드·테스트 체계 검증) |
| **Key Technical Challenges** | 육각 좌표·회전, 결정적 연쇄 해석기와 미리보기 공유(이전 ADR 패턴 재사용 가능), 디오라마 시각화 성능(모바일), PC/모바일 입력 이중 대응 |
| **Art Style** | 디오라마 — 스프라이트 스태킹(2D 층 쌓기 의사 3D) |
| **Art Pipeline Complexity** | Medium~High (오브젝트 성장 단계별 에셋) |
| **Audio Needs** | Moderate (나무 타일 딸깍, 자연음, 연쇄 효과음) |
| **Networking** | None (T2 이후 광고·결제 SDK, T3 점수판 검토) |
| **Content Volume** | MVP: 타일 종류 6, 캠페인 섬 10. 풀 비전: 섬 20+, 건물 다수, 무작위 모드 |
| **Procedural Systems** | 손패 뽑기(시드), 무작위 섬 모드의 섬 생성(T2) |

---

## Risks and Open Questions

### Design Risks
- 연쇄가 계산하기 너무 어려우면 장부처럼 느껴진다 → 미리보기 필수, 트랙 수 제한.
- 합산 점수에서 한 자원 몰빵이 최적이 될 수 있다 → 트랙 문턱 보너스가 다른 트랙을 올리도록 설계, 섬 숙제로 변주.
- 경영 요소(식량·인구)가 퍼즐을 무겁게 만들 위험 → 계절 정산은 단순하게, 자원 6종 이하.

### Technical Risks
- 디오라마 시각화의 아트·성능 비용(모바일).
- 육각 + 회전 + 2칸 타일의 입력 UX(터치에서 회전 조작).

### Market Risks
- 타일 배치 아늑 게임 장르 경쟁(Dorfromantik 등) → 차별점은 보드게임식 연쇄와 섬 숙제.
- 무료 + 광고/소액결제는 퍼즐 장르 신뢰를 해칠 수 있음 → 광고는 선택형(보상형) 위주, 결제 = 점수 금지.

### Legal / Platform Risks
- 보드게임 메커니즘 계열은 허용되나 이름·아트·카드/트랙 구성은 오리지널로(Ingenious·Witchstone 명칭 미사용).
- 소액결제 시 확률형 상품을 넣는다면 확률 공개 의무(한국 게임산업법) — 현재 계획엔 확률형 없음.

### Scope Risks
- 두 테마(농장+마을) + 캠페인 + 무작위 모드 + 멀티 플랫폼 → MVP에서 무작위 모드·결제·모바일 빌드 이연.
- 1인 개발, 디오라마 아트 물량.

### Open Questions
- (해결) 비주얼 기술 = 스프라이트 스태킹. 남은 질문: 섬 전체(타일 ~100 × 오브젝트 × 층) 그리기 성능 → 프로토타입에서 측정.
- 손패 3장 + 보충 1장, 타일 회전 6방향이 터치에서 편한가? → 프로토타입.
- 트랙 문턱 보너스의 종류와 연쇄 빈도는? → 페이퍼/HTML 프로토타입으로 검증.
- 계절 정산(식량 소비)이 재미를 더하는가, 부담인가? → 프로토타입 A/B.

---

## MVP Definition

**Core hypothesis**: 플레이어는 손패의 타일을 놓기 전 미리보기를 보며 무리 발동과 트랙 연쇄를 설계하고, 연쇄가 섬 위에 자라나는 순간에 재미를 느껴 같은 섬을 별 3개까지 다시 한다.

**Required for MVP**:
1. 육각 섬 + 2칸 타일 배치(손패 3장, 회전, 지형 제약)
2. 무리 발동 + 자원 트랙 + 문턱 보너스 연쇄 + 놓기 전 미리보기 (결정적 해석기)
3. 타일 종류 6 (밭·숲·목장·물·집 + 해금 1)
4. 계절 진행 + 식량·인구 정산(단순형)
5. 캠페인 섬 10개 (섬별 숙제·별 기준), 합산 점수
6. 디오라마 시각화(오브젝트 성장 단계, 연쇄 연출) + 로컬 세이브

**Explicitly NOT in MVP**: 무작위 섬 모드, 광고·소액결제, 모바일 스토어 빌드, 건물 다수, 점수판, 꾸미기.

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **T0 프로토타입** | 섬 1개, 타일 3~4종 | 배치·무리 발동·트랙 연쇄·미리보기 (HTML 또는 Godot 그레이박스) | ~2~4주 |
| **T1 MVP** | 섬 10개, 타일 6종 | 위 MVP 6항목 | ~3~4개월 |
| **T2 소프트런치** | 섬 20개, 무작위 섬 모드 | + 광고(보상형)·소액결제, PC(Steam)·모바일 빌드 | ~6개월+ |
| **T3 풀 비전** | 섬 30+, 건물 다수 | 점수판, 꾸미기, 이벤트 섬 | 출시 후 업데이트 |

---

## Director Gate Results

| Gate | Verdict | Notes |
| ---- | ---- | ---- |
| CD-PILLARS | SKIPPED — lean mode | 기둥 2를 사용자 요청으로 "균형이 실력" → "섬마다 다른 숙제"(기본 합산, 균형은 숙제)로 변경 |
| AD-CONCEPT-VISUAL | SKIPPED — lean mode | 방향 3안 제시, 사용자가 디오라마 선택 |
| TD-FEASIBILITY | SKIPPED — lean mode | |
| PR-SCOPE | SKIPPED — lean mode | |

---

## Next Steps

- [ ] `/setup-engine godot` — 새 게임 기준 재설정(플랫폼 PC+모바일, 2D/3D 결정)
- [ ] `/prototype 육각 2칸 타일 무리 발동 + 트랙 연쇄` — 핵심 재미 검증 (T0)
- [ ] PROCEED 시 `/art-bible` → `/map-systems` → `/design-system`
