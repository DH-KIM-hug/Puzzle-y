# 오디오 SFX (Audio)

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user (delegated: "알아서 다") + Claude (`/design-system`, automation guided, review_mode lean)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09
> **Implements Pillar**: 기둥 1 도미노의 손맛 (주), 기둥 5 다정한 세계, 기둥 3 보이는 연쇄 (소리가 단계를 읽어 줌)
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — Lean mode

## Summary

말랑 크루의 효과음 시스템. 연쇄 연출 재생기가 내보내는 큐(`cue_fired`)와 판 화면의 입력·점수·결과 이벤트를 받아,
스티커북 톤의 짧은 합성 효과음 21종을 풀링된 플레이어로 재생한다. 연쇄 웨이브 타격음은 깊이마다 피치가 한 단계씩
올라가 "연쇄가 커진다"를 귀로도 읽게 하고(기둥 1), 실패 소리조차 귀엽게 만든다(기둥 5). 음량·음소거는 데이터와 설정으로
조절하고, 웹 빌드에서는 첫 사용자 입력 전에는 아무 소리도 내지 않는다.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `연쇄 연출 재생기` (Hard), `판 진행 흐름` (Hard), `드래그 & 배치 입력` · `점수 & 연쇄 배율` · `크루 정의` (Soft) — downstream: 설정 & 접근성 (VS)

## Overview

오디오 SFX는 **보여 주는 연출에 소리를 붙이는 재생 전용 계층**이다. 규칙을 판정하지 않고, 보드나 점수를 바꾸지 않으며,
연쇄 연출 재생기의 큐 시각·판 화면 이벤트를 그대로 따라 소리를 낸다. 플레이어는 이 시스템을 직접 조작하지 않지만
(음량·음소거 설정 제외) 모든 배치에서 직접 듣는다: 조각을 집으면 "뽁", 놓으면 "꾹", 줄이 지워지면 종이가 "샤라락" 쓸리고,
얼굴이 발동하면 크루마다 다른 소리(냥이 할퀴기, 곰곰 쿵, 삐약 퐁 …)가 나며, 연쇄 웨이브마다 타격음이 한 음씩 올라가다가
"대연쇄!!"에서 팡파르가 터진다. 이 시스템이 없으면 기둥 1의 "압도적으로 시원한" 대비가 화면에만 남고, 연쇄 깊이를 눈을 떼고도
느끼는 수단이 사라진다. 소리 에셋은 외부·저작권 소재 없이 저장소 안의 생성기(`tools/audio/`)로 합성한다.
구현 방식(버스 구성, 풀, 데이터 리소스)은 이 문서의 규칙을 따르되 세부 구조는 ADR 후보다(→ Open Questions Q3).

## Detailed Design

> *Specialist note*: `game-designer` · `audio-director` · `sound-designer` (Section C 라우팅) not consulted — Lean mode, and this run has no Agent tool.
> Review manually before production.

### Core Rules

**A. 재생 계층 원칙**

1. **재생 전용.** 오디오는 연쇄 연출 재생기(`ChainPlayer.cue_fired`)와 판 화면(GameScreen)의 이벤트를 듣기만 한다. 규칙 판정·보드·점수·타이밍을
   바꾸지 않는다. 오디오가 꺼져 있거나 초기화에 실패해도 게임 진행은 같다.
2. **큐 시각 = 소리 시각.** 소리는 해당 시각 큐가 발화한 프레임에 재생 요청된다. 연출 쪽 지연(줄 스윕 캐스케이드 `sweep_cascade_s × i`)이
   있는 큐만 같은 지연을 소리에도 준다(F2). 히트스톱 중에는 웨이브 타격음이 히트스톱 시작 프레임에 울린다(정지된 화면 = 타격의 순간).
3. **데이터 주도.** 소리 목록(id → 파일), 소리별 게인·우선순위·최대 동시 발음 수, 피치 단계, 풀 크기, 빨리 감기 정책, 기본 음량은
   `assets/data/audio/audio_tuning.tres`에 있다. 코드에 dB·반음·초 값을 박지 않는다.
4. **웹 오디오 정책.** 첫 사용자 입력(터치·클릭·키 누름) 전에는 재생 요청을 모두 버린다(부팅·첫 화면에서 무음). 무장(armed) 이후 요청만 재생한다.
   Godot 웹 내보내기는 첫 입력에서 AudioContext를 깨우므로, 이 규칙은 "깨우기 전에 쌓인 소리가 한꺼번에 터지는" 일을 막는다.

**B. 버스 구성**

5. 버스는 `Master` ← `SFX`, `Master` ← `Music` 세 개다 (`default_bus_layout.tres`). MVP에는 Music 버스에 아무것도 없다 — BGM은 이후 작업(Q1).
   모든 효과음은 `SFX` 버스로 간다.
