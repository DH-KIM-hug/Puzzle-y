# Session Checkpoint

- **Concept**: 말랑 크루 (Mallang Crew) — 스티커 배치 + 크루 얼굴 능력 도미노 (design/gdd/game-concept.md, revised 2026-11-07)
- **Stage**: Concept · rigor standard · automation guided · review lean
- **Engine**: Godot 4.7 / GDScript, 2D mobile portrait (project.godot scaffolded, no scenes yet)
- **Prototypes** (prototypes/index.md):
  - match3-blitz-concept — PIVOT ("다른 게임과 변별력이 없다")
  - sticker-place-concept — PROCEED ("괜찮은데?"; 얼굴=스위치는 강조+연쇄 미리보기가 있어야 읽힘)
- **Decisions this session**: 유료 재화 포함 가챠(천장·조각 교환·확률 공개, IAP는 T2), MVP 2~3개월 = MVP+재미 검증, 새 기둥 "보이는 연쇄", 안티 기둥 "시간 압박 없음"
- **Current phase**: concept revised after prototype PROCEED
- **Next**: /design-review design/gdd/game-concept.md → /gate-check → /art-bible → /map-systems

## 2026-11-07 — /gate-check systems-design (subagent)
- Verdict: CONCERNS + director panel NOT ASSESSED (no Agent tool in the running session) → stage stays Concept.
- Report: production/gate-checks/gate-check-systems-design-2026-11-07.md
- Next: re-run /gate-check systems-design from a session that can spawn TD + PR; optionally /design-review game-concept re-run first.

## 2026-11-07 — /map-systems (subagent, user delegated "진행부탁 알아서 다")
- Task: Systems decomposition · Status: Systems index created (Draft)
- File: design/gdd/systems-index.md — 31 systems (MVP 22 · VS 2 · Alpha 3 · Full Vision 2 + inferred)
- Gates TD-SYSTEM-BOUNDARY / PR-SCOPE / CD-SYSTEMS skipped (review_mode lean)
- Next: /design-system board-rules → /design-system chain-resolver (+ /architecture-decision deterministic chain resolver)

## 2026-11-07 — /design-system board-rules (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing board-rules GDD
- Current section: Starting (skeleton created)
- File: design/gdd/board-rules.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules / States and Transitions / Interactions), Formulas, Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria, Open Questions (+ Decision Log). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: +3 constants (board_width, board_height, max_piece_cells), +1 formula (line_cell_count); validate clean
- Systems index: row 1 → Designed; progress 1/22
- Skipped gates/specialists (lean / no Agent tool): systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), game-designer+systems-designer (C, lean), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/board-rules.md (fresh session) → /design-system chain-resolver

## 2026-11-07 — /design-system chain-resolver (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing chain-resolver GDD
- Current section: Starting (skeleton created)
- File: design/gdd/chain-resolver.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–I incl. 프리미티브 어휘·이벤트 스키마·훅·시드 RNG 계약 / States and Transitions / Interactions), Formulas (F1–F8), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-01–22), Open Questions (+ Decision Log D1–D12). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: +1 constant (depth_cap=6), +1 formula (chain_depth); referenced_by updated (board_width, board_height, line_cell_count); validate clean
- Systems index: row 2 → Designed; 판 진행 흐름 Depends On += 보드 & 조각 규칙 (board-rules Q6); progress 2/22
- Skipped gates/specialists (lean / no Agent tool): game-designer+systems-designer (C), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/chain-resolver.md (fresh session) → /architecture-decision (deterministic chain resolver, first critical ADR) → /design-system scoring

