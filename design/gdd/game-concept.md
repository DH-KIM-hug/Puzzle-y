# Game Concept: 말랑 크루 (Mallang Crew)

*Created: 2026-11-07*
*Status: Draft*

---

## Elevator Pitch

> 오려 붙인 스티커처럼 생긴 동물 크루를 60초 동안 정신없이 맞추고, 게이지가 차면
> 탭 한 번으로 크루원의 고유 스킬을 터뜨리는 실시간 매치-3 퍼즐. 크루원을 모아
> 3인 팀을 짜고, 스킬끼리 이어지는 연쇄 콤보로 스테이지를 깬다.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 캐주얼 퍼즐 — 실시간 매치-3(블리츠) + 캐릭터 수집 |
| **Platform** | Mobile (Android 우선, iOS는 이후), 세로 화면 터치 |
| **Target Audience** | 수집형 성취가 (아래 Player Profile 참조) |
| **Player Count** | Single-player |
| **Session Length** | 한 판 60초, 한 세션 10~30분 |
| **Monetization** | F2P + 크루 가챠 (게임 내 재화 + 유료 재화). 안전장치: 천장(pity), 중복 → 조각 교환, 확률 공개. 유료 결제(IAP)는 T2 소프트런치부터 |
| **Estimated Scope** | MVP: Small (2~3개월, solo, MVP 완성 + 재미 검증까지). 풀 비전: Medium (출시 이후 업데이트로 확장, 별도 재추정) |
| **Comparable Titles** | Disney Emoji Blitz, LINE: 디즈니 츠무츠무, Puzzle & Dragons(팀 편성) |

---

## Core Fantasy

내가 모은 최애 크루원이 보드를 뒤집는 **한 방**. 60초의 아슬아슬한 순간에 게이지가
가득 찬 크루원을 탭하면, 스티커가 들썩 떼어지며 스킬이 터지고 — 그 결과가 옆 팀원의
게이지를 채워 또 한 번 터지는 연쇄. "이 셋을 같이 데려오면 이렇게 된다"는 걸 내가
알아냈다는 뿌듯함.

---

## Unique Hook

**"이모지 블리츠 같은 캐릭터 스킬 매치-3인데, 3인 크루의 스킬이 서로 연쇄 콤보를 만든다."**

- 캐릭터마다 스킬이 있는 매치-3는 많지만, 대부분 스킬이 서로 독립적이다.
  말랑 크루는 A의 스킬 결과(지운 타일 색, 생성한 특수 타일)가 B의 게이지·효과를
  바꾸도록 설계해, **팀 구성 자체가 퍼즐**이 된다.
- "오리지널 캐릭터"는 훅이 아니라 전제 조건이다 (모든 캐릭터·아트는 오리지널).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** (obstacle course, mastery) | 1 | 60초 제한, 스테이지 목표, 별 1~3개, 스킬 발동 타이밍 숙련 |
| **Sensation** (sensory pleasure) | 2 | 스킬 발동 연출 최우선 — 스티커 떼어짐, 스쿼시&스트레치, 파티클, 컷인, 사운드 |
| **Expression** (self-expression, creativity) | 3 | 3인 팀 조합, 나만의 시너지 발견 |
| **Discovery** (exploration, secrets) | 4 | 새 크루원 = 새 스킬, 숨은 시너지 쌍 |
| **Fantasy** (make-believe, role-playing) | 5 | 귀여운 크루원 캐릭터성, 최애 애착 |
| **Submission** (relaxation, comfort zone) | 6 | 짧은 판, 귀여운 실패 연출, 압박 없는 진행 |
| **Narrative** (drama, story arc) | N/A | 긴 스토리 없음 (안티 기둥) |
| **Fellowship** (social connection) | N/A | 온라인/소셜 기능 없음 |

