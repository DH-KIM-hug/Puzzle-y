## Pure audio rules (design/gdd/audio.md Formulas F1–F6, Core Rules D–E):
## pitch ladders, voice admission and the cue → sound mapping. No nodes, no
## engine state — every function is a deterministic function of its inputs so
## the whole mapping is unit-testable without an audio device.
## [codeblock]
## for r: Dictionary in SfxRules.cue_requests(kind, level, index, species, first_peel, tuning, 0.05):
##     sfx.play(r[SfxRules.R_ID], r[SfxRules.R_PITCH], r[SfxRules.R_DELAY])
## [/codeblock]
class_name SfxRules
extends RefCounted

## Pseudo cue kind of the "대연쇄!!" finisher (ChainPlayer emits -1).
const KIND_FINISHER := -1

## Request keys.
const R_ID := &"id"
const R_PITCH := &"pitch"
const R_DELAY := &"delay"


## F1 — chain depth pitch: whole-tone ladder from depth 1, flat from the cap; depth ≤ 0 → 1.0.
static func chain_pitch(depth: int, tuning: AudioTuning) -> float:
	if depth <= 0:
		return 1.0
	var d := clampi(depth, 1, maxi(tuning.chain_pitch_cap, 1))
	return pow(2.0, float(d - 1) * tuning.chain_semitone_step / 12.0)


## F2 — order-inside-a-burst pitch on top of the depth pitch.
static func cascade_pitch(index: int, depth: int, tuning: AudioTuning) -> float:
	var i := clampi(index, 0, maxi(tuning.index_pitch_cap, 0))
	return chain_pitch(depth, tuning) * pow(2.0, float(i) * tuning.index_semitone_step / 12.0)


## F5 — score tick pitch for the [param n]-th tick (0-based) of one roll-up.
static func tick_pitch(n: int, tuning: AudioTuning) -> float:
	return pow(2.0, float(clampi(n, 0, maxi(tuning.tick_pitch_cap, 0))) * tuning.tick_semitone_step / 12.0)


## F6 — jitter factor for a uniform [param u] ∈ [-1, 1].
static func jitter(u: float, cents: float) -> float:
	return pow(2.0, clampf(u, -1.0, 1.0) * cents / 1200.0)


## F4 — bus dB for a 0..1 volume (0 → -INF, i.e. the caller mutes the bus).
static func bus_db(volume: float) -> float:
	var v := clampf(volume, 0.0, 1.0)
	return -INF if v <= 0.0 else linear_to_db(v)


## F4 — voice dB.
static func voice_db(id: StringName, fast: bool, tuning: AudioTuning) -> float:
	return tuning.gain_db(id) + (tuning.ff_gain_db if fast else 0.0)


## Rule 12 — may [param id] sound while the chain player is fast-forwarding?
static func admit_fast(id: StringName, fast: bool, tuning: AudioTuning) -> bool:
	return not fast or tuning.priority(id) >= tuning.ff_min_priority


## F3 — same-sound repeat gap.
static func admit_repeat(now: float, last_play: float, gap: float) -> bool:
	return now - last_play >= gap


## F3 / rule 9 — which pool voice to use. [param busy], [param prios] and
## [param starts] describe the pool (one entry per voice). Returns a free voice,
## else the oldest voice of the lowest priority when that priority ≤
## [param new_prio], else -1 (drop the request).
static func pick_voice(busy: Array[bool], prios: Array[int], starts: Array[float], new_prio: int) -> int:
	for i: int in busy.size():
		if not busy[i]:
			return i
	var best := -1
	for i: int in busy.size():
		if prios[i] > new_prio:
			continue
		if best < 0 or prios[i] < prios[best] or (prios[i] == prios[best] and starts[i] < starts[best]):
			best = i
	return best


## Core Rules D — the sounds one chain cue asks for. [param index] is the
## order inside its burst (line / egg) or the wave number (SHAKE, PEEL).
## [param first_peel] = this PEEL is the first of its wave (rule: "샥" once per wave).
## [param sweep_cascade_s] = the presentation's line sweep cascade (F2 delay).
static func cue_requests(kind: int, level: int, index: int, species: StringName, first_peel: bool,
		tuning: AudioTuning, sweep_cascade_s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		ChainTimeline.Kind.PLACE:
			out.append(_req(&"place_thud", 1.0))
		ChainTimeline.Kind.LINE_FLASH:
			out.append(_req(&"line_sweep", cascade_pitch(index, level, tuning), sweep_cascade_s * maxi(index, 0)))
		ChainTimeline.Kind.PEEL:
			if first_peel:
				out.append(_req(&"sticker_peel", chain_pitch(level, tuning)))
			out.append(_req(&"cell_pop", chain_pitch(level, tuning)))
		ChainTimeline.Kind.EFFECT:
			out.append(_req(tuning.ability_sound(species), chain_pitch(level, tuning)))
		ChainTimeline.Kind.EGG:
			out.append(_req(&"cell_pop", cascade_pitch(maxi(index - 1, 0), level, tuning)))
		ChainTimeline.Kind.SHAKE:
			if index >= 1:
				out.append(_req(&"chain_hit", chain_pitch(index, tuning)))
		ChainTimeline.Kind.BANNER:
			out.append(_req(&"banner_slam", chain_pitch(level, tuning)))
		ChainTimeline.Kind.FIZZLE:
			out.append(_req(&"fizzle", 1.0))
		ChainTimeline.Kind.CAP_BANNER:
			out.append(_req(&"cap_fanfare", 1.0))
		KIND_FINISHER:
			out.append(_req(&"finisher_fanfare", 1.0))
			out.append(_req(&"confetti_burst", 1.0))
	return out


static func _req(id: StringName, pitch: float, delay: float = 0.0) -> Dictionary:
	return {R_ID: id, R_PITCH: pitch, R_DELAY: delay}