## 2026-11-07 — /design-system scoring (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing scoring GDD
- Current section: all done
- File: design/gdd/scoring.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–C / States and Transitions / Interactions), Formulas (F1–F6), Edge Cases, Dependencies, Tuning Knobs (user-requested beyond standard tier), Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-S01–S15), Open Questions (+ Decision Log D1–D10). Player Fantasy omitted by standard tier.
- Registry: +2 formulas (depth_mult_pct, placement_total), +2 constants (depth_step_pct=50, cell_points=10); referenced_by += scoring for line_cell_count, max_piece_cells, depth_cap; validate clean
- Systems index: row 4 → Designed; progress 3/22 (concurrent agents may also have bumped it)
- Skipped gates/specialists (lean / no Agent tool): systems-designer (D, E, G), qa-lead (H), art-director (Visual/Audio), game-designer+systems-designer (C, lean), CD-GDD-ALIGN (lean). Engine ref: no modules/scripting.md — feasibility not checked against pinned engine.
- Next: /design-review design/gdd/scoring.md (fresh session) → /consistency-check → /design-system crew-definition

## 2026-11-07 — /design-system placement-input (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing placement-input GDD (system #7 드래그 & 배치 입력)
- Current section: Starting (skeleton created)
- File: design/gdd/placement-input.md

## 2026-11-07 — /design-system crew-definition (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing crew-definition GDD
- Current section: Starting (skeleton created)
- File: design/gdd/crew-definition.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–F / States and Transitions / Interactions), Formulas (F1–F7), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-01–18), Open Questions (+ Decision Log D1–D12). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: +1 constant (lift_offset_cells=0.6); referenced_by updated (board_width, board_height, max_piece_cells); validate clean
- Systems index: row 7 → Designed; MVP 4/22; Next Steps entry added ("Design docs started" count left untouched — concurrent editors)
- Skipped gates/specialists (lean / no Agent tool): game-designer+ux-designer+gameplay-programmer (C, lean), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/placement-input.md (fresh session) → /design-system chain-preview

## 2026-11-07 — /design-system chain-preview (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing chain-preview GDD
- Current section: Starting (skeleton created)
- File: design/gdd/chain-preview.md

## 2026-11-07 — /design-system chain-presentation (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing chain-presentation GDD (system #19 연쇄 연출 재생기)
- Current section: all done
- File: design/gdd/chain-presentation.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Registry: +1 formula (chain_playback_time), +1 constant (chain_playback_budget_s=4.0); referenced_by += chain-presentation for depth_cap, depth_mult_pct; validate clean
- Systems index: row 19 → Designed; MVP designed 7/22
- Skipped gates/specialists (lean / no Agent tool): game-designer+art-director+technical-artist+systems-designer (C, lean), systems-designer (D, E), qa-lead (H), art-director+technical-artist (Visual/Audio), CD-GDD-ALIGN (lean). Engine ref: modules/animation.md + rendering.md read; Android reduced-motion API = knowledge gap (Q4)
- Next: /design-review design/gdd/chain-presentation.md (fresh session) → /consistency-check → /design-system round-flow
- Sections done: Overview, Detailed Design, Formulas, Edge Cases, Dependencies, Visual/Audio, Game Feel, UI Requirements, Cross-References, Acceptance Criteria, Open Questions (+ Decision Log D1–D12), Summary
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–G: CrewDef 스키마·모양 카탈로그 25·능력·등급·레지스트리 검증·MVP 6명·궁합표 / States and Transitions / Interactions), Formulas (F1–F6), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-01–20), Open Questions (+ Decision Log D1–D14). Player Fantasy & Tuning Knobs omitted by standard tier.
- MVP crew: nyangi 냥이 clear_cross · gomgom 곰곰 clear_area r1 · piyak 삐약 lay_eggs_in_own_line · gaegul 개굴 clear_diagonals (RARE) · kkangchong 깡총 clear_pattern 2-hop ring (SPECIAL) · mongsil 몽실 lay_eggs_pattern plus (RARE)
- Registry: +6 entities (crew), +1 formula (expected_piece_cells); referenced_by max_piece_cells; validate clean
- Systems index: row 5 → Designed; MVP designed count +1
- Skipped gates/specialists (lean / no Agent tool): game-designer+art-director+narrative-director+systems-designer (C, lean), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/crew-definition.md (fresh session) → /design-system tray-supply

