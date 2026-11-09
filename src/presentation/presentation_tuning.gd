## Data-driven presentation values: chain-presentation Formulas F1–F7 and the
## chain-preview F1/F4 display knobs. Starting values and safe ranges are the
## GDD variable tables; loaded from [code]assets/data/presentation/presentation_tuning.tres[/code].
class_name PresentationTuning
extends Resource

@export_group("Chain playback (chain-presentation F1–F7)")
## F1 tempo decrease per wave.
@export var tempo_step: float = 0.08
## F1 tempo floor.
@export var tempo_floor: float = 0.6
## F2 peel segment base length.
@export var peel_dur: float = 0.24
## F2 effect gap base length.
@export var gap_dur: float = 0.30
## F2 stagger between faces in one wave.
@export var face_gap: float = 0.06
## F2 total face stagger cap.
@export var face_stagger_cap: float = 0.12
## F2 face lift → effect start.
@export var face_lead: float = 0.12
## F2 effect arrival → next beat.
@export var arrive_hold: float = 0.08
## F2 last-wave whiff.
@export var whiff_dur: float = 0.20
## F4 landing.
@export var place_dur: float = 0.12
## F4 "최대 연쇄!" hold.
@export var cap_hold: float = 0.5
## F4 settle.
@export var settle_dur: float = 0.15
## F4 playback budget at speed 1.0.
@export var t_budget: float = 4.0
## F4 minimum compression.
@export var c_min: float = 0.7
## F5 per-cell stagger step.
@export var stagger_step: float = 0.02
## F5 stagger cap.
@export var stagger_cap: float = 0.08
## F5 one cell's lift → fly.
@export var cell_lift_dur: float = 0.16
## Egg pop length.
@export var egg_pop_dur: float = 0.14
## Gap between eggs of one effect.
@export var egg_gap: float = 0.05
## Score popup length.
@export var popup_dur: float = 0.9
## Cut-in banner length.
@export var banner_dur: float = 0.9
## Stage-1 ability label length.
@export var label_dur: float = 0.7
## F7 fast-forward multiplier.
@export var ff_speed: float = 3.0
## F7 skip flush display.
@export var skip_flush_dur: float = 0.25
## F7 tap guard after a placement.
@export var skip_guard: float = 0.15
## Playback speed preference (rule 23: 1.0 or 1.5).
@export var speed_pref: float = 1.0
## F3 level cap.
@export var level_cap: int = 4
## F3 shake (px@1080).
@export var shake_base_px: float = 3.0
@export var shake_step_px: float = 2.0
@export var shake_max_px: float = 10.0
## Shake duration.
@export var shake_dur: float = 0.25
## Reduced motion (rule 25) — greybox honours it for shake/rotation.
@export var reduced_motion: bool = false

## Flash-off accessibility toggle (rule 25 / D8): no screen flash, no brightness pulse.
@export var flash_off: bool = false
## Follow the OS "reduce animation" accessibility setting (DisplayServer).
@export var follow_os_reduced_motion: bool = true

@export_group("Polish FX (chain-presentation D15–D18)")
## Hit-stop (playback clock frozen) at each chain wave start, s, by level 1..
@export var hitstop_base_s: float = 0.06
@export var hitstop_step_s: float = 0.02
@export var hitstop_max_s: float = 0.11
## Sum of all hit-stops in one playback (keeps depth 6 ≤ t_budget + this ≈ 4.5 s).
@export var hitstop_total_cap_s: float = 0.45
## Camera punch-in toward the firing face: zoom gain per level and its cap.
@export var punch_zoom_step: float = 0.025
@export var punch_zoom_max: float = 0.06
## Punch ease-back length, s (real time).
@export var punch_release_s: float = 0.32
## Screen flash alpha (sticker white) at a wave start: base + step × level, capped.
@export var flash_base_alpha: float = 0.08
@export var flash_step_alpha: float = 0.04
@export var flash_max_alpha: float = 0.22
## Minimum real time between flashes (art-bible pulse ≤ 3/s).
@export var flash_min_gap_s: float = 0.34
## Flash fade, s.
@export var flash_dur_s: float = 0.18
## Line sweep: travel time along one cleared line, s; cascade gap between lines, s.
@export var sweep_dur_s: float = 0.22
@export var sweep_cascade_s: float = 0.05
## Confetti pieces per peeled cell: plain line clear / chain wave (+ step per level).
@export var confetti_line_per_cell: int = 2
@export var confetti_chain_per_cell: int = 3
@export var confetti_chain_step: int = 1
## Hard cap of live paper particles (mobile / web budget).
@export var particle_cap: int = 220
## Confetti cannon pieces per side for the finisher card.
@export var cannon_per_side: int = 36
## Finisher card ("대연쇄!!") when depth ≥ this or lines in one wave ≥ finisher_lines.
@export var finisher_depth: int = 4
@export var finisher_lines: int = 3
## Finisher card life, s (real time; it shrinks away, never blocks input).
@export var finisher_dur_s: float = 1.2
## Deep-chain mood (level ≥ deep_level): background ink veil alpha and board glow alpha.
@export var deep_level: int = 2
@export var deep_veil_alpha: float = 0.14
@export var deep_glow_alpha: float = 0.55
## Glow pulse rate, Hz (≤ 3).
@export var deep_glow_hz: float = 1.2
## Banner scale gain per level and wobble (deg, Hz ≤ 3).
@export var banner_scale_step: float = 0.1
@export var banner_wobble_deg: float = 2.5
@export var banner_wobble_hz: float = 1.5
## Placement landing squash amount (fraction) and dust puff count.
@export var land_squash: float = 0.14
@export var land_dust: int = 8
## Score HUD roll-up time constant, s; pop scale; gold flash every N points.
@export var score_roll_s: float = 0.35
@export var score_pop_scale: float = 0.28
@export var score_milestone: int = 500
## Idle life: face breathe amplitude (fraction) and period, blink interval / length.
@export var idle_breathe_amp: float = 0.025
@export var idle_breathe_period_s: float = 3.2
@export var idle_blink_every_s: float = 3.6
@export var idle_blink_s: float = 0.12
## Background sparkle dust count.
@export var idle_dust_count: int = 14
## Tray bob for placeable pieces, px@1080 and period, s.
@export var tray_bob_px: float = 4.0
@export var tray_bob_period_s: float = 2.2

@export_group("Round result (round-flow F3, UI Requirements)")
## Delay between the last playback and the result card (round-flow F3).
@export_range(0.0, 2.0) var result_reveal_delay_s: float = 0.6
## Result buttons ignore input this long after the card opens (round-flow UI).
@export_range(0.0, 1.0) var result_input_guard_s: float = 0.3

@export_group("Chain preview (chain-preview F1, F4)")
## F1 badge diameter / cell.
@export var badge_scale: float = 0.40
## F1 badge minimum (px@1080).
@export var badge_min_px: float = 32.0
## F4 pulse period, s.
@export var wave_pulse_period_s: float = 0.9
## F4 phase stagger per wave, s.
@export var wave_pulse_stagger_s: float = 0.12
## F4 resting lift shadow, px.
@export var lift_base_px: float = 2.0
## F4 breathing amplitude, px.
@export var lift_amp_px: float = 2.0
## Rule 8 LRU size (0 = off).
@export var preview_cache_size: int = 16


## F1: tempo(k).
func tempo(k: int) -> float:
	return maxf(tempo_floor, 1.0 - tempo_step * k)
