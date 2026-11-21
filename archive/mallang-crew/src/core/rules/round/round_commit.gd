## Result of [method RoundCore.commit] (AC-P02 path B).
class_name RoundCommit
extends RefCounted

## Authoritative resolver result.
var result: ChainResult
## Score of this placement.
var breakdown: ScoreBreakdown
## [code]stage_score[/code] after minus before.
var score_delta: int = 0
## Non-empty when the placement was refused.
var error: String = ""
