## Resolver hook points for cell kinds & obstacles (chain-resolver rule 21).
## An invalid (unset) [Callable] means "use the default". Hook implementations
## must be pure static functions (ADR-0001 Risks).
class_name ChainHooks
extends RefCounted

## [code](board: BoardState, cell: int) -> Dictionary {keep: bool, modifiers: PackedInt32Array}[/code].
## Default: clear the cell.
var pre_clear: Callable
## [code](board: BoardState, cell: int) -> bool[/code]. Default: true.
var can_activate: Callable
## [code](board: BoardState, cell: int, primitive: StringName) -> bool[/code]. Default: true.
var target_filter: Callable


## Hooks with every default (no obstacles).
static func defaults() -> ChainHooks:
	return ChainHooks.new()


## Runs [member pre_clear]; returns {keep, modifiers}.
func run_pre_clear(board: BoardState, cell: int) -> Dictionary:
	if not pre_clear.is_valid():
		return {&"keep": false, &"modifiers": PackedInt32Array()}
	var res: Dictionary = pre_clear.call(board, cell)
	return {&"keep": bool(res.get(&"keep", false)), &"modifiers": res.get(&"modifiers", PackedInt32Array())}


## Runs [member can_activate].
func run_can_activate(board: BoardState, cell: int) -> bool:
	if not can_activate.is_valid():
		return true
	return bool(can_activate.call(board, cell))


## Runs [member target_filter].
func run_target_filter(board: BoardState, cell: int, primitive: StringName) -> bool:
	if not target_filter.is_valid():
		return true
	return bool(target_filter.call(board, cell, primitive))
