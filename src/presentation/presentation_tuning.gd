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
