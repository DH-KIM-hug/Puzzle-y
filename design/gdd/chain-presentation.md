# 연쇄 연출 재생기 (Chain Presentation)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Implements Pillar**: 기둥 1 도미노의 손맛 · 기둥 3 보이는 연쇄 · 기둥 4 한 판 더 · 기둥 5 다정한 세계

## Summary

[To be designed]

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: [To be designed]

## Overview

연쇄 연출 재생기는 배치 하나의 **이미 끝난 결과**를 눈과 귀로 다시 들려주는 재생기다. 데이터 층에서는 연쇄 해석기의
`ChainResult.events`(순서 있는 이벤트 목록)와 점수 시스템의 `ScoreBreakdown`(웨이브별 점수)을 받아, 이벤트 하나하나를
**시간이 정해진 연출 큐(cue)의 타임라인**으로 바꾸고 그 타임라인을 재생한다. 타임라인은 이벤트·설정값만으로 결정되는 순수한
변환이라 같은 입력이면 같은 타임라인이 나오며, 재생기는 보드·점수·트레이·스테이지 상태를 **한 칸도 바꾸지 않고 아무것도 판정하지 않는다** —
결과는 해석기가 이미 확정했고(chain-resolver 규칙 3), 점수도 이미 커밋됐다(scoring 규칙 12). 플레이어 쪽에서 보면 이 시스템은
"놓는 순간 스티커들이 들썩이며 차례로 터지는" 장면 그 자체이며, 기둥 1 "연쇄가 터지는 순간은 일반 줄 지우기보다 압도적으로
시원해야 한다"의 실제 담당자다: 웨이브마다 하나의 박자로 도미노 순서를 보여 주고(기둥 3), 깊어질수록 컷인·흔들림·종이 컨페티가
커지되 템포는 오히려 빨라져 연쇄 6단도 4초 안에 끝나며(기둥 4), 탭 한 번이면 빨리 감기·건너뛰기가 된다. 피즐한 얼굴은 꾸벅
졸고, 상한 도달은 축하로 끝난다(기둥 5).

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing; Layer `Presentation`) · ADR ref `[B] No`
(`docs/architecture/adr-*.md` 없음) · Fantasy `[A] Yes`이지만 standard tier라 Player Fantasy 섹션은 생략하고 이 Overview와 Game Feel이
감정 목표를 싣는다. 구현 형태(타임라인을 Tween 체인으로 둘지 자체 큐 스케줄러로 둘지, 파티클을 `CPUParticles2D` vs `GPUParticles2D`로
둘지, 연출 노드 풀링)는 → ADR 대상.

## Detailed Design

> *Specialist note*: `game-designer` · `art-director` · `technical-artist` · `systems-designer` (Section 6 라우팅: Gameplay →
> Visual effects 행) not consulted — Lean mode (Section C는 lean에서 생략). Review manually before production.

### Core Rules

**A. 재생기 계약 (재생만, 판정 금지)**

1. **입력** — 판 진행 흐름이 배치 1회마다 `play(request)`를 한 번 부른다. `request` = {
   `pre_board`(배치 직전 안정 보드의 읽기 전용 사본), `result`(`ChainResult` — `events`·`final_board`·`summary`),
   `score`(`ScoreBreakdown`), `crew_visuals`(crew_id → 색 슬롯·실루엣·무늬·`fill_visual`·`ability_name_key`, 크루 정의 GDD),
   `settings`(재생 속도 선호·움직임 줄이기·번쩍임 끄기, 아래 규칙 21–24) }.
2. **출력** — 화면 연출(노드·파티클·컷인·흔들림)과 신호 셋뿐이다: `cue_fired(cue)`(오디오·HUD·튜토리얼 구독용),
   `wave_presented(wave, clear_points + activation_points)`(HUD 숫자 박자), `playback_finished(was_skipped)`(판 진행 흐름이 입력을 다시 켬).
   게임 상태를 바꾸는 호출은 하나도 없다.
3. **판정 금지** — 재생기는 줄 판정·능력 범위 계산·점수 계산·발동 순서 결정을 하지 않는다. 화면에 그릴 모든 칸·순서·숫자는
   이벤트 필드(`CELLS_CLEARED.cells[]`, `source_order`, `order_index`, `ABILITY_EFFECT.cells`)와 `ScoreBreakdown.waves[]`에서만 읽는다.
   이벤트에 없는 정보가 연출에 필요하면 재생기가 계산하지 않고 해석기·점수 GDD에 필드 추가를 요청한다 (Open Questions).
4. **표시 보드 (display board)** — 재생기는 `pre_board`에서 시작해 이벤트를 **그림으로만** 적용하는 표시용 사본을 들고 있다
   (`PLACED` → 칸 추가, `CELLS_CLEARED` → 칸 제거, `ABILITY_EFFECT(FILL)` → 알 추가, `CELL_MODIFIED` → 겹 표시 변경). 표시 보드는 규칙
   판정에 쓰이지 않으며, 재생이 끝나면 `final_board`와 칸 단위로 같아야 한다. 다르면 디버그 빌드 assert, 출시 빌드는 오류 로그 후
   `final_board`로 즉시 다시 그린다 (진실은 언제나 `final_board`).
5. **타임라인 선계산** — `play`는 먼저 `build_timeline(events, score, settings) → Timeline`(큐 목록, 각 큐 = {`t_start`, `duration`,
   `kind`, 대상 칸/얼굴, 강도 `level`})을 **한 번에** 만든 뒤 재생한다. `build_timeline`은 순수 함수다 — 시간·프레임·전역 상태를 읽지
   않으며 같은 입력 → 같은 타임라인. 그래서 재생 시간 상한(F4)·펄스 간격(F6) 같은 수용 기준을 렌더링 없이 단위 테스트할 수 있다.
   재생 중 프레임 저하가 생겨도 큐는 타임라인 시각을 따라 진행한다 (느린 기기에서 연출이 길어지지 않음 — 시각 기준 재생).

**B. 박자 구조 — 웨이브 = 박자 하나**

