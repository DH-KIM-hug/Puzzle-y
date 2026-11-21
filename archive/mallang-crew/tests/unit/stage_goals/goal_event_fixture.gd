## Hand-written ChainResults for goal-counting tests ("arithmetic only" fixtures,
## stage-goals AC preamble: GoalTracker reads events, so these exercise the
## counting rules without the resolver). Builder style:
## [codeblock]
## var res := GoalEventFixture.new().cleared(0, [Vector2i(0, 7)], Vector2i(7, 0)).thawed(0, Vector2i(3, 3), 1, 0).result(2)
## [/codeblock]
class_name GoalEventFixture
extends RefCounted

var _events: Array[ChainEvent] = []


## CELLS_CLEARED in wave [param k] with [param cells] (by LINE) and an optional kept cell.
func cleared(k: int, cells: Array, kept: Variant = null, by: StringName = ChainEvent.BY_LINE) -> GoalEventFixture:
	var entries := []
	for c: Vector2i in cells:
		entries.append({ChainEvent.K_R: c.x, ChainEvent.K_C: c.y, ChainEvent.K_CREW_ID: &"", ChainEvent.K_IS_FACE: false,
				ChainEvent.K_ORIGIN: BoardState.ORIGIN_PIECE, ChainEvent.K_BY: by, ChainEvent.K_SOURCE_ORDER: -1})
	var kept_cells := [] if kept == null else [kept]
	return _add(ChainEvent.Type.CELLS_CLEARED, k, {ChainEvent.K_WAVE: k, ChainEvent.K_CELLS: entries,
			ChainEvent.K_LINE_CELL_COUNT: entries.size(), ChainEvent.K_ABILITY_CELL_COUNT: 0, ChainEvent.K_KEPT: kept_cells})


## CELL_MODIFIED: ice [param before] → [param after] layers at [param cell].
func thawed(k: int, cell: Vector2i, before: int, after: int, is_face: bool = false) -> GoalEventFixture:
	return _add(ChainEvent.Type.CELL_MODIFIED, k, {ChainEvent.K_CELL: cell, ChainEvent.K_IS_FACE: is_face,
			ChainEvent.K_MODIFIERS_BEFORE: ObstacleRules.with_ice(PackedInt32Array(), before),
			ChainEvent.K_MODIFIERS_AFTER: ObstacleRules.with_ice(PackedInt32Array(), after)})


## Finishes with CHAIN_END(chain_depth = [param depth]) and returns the result.
func result(depth: int = 0) -> ChainResult:
	var summary := {ChainEvent.K_CHAIN_DEPTH: depth, ChainEvent.K_WAVES: 1, ChainEvent.K_CELLS_CLEARED_TOTAL: 0,
			ChainEvent.K_LINES_CLEARED_TOTAL: 0, ChainEvent.K_FACES_ACTIVATED: depth, ChainEvent.K_FACES_FIZZLED: 0,
			ChainEvent.K_EGGS_LAID: 0, ChainEvent.K_CAP_REACHED: false, ChainEvent.K_BOARD_HASH: 0}
	var end := _add_event(ChainEvent.Type.CHAIN_END, -1, summary)
	var r := ChainResult.new()
	r.events = _events
	r.final_board = BoardState.create(8, 8)
	r.summary = end.data
	return r


func _add(t: ChainEvent.Type, k: int, payload: Dictionary) -> GoalEventFixture:
	_add_event(t, k, payload)
	return self


func _add_event(t: ChainEvent.Type, k: int, payload: Dictionary) -> ChainEvent:
	var e := ChainEvent.make(_events.size(), t, k, payload)
	_events.append(e)
	return e


## A minimal valid stage for tracker / loader tests: empty 8×8 board, one goal.
static func stage(goals: Array[GoalDef], targets: Array[Vector2i] = [], rows: Array = [], legend: Dictionary = {}) -> StageDef:
	var s := StageDef.new()
	s.id = &"t-1"
	if not rows.is_empty():
		s.board_rows = PackedStringArray(rows)
	s.cell_legend = legend
	s.goals = goals
	s.target_cells = targets
	s.piece_limit = 12
	s.star_points = PackedInt32Array([1700, 2400])
	s.stage_seed = 77
	s.team_rule = TeamRule.make()
	return s
