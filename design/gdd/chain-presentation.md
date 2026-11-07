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