6. 음량 설정은 버스 단위다: `master_volume`, `sfx_volume`, `music_volume` ∈ [0, 1] → 버스 dB(F4). `muted = true`면 Master 버스를 음소거한다.
   설정은 `user://audio_settings.cfg`에 저장하고 시작 시 읽는다 (provisional — 설정 & 접근성 GDD와 로컬 세이브가 생기면 그쪽 저장소로 옮김, Q2).
   실행 인자 `-- --mute`는 그 실행 동안 음소거한다(자동 플레이·CI용).

**C. 풀과 발음 제한**

7. 효과음은 시작 시 미리 만든 `pool_size`(12)개의 `AudioStreamPlayer` 풀로 재생한다. 런타임에 플레이어 노드를 만들지 않는다.
8. 같은 소리는 `min_repeat_gap_s` 안에 다시 울리지 않고, 동시에 `max_voices`(소리별, 기본 3)를 넘지 않는다 — 넘는 요청은 버린다(F3).
   한 웨이브에 칸 20개가 떼어져도 "팝" 20개가 겹쳐 뭉개지지 않는다.
9. 풀이 다 차면 **우선순위가 가장 낮고 가장 오래된** 발음을 빼앗는다. 단 빼앗길 발음의 우선순위가 새 요청보다 높으면 새 요청을 버린다.
   우선순위: 0 = 틱·팝, 1 = 입력·착지·떼어짐·스윕, 2 = 능력·알·꾸벅·웨이브 타격·배너, 3 = 팡파르·결과 차임.

**D. 소리 목록과 이벤트 연결 (21종)**

| id | 이름 (의성어) | 트리거 | 우선순위 | 피치 규칙 |
|---|---|---|---|---|
| `ui_tap` | UI 탭 "똑" | 버튼 누름, 재생 중 탭(빨리 감기·건너뛰기) | 1 | 고정 |
| `pick_up` | 집기 "뽁" | 트레이 조각 누름이 받아들여짐 | 1 | 고정 |
| `place_thud` | 착지 "꾹" (찌그러짐) | `PLACE` 큐 | 1 | 고정 |
| `invalid_return` | 되돌아가기 "뿅~↘" | 놓기 실패·취소로 조각이 트레이로 돌아감 (판 위 실패면 게인 그대로, 판 밖 취소면 −6 dB) | 1 | 고정 |
| `line_sweep` | 줄 스윕 "샤라락" | `LINE_FLASH` 큐, 줄마다 1회 | 1 | F2 (줄 순서마다 상승) |
| `cell_pop` | 칸 팝 "퐁" | `PEEL` 큐(칸마다, F3 제한) · `EGG` 큐(알마다) | 0 | F1 × 지터, 알은 F2 순서 상승 |
| `sticker_peel` | 떼어짐 "샥" | 웨이브의 첫 `PEEL` 큐 (웨이브당 1회) | 1 | F1 |
| `ab_cat_claw` | 냥이 할퀴기 "샥샥" | `EFFECT` 큐, 종 `cat` | 2 | F1 |
| `ab_bear_thump` | 곰곰 쿵 + 충격파 "쿠웅" | `EFFECT`, `bear` | 2 | F1 |
| `ab_chick_pop` | 삐약 알 "삐-퐁" | `EFFECT`, `chick` | 2 | F1 |
| `ab_sheep_pop` | 몽실 "뭉실-퐁" | `EFFECT`, `sheep` | 2 | F1 |
| `ab_frog_splash` | 개굴 "첨벙" | `EFFECT`, `frog` | 2 | F1 |
| `ab_rabbit_hop` | 깡총 "뿅뿅" | `EFFECT`, `rabbit` | 2 | F1 |
| `chain_hit` | 웨이브 타격 "탕!" | `SHAKE` 큐 (웨이브 시작, level ≥ 1) | 2 | **F1 깊이마다 상승** |
| `banner_slam` | 배너 "착!" | `BANNER` 큐 | 2 | F1 |
| `fizzle` | 꾸벅 "쿨…" | `FIZZLE` 큐 | 2 | 고정 |
| `cap_fanfare` | 최대 연쇄 팡파르 | `CAP_BANNER` 큐 | 3 | 고정 |
| `finisher_fanfare` | "대연쇄!!" 팡파르 | 피니셔 큐 (`kind = -1`) | 3 | 고정 |
| `confetti_burst` | 컨페티 "팡 바스락" | 피니셔 큐와 함께 | 3 | 고정 |
| `score_tick` | 점수 틱 "틱" | HUD 점수 숫자가 올라갈 때 (F5 간격) | 0 | F5 롤업마다 상승 |
| `result_chime` | 결과 차임 "딩-동-댕" | 결과 패널 표시 | 3 | 고정 |

