# 트레이 공급 (Tray Supply)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Implements Pillar**: 기둥 2 크루가 곧 전략 · 기둥 3 보이는 연쇄 · 기둥 4 한 판 더

## Summary

[To be designed]

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `[To be designed]`

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

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

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
