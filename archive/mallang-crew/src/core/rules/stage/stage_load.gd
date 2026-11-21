## Result of [method StageLoader.load_stage]: the built start board plus load
## errors (stage must not start) and lint warnings (loads anyway).
class_name StageLoad
extends RefCounted

## The stage that was loaded.
var stage: StageDef
## Start board (null when the board text itself was unreadable).
var board: BoardState
## Load errors; each names the offending field.
var errors: PackedStringArray = PackedStringArray()
## Lint warnings.
var warnings: PackedStringArray = PackedStringArray()


## True when there were no load errors.
func is_valid() -> bool:
	return errors.is_empty()