10. 알 큐(`EGG`)는 능력 소리(`EFFECT`)와 겹치지 않도록 `cell_pop`만 낸다 — 삐약·몽실의 능력 소리는 `EFFECT`에서 한 번, 알 하나하나는 가벼운 "퐁"이
    한 음씩 올라간다(F2). `LABEL`·`POPUP`·`MODIFY`·`END` 큐는 소리가 없다(점수 소리는 HUD 틱이 맡는다).
11. 크루 종(species)이 목록에 없으면(새 크루, 자리표시) `EFFECT`는 `chain_hit`과 겹치지 않게 `cell_pop`으로 대체한다 — 무음보다 낫고, 에러가 아니다.

**E. 빨리 감기 · 건너뛰기 (chain-presentation Q5 결정)**

12. 재생기 상태 `FAST`(첫 탭) 동안에는 우선순위 2 이상만 울리고 `ff_gain_db`(−6 dB)를 더한다 — 웨이브 타격의 상승 음계는 남기고 팝·스윕·틱의 홍수는 뺀다.
13. 건너뛰기(두 번째 탭, `FLUSHING`)는 남은 큐를 소리 없이 적용한다. 들리는 소리는 탭의 `ui_tap`뿐이다. 소리를 몰아서 재생하지 않는다.

### States and Transitions

| 상태 | 의미 | 들어가는 조건 | 나가는 조건 |
|---|---|---|---|
| `DISARMED` | 풀·버스 준비됨, 모든 요청 버림 | 게임 시작 | 첫 사용자 입력(눌림) → `ARMED` |
| `ARMED` | 정상 재생 | 첫 입력 | 앱이 백그라운드/일시정지 → `SUSPENDED` |
| `SUSPENDED` | 새 요청 버림, 재생 중 소리 정지 | `NOTIFICATION_APPLICATION_PAUSED`/`FOCUS_OUT` | 다시 포커스 → `ARMED` |

음소거(`muted`)는 상태가 아니라 버스 설정이다 — 음소거 중에도 요청 처리·발음 제한 계산은 같아서 음소거 해제 직후 소리가 몰려 나오지 않는다.

### Interactions with Other Systems

| 시스템 | 방향 | 데이터 | 소유 |
|---|---|---|---|
| 연쇄 연출 재생기 | 연출 → 오디오 | `cue_fired(kind, level, index, species)`; 재생기 `state`(`FAST` 판단) | 신호·큐 시각 = 연출 GDD, 소리 선택·피치 = 이 문서 |
| 판 화면 / 드래그 입력 | 입력 → 오디오 | 집기 수락, 놓기 실패·취소(판 위 여부), 재생 중 탭, 버튼 탭 | 이벤트 = placement-input, 소리 = 이 문서 |
| 플레이 HUD (점수) | HUD → 오디오 | 표시 점수 정수가 바뀐 순간, 롤업이 목표에 닿은 순간 | 롤업 = HUD/연출, 틱 규칙(F5) = 이 문서 |
| 판 진행 흐름 | 흐름 → 오디오 | 결과 패널 표시(`NO_MOVES`), 재시도 | 흐름 GDD (미작성, provisional) |
| 크루 정의 | 데이터 | `species` → 능력 소리 id (`ab_<species>` 매핑은 `audio_tuning.tres`) | 크루 정의 = 종, 이 문서 = 소리 |
| 설정 & 접근성 (VS) | 설정 → 오디오 | `master/sfx/music_volume`, `muted` | 값 소유 = 설정 GDD (그 전까지 이 문서의 provisional 저장) |

## Formulas

**F1 — 연쇄 깊이 피치 (chain_pitch)**

The chain_pitch formula is defined as:

`chain_pitch(d) = 2 ^ ((clamp(d, 1, d_cap) − 1) × s_step / 12)`  (d ≤ 0 → 1.0)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| d | int | 0–6 | calculated (`cue.index` = 웨이브 번호 for `SHAKE`; `cue.level` for 그 밖) | 연쇄 깊이 (웨이브 1 = 첫 연쇄) |
| s_step | float | 1.0–3.0 반음 | data file (`chain_semitone_step`, 2.0) | 깊이당 올라가는 반음 수 |
| d_cap | int | 4–8 | data file (`chain_pitch_cap`, 6) | 이 깊이 이상은 같은 피치 (depth_cap 6과 맞춤) |

**Output Range:** 1.0 (깊이 1) – 2^(10/12) ≈ 1.782 (깊이 6) at 기본값. s_step 3.0이면 깊이 6에서 2^(15/12) ≈ 2.38 — 합성음이 얇아지므로 상한 3.0.
**Example:** 3단 연쇄의 `chain_hit` = 2^(4/12) ≈ 1.26 (장3도 위). 깊이 1→6은 도-레-미-파#-솔#-라# 온음 계단.