### Key Dynamics (Emergent player behaviors)
- 막힌 스테이지에서 **팀 구성을 바꿔가며 실험**한다 ("이 판은 폭탄형 둘이 필요해").
- 게이지가 찼어도 **바로 쓰지 않고 연쇄 타이밍을 기다린다** (팀원 게이지가 차기 직전까지).
- 새 크루원을 얻으면 **예전에 별 3개를 못 받은 판으로 돌아간다**.
- 특정 색을 의도적으로 노려 맞춘다 (원하는 크루원 게이지를 먼저 채우려고).

### Core Mechanics (Systems we build)
1. **실시간 매치-3 보드** — 7×9, 6색, 스왑·매치 판정·캐스케이드·리필, 캐스케이드 중 입력 허용(칸 단위 상태).
2. **크루 게이지 & 스킬 발동** — 색 = 크루원, 매치하면 해당 크루원 게이지 충전, 탭으로 발동.
3. **데이터 기반 스킬 조합** — 소수의 효과 프리미티브(줄 지우기, 범위 폭발, 색 변환, 게이지 충전 등)를 데이터로 조합해 각 크루원 스킬을 정의. 시너지는 이벤트 큐 + 연쇄 깊이 상한.
4. **팀 편성 & 수집(가챠)** — 스테이지 전 3인 편성(재시도 시 직전 팀 유지). 크루는 가챠로 획득: 게임 내 재화(코인/스티커 티켓) + 유료 재화. 천장, 중복 → 조각(조각으로 원하는 크루 교환), 등급별 확률 공개.
5. **스테이지 & 목표** — 점수 / 특정 타일 N개 수집 / 방해물 제거, 별 1~3개.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 3인 팀 편성, 스킬 발동 타이밍 선택 | Core |
| **Competence** (mastery, skill growth) | 60초 내 목표 달성, 별 3개, 연쇄 콤보 성공 | Core |
| **Relatedness** (connection, belonging) | 최애 크루원에 대한 애착, 귀여운 반응 | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: 크루 도감 완성, 전 스테이지 별 3개
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: 숨은 시너지 쌍 발견, 스킬 조합 실험
- [ ] **Socializers** (relationships, cooperation, community) — How: 해당 없음 (온라인 없음)
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: 해당 없음 (리더보드는 풀 비전 이후 검토)

### Flow State Design

- **Onboarding curve**: 1-1은 크루 1명·스킬 없이 매치만, 1-2에서 게이지·스킬 첫 발동(강제 튜토리얼 1회), 1-3에서 3인 팀, 1-5 전후 첫 시너지 쌍 체험.
- **Difficulty scaling**: 목표 수치 상승 → 방해물 등장 → 특정 스킬 유형이 유리한 판 설계. 레벨업은 최대 +20%로 상한을 둬 실력·조합이 주역.
- **Feedback clarity**: 점수·콤보 카운터, 게이지 시각화, 별 기준선이 타이머 바에 표시, 결과 화면에 "최고 연쇄" 표시.
- **Recovery from failure**: 실패 시 크루원이 "푸슝" 주저앉는 귀여운 연출 → **원탭 재시작(직전 팀 유지)**. 페널티(스태미나 등) 없음.

---

## Core Loop

### Moment-to-Moment (30 seconds)
60초 블리츠 안에서 타일을 스와이프해 3개 이상 맞춘다. 맞춘 색의 크루원 게이지가 차고,
가득 차면 크루원 아이콘을 탭해 스킬 발동. 연쇄(캐스케이드)와 스킬 연출이 손맛의 핵심이며,
스킬 발동이 일반 매치보다 **압도적으로** 시원해야 한다 (기둥 1).

### Short-Term (5-15 minutes)
스테이지 하나 = 팀 편성(또는 직전 팀 유지) → 60초 블리츠 → 결과(별 1~3, 코인·티켓) → 재도전 또는
다음 스테이지. "한 판만 더"는 별 3개 기준선을 아깝게 놓쳤을 때, 그리고 다른 팀 조합이
떠올랐을 때 생긴다.