6. **박자** — 웨이브 k 하나가 연출 박자 하나다. 박자 k는 박자 k−1이 끝난 뒤 시작한다 (chain-resolver Visual/Audio "웨이브 k+1은 웨이브 k가
   끝난 뒤"). 한 박자는 두 구간으로 나뉜다:
   - **떼어짐 구간 (peel)** — 길이 `peel_dur × tempo(k)`. 그 웨이브 `CELLS_CLEARED.cells`의 스티커가 모서리부터 들썩 떼어져 날아간다.
   - **효과 구간 (effect gap)** — 길이 `gap_dur × tempo(k)` + 얼굴 엇갈림(F2). 그 웨이브에서 발동한 얼굴의 능력이 다음 웨이브 대상까지
     뻗어 나가고, 알이 떨어진다. **다음 웨이브가 없으면 효과 구간을 두지 않는다** (단 헛손질 발동은 규칙 13의 짧은 연출만).
7. **재생 순서 = 이벤트 순서** — 큐는 이벤트 `seq` 순서를 절대 뒤집지 않는다. 같은 웨이브 안에서 시각이 겹칠 수는 있지만
   (떼어짐과 얼굴 들썩임이 동시에 시작) 시작 시각은 `seq`에 대해 단조 증가(같거나 늦음)다.
8. **배치 착지** — `PLACED`: 조각이 고스트 자리(드래그 & 배치 입력 GDD)에서 "꾹" 눌러 붙는다 — 그림자 6–10px → 1–2px, 스케일 1.06 → 1.0,
   `place_dur`. 배치 점수 "+N"(작은 스타일)이 놓은 칸 중심에서 떠오른다. 줄이 없으면(`waves = 0`) 착지 후 바로 마무리(규칙 15).

**C. 이벤트별 연출 (기본 속도, 시작값은 Formulas 변수표)**

9. **`WAVE_BEGIN`** — 웨이브 0: 완성 줄 칸 전체가 0.06s 동안 스티커 백 테두리로 반짝(줄 완성 확인). 2줄 이상이면 "N줄 동시!"
   플로팅(프로토타입). 웨이브 k ≥ 1: 별도 시간을 쓰지 않는다 — 앞 박자 효과 구간의 "도착 떨림"(규칙 12)이 이미 예고를 했다.
   `causes`에 `LINE`이 있는 k ≥ 1 웨이브(알 재점화)는 그 줄만 0.06s 반짝을 더한다 (재점화가 인과로 읽히게, 시간은 떼어짐 구간 안).
10. **`CELLS_CLEARED`** — 떼어짐 문법 (art-bible 원칙 2·3): 칸마다 ① 모서리 들썩(회전 ±6°, 스케일 1.0 → 1.08, 그림자 1–2px → 8px)
    ② 날아감(위쪽으로 흩어지며 페이드) — 칸 하나의 애니메이션 길이 `cell_lift_dur`. 칸마다 시작 시각을 엇갈린다(F5):
    `by = ABILITY`·`BOTH` 칸은 `source_order` 얼굴에서 거리 순으로, `by = LINE` 칸은 놓은 칸에서 거리 순으로 — 도미노가 "뻗어 나가는"
    방향이 보인다. 엇갈림은 떼어짐 구간 안에 들어가도록 상한이 있다. 날아가는 칸마다 종이 조각 입자(F7)를 뿌린다.
    웨이브 점수 팝업 "+(`clear_points(k)` + `activation_points(k)`)"이 그 웨이브 지워진 칸 무리의 중심에서 떼어짐 시작과 함께 떠오른다
    (`popup_dur`). k ≥ 1이면 강조 스타일, 옆에 금색 배율 "×`depth_mult_pct(k)`/100"을 붙인다 (scoring Visual/Audio).
11. **`FACE_ACTIVATED`** — 얼굴은 떼어짐 구간 시작에 다른 칸보다 **더 높이** 들린다(그림자 10px, 스케일 1.15, 발동 표정으로 교체).
    `face_lead` 뒤 능력 효과가 시작되고(크루 정의 Game Feel "발동 → 효과 시작 ≤ 0.15s"), 효과가 끝나면 얼굴 스티커는 판에서 떨어져
    **화면 가장자리 컷인 자리로 날아가 "착" 다시 붙는다** — art-bible의 "떼어짐 → 효과 → 다시 붙음" 문법을 얼굴이 완성한다.
    같은 웨이브의 얼굴은 `order_index` 순서로 `face_gap`씩 엇갈려 들리고 효과도 같은 간격으로 시작한다 (기둥 3: 미리보기 번호와 같은 순서).
    컷인 규칙은 규칙 14.
12. **`ABILITY_EFFECT`** — 효과 구간에서 재생한다.
    - `CLEAR`: 크루별 효과 그림(냥이 할퀴기 선, 곰곰 포옹 원 등 — 크루 정의 Visual/Audio)이 얼굴 칸에서 대상 칸까지 `effect_spread_dur` 동안
      뻗어 나간다. 효과가 닿은 대상 칸은 효과 구간 끝까지 "도착 떨림"(±1.5px, 4Hz 미만)을 하며 다음 박자에 떼어진다. `cells = []`이면 헛손질(규칙 13).
    - `FILL`: `cells` 순서대로 `face_lead` 시점부터 `effect_spread(k)` 창 안에(간격은 Formulas 기타 상수 `egg_gap`) 알(`fill_visual`)이 위에서 "톡" 떨어져 붙는다 (스케일 0 → 1.18 → 1.0, `egg_pop_dur`, 그림자 1–2px).
      알로 완성된 줄은 다음 박자 `WAVE_BEGIN` 반짝(규칙 9)으로 이어진다.
13. **헛손질 · 피즐 · 상한**
    - **헛손질** (`ABILITY_EFFECT.cells = []`이고 FILL 없음): 머쓱 표정 + 짧은 효과(`whiff_dur`)로 끝낸다 (크루 정의 "≤ 0.2s"). 다음 웨이브가
      없으면 이 연출이 효과 구간을 대신한다.
    - **`FACE_FIZZLED(DEPTH_CAP)`**: 얼굴이 살짝 들렸다가 "꾸벅" 졸며(눈 감은 표정, Z 스티커) 페이드 — `fizzle_dur`, 떼어짐 구간과 병행.
    - **`FACE_FIZZLED(SUPPRESSED)`**: 얼음에 갇힌 얼굴이 한 번 "바르르"(±2px, 0.15s) 떨고 얼음째 떼어진다. 실패가 아니라 귀여운 마무리 (기둥 5).
    - **`DEPTH_CAP_REACHED`**: 마지막 박자 뒤 "최대 연쇄!" 금색 배너(`banner_dur`) + 최대 강도 컨페티. 타임라인은 `cap_hold`만큼 더 머문다.
    - **`CELL_MODIFIED`**: 얼음 겹이 "찰칵" 깨지는 금 1단계 (0.12s, 떼어짐 구간 안) — 구체 그림은 방해물 GDD.
14. **컷인 (단계 배너)** — 얼굴 발동이 있는 웨이브 k마다 하나:
    - stage 1 (k = 0): 작은 능력 이름 스티커("냥이 할퀴기!")가 발동 얼굴 근처에 붙었다 사라짐 (`label_dur`). 화면 배너 없음 — 첫 발동은 아직 "연쇄"가 아니다.
    - stage ≥ 2 (k ≥ 1): 화면 상단 30% 위치에 "연쇄 N!" 배너 — 프로토타입 `peel` 키프레임(회전 −25° → 4° → −4°, 스케일 0.4 → 1.12 → 1.0, 끝에 위로
      빠지며 페이드) `banner_dur`. 테두리는 그 웨이브 첫 발동 얼굴의 크루 색 (art-bible 4절 예외), 숫자는 금색. 아래 작은 줄에 발동 크루 이름.
      배너 크기는 단계 강도(F3)로 커진다.
    - 컷인은 **겹쳐 쌓이지 않는다** — 새 배너가 나오면 이전 배너는 0.1s 안에 빠진다. 배너는 큐의 임계 경로(재생 시간)에 들어가지 않는 겹침
      연출이다(재생 끝을 늦추지 않음, 예외: `cap_hold`).
15. **마무리 (`CHAIN_END`)** — 마지막 박자(또는 착지) 뒤 `settle_dur` 동안 남은 입자가 가라앉고 표시 보드를 `final_board`와 대조한다(규칙 4).
    그다음 `playback_finished(false)`. HUD 숫자는 이 시점에 정확히 `stage_score`여야 한다 (scoring Game Feel).

**D. 깊이에 따른 상승 (기둥 1) — 강도는 오르고 박자는 빨라진다**

16. **강도 단계 `level(k)`** (F3) — 웨이브 0 = 0(일반 줄 지우기), 웨이브 k ≥ 1 = `min(k, level_cap)`. 강도가 키우는 것: 화면 흔들림 진폭,
    칸당 입자 수, 컷인 컨페티 수, 배너 크기, 밝기 펄스(규칙 18), 오디오 피치 단계(오디오 GDD가 `cue.level`을 읽음).
17. **템포 가속** (F1) — 박자 길이에 `tempo(k)`(1.0에서 웨이브마다 `tempo_step`씩 줄고 `tempo_floor`에서 멈춤)를 곱한다. 도미노가 넘어갈수록
    빨라지는 느낌을 주고 깊은 연쇄의 총 시간을 묶는다. 칸 애니메이션·알 팝·팝업 길이는 템포를 받지 않는다 — 박자 간격만 줄인다(판독성 유지).
18. **일반 줄 지우기 vs 연쇄 대비** — 웨이브 0(강도 0)에는 흔들림·밝기 펄스·배너·컨페티가 **없다**: 칸당 입자 3개와 착지·떼어짐만. 첫 얼굴 발동부터
    능력 이름 스티커, 웨이브 1부터 흔들림·펄스·배너·컨페티가 붙는다. "얼굴이 터지면 화면이 달라진다"가 기둥 1의 대비 장치다 (Game Feel 표).
19. **밝기 펄스 안전 규칙** (art-bible 2절·결정 표) — 화면 전체 밝기 +10% 펄스는 강도 ≥ 1 웨이브의 떼어짐 시작에만 일어나며, **직전 펄스와의 간격이
    `pulse_min_interval`(0.34s) 미만이면 생략**한다(F6). 따라서 템포 가속·빨리 감기·압축이 어떻게 겹쳐도 펄스는 초당 3회를 넘지 않는다. 번쩍임 끄기 또는
    움직임 줄이기가 켜지면 펄스는 0회.

**E. 재생 시간 상한**

20. **총 재생 상한** (F4) — 기본 속도에서 타임라인 총 길이 `T_raw`가 `T_budget`(4.0s)를 넘으면 모든 큐 시각과 길이에 같은 압축 계수
    `c = T_budget / T_raw`를 곱한다(순서·비율 보존). 시작값에서 연쇄 6단은 최소 ≈ 3.5s, 얼굴이 웨이브마다 3개 이상인 최악에도 4.0s다. 상한 이하에서는
    압축하지 않는다 — 짧은 연쇄를 억지로 늘리지 않는다.

**F. 입력 잠금 · 빨리 감기 · 건너뛰기 (기둥 4)**

21. **트레이 입력은 재생 중 잠긴다** — 드래그 & 배치 입력은 배치 직후 `LOCKED`이고(placement-input 규칙 15·상태표), 판 진행 흐름이
    `playback_finished`를 받은 뒤(그리고 트레이 재충전·막힘 판정 뒤) 다시 켠다. 재생 중 다음 조각을 미리 집는 "입력 관통"은 MVP에서 하지 않는다
    (표시 보드가 `final_board`와 다른 동안 집으면 보이는 판과 실제 판이 달라 기둥 3이 깨짐 — Decision Log D5).
22. **탭 = 빨리 감기, 두 번째 탭 = 건너뛰기** — 재생 중 플레이 화면 아무 곳(일시정지 버튼 제외) **새 터치다운**:
    - 1회째: 남은 타임라인을 `ff_speed`(×3) 속도로 재생 (`FAST`).
    - `FAST` 중 1회 더: 남은 모든 이벤트를 즉시 표시 보드에 적용하고, 남은 웨이브 점수를 합친 "+합계" 팝업 1개와 도달한 최대 단계 배지("연쇄 N")를
      `skip_flush_dur` 동안 보여 준 뒤 마무리 → `playback_finished(true)`. 흔들림·펄스·컨페티는 건너뛴다.
    - **보호 시간**: 배치 직후 `skip_guard`(0.15s) 안의 터치다운은 무시한다 — 드래그를 놓은 손가락의 떨림이 스킵으로 읽히지 않게. 놓기 동작의 터치업은
      애초에 터치다운이 아니므로 세지 않는다.
    - 빨리 감기·건너뛰기는 **재생 속도만** 바꾼다. 점수·보드·목표 판정은 이미 확정돼 있어 결과는 같다 (chain-resolver Game Feel, scoring 규칙 12).
23. **재생 속도 선호** — 설정값 `speed_pref` ∈ {1.0 보통, 1.5 빠르게}. 타임라인 전체를 이 값으로 나눈다(압축 F4 뒤에 적용 → 빠르게면 연쇄 6단 ≤ 2.67s).
    MVP는 일시정지 메뉴의 토글로 노출하고, VS 설정 & 접근성 GDD가 정식 화면을 소유한다 (provisional).
24. **앱이 백그라운드로 가면** 재생을 즉시 건너뛰기(규칙 22 두 번째 탭과 같은 플러시, 팝업 생략)로 끝낸다 — 돌아왔을 때 언제나 안정 보드.

**G. 움직임 줄이기 (reduced motion)**

25. 설정 `reduced_motion = true`(MVP 기본 false, 일시정지 메뉴 토글 — provisional; OS 접근성 설정 연동은 Open Question)이면:
    - **끔**: 화면 흔들림, 밝기 펄스, 도착 떨림, 배너 회전·튀는 스케일, 날아가는 칸의 회전.
    - **바꿈**: 떼어짐 = 그림자 높이 1–2px → 8px + 페이드(스케일 ≤ 1.03), 배너 = 0.15s 페이드 인 / 유지 / 0.15s 페이드 아웃(같은 `banner_dur`),
      얼굴 → 컷인 자리 비행 = 제자리 페이드 후 컷인 자리 페이드 인, 알 = 페이드 + 그림자(튀는 스케일 없음).
    - **줄임**: 입자 수 × `rm_particle_mult`(0.25, 내림·최소 0), 컨페티는 떨어지지 않고 제자리 페이드.
    - **유지**: 박자 시간·순서·엇갈림·팝업·점수 숫자·배너 문구 — 정보는 하나도 빼지 않는다(기둥 3). 시간을 늘리지도 않는다(프로토타입의
      `prefers-reduced-motion` 1.2s 연장은 채택하지 않음 — D7).
26. **번쩍임 끄기** (`flash_off`, 움직임 줄이기와 별개 토글) — 밝기 펄스와 금색 배너의 광채 스프라이트만 끈다.

### States and Transitions

재생기는 배치 1회의 재생 동안만 상태를 가진다. 게임 상태(보드·점수)는 `play` 이전에 이미 확정돼 있다.

| 상태 | 하는 일 | 들어오는 조건 | 나가는 조건 → 다음 |
|---|---|---|---|
| `IDLE` | 아무것도 재생하지 않음. 표시 보드 = 현재 보드 | 시작; `playback_finished` 직후 | `play(request)` → `BUILDING` |
| `BUILDING` | `build_timeline` (같은 프레임 안, 동기) | `play` 호출 | 항상 → `PLAYING` |
| `PLAYING` | 타임라인을 `speed_pref` 속도로 재생, 큐마다 `cue_fired` | `BUILDING` 완료 | 새 터치다운(보호 시간 뒤) → `FAST`; 앱 백그라운드 → `FLUSHING`; 마지막 큐 끝 → `SETTLING` |
| `FAST` | 남은 타임라인을 `speed_pref × ff_speed` 속도로 재생 | `PLAYING` 중 탭 | 새 터치다운 → `FLUSHING`; 앱 백그라운드 → `FLUSHING`; 마지막 큐 끝 → `SETTLING` |
| `FLUSHING` | 남은 이벤트를 표시 보드에 즉시 적용, 남은 `wave_presented`를 한꺼번에 발신, "+합계"·"연쇄 N" 배지 (백그라운드면 생략) | `FAST` 중 탭; 백그라운드 | `skip_flush_dur` 뒤 (백그라운드면 즉시) → `SETTLING` |
| `SETTLING` | 입자 가라앉힘, 표시 보드 ↔ `final_board` 대조 (규칙 4) | 위 셋 | `settle_dur` 뒤 (`FLUSHING`에서 왔으면 0) → `IDLE` + `playback_finished(was_skipped)` |

- `play`가 `IDLE`이 아닐 때 불리면 프로그래밍 오류다 — 판 진행 흐름은 `playback_finished` 전에 다음 배치를 받지 않는다(규칙 21). 출시 빌드는 진행 중인 재생을
  `FLUSHING`으로 즉시 끝내고 새 재생을 시작한다.
- `waves = 0`인 배치(줄 없음)는 `PLAYING`이 착지(`place_dur`)만 재생하고 `SETTLING`은 0s다 — 착지 직후 입력이 열린다.

### Interactions with Other Systems

| 시스템 | 방향 | 주고받는 것 | 인터페이스 소유 |
|---|---|---|---|
| 연쇄 해석기 | 해석기 → 연출 (판 흐름 경유) | `ChainResult.events` 전체, `final_board`, `summary` | 해석기 (스키마) / 이 문서 (재생 방법) |
| 점수 & 연쇄 배율 | 점수 → 연출 (판 흐름 경유) | `ScoreBreakdown.placement_points`, `waves[]`의 `clear_points`·`activation_points`·`depth_mult_pct` | 점수 GDD (값) / 이 문서 (팝업 표시) |
| 판 진행 흐름 | 판 흐름 → 연출 → 판 흐름 | `play(request)` 호출; `playback_finished(was_skipped)` 수신 후 트레이 재충전·막힘 판정·입력 재개 | 판 진행 흐름 (호출 타이밍·입력 재개) |
| 드래그 & 배치 입력 | 입력 → 연출 | 고스트 자리 = 착지 연출 시작 위치; 재생 중 트레이 입력은 `LOCKED` (판 위 탭은 입력이 소비하지 않음 — placement-input 규칙) | 입력 GDD |
| 보드 & 조각 규칙 | 보드 규칙 → 연출 | `pre_board` 사본의 칸 상태(`crew_id`, `is_face`, `origin`, `modifiers`)를 그리기만 함 | 보드 규칙 |
| 크루 정의 & 능력 | 크루 → 연출 | `crew_id` → 색 슬롯·실루엣·무늬·`fill_visual`·`ability_name_key`·효과 그림 id | 크루 정의 GDD |
| 칸 종류 & 방해물 | 방해물 → 연출 | `CELL_MODIFIED`·`FACE_FIZZLED(SUPPRESSED)`의 겹 그림 | 방해물 GDD (그림) / 이 문서 (타이밍) |
| 플레이 HUD | 연출 → HUD | `wave_presented(wave, points)` — HUD 점수 숫자를 웨이브 박자에 맞춰 올림; `playback_finished` 시 정확히 `stage_score` | HUD GDD |
| 오디오 SFX | 연출 → 오디오 | `cue_fired(cue)` — `kind`(착지·떼어짐·발동·알·피즐·배너·상한), `crew_id`, `level`, 속도 배율 | 오디오 GDD (소리·피치·겹침) |
| 튜토리얼 & 힌트 (VS) | 연출 → 튜토리얼 | 첫 `FACE_ACTIVATED` 큐 (첫 발동 팁 숨김 — 프로토타입 `seenAbility`) | 튜토리얼 GDD |
| 설정 & 접근성 (VS) | 설정 → 연출 | `speed_pref`, `reduced_motion`, `flash_off` | 설정 GDD (화면·저장) / 이 문서 (동작) |
| 플랫폼 & 화면 | 플랫폼 → 연출 | 칸 크기(px), 화면 비율 — 흔들림 진폭·배너 위치 기준 | 플랫폼 GDD |

## Formulas

> *Specialist note*: `systems-designer` not consulted — Section D는 lean에서도 spawn 대상이지만 이 실행에는 Agent 도구가 없어 생략.
> Review manually before production. 시작값은 프로토타입(`prototypes/sticker-place-concept/prototype.html`) 검증값 — 떼어짐 0.24s,
> 웨이브 대기 0.3s, 컷인 0.9s, 팝업 0.9s, 흔들림 0.3/0.45 — 에서 출발했다. 모든 시간 단위는 초(s), 기본 속도(`speed_pref = 1.0`) 기준.
> standard tier라 Tuning Knobs 섹션은 생략 — 모든 값은 `PresentationTuning` 데이터 리소스(경로는 ADR)에 두고, 안전 범위와 근거는 아래 변수표에 둔다.

**F1. 템포 가속**

The tempo formula is defined as:

`tempo(k) = max(tempo_floor, 1 − tempo_step × k)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 0 – `depth_cap` | calculated (`WAVE_BEGIN.wave`) | 웨이브 번호 = 깊이 (chain-resolver 규칙 5) |
| tempo_step | float | 0.0 – 0.12 (시작 0.08) | data file | 웨이브마다 박자를 줄이는 비율. 0이면 가속 없음, 크면 깊은 웨이브가 금방 바닥에 닿음 |
| tempo_floor | float | 0.5 – 1.0 (시작 0.6) | data file | 박자 최소 배율. 0.5 미만이면 떼어짐이 판독 불가 속도(칸 들썩임 < 0.12s) |

**Output Range:** 0.6 – 1.0 (시작값). k = 0…6 → 1.00, 0.92, 0.84, 0.76, 0.68, 0.60, 0.60.
**Example:** k = 3 → max(0.6, 1 − 0.24) = 0.76.

**F2. 박자 길이**

The wave_beat formula is defined as:

`beat(k) = peel_dur × tempo(k) + gap(k) + stagger(k)`
`gap(k) = has_next(k) ? gap_dur × tempo(k) : (whiff(k) ? whiff_dur : 0)`
`stagger(k) = min(face_gap × (n_act(k) − 1), face_stagger_cap) × tempo(k)` (n_act ≤ 1이면 0)
`effect_spread(k) = (peel_dur + gap_dur) × tempo(k) − face_lead − arrive_hold` (has_next일 때만)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| peel_dur | float | 0.18 – 0.32 (시작 0.24) | data file | 떼어짐 구간 기본 길이 (프로토타입 `later(0.24)`) |
| gap_dur | float | 0.20 – 0.40 (시작 0.30) | data file | 효과 구간 기본 길이 (프로토타입 `later(0.3)`) |
| face_gap | float | 0.03 – 0.10 (시작 0.06) | data file | 같은 웨이브 얼굴 사이 엇갈림 |
| face_stagger_cap | float | 0.06 – 0.20 (시작 0.12) | data file | 엇갈림 총합 상한 — 얼굴 3개 이상이면 더 늘지 않음 |
| face_lead | float | 0.08 – 0.15 (시작 0.12) | data file | 얼굴 들썩 → 효과 시작 (크루 정의 "≤ 0.15s"). `peel_dur × tempo_floor` 이하여야 함 (0.144 ≥ 0.12 ✓) |
| arrive_hold | float | 0.04 – 0.12 (시작 0.08) | data file | 효과 도착 → 다음 박자 시작 사이 "도착 떨림" |
| whiff_dur | float | 0.12 – 0.20 (시작 0.20) | data file | 마지막 웨이브의 헛손질 연출 (크루 정의 "≤ 0.2s") |
| has_next(k) | bool | — | calculated | 웨이브 k+1이 이벤트 목록에 있는가 |
| whiff(k) | bool | — | calculated | 웨이브 k에 발동이 있고 그 `ABILITY_EFFECT`가 모두 빈 CLEAR, FILL 없음 |
| n_act(k) | int | 0 – 64 | calculated (`FACE_ACTIVATED` 수) | 웨이브 k에서 발동한 얼굴 수 |

**Output Range:** 한 박자 0.144 s(바닥 템포, 다음 없음) ~ 0.66 s(k = 0, 얼굴 3개 이상). `effect_spread`: 0.34 s(k = 0, 크루 정의 "≤ 0.35s" ✓) ~ 0.124 s(바닥 템포).
**Example:** k = 0, 얼굴 1개, 다음 웨이브 있음 → 0.24 + 0.30 + 0 = 0.54 s (chain-resolver Game Feel "≈ 0.5s"와 일치). k = 0, 얼굴 3개 → 0.54 + 0.12 = 0.66 s.

**F3. 강도 단계와 강도별 값**

The intensity formula is defined as:

`level(k) = (k = 0) ? 0 : min(k, level_cap)`
`shake_px(L) = (L = 0) ? 0 : min(shake_max_px, shake_base_px + shake_step_px × (L − 1))`
`particles_per_cell(L) = (L = 0) ? ppc_plain : min(ppc_max, ppc_chain_base + L)`
`confetti(L) = (L = 0) ? 0 : min(confetti_max, confetti_step × L)`
`banner_scale(L) = 1 + banner_step × (max(L, 1) − 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| level_cap | int | 2 – 6 (시작 4) | data file | 강도가 더 오르지 않는 웨이브. 6 이상이면 상한 근처 차이가 안 보임 |
| shake_base_px / shake_step_px / shake_max_px | int | 2–4 / 1–3 / 8–12 (시작 3 / 2 / 10) | data file | 1080 폭 기준 화면 흔들림 진폭(px). 실제 px는 화면 폭 비례. 지속 `shake_dur` 0.25s 선형 감쇠 |
| ppc_plain | int | 2 – 5 (시작 3) | data file | 일반 줄 지우기(웨이브 0) 칸당 종이 조각 |
| ppc_chain_base / ppc_max | int | 3–5 / 6–10 (시작 4 / 8) | data file | 연쇄 웨이브 칸당 종이 조각 |
| confetti_step / confetti_max | int | 10–20 / 40–80 (시작 15 / 60) | data file | 배너와 함께 터지는 컨페티 수 |
| banner_step | float | 0.0 – 0.08 (시작 0.05) | data file | 단계마다 배너 크기 증가 |
| particle_budget | int | 150 – 400 (시작 300) | data file | 동시에 살아 있는 입자 상한. 넘으면 새 버스트의 수를 비례로 줄인다(최소 1). 저가 Android 성능 보호 |

**Output Range:** L = 0…4 → 흔들림 0/3/5/7/9 px, 칸당 입자 3/5/6/7/8, 컨페티 0/15/30/45/60, 배너 1.00/1.00/1.05/1.10/1.15. 움직임 줄이기: 흔들림 0, 입자·컨페티 × `rm_particle_mult`(0.25, 내림).
**Example:** 웨이브 2(L = 2), 지운 칸 20개 → 흔들림 5 px, 입자 120개, 컨페티 30, 배너 1.05배.

**F4. 총 재생 시간과 압축**

The chain_playback_time formula is defined as:

`T_raw = place_dur + Σ_{k=0}^{W−1} beat(k) + (cap_reached ? cap_hold : 0) + (W > 0 ? settle_dur : 0)`
`c = max(c_min, min(1, T_budget / T_raw))`
`T_play = T_raw × c / speed_pref`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| W | int | 0 – `depth_cap` + 1 | calculated (`CHAIN_END.waves`) | 웨이브 수 |
| place_dur | float | 0.08 – 0.16 (시작 0.12) | data file | 착지 "꾹" (board-rules Game Feel 0.1–0.15s) |
| cap_hold | float | 0.3 – 0.8 (시작 0.5) | data file | "최대 연쇄!" 배너를 읽을 여유 |
| settle_dur | float | 0.10 – 0.25 (시작 0.15) | data file | 마무리. 바닥 템포 마지막 웨이브의 칸 애니메이션 넘침(≤ 0.064 s)보다 커야 함 |
| T_budget | float | 3.0 – 5.0 (시작 4.0) | data file | 기본 속도 총 재생 상한 — "한 판 더" 템포 (chain-resolver Game Feel "연쇄 6단 ≤ 약 4s") |
| c_min | float | 0.6 – 0.9 (시작 0.7) | data file | 최소 압축 계수 — 이보다 빠르면 판독 불가. `depth_cap ≤ 10`에서도 T ≤ 4.0이 되도록 고른 값 |
| speed_pref | float | {1.0, 1.5} | settings | 재생 속도 선호 (규칙 23) |
| cap_reached | bool | — | calculated (`CHAIN_END.cap_reached`) | 깊이 상한 도달 |

**Output Range:** 시작값에서 0.12 s(줄 없음) ~ 4.0 s(연쇄 6단 최악). `depth_cap = 10`(안전 범위 최대)·웨이브마다 얼굴 3개라도 T_raw ≈ 5.67 → c = 0.705 → 4.0 s. 속도 1.5 → 최대 2.67 s.
**Example (속도 1.0):**

| 경우 | 계산 | T_play |
|---|---|---|
| 줄 없음 | 0.12 | **0.12 s** |
| 한 줄, 얼굴 없음 | 0.12 + 0.24 + 0.15 | **0.51 s** |
| 얼굴 헛손질 (웨이브 0만) | 0.12 + 0.24 + 0.20 + 0.15 | **0.71 s** |
| 연쇄 1 (웨이브 0 → 1) | 0.12 + 0.54 + 0.24×0.92 + 0.15 | **1.03 s** |
| 연쇄 3 (웨이브 0–3, 얼굴 1개씩) | 0.12 + 0.54×(1+0.92+0.84) + 0.24×0.76 + 0.15 | **1.94 s** |
| 연쇄 6, 상한 미도달 (웨이브 6에 얼굴 없음) | 0.12 + 0.54×4.80 + 0.24×0.60 + 0.15 | **3.01 s** |
| 연쇄 6, 상한 도달 (웨이브 6 피즐) | 위 + 0.5 | **3.51 s** |
| 연쇄 6, 상한 도달, 웨이브 0–5마다 얼굴 3개 | 3.506 + 0.12×4.80 = 4.082 → c = 0.980 | **4.00 s** |

**F5. 칸 엇갈림**

The cell_stagger formula is defined as:

`offset(cell) = min(stagger_step × d(cell), stagger_cap) × tempo(k) × c`

- `d` = 체비쇼프 거리. `by ∈ {ABILITY, BOTH}` 칸: `source_order` 얼굴 칸(이전 웨이브)에서. `by = LINE` 칸: 웨이브 0이면 가장 가까운 `PLACED.cells`에서,
  k ≥ 1(알 재점화 줄)이면 직전 웨이브 `ABILITY_EFFECT(FILL).cells` 중 가장 가까운 알에서. 기준 칸이 없으면 0. (이벤트 필드의 좌표 거리일 뿐 규칙 판정이 아니다 — 규칙 3.)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stagger_step | float | 0.01 – 0.03 (시작 0.02) | data file | 거리 1칸당 지연 |
| stagger_cap | float | 0.04 – 0.10 (시작 0.08) | data file | 최대 지연. `cell_lift_dur + stagger_cap = peel_dur`가 되게 고른다 (0.16 + 0.08 = 0.24) |
| cell_lift_dur | float | 0.12 – 0.20 (시작 0.16) | data file | 칸 하나의 들썩 → 날아감 (템포를 받지 않음) |
| d | int | 0 – 7 | calculated | 기준 칸과의 거리 |

**Output Range:** 0 – 0.08 s (k = 0), 바닥 템포에서 0 – 0.048 s. 칸 애니메이션은 떼어짐 구간을 최대 0.064 s 넘을 수 있고, 넘친 부분은 다음 효과 구간 또는 마무리와 겹친다.
**Example:** 냥이 십자(`reach = −1`)가 지운 칸 중 얼굴에서 5칸 떨어진 칸, k = 1 → min(0.10, 0.08) × 0.92 = 0.074 s.

**F6. 밝기 펄스 간격 (광과민성 안전)**

The pulse_gate formula is defined as:

`pulse(k) = level(k) ≥ 1 ∧ ¬flash_off ∧ ¬reduced_motion ∧ (t_real(k) − t_real(last_pulse) ≥ pulse_min_interval)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| pulse_min_interval | float | 0.34 – 1.0 (시작 0.34, **0.34 미만 금지**) | data file | 펄스 사이 최소 실제 시간. 1/3 s보다 조금 길어 임의의 1초 창에 펄스가 4번 들어갈 수 없다 — art-bible "초당 3회 이하" |
| pulse_gain | float | 0.05 – 0.10 (시작 0.10) | data file | 화면 밝기 +10% (art-bible 2절) |
| pulse_dur | float | 0.08 – 0.15 (시작 0.12) | data file | 펄스 한 번 길이 |
| t_real(k) | float | — | calculated | 웨이브 k 떼어짐 시작의 **실제 화면 시각**(압축·속도 선호·빨리 감기 반영 후) |

**Output Range:** 펄스 0 ~ 6회/배치, 임의의 1초 창 안에서 ≤ 3회. 바닥 템포·c = 0.7·속도 1.5·빨리 감기 ×3이 겹쳐 박자가 0.05 s가 돼도 게이트가 펄스를 생략한다.
**Example:** 연쇄 6, 속도 1.0: 펄스 후보 시각(웨이브 1–6) 0.66, 1.16, 1.61, 2.02, 2.39, 2.71 s → 간격 0.50·0.45·0.41·0.37·0.32 → 웨이브 6(간격 0.32 < 0.34)만 생략, 5회. 어느 1초 창에도 3회 이하 (예: [1.16, 2.16) → 1.16·1.61·2.02).

**F7. 빨리 감기 · 건너뛰기 대기 시간**

The skip_latency formula is defined as:

`T_left_fast = T_left / ff_speed` · `T_skip = skip_flush_dur`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_left | float | 0 – 4.0 | calculated | 탭 시점의 남은 재생 시간 |
| ff_speed | float | 2.0 – 4.0 (시작 3.0) | data file | 빨리 감기 배율 |
| skip_flush_dur | float | 0.15 – 0.40 (시작 0.25) | data file | 건너뛰기 "+합계" 팝업·배지 표시 후 마무리까지 |
| skip_guard | float | 0.10 – 0.25 (시작 0.15) | data file | 배치 직후 탭 무시 시간 |

**Output Range:** 빨리 감기 후 남은 대기 ≤ 1.33 s, 두 번째 탭 후 ≤ 0.25 s.
**Example:** 연쇄 6(3.51 s)에서 0.5 s에 탭 → 남은 3.01 s / 3 = 1.00 s. 0.7 s에 한 번 더 탭 → 0.25 s 뒤 입력 재개 (총 0.95 s).

**기타 연출 상수 (식 없음 — 데이터 리소스 값)**

| 값 | 시작값 | 안전 범위 | 근거 |
|---|---|---|---|
| `popup_dur` (점수 "+N" 떠오름) | 0.9 s | 0.6 – 1.2 | 프로토타입 floats 0.9 s. 재생 끝 뒤에도 남을 수 있음(입력 비차단) |
| `banner_dur` ("연쇄 N!", "최대 연쇄!") | 0.9 s | 0.7 – 1.2 | 프로토타입 컷인 `.9s`. 임계 경로 밖 |
| `label_dur` (stage 1 능력 이름 스티커) | 0.6 s | 0.4 – 0.9 | 배너보다 가벼운 첫 발동 |
| `egg_gap` / `egg_pop_dur` | 0.06 / 0.10 s | 0.04–0.10 / 0.08–0.16 | 알은 `face_lead` 시점부터 `effect_spread(k)` 안에 모두 떨어진다: 실제 간격 = max(0, min(`egg_gap`, (`effect_spread(k)` − `egg_pop_dur`) / max(n − 1, 1))). k = 0 알 3개: 간격 0.06 → 0.22 s ≤ 0.34 ✓; 바닥 템포: 간격 0.012 → 거의 동시 |
| `fizzle_dur` | 0.30 s | 0.2 – 0.5 | 꾸벅 — 떼어짐과 병행 |
| `rm_particle_mult` | 0.25 | 0 – 0.5 | 움직임 줄이기 입자 배율 |

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — Lean mode (Section E). Review manually before production.

- **If 배치가 줄을 하나도 완성하지 않으면** (`waves = 0`): 착지 `place_dur`(0.12 s)와 배치 점수 팝업만. `SETTLING` 0 s → 0.12 s 뒤 `playback_finished`. 탭은 보호 시간(0.15 s) 안이라 무시된다.
- **If 배치로 행과 열이 동시에 완성되면**: 웨이브 0 하나로 함께 떼어진다. 교차 칸은 `CELLS_CLEARED`에 한 번만 있으므로 한 번만 날아간다. "2줄 동시!" 플로팅. 강도 0이라 흔들림·배너 없음.
- **If 같은 웨이브에 얼굴이 여러 개면**: `order_index` 순서로 `face_gap`씩 엇갈려 들리고 효과도 같은 순서로 시작한다. 엇갈림은 `face_stagger_cap`에서 멈추므로
  얼굴 4개 이상이어도 박자는 0.12 s × 템포까지만 길어진다. 배너는 웨이브당 하나("연쇄 N!"), 아래 줄에 발동 크루 이름을 순서대로(최대 3개 + "…").
- **If 두 얼굴의 CLEAR 대상이 겹치면**: 해석기가 이미 `source_order`를 앞선 얼굴로 정했다 — 그 칸은 앞선 얼굴에서 뻗어 나가는 효과에 맞아 떼어진다. 재생기는 겹침을 다시 계산하지 않는다.
- **If 발동이 헛손질이면** (대상 모두 빈칸, FILL 없음): 머쓱 표정 + `whiff_dur`. 다음 웨이브가 없으면 이것이 마지막 박자. 강도는 그 웨이브 값 그대로(웨이브 0이면 흔들림 없음).
- **If 같은 웨이브에 헛손질 얼굴과 실제 효과 얼굴이 섞이면**: 각 얼굴이 자기 효과를 재생한다. 박자 길이는 `has_next`로만 정한다(실제 효과가 다음 웨이브를 만들면 효과 구간 있음).
- **If FILL 알이 줄을 완성하면**: 다음 박자 `WAVE_BEGIN`에서 그 줄이 0.06 s 반짝(규칙 9)하고, 그 줄 칸은 가장 가까운 알에서 거리 순으로 떼어진다(F5). 재점화가 "알 → 줄 → 터짐"으로 읽혀야 한다.
- **If 알이 하나도 놓이지 않으면** (`ABILITY_EFFECT(FILL).cells = []`): 엉덩이 들썩 표정만, 알 연출 없음. 헛손질 규칙과 같다.
- **If 웨이브 k = `depth_cap`이면** (상한): 그 웨이브 칸은 정상적으로 떼어지고 얼굴은 `FACE_FIZZLED(DEPTH_CAP)` 꾸벅, 뒤이어 "최대 연쇄!" 배너와 최대 강도 컨페티, `cap_hold`. 상한은 벌이 아니라 정점이다(기둥 1·5).
- **If 얼굴이 `SUPPRESSED`로 피즐하면** (얼어붙은 얼굴): 바르르 떨고 얼음째 떼어진다. 그 웨이브에 발동이 없으면 배너도 없다(`chain_depth`에 세지 않으므로 "연쇄 N" 숫자가 오르지 않아야 함).
- **If `pre_clear` 훅이 `KEEP`을 돌려주면** (`CELL_MODIFIED`): 그 칸은 떼어지지 않고 겹 깨짐 연출만, 표시 보드에 남는다. 그 칸이 얼굴이면 들리지 않는다.
- **If 깊이 6 연쇄가 웨이브마다 얼굴 3개 이상이면**: T_raw 4.08 s → 압축 c = 0.98로 정확히 4.0 s (F4). 압축은 모든 큐에 같은 비율이라 순서·엇갈림이 보존된다.
- **If `depth_cap`이 데이터로 10까지 오르면**: 압축 하한 `c_min = 0.7`이 걸려도 T ≤ 4.0 s (F4 Output Range). 10을 넘기면 4.0 s 상한이 깨질 수 있다 — chain-resolver 안전 범위(3–10)를 넘는 값은 데이터 검증에서 경고.
- **If `depth_cap = 0`이면**: 웨이브 0만 있고 모든 얼굴이 피즐 — 일반 블록 퍼즐처럼 0.51 s + 꾸벅 + "최대 연쇄!"는 **띄우지 않는다**(`DEPTH_CAP_REACHED`가 와도 `chain_depth = 0`이면 배너 생략 — 연쇄 없이 "최대 연쇄"는 거짓말).
- **If 재생 중 탭을 연타하면**: 첫 탭 `FAST`, 두 번째 `FLUSHING`, 그 뒤 탭은 무시. 한 프레임에 여러 터치다운이 와도 한 번으로 센다(프레임당 최대 1단계 전진).
- **If 드래그를 놓은 직후 다른 손가락이 화면을 누르면**: `skip_guard`(0.15 s) 안이면 무시, 뒤면 빨리 감기. 일시정지 버튼 누름은 스킵으로 세지 않고 일시정지(판 진행 흐름)로 간다.
- **If 재생 중 일시정지하면**: 판 진행 흐름이 일시정지를 걸면 타임라인 시각이 멈춘다(입자·흔들림도 정지). 재개하면 이어서 재생한다. 백그라운드 전환만 플러시한다(규칙 24).
- **If 앱이 재생 중 백그라운드로 가면**: 즉시 `FLUSHING`(팝업 생략) → `SETTLING` 0 s → `playback_finished(true)`. 상태는 이미 커밋돼 있어 세이브와 충돌 없음.
- **If 프레임이 크게 끊기면** (저가 Android 순간 정지 0.5 s): 타임라인은 실제 시각을 따르므로 건너뛴 큐는 다음 프레임에 시작 시각 순서대로 한꺼번에 실행된다(이미 끝났어야 할 큐는 끝 상태로). 재생 시간은 늘지 않는다.
- **If 입자가 `particle_budget`(300)을 넘으려 하면**: 새 버스트 수를 남은 예산에 비례해 줄인다(최소 1). 오래된 입자를 지우지 않는다 — 지우면 팝 현상이 보인다.
- **If 표시 보드가 재생 끝에 `final_board`와 다르면**: 재생기 버그(이벤트 적용 누락). 디버그 assert, 출시 빌드는 오류 로그 + `final_board`로 다시 그림. 게임 결과는 영향 없음.
- **If `play`가 재생 중에 다시 불리면**: 판 진행 흐름 버그. 디버그 assert, 출시 빌드는 현재 재생을 플러시하고 새 재생 시작.
- **If 크루 시각 정보가 없으면** (`crew_visuals`에 `crew_id` 없음 — 크루 정의 로드 검증상 불가능): 회색 자리표시 스티커 + 오류 로그. 재생은 계속한다.
- **If 움직임 줄이기 중 상한에 도달하면**: 배너는 페이드, 컨페티는 15개(60 × 0.25), 흔들림·펄스 없음. 시간은 같다.
- **If 점수 팝업이 재생 끝 뒤에도 떠 있으면**: 그대로 끝까지 떠오른다(입력 비차단). 다음 배치가 시작되면 남은 팝업은 0.1 s 안에 페이드.

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