**F2 — 순서 상승 피치 (cascade_pitch)와 지연**

The cascade_pitch formula is defined as:

`cascade_pitch(i, d) = chain_pitch(d) × 2 ^ (min(i, i_cap) × s_idx / 12)`;  `delay(i) = sweep_cascade_s × i` (줄 스윕만)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| i | int | 0–15 | calculated (`cue.index`) | 같은 큐 묶음 안 순서 (줄 번호, 알 번호) |
| s_idx | float | 0.5–3.0 반음 | data file (`index_semitone_step`, 2.0) | 순서당 반음 |
| i_cap | int | 2–8 | data file (`index_pitch_cap`, 4) | 이 순서 이상은 같은 피치 |
| sweep_cascade_s | float | 0.03–0.1 s | data file (presentation_tuning, 0.05) | 연출 스윕 캐스케이드 — 연출과 같은 값을 읽음 |

**Output Range:** 1.0 – chain_pitch(d) × 2^(8/12) ≈ 1.587배. 깊이 0에서 4줄 동시 = 도-레-미-파# 0.05 s 간격.
**Example:** 웨이브 0에서 줄 3개 → `line_sweep` 피치 1.0 / 1.122 / 1.26, 시각 0 / 0.05 / 0.10 s.

**F3 — 발음 제한 (voice_admit)**

The voice_admit formula is defined as:

`admit(id, now) = (now − last_play[id] ≥ min_repeat_gap_s) ∧ (active[id] < max_voices[id]) ∧ (pool_free > 0 ∨ steal_ok)`;
`steal_ok = ∃ voice v: priority(v) ≤ priority(id)` (가장 낮은 우선순위 중 가장 오래된 v를 빼앗음)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| min_repeat_gap_s | float | 0.0–0.1 s | data file (0.035) | 같은 소리 최소 간격 |
| max_voices[id] | int | 1–6 | data file (소리별, 기본 3) | 같은 소리 동시 발음 상한 |
| pool_size | int | 6–24 | data file (12) | 전체 발음 수 |
| priority(id) | int | 0–3 | data file (소리별) | 규칙 9 |

**Output Range:** true/false. 기본값에서 한 웨이브 칸 20개 떼어짐 → `cell_pop` 최대 3개 동시, 0.035 s 간격.
**Example:** 같은 프레임(Δt=0)에 `cell_pop` 2회 요청 → 두 번째는 간격 미달로 버림.

**F4 — 음량 (gain)**

`voice_db = gain_db[id] + (ff_gain_db if FAST else 0)`;  `bus_db(v) = linear_to_db(v)` (v = 0 → 버스 음소거)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| gain_db[id] | float | −24–0 dB | data file (소리별) | 소리별 기준 게인 (믹스) |
| ff_gain_db | float | −12–0 dB | data file (−6) | 빨리 감기 중 감쇠 |
| v | float | 0.0–1.0 | user setting (기본 master 1.0, sfx 0.8, music 0.7) | 버스 음량 |

**Output Range:** voice −36–0 dB; bus −∞(음소거)–0 dB. 클리핑 방지를 위해 생성기가 모든 파일을 −1 dBFS 피크로 정규화하고 기본 게인은 ≤ 0 dB.
**Example:** sfx_volume 0.5 → SFX 버스 −6.02 dB; FAST 중 `chain_hit`(−3 dB) → −9 dB.

**F5 — 점수 틱 (score_tick)**

`tick_now = (shown_int changed) ∧ (now − last_tick ≥ tick_gap_s)`;  `tick_pitch(n) = 2 ^ (min(n, tick_cap) × tick_step / 12)`, n = 이번 롤업에서 울린 틱 수 (롤업이 목표에 닿으면 0)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tick_gap_s | float | 0.03–0.12 s | data file (0.05) | 틱 최소 간격 (초당 ≤ 20틱) |
| tick_step | float | 0.25–1.0 반음 | data file (0.5) | 틱당 상승 |
| tick_cap | int | 4–24 | data file (14) | 상승 상한 → 최대 7반음 |

**Output Range:** 피치 1.0 – 2^(7/12) ≈ 1.498. 0.6 s 롤업 → 최대 12틱.
**Example:** 점수 0 → 840 롤업 동안 12틱, 마지막 틱 피치 2^(5.5/12) ≈ 1.374.

**F6 — 지터 (jitter)**

