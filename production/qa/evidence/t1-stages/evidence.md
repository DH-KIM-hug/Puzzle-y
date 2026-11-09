# T1 stage loop — run-and-observe evidence (2026-11-09)

Runs (Godot 4.7.2, Compatibility / llvmpipe, 720×1280 viewport, xvfb):
- `xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --windowed --resolution 720x1280 -- --autoplay --save=<corrupt file>` — main scenario, started from a deliberately corrupt save (fallback to a new save, bad file kept as `*.corrupt`). Result: `AUTOPLAY done fails=0`.
- `... -- --autoplay --scenario=obstacles --fresh-save --unlock-all --save=user://autoplay_progress.json` — obstacle scenario. Result: `AUTOPLAY done fails=0`.

The bot (`src/game/debug_autoplay.gd`) drives the real input path with synthetic touches and replays the committed
stage solutions (`tests/fixtures/stages/solutions.json`). Still frames cover layout / legibility / presence, not feel or timing.

| Shot | Shows |
|---|---|
| `01-stage-select-fresh.png` | Title sticker, 10 stage tiles; only 1-1 open (ink rim = next to play), 1-2…1-10 locked (padlock, dashed), "연습 (끝없이)" |
| `02-team-select-1-1.png` | Stage card (goal 점수 160, 조각 8, ★2 600/★3 750, best stars), fixed 1-crew pocket with padlock, reason line, roster with ability diagrams + shapes (자주/가끔), unowned crews as grey silhouettes, 궁합 노트 stub, "시작!" |
| `03-play-1-1-start.png` | Stage HUD: II pause, score, stage name, 남은 조각 chip, goal chip, star bar with ★2/★3 marks + bonus note |
| `04-play-1-1-preview.png` | Drag preview (+3 predicted score on 1-1) |
| `04-play-1-1-tray-held-during-chain.png` / `-refilled-after-chain.png` | Tray stays at the pre-commit state while the playback runs; refilled tray appears only after |
| `06-result-1-1-clear.png` | Clear card: 1★, 점수/보너스/최종, 새 기록!, "한 판 더" (largest), 다음 스테이지, 팀 바꾸기 (disabled: fixed team), 스테이지 선택 |
| `07-team-select-1-2.png`, `08-play-1-2-preview.png`, `09-result-1-2-clear.png` | Next-stage path; CHAIN goal chip "연쇄 1 · 0/2"; 2★ result |
| `10-retry-1-2.png` | "한 판 더": same team, attempt +1, fresh board |
| `11-pause.png` | Pause overlay: 계속 / 다시 하기 / 스테이지 선택 (paper veil, not dark) |
| `12-stage-select-progress.png` | 1-1 1★, 1-2 2★, 1-3 unlocked, 1-4+ locked |
| `13-practice.png` | Endless practice round (T0 HUD) |
| `20/21/22-*.png` | Unlocked select; 1-10 team select (3 pockets); pocket emptied → "빈 자리가 하나 있어요", start disabled |
| `23-play-1-10-start.png` | Stones (pebble, stipple, no shadow), 1-layer ice (one hatch direction), target-cell dashed rings, goal chips 남은 칸 / 남은 얼음 |
| `24-play-1-10-preview.png` | Preview: freed ice = crack + sparkle, badges, eggs, banner |
| `24-play-1-10-tray-*.png` | Empty tray held during the chain → refilled after |
| `26-result-1-10.png` | 1-10 cleared, both goals ✓ |
| `27/28-play-1-9-*.png` | Frozen faces visible under thin ice, 2-layer ice cross-hatch; preview thaw = crack + water drop |

Run result: OBSERVED — every screen renders inside 720×1280, Korean text legible, no overlap after the
team-select fix (reason line vs roster hint). `stamp.txt` holds hashes of the files these shots prove.
