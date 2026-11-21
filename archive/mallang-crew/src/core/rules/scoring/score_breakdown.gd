## Result of [method ScoreCalculator.score_placement] (scoring rule 1).
class_name ScoreBreakdown
extends RefCounted

const K_WAVE := &"wave"
const K_LINE_COUNT := &"line_count"
const K_LINE_CELLS := &"line_cells"
const K_ABILITY_CELLS := &"ability_cells"
const K_DEPTH_MULT_PCT := &"depth_mult_pct"
const K_LINE_MULT_PCT := &"line_mult_pct"
const K_CLEAR_POINTS := &"clear_points"
const K_ACTIVATION_POINTS := &"activation_points"

## F1 placement points.
var placement_points: int = 0
## One Dictionary per wave, ascending, keyed by the [code]K_*[/code] constants.
var waves: Array[Dictionary] = []
## Number of fizzled faces counted.
var fizzled: int = 0
## [code]fizzle_points × fizzled[/code].
var fizzle_total: int = 0
## F5 placement total.
var total: int = 0
## Non-empty when the event list broke the schema (scored placement points only).
var error: String = ""


## Plain Dictionary form for equality checks (preview = commit parity).
func to_dict() -> Dictionary:
	return {
		&"placement_points": placement_points, &"waves": waves, &"fizzled": fizzled,
		&"fizzle_total": fizzle_total, &"total": total, &"error": error,
	}


## The breakdown of wave [param k], or an empty Dictionary.
func wave(k: int) -> Dictionary:
	for w: Dictionary in waves:
		if w[K_WAVE] == k:
			return w
	return {}
