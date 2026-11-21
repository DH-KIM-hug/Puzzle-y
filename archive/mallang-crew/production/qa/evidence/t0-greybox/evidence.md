# T0 greybox — run-and-observe evidence (2026-11-08)

Run: `xvfb-run -a -s "-screen 0 800x1400x24" godot --path . --windowed --resolution 720x1280 -- --autoplay`
(Godot 4.7.2, Compatibility / llvmpipe, 720×1280 viewport; `--seed=1201` default). The autoplay
bot (`src/game/debug_autoplay.gd`) drives the real input path with synthetic touches.
Run result: PASS — 20 placements, score 731, best +303, result panel reached, "한 판 더" restarted (attempt 2, score 0).

| Shot | Shows |
|---|---|
| `t0-01-start.png` | Empty 8×8 board, HUD "점수 0 / 1번째 판", tray of 3 (삐약, 곰곰, 냥이) with faces, white cut-out, ground shadow |
| `t0-02-drag-preview.png` | Drag at anchor (0,3): ink dashed outlines on cells that will clear, stage badges 1/1/1/1/2 on faces, predicted eggs (small, bottom-left where an egg refills a cleared cell), banner "연쇄 2 예상!", no score; tray slot left as an empty sticker spot |
| `t0-03-chain-midplay.png` | Same placement replaying: wave 1 cut-in "연쇄 2! / 냥이" in the banner band, 냥이 face lifted (activated expression), wave popup "+60 ×1.5", scratch line, eggs laid in row 0–2 |
| `t0-04-result.png` | No moves → result card: "더 놓을 자리가 없어요", 이번 판 점수 731, 최고 한 수 +303, 놓은 조각 20개, ink "한 판 더" button |
| `t0-05-retry.png` | After one tap on "한 판 더": empty board, score 0, "2번째 판", a new tray order (PER_ATTEMPT seed) |

`stamp.txt` holds the content hashes of the files these shots prove.
