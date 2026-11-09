## Data-driven audio values (design/gdd/audio.md Formulas F1–F6, Core Rules
## 3, 6–9, 12). Starting values and safe ranges are the GDD variable tables;
## loaded from [code]assets/data/audio/audio_tuning.tres[/code].
## [codeblock]
## var t: AudioTuning = load("res://assets/data/audio/audio_tuning.tres")
## var p := SfxRules.chain_pitch(3, t)
## [/codeblock]
class_name AudioTuning
extends Resource

@export_group("Assets")
## Folder holding one [code]<id>.wav[/code] per sound id.
@export var sfx_dir: String = "res://assets/audio/sfx/"
## Per-sound mix data: id → {gain_db, priority (0–3), max_voices, jitter_cents}.
## The keys are the complete sound list (GDD Core Rules D).
@export var sounds: Dictionary = {}
## Crew species → ability sound id (GDD rule 11: unknown species → [member fallback_ability]).
@export var species_sounds: Dictionary = {}
## Sound for an unmapped species.
@export var fallback_ability: StringName = &"cell_pop"

@export_group("Pitch (F1, F2, F5, F6)")
## F1 semitones per chain depth step.
@export var chain_semitone_step: float = 2.0
## F1 depth at which the pitch stops rising.
@export var chain_pitch_cap: int = 6
## F2 semitones per index inside a burst (line / egg order).
@export var index_semitone_step: float = 2.0
## F2 index at which the pitch stops rising.
@export var index_pitch_cap: int = 4
## F5 minimum seconds between score ticks.
@export var tick_gap_s: float = 0.05
## F5 semitones per tick inside one roll-up.
@export var tick_semitone_step: float = 0.5
## F5 tick count at which the pitch stops rising.
@export var tick_pitch_cap: int = 14
## F6 seed of the audio-only jitter RNG (never the rules RNG).
@export var jitter_seed: int = 11

@export_group("Voices (F3)")
## Pre-built players (rule 7).
@export var pool_size: int = 12
## Same sound minimum gap (s).
@export var min_repeat_gap_s: float = 0.035
## Default per-sound simultaneous voice cap (overridden per sound by max_voices).
@export var default_max_voices: int = 3

@export_group("Fast-forward (rules 12–13, F4)")
## Only sounds with priority ≥ this play while the chain player is FAST.
@export var ff_min_priority: int = 2
## Extra gain while FAST (dB).
@export var ff_gain_db: float = -6.0
## Extra gain for a cancelled drag that never touched the board (dB).
@export var off_board_return_db: float = -6.0

@export_group("Default volumes (F4, user setting defaults)")
## Master bus volume 0..1.
@export var master_volume: float = 1.0
## SFX bus volume 0..1.
@export var sfx_volume: float = 0.8
## Music bus volume 0..1.
@export var music_volume: float = 0.7
## Start muted.
@export var muted: bool = false
## Where the player's volume settings live (provisional, GDD Q2).
@export var settings_path: String = "user://audio_settings.cfg"


## Mix entry for [param id] (empty when unknown).
func entry(id: StringName) -> Dictionary:
	return sounds.get(id, {})


## Priority 0–3 for [param id] (GDD rule 9); unknown → 0.
func priority(id: StringName) -> int:
	return int(entry(id).get("priority", 0))


## Base gain for [param id] in dB.
func gain_db(id: StringName) -> float:
	return float(entry(id).get("gain_db", 0.0))


## Simultaneous voice cap for [param id].
func max_voices(id: StringName) -> int:
	return int(entry(id).get("max_voices", default_max_voices))


## F6 jitter width for [param id] in cents.
func jitter_cents(id: StringName) -> float:
	return float(entry(id).get("jitter_cents", 0.0))


## Ability sound for a crew species.
func ability_sound(species: StringName) -> StringName:
	return StringName(species_sounds.get(species, fallback_ability))