`pitch_final = pitch × 2 ^ (u × jitter_cents / 1200)`, u ∈ [−1, 1] (오디오 전용 고정 시드 RNG, 규칙 판정 RNG와 분리)

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| jitter_cents | float | 0–50 | data file (소리별 `jitter`, `cell_pop`·`score_tick`·`sticker_peel` 25, 나머지 0) | 반복음의 기계적 느낌 제거 |
| u | float | −1–1 | calculated (seed 11 RNG) | 균등 |

**Output Range:** ±25 cents = ±1.45%. 피치 상승 계단(200 cents)보다 충분히 작아 F1·F2의 음계가 흐려지지 않는다.

## Edge Cases

> *Specialist note*: `systems-designer` not consulted — this run has no Agent tool. Review manually before production.

- **If 첫 입력 전에 큐가 발화하면** (예: 자동 플레이가 입력 없이 시작 — 실제 자동 플레이는 터치를 주입하므로 해당 없음): 버린다. 몰아 재생하지 않는다.
- **If 깊이가 `chain_pitch_cap`(6)을 넘으면** (depth_cap 데이터를 올린 경우): 6의 피치를 유지한다. 음계가 끝없이 올라가 귀를 찌르지 않는다.
- **If 같은 프레임에 웨이브 타격 + 배너 + 능력 소리가 겹치면**: 모두 요청한다(서로 다른 id). 풀이 차면 규칙 9로 팝·틱부터 빼앗긴다.
- **If 풀 12개가 모두 우선순위 3(팡파르·차임)으로 차 있고 새 요청이 우선순위 ≤ 3이면**: 새 요청보다 높은 것만 남아 있지 않으므로 가장 오래된 3을 빼앗는다(같으면 빼앗기 허용). 현실적으로 우선순위 3은 한 번에 2개를 넘지 않는다.
- **If 소리 파일이 없거나 로드 실패하면**: 시작 시 `push_warning` 한 번, 그 id 요청은 무시. 게임은 계속(규칙 1).
- **If `species`가 매핑에 없으면**: 규칙 11 — `cell_pop` 대체.
- **If 빨리 감기 도중 피니셔 큐가 발화하면**: 우선순위 3이라 울린다(−6 dB). 건너뛰기(FLUSHING)로 끝나면 피니셔 큐 자체가 발화하지 않으므로 무음.
- **If 재시도("한 판 더")를 누르면**: `ui_tap`만. 재생 중이던 팡파르·차임은 끊지 않고 자연 감쇠(최대 1.6 s)에 맡긴다.
- **If 앱이 백그라운드로 가면**: `SUSPENDED` — 재생 중 소리 정지, 새 요청 버림. 복귀 시 소급 재생 없음.
- **If 볼륨 0이면**: 해당 버스 음소거(F4). 요청 처리·제한 계산은 같게 유지(상태 표).
- **If 점수가 한 번에 크게 뛰어 롤업이 길어지면**: F5 간격이 초당 20틱으로 묶고 피치는 7반음에서 멈춘다.
- **If 점수가 줄어들면(재시도로 0)**: 틱 없음(롤업은 증가에서만 틱).
- **If Android 출력 지연이 크면** (기기별 50–200 ms): MVP는 보정하지 않는다 — 큐 시각에 요청. 측정 후 보정 여부는 Q4.

## Dependencies

**Upstream (이 시스템이 의존)**

| 시스템 | 강도 | 쓰는 것 | 상태 |
|---|---|---|---|
| 연쇄 연출 재생기 (`chain-presentation.md`) | Hard | `cue_fired` 큐 종류·`level`·순서 index·`species`, 재생기 상태(`FAST`/`FLUSHING`), `sweep_cascade_s` | Designed — 이 문서가 그 Q5(빨리 감기 소리 정책)를 규칙 12–13으로 결정. 신호에 `species` 인자 추가 필요 (구현에서 추가) |
| 판 진행 흐름 (`round-flow.md`) | Hard | 결과 패널 표시, 재시도 | 미작성 — provisional (게임 화면이 호출) |
| 드래그 & 배치 입력 (`placement-input.md`) | Soft | 집기 수락, 놓기 실패·취소(판 위 여부) | Designed — 규칙 16 되돌아가기 / 흔들림과 같은 시점 |
| 점수 & 연쇄 배율 (`scoring.md`) / 플레이 HUD | Soft | 표시 점수 롤업 | scoring Designed, HUD 미작성 |
| 크루 정의 & 능력 (`crew-definition.md`) | Soft | `species` | Designed — 6종 (cat, bear, chick, sheep, frog, rabbit) |

**Downstream (이 시스템에 의존)**

| 시스템 | 강도 | 쓰는 것 |
|---|---|---|
| 설정 & 접근성 (`settings-accessibility.md`, VS) | Soft | 음량·음소거 API (`AudioSettings`), 저장 위치 이전 (Q2) |
| 튜토리얼 & 힌트 (VS) | Soft | 없음 (MVP) — 필요 시 `ui_tap` 재사용 |