## 2026-11-07 — /design-system tray-supply (subagent, user delegated "진행부탁 알아서 다")
- Task: Designing tray-supply GDD
- Current section: Starting (skeleton created)
- File: design/gdd/tray-supply.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules / States and Transitions / Interactions), Formulas (F1–F6), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-P01–P21), Open Questions (+ Decision Log D1–D10). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: no new entries; chain-preview.md added to referenced_by of chain_depth, depth_cap, board_width, board_height, placement_total; validate clean
- Skipped (no Agent tool / lean): systems-designer (D, E), qa-lead (H), art-director (V/A), game-designer/systems-designer (C), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/chain-preview.md (fresh session); /consistency-check (Q1 badge number vs chain-resolver rule 9)
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–F / States and Transitions / Interactions), Formulas (F1–F7), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-01–23), Open Questions (+ Decision Log D1–D13). Player Fantasy & Tuning Knobs omitted by standard tier.
- Algorithm: crew bag (k=1 → every tray = one piece per team crew) + per-crew weighted shape bag + uniform face cell; per-draw seeds hash32(stage_seed, STREAM_TRAY_*, index); tray_seed_mode FIXED default; minimal rescue (all 3 unfit → replace 1 slot with a fitting team shape, before display, not on scripts); tray_script overrides.
- Registry: +1 constant (tray_size), +1 formula (crew_share); referenced_by updated (expected_piece_cells, max_piece_cells); validate clean
- Systems index: row 6 → Designed; MVP designed 8/22
- Skipped (lean / no Agent tool): game-designer+systems-designer (C, lean), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN (lean)
- Next: /design-review design/gdd/tray-supply.md (fresh session); /consistency-check; stage-goals GDD should add tray fields

## 2026-11-08 — T0 greybox playable scene (subagent, user delegated: no questions, log choices; no commit)
- Built: main scene `res://src/game/main.tscn` (run/main_scene set), `src/game/{game_screen,debug_autoplay}.gd`,
  `src/gameplay/round/round_flow.gd`, `src/gameplay/input/{drag_controller,placement_input_tuning}.gd`,
  `src/presentation/{board_layout,chain_player,chain_timeline,crew_visuals,draw_layer,palette,presentation_tuning,preview_view,sticker_painter}.gd`,
  data `assets/data/presentation/{placement_input,presentation_tuning}.tres`, strings `assets/locale/strings.csv` (ko).
