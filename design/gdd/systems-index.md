# Systems Index: 말랑 크루 (Mallang Crew)

> **Status**: Draft
> **Created**: 2026-11-07
> **Last Updated**: 2026-11-07 (board-rules Designed)
> **Source Concept**: design/gdd/game-concept.md (Status: In Review, revised 2026-11-07)
> **Created by**: `/map-systems` (automation guided, review_mode lean, docs.density balanced). 사용자 위임("진행부탁 알아서 다")으로 모든 질문은 권장안으로 결정했다. 결정 내역은 아래 [Decision Log](#decision-log).

---

## Overview

말랑 크루는 **턴 기반 블록 배치 퍼즐 위에 캐릭터 능력 연쇄를 얹은 게임**이라, 시스템의 무게중심은
"한 번의 배치 → 결정적으로 해석되는 연쇄 → 그 결과를 그대로 보여 주는 미리보기와 연출"에 있다
(기둥 1 도미노의 손맛, 기둥 3 보이는 연쇄). 그 위에 크루(조각 모양 + 능력)를 고르는 팀 편성(기둥 2
크루가 곧 전략), 짧은 스테이지와 원탭 재시작(기둥 4 한 판 더), 천장·샤드·확률 공개가 있는 가챠
(안티 기둥: 바닥 없는 가챠 아님)가 바깥 고리를 이룬다. 실시간 요소·네트워크·스토리 시스템은 없다.
총 31개 시스템, 그중 MVP 22개(T1). 기술 기반은 phase gate(TD-PHASE-GATE READY)의 조건을 그대로 따른다:
**연쇄 해석기는 순수 함수(보드 + 배치 → 이벤트 목록)**, 연출·미리보기는 이벤트를 재생/표시만 하며,
랜덤은 주입된 시드 RNG만 쓰고, 깊이 상한 6은 데이터다. 크루는 능력 프리미티브를 조합한 Custom Resource다.

**시스템별 요약 (MVP)**

- **보드 & 조각 규칙** — 8×8 칸 상태, 조각 모양 데이터(회전 없음), 배치 가능 판정, 가로·세로 줄 완성 판정, "놓을 곳 없음" 판정. 연쇄 해석기와 미리보기가 같은 규칙을 호출해야 하므로 순수 데이터 + 순수 함수로 정의한다.
- **연쇄 해석기 & 능력 프리미티브** — 이 게임의 심장. 배치 하나를 받아 줄 지우기 → 얼굴 발동 → 다른 얼굴 지우기 → … 를 깊이 상한까지 결정적으로 풀고 이벤트 목록을 낸다. 같은 단계 동시 발동 순서 규칙, 상한 도달 시 동작, 알(egg)이 줄을 채워 재점화하는 규칙이 여기서 정해진다. 능력 프리미티브(십자, 3×3, 줄 채우기 등)의 실행 계약도 이 시스템이 소유한다 — 그래야 크루 정의가 해석기에 의존하되 해석기는 특정 크루를 몰라도 된다.
- **시드 RNG** (inferred) — 트레이 뽑기·가챠·(있다면) 능력 랜덤을 하나의 주입 가능한 시드 RNG로 통일. 미리보기 = 결과를 보장하고 테스트를 결정적으로 만든다. GDD 대신 ADR 한 건으로 충분하다.
- **점수 & 연쇄 배율** — 줄 지우기·얼굴 발동 점수와 단계당 +50% 배율(시작값). 스테이지 목표와 별 기준의 입력이라 공식 섹션이 필수인 시스템.
- **크루 정의 & 능력** — 크루 6명 = 조각 모양 세트 + 얼굴 1칸 + 프리미티브 조합 능력. "새 크루 = 새 동작" 원칙(기둥 2)과 "모든 능력은 미리보기로 예측 가능"(기둥 3)이 이 문서의 수용 기준이다.
- **트레이 공급** — 3칸 트레이, 3개를 다 놓으면 재충전, 팀 조각 풀에서 시드 RNG로 뽑기, 스테이지 고정 시드/가방 방식 등 공급 규칙. "운으로 느껴짐" 위험을 직접 다루는 곳.
- **드래그 & 배치 입력** (inferred) — 터치 드래그, 손가락 오프셋, 스냅 앵커 칸 계산, 놓기 취소. 앵커 칸이 바뀔 때만 미리보기를 재계산(TD 조건)하는 트리거가 여기서 나온다.
- **연쇄 미리보기** — 드래그 중 해석기를 그대로 호출해 지워질 칸·발동 순서 번호·예상 알을 표시. 해석기와 별도 로직을 두는 것은 금지(미리보기 ≠ 결과면 버그). "가장 큰 숫자 찾기" 퇴화 위험의 1차 방어선.
- **칸 종류 & 방해물** — 지워지지 않는 칸, 얼어붙은 얼굴 등. MVP는 1~2종만. 칸 종류 열거형은 보드 규칙이 소유하고, 각 방해물의 해석기 훅은 이 문서가 정의한다(순환 방지).
- **스테이지 & 목표** — 제한 조각 수, 목표 4형(점수 / 특정 칸 / 방해물 / 연쇄 N), 별 1~3 기준, 시작 보드·고정 시드·얼굴 없는 조각 지정 등 스테이지 데이터 포맷. 10스테이지 콘텐츠는 이 포맷 위에 level-designer가 쓴다.
- **판 진행 흐름** — 판 상태 머신(준비 → 배치 → 해석 → 연출 대기 → 승/패 판정 → 결과)과 원탭 재시작(직전 팀 유지, 기둥 4).
- **화면 흐름 & 내비게이션** (inferred) — 타이틀/스테이지 선택/팀 편성/플레이/결과/가챠 사이 전환, Android 뒤로 가기.
- **보유 크루** (inferred) — 어떤 크루를 가졌는지, 샤드 보유량. 팀 편성과 가챠가 모두 읽고 쓰는 소유 데이터.
- **팀 편성** — 보유 크루 중 3인 선택 = 트레이 조각 풀. 직전 팀 기억.
- **스테이지 진행 & 해금** (inferred) — 10스테이지 선형 해금, 별 기록, 최장 연쇄 기록.
- **재화 & 보상** — 코인·스티커 티켓의 획득(스테이지 결과)과 소비(가챠). 획득량은 economy GDD + `/balance-check`로 확정.
- **가챠** — 게임 내 재화 전용(MVP), 등급별 확률, 천장, 중복 → 샤드 → 원하는 크루 교환. 빌드 순서상 마지막 MVP 게임플레이 시스템(PR-PHASE-GATE 결정).
- **로컬 세이브** — 보유 크루·재화·진행·천장 카운트·설정을 버전 필드와 함께 저장. 구조상 Foundation이지만 스키마가 다른 시스템에 달려 있어 설계는 경제 시스템 다음.
- **연쇄 연출 재생기** — 해석기 이벤트 목록을 받아 스티커 들썩임 → 효과 → 다시 붙음, 단계 컷인, 파티클을 순서대로 재생. 기둥 1의 실제 담당자. 게임 상태를 바꾸지 않는다.
- **플레이 HUD** — 목표, 남은 조각 수, 점수, 연쇄 단계 표시.
- **메타 화면 UI** — 스테이지 선택, 팀 편성, 결과(별·최장 연쇄·재시작 버튼) 화면.
- **가챠 UI & 확률 표시** — 스티커 팩 개봉 연출, 확률 표, 천장까지 남은 횟수.
- **오디오 (SFX 중심)** — 붙이기·떼어짐·연쇄 단계 SFX, BGM 1~2곡. Android 오디오 지연 대응.
- **플랫폼 & 화면** (inferred) — 세로 고정, 노치/세이프 영역, 64px 터치 타깃, Android 익스포트, 저가 기기 성능 예산.

**MVP 이후**: 튜토리얼 힌트·설정/접근성(Vertical Slice), 레벨업(+20% 상한)·스티커 앨범·유료 재화 IAP(Alpha = T2 소프트런치), 무한 모드·월드맵 연출·기록 리더보드(Full Vision = T3).

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 보드 & 조각 규칙 (Board & Piece Rules) | Gameplay | MVP | Designed | [design/gdd/board-rules.md](board-rules.md) | — |
| 2 | 연쇄 해석기 & 능력 프리미티브 (Chain Resolver) | Gameplay | MVP | Not Started | design/gdd/chain-resolver.md | 보드 & 조각 규칙, 시드 RNG |
| 3 | 시드 RNG (Seeded RNG) (inferred) | Core | MVP | Not Started | — (ADR only) | — |
| 4 | 점수 & 연쇄 배율 (Scoring) | Gameplay | MVP | Not Started | design/gdd/scoring.md | 연쇄 해석기 |
| 5 | 크루 정의 & 능력 (Crew Definition) | Gameplay | MVP | Not Started | design/gdd/crew-definition.md | 연쇄 해석기, 보드 & 조각 규칙 |
| 6 | 트레이 공급 (Tray Supply) | Gameplay | MVP | Not Started | design/gdd/tray-supply.md | 보드 & 조각 규칙, 크루 정의, 시드 RNG |
| 7 | 드래그 & 배치 입력 (Drag & Placement Input) (inferred) | Core | MVP | Not Started | design/gdd/placement-input.md | 보드 & 조각 규칙 |
| 8 | 연쇄 미리보기 (Chain Preview) | Gameplay | MVP | Not Started | design/gdd/chain-preview.md | 연쇄 해석기, 드래그 & 배치 입력 |
| 9 | 칸 종류 & 방해물 (Cell Types & Obstacles) | Gameplay | MVP | Not Started | design/gdd/obstacles.md | 보드 & 조각 규칙, 연쇄 해석기 |
| 10 | 스테이지 & 목표 (Stage & Goals) | Gameplay | MVP | Not Started | design/gdd/stage-goals.md | 보드 & 조각 규칙, 점수, 트레이 공급, 칸 종류 & 방해물 |
| 11 | 판 진행 흐름 (Round Flow) | Core | MVP | Not Started | design/gdd/round-flow.md | 스테이지 & 목표, 트레이 공급, 연쇄 해석기, 팀 편성 |
| 12 | 화면 흐름 & 내비게이션 (Scene Flow) (inferred) | Core | MVP | Not Started | design/gdd/scene-flow.md | 판 진행 흐름 |
| 13 | 보유 크루 (Crew Ownership) (inferred) | Progression | MVP | Not Started | design/gdd/crew-ownership.md | 크루 정의 |
| 14 | 팀 편성 (Team Composition) | Gameplay | MVP | Not Started | design/gdd/team-composition.md | 크루 정의, 보유 크루 |
| 15 | 스테이지 진행 & 해금 (Stage Progression) (inferred) | Progression | MVP | Not Started | design/gdd/stage-progression.md | 스테이지 & 목표 |
| 16 | 재화 & 보상 (Currency & Rewards) | Economy | MVP | Not Started | design/gdd/currency-rewards.md | 스테이지 & 목표, 스테이지 진행 |
| 17 | 가챠 (Gacha: 천장·샤드·확률) | Economy | MVP | Not Started | design/gdd/gacha.md | 재화 & 보상, 크루 정의, 보유 크루, 시드 RNG |
| 18 | 로컬 세이브 (Local Save) | Persistence | MVP | Not Started | design/gdd/save-system.md | — (스키마는 보유 크루·재화·진행·가챠 상태를 담음) |
| 19 | 연쇄 연출 재생기 (Chain Presentation) | Gameplay | MVP | Not Started | design/gdd/chain-presentation.md | 연쇄 해석기 (이벤트 목록) |
| 20 | 플레이 HUD (Gameplay HUD) | UI | MVP | Not Started | design/gdd/gameplay-hud.md | 스테이지 & 목표, 점수, 판 진행 흐름 |
| 21 | 메타 화면 UI (스테이지 선택·팀 편성·결과) | UI | MVP | Not Started | design/gdd/meta-screens-ui.md | 스테이지 진행, 팀 편성, 판 진행 흐름, 화면 흐름 |
| 22 | 가챠 UI & 확률 표시 (Gacha UI) | UI | MVP | Not Started | design/gdd/gacha-ui.md | 가챠 |
| 23 | 오디오 SFX (Audio) | Audio | MVP | Not Started | design/gdd/audio.md | 연쇄 연출 재생기, 판 진행 흐름 |
| 24 | 플랫폼 & 화면 (Platform & Display) (inferred) | Core | MVP | Not Started | design/gdd/platform-display.md | — (모든 UI가 이를 따름) |
| 25 | 튜토리얼 & 힌트 (Tutorial & Hints) | Meta | Vertical Slice | Not Started | design/gdd/tutorial.md | 스테이지 & 목표, 연쇄 미리보기, 플레이 HUD |
| 26 | 설정 & 접근성 (Settings & Accessibility) | Meta | Vertical Slice | Not Started | design/gdd/settings-accessibility.md | 로컬 세이브, 오디오 |
| 27 | 크루 레벨업 (+20% 상한) (Crew Level-up) | Progression | Alpha | Not Started | design/gdd/crew-levelup.md | 보유 크루, 크루 정의, 재화 & 보상 |
| 28 | 스티커 앨범 도감 (Sticker Album) | UI | Alpha | Not Started | design/gdd/sticker-album.md | 보유 크루, 크루 정의 |
| 29 | 유료 재화 & IAP (Paid Currency & IAP) | Economy | Alpha | Not Started | design/gdd/iap.md | 재화 & 보상, 가챠, 로컬 세이브 |
| 30 | 무한 모드 (Endless Mode) | Gameplay | Full Vision | Not Started | — | 보드 & 조각 규칙, 트레이 공급, 점수 |
| 31 | 월드맵 & 기록 (World Map & Records/Leaderboard) | Progression | Full Vision | Not Started | — | 스테이지 진행, 점수 |

*Alpha = 컨셉의 T2 Android 소프트런치, Full Vision = T3. T0 그레이박스는 MVP 시스템 1~8 + 19의 회색 박스 구현.*

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Core** | Foundation systems everything depends on | 시드 RNG, 입력, 판 진행 흐름, 화면 흐름, 플랫폼 & 화면 |
| **Gameplay** | The systems that make the game fun | 보드 규칙, 연쇄 해석기, 크루 능력, 트레이, 미리보기, 방해물, 스테이지, 연쇄 연출 |
| **Progression** | How the player grows over time | 보유 크루, 스테이지 진행, 레벨업, 월드맵 & 기록 |
| **Economy** | Resource creation and consumption | 재화 & 보상, 가챠, IAP |
| **Persistence** | Save state and continuity | 로컬 세이브 |
| **UI** | Player-facing information displays | 플레이 HUD, 메타 화면, 가챠 UI, 스티커 앨범 |
| **Audio** | Sound and music systems | SFX 중심 오디오 |
| **Meta** | Systems outside the core game loop | 튜토리얼, 설정 & 접근성 |

*Narrative 카테고리 없음 — 안티 기둥 "긴 스토리 컷신 아님".*

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | T1 MVP (T0 그레이박스는 그 부분집합) | Design FIRST |
| **Vertical Slice** | Required for one complete, polished area. Demonstrates the full experience. | 외부 플레이테스트 / 데모 | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | T2 Android 소프트런치 | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | T3 풀 비전 | Design as needed |

> **Director gates (lean mode)**: TD-SYSTEM-BOUNDARY, PR-SCOPE, CD-SYSTEMS — skipped (review_mode lean; not PHASE-GATEs). 이전 phase gate의 PR-PHASE-GATE CONCERNS(가챠는 MVP 가설을 검증하지 않음·일정 위험, 속도 데이터 없음, 아트 범위 미산정)는 이 우선순위에 반영했다: 가챠는 MVP에 남기되 설계·빌드 순서 마지막, T0를 속도 측정 마일스톤으로 사용.

**우선순위 근거 (요약)**

- **MVP 22개**: 컨셉의 "Required for MVP" 6항목과 그 Foundation 의존성. 시스템 1~8은 30초 루프 그 자체다 — 이것 없이는 "미리보기를 보며 얼굴을 노려 놓는다"는 핵심 가설을 테스트할 수 없다 (기둥 3 보이는 연쇄). 연쇄 연출 재생기(19)는 UI처럼 보이지만 MVP 핵심이다 — 연쇄가 일반 줄 지우기보다 압도적으로 시원하지 않으면 가설 기준 4("다른 블록 퍼즐과 다르다")가 무너진다 (기둥 1 도미노의 손맛). 팀 편성(14)은 같은 스테이지에서 팀이 다르면 경로가 달라지는지 확인하는 장치다 (기둥 2 크루가 곧 전략). 판 진행 흐름(11)의 원탭 재시작은 가설 기준 3("한 판 더" 비율)의 직접 측정 대상이다 (기둥 4). 가챠(17)는 가설 검증에는 필요 없지만 사용자가 명시적으로 MVP에 요구했다.
- **Vertical Slice**: 튜토리얼 힌트는 MVP 가설 기준 1이 "설명 없이 3판 안에"이므로 첫 플레이테스트에서는 의도적으로 스테이지 데이터(1-1 얼굴 없는 조각 등)만으로 온보딩하고, 힌트 레이어는 그 결과를 본 뒤 설계한다. 설정·접근성(색약 대응은 아트 규칙에서 이미 처리)은 외부 배포 전 다듬기.
- **Alpha (T2)**: 레벨업·앨범·IAP는 컨셉의 "Explicitly NOT in MVP" 목록 그대로.
- **Full Vision (T3)**: 무한 모드(컨셉 Open Question — MVP에 넣지 않는 쪽으로 결정), 월드맵 연출·리더보드.

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **보드 & 조각 규칙** — 모든 게임플레이 시스템이 읽는 칸 상태·조각 모양·줄 판정. 해석기와 미리보기가 공유하는 결정적 규칙의 최하단.
2. **연쇄 해석기 & 능력 프리미티브** — 보드 규칙과 RNG 계약에만 의존. phase gate가 지정한 Foundation 시스템이자 **첫 critical ADR 후보**(순수 함수, 이벤트 목록 출력, 시드 RNG 주입, 깊이 상한 6 데이터화). 프리미티브 실행 계약을 소유해 크루 정의와의 순환을 끊는다.
3. **시드 RNG** — 의존성 없음. 해석기·트레이·가챠가 주입받는다.
4. **로컬 세이브** — 프레임워크 자체는 의존성 없음(버전 필드, 직렬화 계약). 각 시스템이 저장 항목을 등록하는 구조라 스키마 확정은 경제 시스템 이후.
5. **플랫폼 & 화면** — 세이프 영역·해상도·터치 타깃 규칙. 모든 UI의 전제.

### Core Layer (depends on foundation)

1. **점수 & 연쇄 배율** — depends on: 연쇄 해석기 (이벤트의 단계 정보)
2. **크루 정의 & 능력** — depends on: 연쇄 해석기 (프리미티브 계약), 보드 & 조각 규칙 (조각 모양)
3. **드래그 & 배치 입력** — depends on: 보드 & 조각 규칙 (스냅·배치 가능 판정)
4. **보유 크루** — depends on: 크루 정의
5. **트레이 공급** — depends on: 보드 & 조각 규칙, 크루 정의 (조각 풀의 원소), 시드 RNG. 조각 풀은 입력 목록으로 받으므로 팀 편성에는 의존하지 않는다.

### Feature Layer (depends on core)

1. **연쇄 미리보기** — depends on: 연쇄 해석기, 드래그 & 배치 입력
2. **칸 종류 & 방해물** — depends on: 보드 & 조각 규칙, 연쇄 해석기
3. **팀 편성** — depends on: 크루 정의, 보유 크루
4. **스테이지 & 목표** — depends on: 보드 & 조각 규칙, 점수, 트레이 공급, 칸 종류 & 방해물
5. **판 진행 흐름** — depends on: 스테이지 & 목표, 트레이 공급, 연쇄 해석기, 팀 편성
6. **스테이지 진행 & 해금** — depends on: 스테이지 & 목표
7. **재화 & 보상** — depends on: 스테이지 & 목표, 스테이지 진행
8. **가챠** — depends on: 재화 & 보상, 크루 정의, 보유 크루, 시드 RNG
9. *(T2)* 크루 레벨업, 유료 재화 & IAP · *(T3)* 무한 모드

### Presentation Layer (depends on features)

1. **연쇄 연출 재생기** — depends on: 연쇄 해석기 (이벤트 목록만; 상태 변경 금지)
2. **플레이 HUD** — depends on: 스테이지 & 목표, 점수, 판 진행 흐름
3. **화면 흐름 & 내비게이션** — depends on: 판 진행 흐름
4. **메타 화면 UI** — depends on: 스테이지 진행, 팀 편성, 판 진행 흐름, 화면 흐름
5. **가챠 UI & 확률 표시** — depends on: 가챠
6. **오디오 SFX** — depends on: 연쇄 연출 재생기, 판 진행 흐름
7. *(T2)* 스티커 앨범 · *(T3)* 월드맵 & 기록

### Polish Layer (depends on everything)

1. **튜토리얼 & 힌트** (VS) — depends on: 스테이지 & 목표, 연쇄 미리보기, 플레이 HUD
2. **설정 & 접근성** (VS) — depends on: 로컬 세이브, 오디오

**병목(bottleneck) 시스템**: 연쇄 해석기(직·간접 의존 시스템 15개 이상 — 미리보기·연출·점수·크루·방해물·스테이지·판 흐름), 보드 & 조각 규칙(사실상 전부), 크루 정의(트레이·팀·보유·가챠·레벨업·앨범). 이 셋의 인터페이스가 흔들리면 하위 GDD 전부가 재작업된다.

**리프(leaf) 시스템** (의존하는 시스템 없음 — 늦게 설계해도 안전): 가챠 UI, 플레이 HUD, 오디오, 튜토리얼, 설정, 앨범, 무한 모드, 월드맵 & 기록.

---

## Recommended Design Order

phase gate 권고 순서(보드/해석기 → 크루 능력 → 스테이지 → 가챠/경제)를 의존성 정렬과 합쳤다. 같은 레이어의 독립 시스템은 병렬 설계 가능.

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 보드 & 조각 규칙 | MVP | Foundation | game-designer, systems-designer | S |
| 2 | 연쇄 해석기 & 능력 프리미티브 (+ 시드 RNG 절, critical ADR 동시 착수) | MVP | Foundation | systems-designer, game-designer, technical-director (ADR) | L |
| 3 | 점수 & 연쇄 배율 | MVP | Core | systems-designer | S |
| 4 | 크루 정의 & 능력 (6명) | MVP | Core | game-designer, systems-designer | M |
| 5 | 트레이 공급 | MVP | Core | systems-designer, game-designer | M |
| 6 | 드래그 & 배치 입력 | MVP | Core | ux-designer, gameplay-programmer | S |
| 7 | 연쇄 미리보기 | MVP | Feature | ux-designer, game-designer | M |
| 8 | 칸 종류 & 방해물 (MVP 1~2종) | MVP | Feature | game-designer, level-designer | S |
| 9 | 스테이지 & 목표 (+ 10스테이지 데이터 포맷) | MVP | Feature | level-designer, game-designer | L |
| 10 | 보유 크루 | MVP | Core | systems-designer | S |
| 11 | 팀 편성 | MVP | Feature | game-designer | S |
| 12 | 판 진행 흐름 (원탭 재시작) | MVP | Feature | game-designer, gameplay-programmer | M |
| 13 | 스테이지 진행 & 해금 | MVP | Feature | game-designer | S |
| 14 | 재화 & 보상 | MVP | Feature | economy-designer | M |
| 15 | 가챠 (천장·샤드·확률) | MVP | Feature | economy-designer, game-designer | L |
| 16 | 로컬 세이브 | MVP | Foundation | systems-designer, lead-programmer | M |
| 17 | 연쇄 연출 재생기 | MVP | Presentation | game-designer, technical-artist, art-director | M |
| 18 | 플레이 HUD | MVP | Presentation | ux-designer | S |
| 19 | 화면 흐름 & 내비게이션 | MVP | Presentation | ux-designer | S |
| 20 | 메타 화면 UI | MVP | Presentation | ux-designer | M |
| 21 | 가챠 UI & 확률 표시 | MVP | Presentation | ux-designer, economy-designer | S |
| 22 | 오디오 SFX | MVP | Presentation | audio-director, sound-designer | S |
| 23 | 플랫폼 & 화면 | MVP | Foundation | ux-designer, godot-specialist | S |
| 24 | 튜토리얼 & 힌트 | Vertical Slice | Polish | game-designer, ux-designer | S |
| 25 | 설정 & 접근성 | Vertical Slice | Polish | ux-designer, accessibility-specialist | S |
| 26 | 크루 레벨업 (+20% 상한) | Alpha | Feature | economy-designer, game-designer | S |
| 27 | 스티커 앨범 도감 | Alpha | Presentation | ux-designer, art-director | S |
| 28 | 유료 재화 & IAP (+ 확률 공시 페이지) | Alpha | Feature | economy-designer, security-engineer | M |
| 29 | 무한 모드 | Full Vision | Feature | game-designer | S |
| 30 | 월드맵 & 기록 | Full Vision | Presentation | game-designer, ux-designer | M |

*시드 RNG(#3)는 별도 GDD 없이 연쇄 해석기 GDD의 한 절 + ADR로 처리한다. 연쇄 연출 재생기(17)는 Presentation이지만 기둥 1 담당이라 해석기 GDD의 이벤트 스키마가 확정되면 앞당겨 병렬 설계해도 좋다. T0 그레이박스 착수 최소 집합: 순서 1~7 + 17.*

---

## Circular Dependencies

순환은 발견되지 않았다. 순환 후보 3건은 계약으로 미리 끊었다:

- **연쇄 해석기 ↔ 크루 정의**: 해석기가 크루 능력을 실행해야 하고 크루는 해석기의 규칙을 따른다. → 해석기가 **능력 프리미티브 실행 계약**을 소유하고, 크루는 프리미티브를 조합한 Custom Resource일 뿐이다. 해석기는 특정 크루를 모른다.
- **연쇄 해석기 ↔ 칸 종류 & 방해물**: 방해물(얼어붙은 얼굴 등)은 해석기 동작을 바꾼다. → **칸 종류 열거형과 훅 지점은 보드 규칙/해석기가 정의**, 방해물 GDD는 훅의 구체 동작만 채운다.
- **트레이 공급 ↔ 팀 편성**: 팀이 조각 풀을 정하고 트레이가 그 풀을 쓴다. → 트레이는 **조각 풀을 입력 목록으로 받는다**. 팀 편성 → 판 진행 흐름이 풀을 만들어 넘긴다.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 연쇄 해석기 & 능력 프리미티브 | Technical / Design | 미리보기와 실제 결과 불일치, 동시 발동 순서 모호, 무한 루프, 알 재점화가 깊이 상한과 충돌. 최대 병목 | 첫 critical ADR(순수 함수 + 이벤트 목록 + 시드 RNG 주입), 같은 판 예측 = 결과 단위 테스트, 깊이 상한 6 데이터화 + 상한 도달 동작 명시 |
| 연쇄 미리보기 | Design | 너무 친절하면 "최고 숫자 뜨는 자리 찾기"로 퇴화 (concept review log NOT FIXED 항목) | 스테이지 목표·조각 제한으로 트레이드오프, 표시 정보량을 튜닝 노브로, 외부 플레이테스트 |
| 크루 정의 & 능력 | Design / Scope | 24명으로 갈 때 능력이 겹쳐 개성 소실, 예측 불가 능력 유입 | 프리미티브 조합 + "새 동작" 원칙, 모든 능력에 미리보기 예측 가능성 수용 기준 |
| 트레이 공급 | Design | 랜덤 트레이가 운으로 느껴짐 | 팀 = 조각 풀로 편차 축소, 스테이지 고정 시드/가방 방식 비교 (Open Question) |
| 가챠 + 재화 & 보상 | Scope / Legal | MVP 가설과 무관한데 일정 위험; 천장·획득량 밸런스 실패; 한국 확률 표시 의무 | 설계·빌드 순서 마지막, economy-designer + `/balance-check`, 확률 표시를 MVP UI에 포함 |
| 연쇄 연출 재생기 | Design / Technical | 연출이 시원하지 않으면 기둥 1 실패; 저가 Android 파티클 성능 | 연출 예산 우선 배정, Compatibility 렌더러, 실기기 측정 |
| 로컬 세이브 | Technical | 세이브 버전 관리 누락 시 업데이트에서 데이터 손실 (T2 IAP와 결합하면 결제 자산 손실) | 버전 필드 + 마이그레이션 규칙을 첫 GDD에 포함 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 31 |
| Design docs started | 1 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 1/22 (시드 RNG 포함; GDD 대상은 21) |
| Vertical Slice systems designed | 0/2 |

---

## Decision Log

`/map-systems`의 질문 지점마다 사용자 위임에 따라 권장안을 택했다 (automation guided, 질문 없이 진행).

| Phase | Decision | Alternatives considered |
|-------|----------|-------------------------|
| 2 열거 | inferred 시스템 7개 추가(시드 RNG, 입력, 화면 흐름, 보유 크루, 스테이지 진행, 플랫폼 & 화면, 세이브는 컨셉 명시) | 입력·화면 흐름을 판 진행 흐름에 합치기 — 입력은 미리보기 트리거라 분리 |
| 2 열거 | 시드 RNG는 GDD 없이 ADR + 해석기 GDD 한 절 | 독립 GDD — 규칙이 짧아 과함 |
| 2 열거 | 방해물을 스테이지에서 분리(해석기 훅이 있어서) | 스테이지 GDD에 포함 |
| 2 열거 | 조각 모양 데이터를 보드 규칙에 포함 | 별도 시스템 — 6명 규모에선 과함 |
| 3 의존성 | 해석기가 능력 프리미티브 계약 소유 (순환 차단) | 크루 정의가 실행 로직 소유 — 해석기 순수성 깨짐 |
| 4 우선순위 | 가챠 MVP 유지, 설계/빌드 순서 마지막 (phase gate 결정 승계) | 가챠를 VS로 미루기 — 사용자 명시 요구에 반함 |
| 4 우선순위 | 튜토리얼 힌트는 VS (가설 기준 "설명 없이") | MVP 포함 — 첫 플레이테스트 측정을 오염 |
| 4 우선순위 | 무한 모드 Full Vision (컨셉 Open Question 해소 제안) | MVP 포함 — 스테이지 목표 검증과 초점 분산 |
| 4 우선순위 | 연쇄 연출 재생기 MVP (기둥 1) | VS — 가설 기준 4를 테스트 불가 |
| 5 쓰기 | 새 인덱스 쓰기 승인 질문을 위임으로 대체 | — |

---

## Next Steps

- [ ] Review and approve this systems enumeration (위임 결정 검토 — 특히 Decision Log)
- [x] `/design-system board-rules` (2026-11-07, Designed — `/design-review` 대기; UX Flag: 게임플레이 화면 `/ux-design` 필요; 판 진행 흐름 Depends On에 보드 & 조각 규칙 추가 제안 — board-rules Q6)
- [ ] `/design-system chain-resolver` (MVP Foundation 다음)
- [ ] `/architecture-decision` — 결정적 연쇄 해석기 (첫 critical ADR, 해석기 GDD와 병행)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check technical-setup` when MVP systems are designed
- [ ] (선택) review_mode full에서 TD-SYSTEM-BOUNDARY / PR-SCOPE / CD-SYSTEMS 재실행
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
