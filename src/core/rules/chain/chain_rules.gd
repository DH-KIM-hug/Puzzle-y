## Chain resolver data values (chain-resolver section I). Loaded from
## [code]assets/data/rules/chain_rules.tres[/code]; read-only at runtime.
class_name ChainRules
extends Resource

## Waves 0 .. depth_cap - 1 may activate faces; wave depth_cap clears and fizzles
## (rule 10). Safe range 3–10, 0 allowed for tests.
@export var depth_cap: int = 6
## Simultaneous-face order; MVP fixed to row-major (D3).
@export var face_order: StringName = &"row_major"


## Safety guard derived from [member depth_cap] (rule 8).
func max_waves_guard() -> int:
	return depth_cap + 1


## Validation errors (empty = valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if depth_cap < 0:
		errors.append("ChainRules.depth_cap must be >= 0 (%d)" % depth_cap)
	if face_order != &"row_major":
		errors.append("ChainRules.face_order '%s' unsupported (MVP: row_major)" % face_order)
	return errors