**양방향성**: chain-presentation Dependencies는 오디오를 Hard downstream(`cue_fired`)으로 적었다 → 일치. systems-index의 Depends On("연쇄 연출 재생기, 판 진행 흐름")과 일치; 드래그 입력·점수·크루 정의는 Soft 데이터 의존이라 index에 넣지 않는다.

## Visual/Audio Requirements

> *Specialist note*: `audio-director` / `sound-designer` / `art-director` not consulted — this run has no Agent tool. Review manually before production.

**톤 (스티커북 · 기둥 5)**: 모든 소리는 짧고(대부분 ≤ 0.5 s, 팡파르 ≤ 1.6 s), 둥근 사인·삼각파 위주, 종이 질감은 짧은 노이즈 버스트.
금속성·날카로운 고음·저음 폭발·실패 버저 없음. "실패" 계열(`invalid_return`, `fizzle`)은 내려가는 귀여운 2음 — 웃음이지 경고가 아니다.

**대비 (기둥 1)**: 일반 줄 지우기 = 스윕 + 팝(우선순위 0–1, −6~−9 dB). 연쇄 = 그 위에 웨이브 타격(깊이마다 한 음 위) + 능력 소리 + 배너 "착",
깊은 연쇄는 팡파르. 연쇄 소리 총 에너지가 줄 지우기보다 확실히 크다.

**에셋 형식**: 22,050 Hz, 모노, 16-bit PCM WAV, 피크 −1 dBFS, 앞뒤 무음 ≤ 5 ms, 페이드아웃으로 끝(클릭 없음). 21개 합계 < 2 MB (목표 < 1 MB).
생성기 `tools/audio/gen_sfx.py`(Python 표준 라이브러리 `wave`·`math`·`random`만, 고정 시드)로 재현 가능 — 생성기와 결과 WAV를 함께 커밋한다.

| id | 합성 설계 (요약) | 길이 |
|---|---|---|
| ui_tap | 사인 1300→900 Hz 짧은 블립 + 클릭 | 0.06 s |
| pick_up | 사인 330→760 Hz 상승, 빠른 어택 | 0.10 s |
| place_thud | 사인 150→60 Hz + 저역 노이즈 툭 + 120 Hz 워블(찌그러짐) | 0.18 s |
| invalid_return | 삼각파 2음 620→460 Hz 하강 + 비브라토 | 0.24 s |
| line_sweep | 노이즈를 1차 필터 컷오프 상승으로 쓸기 + 종이 바스락 | 0.26 s |
| cell_pop | 사인 950→480 Hz 퐁 | 0.07 s |
| sticker_peel | 노이즈 상승 + 크래클 점 | 0.18 s |
| ab_cat_claw | 고역 노이즈 슬래시 2회 (0.07 s 간격) | 0.22 s |
| ab_bear_thump | 사인 95→42 Hz 쿵 + 노이즈 충격 + 낮은 "웅" 꼬리 | 0.50 s |
| ab_chick_pop | 처프 1500→2300 Hz "삐" + 퐁 | 0.20 s |
| ab_sheep_pop | 부드러운 어택 사인 420→640 Hz + 비브라토 + 퐁 | 0.30 s |
| ab_frog_splash | 노이즈 첨벙(빠른 감쇠) + 거품 블립 3개 | 0.40 s |
| ab_rabbit_hop | 상승 블립 2회 "뿅뿅" | 0.24 s |
| chain_hit | 삼각파 C5 + 5도 배음 + 노이즈 트랜지언트, 빠른 감쇠 (피치는 런타임 F1) | 0.24 s |
| banner_slam | 저역 툭 + 종이 찰싹 노이즈 | 0.20 s |
| fizzle | 사인 320→170 Hz 워블 하강 | 0.38 s |
| cap_fanfare | 사각·삼각 혼합 C-E-G-C' 아르페지오 | 0.75 s |
| finisher_fanfare | 화음 3연타(G-C'-E' 리듬) + 마지막 C 장화음 서스테인 | 1.50 s |
| confetti_burst | 노이즈 팡 + 무작위 크래클 바스락 | 0.60 s |
| score_tick | 사인 2000 Hz 틱 | 0.03 s |
| result_chime | 벨 배음(1, 2.76, 5.4) C6-E6-G6 순차 | 1.20 s |

## Game Feel