### Session-Level (30-120 minutes)
10~30분 동안 스테이지 몇 개를 클리어하고 코인·티켓을 모아 가챠로 새 크루원을 뽑는다. 새 크루원을
얻는 순간(스티커 팩 개봉 연출)이 자연스러운 정지 지점이자 다음 세션의 동기("이 친구로 막힌 판 다시 해보자").

### Long-Term Progression
월드맵을 따라 스테이지 진행(MVP 10스테이지 → 풀 비전 60스테이지), 크루 도감 채우기
(MVP 6명 → 풀 비전 24명+), 전 스테이지 별 3개. 마지막 월드 클리어 + 도감 완성이 "끝".

### Retention Hooks
- **Curiosity**: 가챠 픽업 크루원의 실루엣과 스킬 힌트, 아직 못 찾은 시너지 쌍, 천장까지 남은 횟수
- **Investment**: 모은 크루원, 레벨업한 최애, 쌓아둔 조각
- **Social**: 해당 없음
- **Mastery**: 별 3개 못 받은 스테이지, 최고 연쇄 기록

---

## Game Pillars

### Pillar 1: 한 방의 손맛 (Skill Burst Juice)
스킬 발동은 일반 매치보다 압도적으로 시원해야 한다.

*Design test*: 연출 예산이 부족하면, 일반 매치·메뉴보다 **스킬 발동 연출부터** 다듬는다.

### Pillar 2: 크루가 곧 전략 (Crew Is Strategy)
3인 팀 구성이 클리어 경로를 바꾼다.

*Design test*: (1) 같은 스테이지에서 팀이 다르면 클리어 경로가 눈에 띄게 달라지는가?
(2) A의 스킬 결과가 B의 게이지나 효과를 바꾸는가? 새 크루원을 수치 상향과 새 동작 중
하나로 만들어야 하면 → **새 동작**. 시너지는 **팀 편성 단계에서 고민**하고, 플레이 중에는
발동 타이밍만 판단한다. 레벨업 효과는 **최대 +20%로 상한**.

### Pillar 3: 한 판 더 (One More Round)
짧은 판과 즉각적인 재도전.

*Design test*: 결과 화면에 정보를 더할지, 재시작을 빠르게 할지 → **재시도 시 직전 팀을
유지한 원탭 시작**. 팀 변경은 선택 사항.

### Pillar 4: 다정한 세계 (Gentle World)
잔인함이 없고, 실패조차 귀엽다.

*Design test*: 패배 연출을 긴장감 있게 할지, 웃기게 할지 → **웃음**.

### Anti-Pillars (What This Game Is NOT)

- **NOT 바닥 없는 가챠**: 천장 없는 뽑기, 확률 비공개, 중복이 쓸모없는 구조는 '다정한 세계'를 해친다. 가챠는 허용하되 천장·조각 교환·확률 공개를 반드시 둔다.
- **NOT 과금 = 수치 우위**: 희귀 크루원은 '더 센' 수치가 아니라 '더 화려하고 독특한' 동작으로 차별화한다 (기둥 2). 수치 강화는 +20% 상한 유지.
- **NOT 스태미나(에너지) 대기 시스템**: 기다리게 만들면 '한 판 더'가 깨진다.
- **NOT 수치만 다른 복붙 캐릭터**: 크루원마다 고유한 동작이 없으면 '크루가 곧 전략'이 무너진다.
- **NOT 긴 스토리 컷신**: '한 판 더'의 템포와 솔로 일정을 해친다.

---

## Visual Identity Anchor

**방향: 스티커북 (Sticker Book)** — art-director 제안 3종(젤리 팝 / 스티커북 / 네온 간식) 중 사용자 선택.

**비주얼 규칙**: "모든 것은 손으로 오려 붙인 스티커다."