- Tests: +18 (tests/unit/gameplay/drag_controller_test.gd 9, tests/unit/presentation/chain_timeline_test.gd 4, tests/integration/round_flow/round_flow_test.gd 5) → 196/196, exit 0.
- Evidence: production/qa/evidence/t0-greybox/ (t0-01..05 png, evidence.md, stamp.txt). Run: `xvfb-run ... godot --path . --windowed --resolution 720x1280 -- --autoplay`.
- Decisions (delegated):
  - D1 RoundFlow is a RefCounted wrapper over RoundCore + TrayState (ADR-0001 calls it a Node; a Node adds nothing for T0 and blocks scene-less tests). Only it hands out ResolveContext.
  - D2 Layout: src/gameplay (flow, input), src/presentation (views/timeline/player), src/game (scene glue + debug bot) — ADR-0001 diagram names gameplay/presentation; ui-code.md path rules (src/ui/**) therefore do not apply; strings still go through tr().
  - D3 "한 판 더" uses tray_seed PER_ATTEMPT from base seed 1201 (new tray order per attempt); FIXED stays the stage default in tray_rules.tres.
  - D4 Font: SystemFont (Noto Sans CJK KR → … → WenQuanYi Zen Hei → sans-serif) — no font asset committed yet; Android has Noto CJK.
  - D5 Mouse: `input_devices/pointing/emulate_touch_from_mouse=true`; the game listens only to ScreenTouch/ScreenDrag (placement-input rule 3).
  - D6 Egg ghost on a cell that clears first (egg refill) is drawn small at the cell's bottom-left so the face and its top-right badge stay visible; extra waves on one cell = extra inner dashed ring.
  - D7 chain-preview F5 corrected ("cleared once" only within a wave) → chain-preview Decision Log D12.
- GDD finding (not edited): chain-presentation rule 7 (cue start times monotone in event seq) conflicts with rule 11/F2 — events are FACE_ACTIVATED(a), ABILITY_EFFECT(a), FACE_ACTIVATED(b)…, and face b lifts face_gap (0.06) after a while effect a starts face_lead (0.12) after a. Implemented rule 11 timings; the timeline test checks effects against their own face only. Needs a rule-7 wording fix in /design-review.
- Also noticed: chain-resolver AC-12 "every cell cleared exactly once across waves" holds only for its AC-03 fixture; not a general invariant (egg refill).
- Gaps: commit snap/fade 0.06 s, landing squash, brightness pulse, paper particles/confetti, reduced-motion & speed toggles (data knobs exist, no UI), PREVIEW_MISMATCH is push_error not assert, preview not cleared with fade, no back-button flow, real-device perf (chain-preview F2) unmeasured.

## 2026-11-09 — /design-system team-composition (subagent, user delegated all decisions)
- Task: Designing team-composition GDD (system #14 팀 편성)
- Current section: Starting (skeleton created)
- File: design/gdd/team-composition.md

## 2026-11-09 — /design-system obstacles (subagent, user delegated)
- Task: Designing obstacles GDD · Current section: Starting (skeleton created)
- File: design/gdd/obstacles.md

## 2026-11-09 — /design-system round-flow (subagent, user delegated all decisions)
- Task: round-flow GDD · Status: Complete (Designed, pending /design-review in a fresh session)
- File: design/gdd/round-flow.md
- Sections: Summary, Overview, Detailed Design (Core Rules A–J incl. T0 code 대조 / States / Interactions), Formulas (F1–F5), Edge Cases, Dependencies, Visual/Audio, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-R01–R20), Open Questions (Q1–Q6 + Decision Log D1–D14). Player Fantasy & Tuning Knobs omitted by standard tier.
- Key decisions: state fully committed at commit frame (refill + end judgment moved earlier than T0 finish_placement); CLEARED > OUT_OF_PIECES > NO_MOVES; one-tap retry same team/FIXED seed; no undo in MVP; no auto-pause on background
- Registry: +formula pieces_left, +constant retry_budget_s; referenced_by += round-flow on tray_size, chain_playback_time, chain_depth; validate clean
- Systems index: #11 → Designed, Depends On += 점수·입력·미리보기·연출; MVP designed 13/22
- Skipped specialists (lean / no Agent tool): game-designer+systems-designer (C), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN
- Next: /design-review design/gdd/round-flow.md (fresh session); reconcile names with stage-goals.md (round-flow Q3)

## 2026-11-09 — /design-system stage-goals (subagent, user delegated — no questions)
- Task: Designing stage-goals GDD (system #10 스테이지 & 목표)
- Current section: all done
- File: design/gdd/stage-goals.md
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–H: StageDef schema, goal counting, outcome, team_rule, goal preview, trade-off levers, MVP 10-stage proposal, data values / States / Interactions), Formulas (F1–F9), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-SG01–22), Open Questions (+ Decision Log D1–D14). Player Fantasy & Tuning Knobs omitted by standard tier.
- Aligned with concurrently written obstacles.md (ice/stone; iced_cells unit), round-flow.md (GoalTracker/is_met/pieces_out/stars names), team-composition.md (team_rule adopted)
- Registry: +1 formula (star_rating), +1 constant (leftover_piece_points=100); referenced_by += stage-goals on chain_depth, depth_cap, cell_points, ice_remaining, pieces_left, board_width, board_height; validate clean
- Systems index: row 10 → Designed, Depends On += 연쇄 해석기 (chain-resolver Q6); MVP 14/22
- Skipped (lean / no Agent tool): game-designer+level-designer+systems-designer (C), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN. Engine ref: no modules/scripting.md
- Next: /design-review design/gdd/stage-goals.md (fresh session) → /consistency-check → T0 autoplay for AC-SG20 / F8–F9 tuning

## 2026-11-09 — /design-system audio (subagent, user delegated: no questions; decisions in production/session-logs/decision-log.md + GDD Decision Log D1–D10)
- File: design/gdd/audio.md — Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–E / States / Interactions), Formulas (F1–F6), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-A01–A13), Open Questions (+ Decision Log). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: depth_cap referenced_by += audio.md. Systems index: row 23 → Designed; MVP designed 10/22.
- Skipped (no Agent tool / lean): game-designer+audio-director+sound-designer (C), systems-designer (D, E), qa-lead (H), CD-GDD-ALIGN (lean)
- Next: implement (src/audio, tools/audio/gen_sfx.py, assets/audio/sfx)
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–F / States / Interactions), Formulas F1–F4, Edge Cases, Dependencies, Visual/Audio, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-O01–17), Open Questions Q1–Q5 + Decision Log D1–D10. Player Fantasy & Tuning Knobs omitted (standard tier).
- MVP set: STONE cell type + ice modifier (layers ≤2); frozen face = ice:1 on face (thaw then fire). SUPPRESSED reserved, unused.
- Registry: +3 constants (ice_max_layers, frozen_face_layers, max_stones_per_line), +1 formula (ice_remaining); referenced_by on line_cell_count, depth_cap; validate clean
- Systems index: row 9 → Designed; MVP 11/22
- Skipped (lean / no Agent tool): game-designer+systems-designer (C), systems-designer (D, E), qa-lead (H), art-director (Visual), CD-GDD-ALIGN
- Follow-ups: chain-preview/chain-presentation SUPPRESSED rows → Post-MVP + thaw visuals (Q3); kept naming (Q4); scoring Q4 resolved (Q5)
- Next: /design-review design/gdd/obstacles.md (fresh session) → /consistency-check → /design-system stage-goals
- Status: Complete (Designed, pending /design-review in a fresh session)
- Sections: Summary, Overview, Detailed Design (Core Rules A–F / States and Transitions / Interactions), Formulas (F1–F5), Edge Cases, Dependencies, Visual/Audio Requirements, Game Feel, UI Requirements, Cross-References, Acceptance Criteria (AC-T01–T20), Open Questions (+ Decision Log D1–D14). Player Fantasy & Tuning Knobs omitted by standard tier.
- Registry: +1 constant (default_team_size=3); referenced_by += team-composition for nyangi, gomgom, piyak; validate clean
- Systems index: row 14 → Designed; Depends On += 스테이지 & 목표 (soft); progress 12/22 (recount)
- Skipped (lean / no Agent tool): game-designer+systems-designer (C), systems-designer (D, E), qa-lead (H), art-director (Visual/Audio), CD-GDD-ALIGN. Engine ref: no modules/scripting.md.
- Next: /design-review design/gdd/team-composition.md (fresh session) → /design-system crew-ownership (adopt Q1 contract) → /consistency-check after stage-goals lands (Q5)
- Implemented (no commit): tools/audio/gen_sfx.py → assets/audio/sfx/*.wav (21, 328 KB, 22.05 kHz mono); default_bus_layout.tres (Master/SFX/Music);
  src/audio/{audio_tuning,sfx_rules,sfx_player,audio_buses,game_audio}.gd; assets/data/audio/audio_tuning.tres; ChainPlayer.cue_fired += species, PEEL/FIZZLE emits;
  GameScreen wiring; DebugAutoplay prints audio voice count. Tests +24 (tests/unit/audio) → 220 pass, exit 0. xvfb autoplay: ARMED, 163 voices, no audio errors from game code (container ALSA → dummy driver fallback only). Not listened to.
- 2026-11-09 T1 stage loop: App router, stage/team select, stage HUD, obstacles, tray-hold fix, progress save; evidence production/qa/evidence/t1-stages/ (not committed)
