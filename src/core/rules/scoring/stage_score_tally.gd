## Running stage score (scoring rules 11–13, States and Transitions). Immutable
## value: every transition returns a new tally. The round flow holds the current one.
class_name StageScoreTally
extends RefCounted

## Sum of committed placement totals this attempt.
var stage_score: int = 0
## Highest single placement total this attempt.
var best_placement: int = 0


## ACTIVE state at attempt start / retry: both values 0.
static func started() -> StageScoreTally:
	return StageScoreTally.new()


## Returns the tally after committing a placement worth [param placement_total].
static func committed(tally: StageScoreTally, placement_total: int) -> StageScoreTally:
	var out := StageScoreTally.new()
	out.stage_score = tally.stage_score + placement_total
	out.best_placement = maxi(tally.best_placement, placement_total)
	return out
