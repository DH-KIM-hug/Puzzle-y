# T0 polish pass ("좀더 화려하게" / "더 극적으로") — run-and-observe evidence (2026-11-08)

Run: `xvfb-run -a -s "-screen 0 800x1400x24" godot --path . --windowed --resolution 720x1280 -- --autoplay --seed=1201 --min-depth=3 --burst --shots=res://production/qa/evidence/t0-polish`
(Godot 4.7.2, Compatibility / llvmpipe, 720×1280). `--min-depth=3` makes the bot hunt a deeper chain; `--burst` saves a frame
series through that chain (curated below). Reduced-motion run: same command + `--reduced-motion`.
Run result: PASS — 44 placements, score 3160, best +1201, a depth-5 chain at placement 34 (finisher fired), result panel reached,
"한 판 더" restarted (attempt 2, score 0). No script errors. gdUnit4: 196/196 pass (exit 0).

| Shot | Shows |
|---|---|
| `t0-01-start.png` | Idle: empty board, tray pieces (placeable → bobbing), background sparkle dust |
| `t0-02-drag-preview.png` | Preview unchanged: badges 1–5, "연쇄 5 예상!" |
| `t0-03a-lines-bearhug.png` | Wave 0/1: "2줄 동시!" label, bear-hug shockwave rings, faces peeling with tilt, paper confetti |
| `t0-03b-chain2-shockwave.png` | "연쇄 2!" banner slam with rays, popup "+180 ×1.5", camera punch toward the bear face, rings |
| `t0-03c-chain3-deep.png` | "연쇄 3!!" gold-bordered banner, background veil + gold board glow (deep chain), ×2 flying to score |
| `t0-03d-chain4-claw-holo.png` | "연쇄 4!!!" holo letters (UI only), cat claw slashes along the cross, egg pops |
| `t0-03e-finisher-slam.png` | "대연쇄!! / 연쇄 5!" finisher card slam with radial rays, "연쇄 5!!!" banner |
| `t0-03f-finisher-cannons.png` | Finisher settling, edge confetti cannons, score rolled up |
| `t0-04-result.png` | Result card over a warm kraft veil (no ink dim — failure never dark) |
| `t0-05-retry.png` | After "한 판 더": empty board, attempt 2 |
| `t0-06-reduced-motion-finisher.png` | `--reduced-motion`: no zoom/shake/flash/rotation; banner, finisher, popups still shown |

Not verified: real-device web/mobile frame rate (llvmpipe only); audio (hooks only via `ChainPlayer.cue_fired`).
`stamp.txt` holds the content hashes of the files these shots prove.
