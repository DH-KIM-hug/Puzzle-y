<!-- PROTOTYPE - NOT FOR PRODUCTION
Question: Do players plan placements with a preview to trigger multi-step chains (cluster -> action -> track threshold -> bonus -> other track), and does the chain moment on a growing sprite-stacked island make them replay? Riskiest assumption: the chain feels like a payoff, not bookkeeping.
Date: 2026-11-21
-->
# 작은 섬 (Tiny Isle) — Hex Isle Concept Prototype

**Status:** in-progress (built and machine-verified; no human playtest yet)
**Concept:** `design/gdd/game-concept.md` (Pillar 1 One-Tile Cascade, Pillar 4 Readable Moves)

## Hypothesis
If players see the outcome before they place (a highlighted cluster, `+N 곡식` labels, predicted
track bars, the bonus chain in order, a `연쇄 N` badge), they will plan placements to set off
multi-step chains (cluster → action → track threshold → bonus → next track). The chain moment
on a growing sprite-stacked island will make them replay.
**Riskiest assumption:** the chain feels like a payoff, not bookkeeping.

## How to run
Open `prototype.html` in any modern browser (desktop or phone). It needs no build or server.
Fonts load from Google Fonts and fall back to system fonts when offline.
`?seed=123` picks the island. Controls: drag a hand tile onto the island, or click/tap a tile
and then the board (on touch, tap the same hex twice). To rotate the piece use R, the mouse
wheel, a right-click or the ↻ button. To turn the camera use Q/E, the ⟲⟳ buttons,
right-drag/left-drag, or a two-finger twist.

## Rules (hard-coded, original)
- The island has radius 4 (61 hexes) with 8 sea hexes on the rim and 3 mountains. Both are fixed by the seed.
- Pieces are 2 hexes drawn from a seeded bag of 30 (every type pair ×2). You hold 3 and draw 1 after each placement.
- Each half earns N of its resource, where N is the size of its same-type cluster after placing:
  밭→곡식, 숲→목재, 목장→양모, 물→물고기, 집→주민.
- Every multiple of 5 a track crosses queues a bonus. The bonuses form a ring:
  곡식→주민+2 (풍년), 주민→목재+3 (일손), 목재→양모+2 (울타리), 양모→물고기+3 (교역), 물고기→곡식+2 (거름).
  Bonuses resolve breadth-first, with depth capped at 8. "연쇄 N" is the deepest bonus level reached.
- There are 4 seasons × 6 placements. At each season end the island eats ceil(주민/2) 곡식, and every missing grain costs −2 points.
- Score = sum of the tracks − penalties. In "균형 섬" mode, score = lowest track × 5 − penalties.
- If no two adjacent empty land hexes are left, the turn is skipped automatically and still counts toward the season.
- Feeding can push 곡식 back below a multiple of 5, so crossing it again re-triggers 풍년 (this is intentional cycling).

## Implementation notes
- `simulate()` is pure and runs on copies. Both the preview and the real placement use it; `commit()` applies its result.
- The board is drawn with sprite stacking on Canvas2D: every slab and object is drawn as stacked slices, with yaw rotation and a 0.55 pitch squash.
  Draw order is two-pass: slabs sorted by rotated depth, then objects sorted by rotated depth. This is correct for a flat board.
- Ambient life: wheat sways, trees sway and rustle, sheep wander their pasture and hop, villagers walk between houses
  (more of them as 주민 grows), chimney smoke and lit windows, fish jump, ripples, shore foam, a drifting boat,
  clouds with shadows, birds, season tint and winter snow. `prefers-reduced-motion` damps all of it.
- The title screen shows a pre-decorated sample island. "새 섬 개척하기" starts the empty playable island with the same seed.
- Test hooks are on `window.__isle`: `state`, `placeAt`, `simulate`, `setHand`, `setBoard`, `setTracks`, `validMoves`,
  `hover`, `screenOf`, `setYaw`, `flush`, `perf`, `freeze`.

## Findings (automated verification, 2026-11-21; no human playtest)
- Preview equals the real result on 68 placements across 3 full games. This was cross-checked against an
  independent reference implementation in the test. A real mouse drag and a hover+click placement also matched their previews.
- A scripted depth-7 chain resolved exactly as previewed (10 steps).
- Chain frequency: **random play reaches 연쇄≥2 on 25% of placements** (≥1: 55%, ≥3: 12%, n=882).
  **Greedy play reaches 59%** (≥3: 31%), and chain-seeking play reaches 65%. Average score is 101 for random and 244 for greedy.
  Planning pays off a lot. But chains are frequent enough that they risk feeling routine:
  watch whether 연쇄 1–2 still reads as a payoff, and consider rarer or bigger thresholds.
- Frame time with the island full (50 tiles, 25 agents): JS draw averages ~3.3 ms, p95 5.5 ms. This was measured in headless
  Chromium with a software 2D canvas. Under SwiftShader GPU canvas, raster is very slow (screenshots took 10–30 s),
  so the tests use `--disable-accelerated-2d-canvas`. Test on a real phone before trusting mobile performance.
- Still open (needs humans): does the chain feel like a payoff or like bookkeeping? Do players replay the same seed?