**지원 원칙**
1. **두꺼운 흰 테두리 + 살짝 불규칙한 실루엣** — 모든 크루원·타일·UI 버튼은 오려낸 스티커 윤곽을 가진다.
   *Design test*: 새 에셋이 배경 위에서 "붙어 있는 스티커"로 읽히지 않으면 반려. 테두리는 런타임 셰이더가 아니라 **텍스처에 구워 넣는다** (TD 권고, 모바일 성능).
2. **스킬 발동 = 스티커가 들썩 떼어짐** — 발동 시 스티커가 종이에서 떨어져 나와 흔들리고 다시 붙는 연출. 기둥 1의 시각적 표현.
   *Design test*: 스킬 연출이 "떼어짐 → 효과 → 붙음" 문법을 따르는가?
3. **수집 화면 = 스티커 앨범** — 크루 도감은 앨범 페이지, 미획득은 점선 빈칸 실루엣, 희귀 크루원은 홀로그램 테두리 (홀로 셰이더는 UI에만).
   *Design test*: 수집 UI가 앨범 메타포를 깨면 반려.

**색 철학**: 크라프트지/종이 질감 바탕 위에 중채도 원색 6색(색 = 크루원 = 게이지). 배경은
따뜻한 저채도라 타일이 항상 먼저 보인다. 색약 대응을 위해 **색만으로 구분하지 않고**
크루원마다 실루엣·아이콘 차이를 반드시 둔다. 터치 대상은 최소 약 64px(1080p 기준).

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Disney Emoji Blitz | 캐릭터 = 타일, 게이지 충전 후 스킬 발동, 짧은 실시간 판, 캐릭터 수집 | 오리지널 크루·스티커 아트, 3인 팀과 스킬 간 연쇄 시너지, 천장·조각 교환·확률 공개로 '적당한' 가챠 | 사용자가 가장 즐긴 게임 — 핵심 재미 공식이 검증됨 |
| LINE: 디즈니 츠무츠무 | 60초 블리츠 템포, 캐릭터별 스킬 개성 | 체인 대신 스왑 매치-3, 팀 편성 | 짧은 판 + 수집의 리텐션 검증 |
| Puzzle & Dragons | 퍼즐 전 팀 편성이 결과를 좌우 | 턴제 RPG 전투 없이 순수 퍼즐 목표 | "팀 구성이 퍼즐"이라는 훅의 근거 |

**Non-game inspirations**: 어린이 스티커북·다이어리 꾸미기, 문구점 홀로그램 스티커, 종이 공작.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 10대 후반 ~ 30대 |
| **Gaming experience** | Casual ~ Mid-core |
| **Time availability** | 출퇴근·휴식 중 5~15분, 저녁 30분 |
| **Platform preference** | 스마트폰 |
| **Current games they play** | Disney Emoji Blitz, 츠무츠무, 캔디크러시류 |
| **What they're looking for** | 귀여운 캐릭터 수집 + 짧고 짜릿한 퍼즐, 과금 압박은 적게 (천장·조각으로 원하는 크루를 결국 얻을 수 있음) |
| **What would turn them away** | 바닥 없는 가챠·확률 비공개, 에너지 대기, 잔인한 표현, 긴 튜토리얼 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 (사용자 선택; 2D 실시간 매치-3에 충분 — TD 확인). 버전은 `/setup-engine`에서 확정 |
| **Key Technical Challenges** | 캐스케이드 중 실시간 입력(칸 단위 상태, 논리 보드/뷰 분리, 헤드리스 단위 테스트), 데이터 기반 스킬 조합과 연쇄 깊이 상한, 모바일 파티클 성능, Android 익스포트 툴체인 |
| **Art Style** | 2D 스티커북 (구운 흰 테두리, 종이 질감) |
| **Art Pipeline Complexity** | Medium (커스텀 2D, 크루원별 일러스트 소량) |
| **Audio Needs** | Moderate (팝/스티커 SFX 중심, BGM 소수) |
| **Networking** | None (로컬 세이브만) |
| **Content Volume** | MVP: 크루 6명, 10스테이지. 풀 비전: 크루 24명+, 4월드 × 15 = 60스테이지 |
| **Procedural Systems** | 보드 초기 배치·리필만 랜덤(시드 가능). 스테이지는 수작업 데이터 |

