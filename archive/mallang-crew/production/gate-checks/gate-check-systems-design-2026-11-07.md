## Gate Check: Concept → Systems Design

**Date**: 2026-11-07
**Checked by**: gate-check skill (run by a subagent; user delegated all decisions — "진행부탁 알아서 다")
**Config**: workflow standard · review_mode lean · qa.level standard · team.size individual (all from `modes.rigor: standard`)

### Decisions taken on the user's behalf
- Gate target: no argument given; auto-detected stage `Concept` (project.yaml + production/stage.txt) → ran Concept → Systems Design. Confirmation question skipped per delegation.
- `artifact-check.sh --phase concept` lists `art-bible` and `map-systems` as required Concept-phase steps (ABSENT). The gate file (`references/gate-systems-design.md`) is the authority for this gate's required/optional split and does not list them; Section 7 names `/map-systems` as the step *after* this gate. Recorded as recommendations, not blockers.

### Required Artifacts: 1/1 present (standard tier)
- [x] `design/gdd/game-concept.md` — exists, 24.8 KB, real content in every concept-template section
- [x] Game pillars (recommended at `standard`) — 5 pillars with design tests + 6 anti-pillars
- [x] Visual Identity Anchor (recommended at `standard`) — present
- [x] Concept prototype with PROCEED (recommended) — `prototypes/sticker-place-concept/REPORT.md`: PROCEED (match-3 PIVOT recorded in `prototypes/index.md`)

### Quality Checks: 4/4 passing
- [x] Concept reviewed, verdict not MAJOR REVISION NEEDED — `/design-review` 2026-11-07: NEEDS REVISION, 5/5 blocking items fixed in-session
- [x] Core loop described — 30 s / 5-15 min / session / long-term / retention hooks
- [x] Target audience identified — Core Identity + Target Player Profile
- [x] Visual Identity Anchor has one-line rule ("모든 것은 손으로 오려 붙인 스티커다.") + 3 supporting principles

### Director Panel Assessment
Panel expected at `workflow: standard`: `technical-director` (TD-PHASE-GATE) + `producer` (PR-PHASE-GATE).

Technical Director: NOT ASSESSED — not spawned: this run had no `Agent` tool available, so the director could not be invoked.
Producer:           NOT ASSESSED — not spawned, same reason.

Panel: 0 of 2 expected returned (2 of 4 by design at `workflow: standard`). Creative and Art perspectives are not on the `standard` panel; set `modes.rigor: full` (or `modes.workflow: full`) for all four.

### Blockers
1. **Director panel NOT ASSESSED** — TD-PHASE-GATE and PR-PHASE-GATE did not run (no Agent tool in the executing session). Re-run `/gate-check systems-design` from a session that can spawn subagents. While this stays NOT ASSESSED, the CONCERNS override is not offered (Section 6).

### Concerns
1. **Concept re-review pending** — the doc says `Status: In Review`; the review log's fixes are unreviewed and the concept's content hash (`dfc0fc8…`) no longer matches the reviewed hash (`030e9c3…`). Recommended: `/design-review design/gdd/game-concept.md` re-run.
2. **CD-PILLARS / TD-FEASIBILITY results are stale** — both were taken on the match-3 version (Director Gate Results table). New Pillar 3 "보이는 연쇄" and the shared deterministic chain resolver were never director-reviewed. At `review_mode: lean` those per-skill gates do not re-run; the TD-PHASE-GATE above is where the feasibility question gets looked at again.
3. **Open design risk carried forward** — preview could reduce the puzzle to "find the biggest number" (review log, NOT FIXED); address in the stage-goal / chain-resolver GDDs.

### Recommendations
- `/art-bible` before `/map-systems` (catalog lists it as a Concept step; none exists).
- `/map-systems` — no `design/gdd/systems-index.md` yet.
- Economy numbers (pity, rates, currency income) → economy GDD + `/balance-check`.

### Verdict: CONCERNS (with a NOT ASSESSED director panel) — stage NOT advanced
Precedence: FAIL → CONCERNS → NOT ASSESSED → PASS. No artifact or quality blocker; concerns present; director panel unassessed, so the stage write is not offered until the panel runs.

Chain-of-Verification: 5 questions checked — verdict unchanged
1. Could a concern be a blocker? Re-review pending: gate criterion is "not MAJOR REVISION NEEDED"; [TOOL ACTION] grep of the review log finds no MAJOR REVISION — stays a concern.
2. Resolvable in next phase? Yes — re-review and director panel are single runs.
3. Softened a FAIL? Art bible / systems index ABSENT are not in this gate's checklist — not softened.
4. Unchecked artifacts? [TOOL ACTION] re-ran artifact-check / `ls production/gate-checks` and concept hash vs review-log hash — found the hash mismatch, added to Concern 1.
5. Do concerns combine into a blocker? No; the real block is the unrun panel, already listed.

---

## Director Panel — re-run from the parent session (2026-11-07)

The subagent run above could not spawn directors; the parent session ran the panel.

- **Technical Director (TD-PHASE-GATE): READY** — 2D turn-based, no reliance on 4.5–4.7 features; pivot removed the real-time cascade risk. Conditions carried to design: resolver is a pure function (board + placement → event list), presentation only replays events; any randomness in abilities uses an injected seeded RNG; depth cap 6 is data with defined at-cap behaviour; preview recomputed only when the anchor cell changes (est. <1 ms, not measured on device); crew as Custom Resources composed from ability primitives. Supersedes the match-3 TD-FEASIBILITY result.
- **Producer (PR-PHASE-GATE): CONCERNS** — scope tiers self-contained and consistent with PR-SCOPE. Concerns: gacha does not test the MVP hypothesis and carries schedule risk; no velocity data (use T0 as velocity milestone and re-estimate T1); art scope (MVP item 6) unsized until `/art-bible`; stale reviews; recommended order map-systems → resolver/board → crew abilities → stages → (gacha/economy).

### Decisions (user delegated: "진행부탁 알아서 다")
- Gacha stays in MVP (user's explicit request) but is **last in build order**; economy numbers via economy GDD + `/balance-check`.
- T0 is the velocity milestone; re-estimate T1 after it.
- `/art-bible` next, then `/map-systems` with the chain resolver as the Foundation system and first critical ADR.

### Final Verdict: CONCERNS — advanced to Systems Design (no blockers; panel 2/2 returned)
