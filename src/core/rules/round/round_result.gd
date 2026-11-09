## Final record of one attempt (design/gdd/round-flow.md rule 12; stars and
## final score from stage-goals F5–F7). Fixed at the commit that ends the round —
## playback, skipping or backgrounding never change it (round-flow rule 7).
class_name RoundResult
extends RefCounted

## Round outcome (round-flow rule 9 + ABANDONED from the pause menu).
enum Outcome { CONTINUE, CLEARED, FAILED, ABANDONED }
## Why a round failed / ended without clearing.
enum FailReason { NONE, NO_MOVES, OUT_OF_PIECES, ABANDONED }

var stage_id: StringName = &""
var team: Array[StringName] = []
var attempt_index: int = 0
var outcome: Outcome = Outcome.CONTINUE
var fail_reason: FailReason = FailReason.NONE
## Running score without the bonus (scoring rule 11).
var stage_score: int = 0
var best_placement: int = 0
var placements_used: int = 0
## F1 / F2; [constant StageDef.UNLIMITED] for free play.
var pieces_left: int = 0
## F5 (0 unless CLEARED).
var leftover_bonus: int = 0
## F6.
var final_score: int = 0
## Highest CHAIN_END.chain_depth of the attempt.
var max_chain_depth: int = 0
## [method GoalTracker.snapshot] at the end.
var goal_snapshot: Array[Dictionary] = []
## F7: 1–3 when CLEARED, else 0.
var stars: int = 0


## Plain comparable form (determinism tests).
func to_dict() -> Dictionary:
	return {
		&"stage_id": stage_id, &"team": team, &"attempt_index": attempt_index, &"outcome": outcome,
		&"fail_reason": fail_reason, &"stage_score": stage_score, &"best_placement": best_placement,
		&"placements_used": placements_used, &"pieces_left": pieces_left, &"leftover_bonus": leftover_bonus,
		&"final_score": final_score, &"max_chain_depth": max_chain_depth, &"goal_snapshot": goal_snapshot, &"stars": stars,
	}