---

## Risks and Open Questions

### Design Risks
- 60초 실시간에서 시너지를 판단할 여유가 부족할 수 있음 → 시너지 판단은 편성 단계, 플레이 중엔 타이밍만 (기둥 2).
- 24명 스킬이 서로 겹쳐 개성이 흐려질 위험 → 효과 프리미티브 조합 + "새 동작" 원칙.
- 레벨업이 커지면 조합 전략을 대체 → +20% 상한.
- 유료 가챠가 '크루가 곧 전략'과 충돌(돈 = 강함) → 희귀도는 수치가 아닌 동작 차별화, 클리어 가능성은 일반 등급 크루로도 보장되도록 스테이지 설계.
- 가챠 경제(재화 획득량 vs 천장) 밸런스 실패 시 수집이 지치거나 너무 쉬움 → economy-designer 검토, `/balance-check`.

### Technical Risks
- **(핵심)** 캐스케이드 도중 입력 경합 — 첫 2주 내 프로토타입으로 검증 (TD-FEASIBILITY: CONCERNS).
- 스킬 연쇄 무한 루프 → 이벤트 큐 + 연쇄 깊이 상한.
- 저가 Android 기기 파티클 성능 → Compatibility 렌더러 검토, 실기기 측정.
- iOS 빌드는 Mac + 연 $99 계정 필요 → Android 우선.
- 고정 Godot 버전이 LLM 지식 이후 버전 → `docs/engine-reference/godot/` 교차 확인.
- 놓치기 쉬운 항목: 앱 백그라운드 시 타이머 일시정지, 노치/세이프 영역, 세이브 버전 관리, Android 오디오 지연.

### Market Risks
- 캐릭터 매치-3는 포화 장르 → 차별점은 "스킬 연쇄 시너지"와 '적당한' 가챠(천장·조각·확률 공개)와 다정함.
- 유명 IP 없이 오리지널 캐릭터의 흡인력 → 스티커북 아트와 캐릭터성에 투자.

### Legal / Platform Risks
- 한국 게임산업법: 확률형 아이템 확률 표시 의무(2024.3 시행) — 유료 재화가 섞인 가챠는 등급·크루별 확률을 게임 내·홈페이지에 공시.
- Google Play / App Store 정책: 루트박스 확률 공개, 연령 등급(가챠 포함 시 등급 영향), 미성년자 결제 보호.
- IAP는 영수증 검증·환불 처리가 필요한데 서버가 없음 → T2에서 로컬 검증 범위와 위험을 ADR로 결정.

### Scope Risks
- **PR-SCOPE: UNREALISTIC (원안 기준)** — 2~3개월에 크루 24명+ 출시는 비현실적. 사용자 결정에 따라 **2~3개월 = MVP 완성 + 재미 검증**으로 재정의, 출시는 별도 마일스톤으로 재추정.
- 크루원 아트 24명 × 0.5~1일 = 12~24일 → T3로 이연.
- 첫 게임이라 속도 데이터 없음 → 매 스프린트 버퍼 20%.
- 문서 오버헤드 → rigor를 full → standard로 낮춤.

### Open Questions
- 60초 블리츠가 "한 판 더"를 부르는가? → T0 그레이박스(4주차)에서 플레이테스트.
- 효과 프리미티브 몇 개면 6명이 각자 개성 있는가? → MVP에 필요한 것만 만들고 7번째 크루원에서 리팩터링.
- 스와이프 매치 vs 탭-탭 스왑 중 터치 조작감 → 프로토타입에서 비교.
- 캐스케이드 중 입력을 어디까지 허용할 것인가? → `/prototype`에서 검증.

---

## MVP Definition

