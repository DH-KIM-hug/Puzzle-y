# 보드 & 조각 규칙 (Board & Piece Rules)

> **Status**: In Design
> **Author**: user (위임) + Claude (`/design-system`)
> **Last Updated**: 2026-11-07
> **Last Verified**: 2026-11-07
> **Implements Pillar**: 기둥 3 보이는 연쇄 (결정적 공유 규칙) · 기둥 1 도미노의 손맛 (연쇄의 바탕) · 기둥 4 한 판 더 (분명한 실패 판정)

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

보드 & 조각 규칙은 말랑 크루의 퍼즐 판 그 자체를 정의한다. 데이터 층에서는 8×8 칸 격자의 칸 상태,
조각 모양 데이터(회전 없음), 조각마다 정확히 한 칸인 얼굴 칸, 그리고 이 상태를 읽는 순수 판정 함수들 —
배치 가능 판정, 가로·세로 줄 완성 판정, 칸 비우기·채우기 원시 연산, "놓을 곳 없음" 판정 — 을 소유한다.
플레이어 쪽에서 보면 이 시스템은 "어디에 붙일 수 있고, 무엇이 줄을 채우며, 언제 판이 막혔는가"라는
판의 물리 법칙이다. 플레이어는 이 규칙을 직접 조작하지 않지만 매 배치마다 그 결과를 읽고 계획한다.
연쇄 해석기, 연쇄 미리보기, 트레이 공급, 입력, 방해물, 스테이지가 모두 **같은 함수**를 호출하므로
(기둥 3 보이는 연쇄 — "미리보기와 실제 결과가 다르면 버그"), 이 시스템이 결정적이지 않거나 두 벌로
구현되면 미리보기가 거짓말을 하게 된다. 연쇄 순서, 점수, 트레이 뽑기, 드래그 입력은 이 시스템의 경계
밖이다 — 이 문서는 그 시스템들이 부를 규칙과 원시 연산만 정한다.

*프레이밍 결정 (guided, 권장안)*: Framing `[C] Both` (Category `Gameplay` → player-facing; Layer
`Foundation`과 충돌 시 Category 우선) · ADR ref `[B] No` (`docs/architecture/adr-*.md` 없음) ·
Fantasy `[B] No` (Foundation layer; standard tier라 Player Fantasy 섹션 자체도 생략).
구현 방식(순수 함수 모듈의 형태, 보드 복제 방식)은 → ADR 대상 (연쇄 해석기 critical ADR과 함께).

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