| 순간 | 소리 반응 목표 |
|---|---|
| 집기 | 터치 수락 프레임에 "뽁" — 손에 붙는 느낌 |
| 착지 | `PLACE` 큐 = 착지 시각에 "꾹" — 찌그러짐(연출 `land_squash`)과 같은 순간 |
| 연쇄 | 웨이브마다 히트스톱 시작에 "탕!", 한 음씩 상승 → 3단 이후 귀로 깊이를 셀 수 있음 |
| 대연쇄 | 팡파르 + 컨페티 — 화면 피니셔 카드와 같은 프레임 |
| 점수 | 롤업 동안 상승 틱 → 숫자가 "차오르는" 느낌 |

지연 목표: 이벤트 프레임 → 재생 요청 0 프레임(같은 프레임). 출력 지연은 플랫폼 몫(Q4).

## UI Requirements

이 시스템은 화면을 만들지 않는다. 음량·음소거 UI는 설정 & 접근성(VS) 몫이다. MVP는 `AudioSettings` API + 저장 파일 + `-- --mute` 인자만 둔다.

## Cross-References

| 참조 | 문서 | 관계 | 상태 |
|---|---|---|---|
| `cue_fired`, 큐 종류, `level`, 빨리 감기·건너뛰기 상태, 오디오 요구(착지 꾹·떼어짐 샥 웨이브당 1회·알 퐁·꾸벅 쿨·배너 착·상한 팡파르·피치 상승) | `design/gdd/chain-presentation.md` § Visual/Audio, Interactions, Q5 | 상위 계약 | 일치 — Q5를 규칙 12–13으로 결정 |
| `sweep_cascade_s` 줄 스윕 캐스케이드 (D16) | `design/gdd/chain-presentation.md` Decision Log D16 | 상위 값 | 같은 값을 읽음 (F2) |
| 깊이 상한 6 (`depth_cap`) | `design/gdd/chain-resolver.md` | 상위 상수 | `chain_pitch_cap` 6과 맞춤 |
| 되돌아가기·흔들림 시점 (규칙 16) | `design/gdd/placement-input.md` | 상위 계약 | 일치 |
| species 6종 | `design/gdd/crew-definition.md` | 상위 데이터 | 일치 |
| 기둥 1, 5 | `design/gdd/game-concept.md` | 기둥 | 일치 |

## Acceptance Criteria

> *Specialist note*: `qa-lead` not consulted — this run has no Agent tool. Review manually before production.

- **AC-A01** **GIVEN** 게임이 막 시작해 입력이 없을 때, **WHEN** 오디오에 재생 요청이 오면, **THEN** 아무 플레이어도 재생하지 않는다 (DISARMED). 첫 터치 이후 같은 요청은 재생된다.
- **AC-A02** **GIVEN** 기본 데이터, **WHEN** `chain_pitch(1..7)`를 계산하면, **THEN** 1.0, 1.122, 1.260, 1.414, 1.587, 1.782, 1.782 (±0.001).
- **AC-A03** **GIVEN** 웨이브 0에서 줄 3개가 지워질 때, **WHEN** `LINE_FLASH` 큐가 index 0/1/2로 발화하면, **THEN** `line_sweep` 요청의 피치가 1.0/1.122/1.260, 지연이 0/0.05/0.10 s다.
- **AC-A04** **GIVEN** 같은 시각에 `cell_pop` 요청 2회, **WHEN** 제한을 거치면, **THEN** 하나만 재생된다; `min_repeat_gap_s` 후 요청은 재생된다; 같은 소리 4번째 동시 요청은 버려진다.
- **AC-A05** **GIVEN** 풀이 우선순위 0 소리로 가득할 때, **WHEN** 우선순위 2 소리를 요청하면, **THEN** 가장 오래된 우선순위 0 발음을 빼앗아 재생한다. 풀이 우선순위 3으로 가득할 때 우선순위 0 요청은 버려진다.
- **AC-A06** **GIVEN** 재생기 `FAST`, **WHEN** 우선순위 0–1 큐(팝·스윕)와 우선순위 2 큐(웨이브 타격)가 오면, **THEN** 앞의 것은 버려지고 뒤의 것은 `gain_db − 6`으로 재생된다.
- **AC-A07** **GIVEN** `EFFECT` 큐 species ∈ {cat, bear, chick, sheep, frog, rabbit}, **WHEN** 매핑하면, **THEN** 각각 `ab_cat_claw`·`ab_bear_thump`·`ab_chick_pop`·`ab_sheep_pop`·`ab_frog_splash`·`ab_rabbit_hop`; 알 수 없는 종은 `cell_pop`.
- **AC-A08** **GIVEN** 한 웨이브의 `PEEL` 큐 여러 개, **WHEN** 매핑하면, **THEN** `sticker_peel`은 그 웨이브 첫 큐에서만 요청된다.
- **AC-A09** **GIVEN** `audio_tuning.tres`, **WHEN** 로드하면, **THEN** 21개 id가 모두 존재하는 WAV를 가리키고, 모든 WAV가 22,050 Hz 또는 44,100 Hz 모노이며 합계 < 2 MB다.
- **AC-A10** **GIVEN** sfx_volume 0.5, **WHEN** 설정을 적용하면, **THEN** SFX 버스 = −6.02 dB (±0.01); volume 0 → 그 버스 음소거; `muted` → Master 음소거.
- **AC-A11** **GIVEN** 점수 롤업 중, **WHEN** 표시 정수가 매 프레임 바뀌면, **THEN** 틱은 `tick_gap_s` 이상 간격으로만 울리고 n번째 틱 피치는 F5와 같다; 롤업 종료 후 n은 0.
- **AC-A12** **GIVEN** 실행 인자 `-- --autoplay`로 창 모드 실행, **WHEN** 연쇄·결과까지 진행하면, **THEN** 출력에 오디오 관련 에러·경고(로드 실패, 버스 없음)가 없다. (실제 청취 확인은 사람 몫 — 헤드리스·xvfb 환경에서는 들을 수 없음)
- **AC-A13** **GIVEN** 오디오 노드가 없는 상태(테스트처럼 `ChainPlayer`만), **WHEN** 연출을 재생하면, **THEN** 재생 결과(보드·점수·타이밍)가 오디오가 있을 때와 같다 (규칙 1).