**Core hypothesis**: 플레이어는 60초 블리츠에서 크루 스킬 발동과 3인 팀 시너지에 재미를 느껴, 실패 후 바로 "한 판 더"를 누른다.

**Required for MVP**:
1. 실시간 매치-3 보드 (7×9, 6색, 스왑·매치·캐스케이드·리필, 캐스케이드 중 입력)
2. 60초 타이머 + 점수 + 스테이지 목표 + 별 1~3개
3. 크루 게이지 충전 & 탭 스킬 발동 (크루 6명 / 스킬 6종, 데이터 기반)
4. 시너지 쌍 2개 (A의 스킬 결과가 B의 게이지·효과에 영향)
5. 3인 팀 편성 + 원탭 재시작(직전 팀 유지)
6. 10스테이지 + 게임 내 재화 가챠(천장·중복 → 조각·확률 표시 포함, 유료 결제 없음) + 로컬 세이브
7. 스티커북 스타일 임시 아트 + 스킬 발동 연출(기둥 1)

**Explicitly NOT in MVP** (defer to later):
- 레벨업/중복 강화, 스티커 앨범 도감 화면 (T2 이후)
- 크루 7명 이상, 시너지 쌍 3개 이상
- 유료 재화·IAP 결제 연동 (T2)
- iOS 빌드, 스토어 출시 작업
- 월드맵 연출, BGM 다수, 리더보드

### Scope Tiers (if budget/time shrinks)

각 티어는 그 자체로 완결된 빌드다 (PR-SCOPE 권고).

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **T0 그레이박스 (재미 판정 게이트)** | 보드 1개, 스킬 3개, 회색 박스 아트 | 매치·캐스케이드·타이머·스킬 발동 | ~4주차 |
| **T1 MVP** | 크루 6명, 10스테이지, 시너지 2쌍 | 위 MVP 7항목 | ~8~12주차 (2~3개월 목표) |
| **T2 Android 소프트런치** | 크루 8~12명, 20스테이지 | + 레벨업(+20% 상한), 스티커 앨범, 유료 재화 IAP(Google Play Billing), 확률 공시 페이지, 출시 작업 | MVP 이후 별도 재추정 |
| **T3 풀 비전** | 크루 24명+, 4월드 × 15 = 60스테이지, 시너지 6쌍+ | 모든 기능, 폴리시, iOS | 출시 후 업데이트 |

---

## Director Gate Results

| Gate | Verdict | Notes |
| ---- | ---- | ---- |
| CD-PILLARS | CONCERNS → 반영 후 확정 | 기둥 1 스킬 중심으로 좁힘, 기둥 2 측정 테스트·레벨업 상한, 2↔3 충돌 해결 규칙, 훅 재정의 |
| AD-CONCEPT-VISUAL | CONCEPTS | 3방향 제안, 사용자가 스티커북 선택 |
| TD-FEASIBILITY | CONCERNS | 차단 요소 없음. 캐스케이드 입력이 핵심 위험, Android 우선 |
| PR-SCOPE | UNREALISTIC (원안) | 사용자 결정: MVP 목표로 재정의 + rigor standard |
| (사용자 변경) | — | 안티 기둥 '과금 가챠 없음' 철회 → 유료 재화 포함 가챠 허용, 천장·조각 교환·확률 공개 필수. 유료 IAP는 T2로 배치 |

---

## Next Steps

- [ ] `/setup-engine godot` — 엔진 버전 확정, 설치 버전 기록
- [ ] `/prototype 실시간 매치-3 캐스케이드 + 스킬 발동` — 핵심 메커닉 검증 (T0)
- [ ] PROCEED 시 `/art-bible` — 스티커북 비주얼 정체성
- [ ] `/map-systems` → `/design-system` (시스템별 GDD)
- [ ] `/create-architecture` → `/architecture-decision` (데이터 기반 스킬 프리미티브 ADR)
- [ ] `/vertical-slice` → `/gate-check`
