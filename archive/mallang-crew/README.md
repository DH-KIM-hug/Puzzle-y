# 말랑 크루 (Mallang Crew) — 보관본

2026-11-21에 새 게임 제작을 위해 보관한 프로젝트입니다. 이 폴더는 **그 자체로 완결된 Godot 4.7 프로젝트**입니다.
보관 직전 커밋: `ba5322d` (playable stage game).

## 무엇이었나
스티커 모양 조각을 8×8 판에 붙여 줄을 지우는 블록 퍼즐. 조각마다 크루 얼굴이 있고, 얼굴이 지워지면 능력이 터져
다른 얼굴을 건드리는 도미노 연쇄가 핵심(연쇄 미리보기 포함). 10개 스테이지, 팀 편성, 방해물(돌·얼음), 합성 효과음, 로컬 세이브까지 구현.

- 컨셉: `design/gdd/game-concept.md` · 시스템 목록: `design/gdd/systems-index.md` · 아트 바이블: `design/art/art-bible.md`
- 설계 결정: `docs/architecture/adr-0001-pure-deterministic-rules-core.md`
- 프로토타입 기록: `prototypes/index.md` (매치-3 PIVOT → 스티커 배치 PROCEED)
- QA 스크린샷: `production/qa/evidence/`
- 웹 빌드(비공개 링크): https://claude.ai/artifact/5dCQR4GqjeJkWKZpyzM7tX

## 실행 / 테스트
```bash
cd archive/mallang-crew
godot --headless --path . --import
godot --path . --windowed --resolution 720x1280          # 플레이
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode   # 303 tests
```
`archive/.gdignore` 때문에 저장소 루트의 새 Godot 프로젝트는 이 폴더를 읽지 않습니다.

## 남아 있던 일 (재개 시)
별 기준 튜닝, 1-3 재설계, 메타(보유 크루·재화·가챠·정식 세이브), 메뉴 효과음, 실기기 성능 측정.
CI 워크플로는 `.github/workflows/tests.yml`에 보관됨(GitHub는 루트의 .github만 실행).