## Open Questions

| # | 질문 | 담당 | 목표 |
|---|---|---|---|
| Q1 | BGM 1–2곡(systems-index 요약) — Music 버스만 만들어 둠. 곡 수·루프·연쇄 중 덕킹 여부 | audio-director | VS 전 |
| Q2 | 음량 설정 저장 위치: 지금은 `user://audio_settings.cfg`. 로컬 세이브/설정 GDD가 생기면 이전 | 설정 GDD | VS |
| Q3 | 오디오 구조(풀 노드를 GameScreen 자식으로 둘지, 오토로드로 둘지) ADR 필요 여부 — standard tier에서는 critical 아님, 현재는 DI로 GameScreen 자식 | technical-director | 구조 문서 작성 시 |
| Q4 | Android 출력 지연 측정·보정 (`AudioServer.get_output_latency()`로 큐를 앞당길지) | audio-director + QA (실기기) | 실기기 테스트 |
| Q5 | 합성음을 실제 녹음/디자인 소리로 바꿀지 (톤 검증은 사람이 듣고 판단해야 함) | sound-designer | 플레이테스트 후 |

### Decision Log (사용자 위임 "알아서 다" — 질문 없이 권장안 채택)

| # | 결정 | 채택 | 대안 |
|---|---|---|---|
| D1 | 섹션 구성 (standard tier, Audio category) | Summary·Overview·Detailed Design·Formulas(피치·게인·간격 수치 있음)·Edge Cases·Dependencies·AC + Audio 필수 Visual/Audio + Cross-References + Game Feel·UI Requirements·Open Questions ("All of them"). Player Fantasy·Tuning Knobs 생략 — 안전 범위는 Formulas 변수표 | Tuning Knobs 추가 — tier 규칙 위반 |
| D2 | Overview 프레이밍 | Both (재생 계층 + 플레이어가 듣는 것) — Audio 카테고리 권장안 | 기술만 |
| D3 | 피치 기준 | 웨이브 깊이(`SHAKE` index = wave)로 온음 상승, 상한 6 — 연출 `level`(상한 4)은 4에서 멈춰 깊은 연쇄가 같은 음이 됨 | `level` 사용 |
| D4 | 떼어짐 소리 | "샥"은 웨이브당 1회(연출 GDD 요구), 칸마다는 가벼운 `cell_pop`을 F3로 제한 | 칸마다 샥 — 연출 GDD와 충돌 |
| D5 | 빨리 감기·건너뛰기 (연출 Q5) | FAST = 우선순위 ≥ 2만, −6 dB; 건너뛰기 = 탭 소리만 | 전부 생략 / 묶음 재생 |
| D6 | 웹 정책 | 첫 입력 전 요청 버림 (DISARMED) | 큐에 쌓았다 재생 — 첫 탭에 소리 폭발 |
| D7 | 에셋 | 저장소 내 Python 표준 라이브러리 합성기, 22,050 Hz 모노 16-bit, 고정 시드 | 외부 무료 SFX — 라이선스·톤 불일치 |
| D8 | 버스 | Master ← SFX, Music (Music은 비움) | SFX/UI 분리 — MVP 과함 |
| D9 | 설정 저장 | `user://audio_settings.cfg` provisional + `-- --mute` | 저장 없음 — "설정 존중" 요구 미충족 |
| D10 | 알 큐 | `cell_pop` 순서 상승, 능력 소리는 `EFFECT`에서 1회 | 알마다 능력 소리 — 과밀 |
