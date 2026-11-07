# Review Log: game-concept.md

## Review — 2026-11-07 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L (컨셉 문서 — 5개 핵심 시스템, 공유 결정적 해석기 ADR 필요; producer가 스프린트 계획 전 확인)
Specialists: none (lean)
Blocking items: 5 | Recommended: 5
Summary: 피벗된 컨셉은 기둥·훅·MVP·프로토타입 근거가 일관되고 컨셉 템플릿 전 섹션을 갖췄다. 다만 '조각'이 퍼즐 조각과 가챠 중복 보상을 동시에 가리키는 용어 충돌, 실패 조건 이중 정의 누락, 삐약 능력 규칙 모호, 튜토리얼 '얼굴 없는 조각'과 '조각마다 얼굴 1칸' 모순, 동시 얼굴 발동 순서 미정의가 있었다. 5건 모두 같은 세션에서 문서에 반영(자율 진행 지시) — 재검토 필요.
Prior verdict resolved: First review
Decisions (user delegated "알아서 다"; no questions asked):
- 구조 판정: 이 문서는 시스템 GDD가 아니라 컨셉 문서. gdd-structure-check.sh가 8개 GDD 섹션을 모두 ABSENT로 보고하지만, `.claude/docs/templates/game-concept.md` 템플릿 기준으로 평가함(전 섹션 존재). 대안: GDD 기준 적용 → NOT ASSESSED/전면 블록 — 컨셉 문서에 부적절하여 기각.
- 다음 단계: [A] 지금 수정 선택 (대안 [B] 별도 세션 수정). systems-index.md는 아직 없음 → 상태 갱신 생략.
- 샤드 명칭: '샤드(shard)' 채택 (대안: 퍼즐 조각을 '블록'으로 개명 — 편집 범위가 커서 기각).
Findings:
- [BLOCKING] Core Mechanics/Monetization/Anti-Pillars/MVP: '조각' 용어 충돌(퍼즐 조각 vs 중복 보상) → 중복 보상을 '샤드'로 통일 [FIXED]
- [BLOCKING] Core Mechanics 1/5: 실패 조건이 '놓을 곳 없음'만 명시, 제한 조각 수 소진 미정의; 트레이 리필 규칙 없음 → 둘 다 명시, 회전 없음 명시 [FIXED]
- [BLOCKING] Core Mechanics 2: 삐약 "자기 줄" 모호 → 프로토타입 규칙(가로·세로 중 더 꽉 찬 쪽, 가까운 빈칸 순, 알이 줄 완성 가능) 명시 [FIXED]
- [BLOCKING] Core Mechanics 2 vs Flow 1-1: '조각마다 얼굴 1칸' vs 얼굴 없는 튜토리얼 조각 → 스테이지 데이터 예외 명시 [FIXED]
- [BLOCKING] Core Mechanics 3: 동시 얼굴 발동 순서 미정의(결정성·미리보기 일치에 필수) → 결정적이어야 함 명시, 규칙은 연쇄 해석기 GDD로 위임 [FIXED]
- [RECOMMENDED] MVP Definition: 핵심 가설에 측정 가능한 검증 기준 없음 → 제안값 4개 추가 [FIXED]
- [RECOMMENDED] Core Mechanics 3: 프로토타입 튜닝 값(깊이 6, 단계당 +50%) 미이관 → 시작값으로 기록 [FIXED]
- [RECOMMENDED] Director Gate Results: CD-PILLARS·TD-FEASIBILITY가 매치-3 안 기준 — 피벗 후 기둥(특히 신규 기둥 3) 재게이트 필요 → `/gate-check`에서 [NOT FIXED]
- [RECOMMENDED] Monetization: 천장 횟수·등급 확률·재화 획득량 미정 → 경제 GDD + `/balance-check` [NOT FIXED — 컨셉 범위 밖]
- [RECOMMENDED] Design Risks: 미리보기가 퍼즐을 "최고 숫자 찾기"로 만들 위험 — 핵심 위험인데 완화책이 플레이테스트뿐 → 스테이지 목표 설계에서 대응 [NOT FIXED]
Reviewed-Content-Hash: design/gdd/game-concept.md 030e9c3cd1dc40f67f06f60b6557624602388e61
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: prototypes/index.md e220a8fecfaaaaa5d1394f76f20f1456ee6583c7
Reviewed-Content-Hash: prototypes/sticker-place-concept/REPORT.md 91031a244ca650e2c30cf4da7920e333322cca50
