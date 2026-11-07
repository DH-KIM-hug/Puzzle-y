## The chain resolver (design/gdd/chain-resolver.md, ADR-0001 Decision 3).
##
## Pure: the same (board, piece, anchor, ctx) always yields an identical
## [ChainResult]; inputs are never mutated; integer arithmetic only. Preview,
## commit and automated tests all call this one function (rule 3).
##
## Spec ambiguities resolved here (logged per task brief):
## [br]- Rule 21 / Edge Cases: [code]can_activate[/code] is evaluated on the board as it
##   was *before* the wave's clear, because clearing removes the face cell's
##   modifiers and the hook exists to read them.
## [br]- Rule 19: [code]CELLS_CLEARED.kept[/code] lists pending cells that stayed
##   filled — both [code]pre_clear[/code] KEEPs and non-removable cells (board-rules F4).
## [br]- Rule 19: an [code]ABILITY_EFFECT[/code] CLEAR lists every filled, filtered target
##   of that face even if an earlier face already targeted it; [code]source_order[/code]
##   in the next [code]CELLS_CLEARED[/code] names the earliest face.
## [br]- Rule 1 / rule 8 "assert": violations are [method @GlobalScope.push_error]ed
##   (catchable by gdUnit4 [code]is_push_error[/code]) and the call returns a result
##   with no events and [member ChainResult.error] set; the input board is untouched.
class_name ChainResolver
extends RefCounted

## push_error text when [method resolve] is given an invalid placement.
const ERR_INVALID_PLACEMENT := "ChainResolver.resolve: can_place is false"
## push_error text when the wave guard trips (unreachable in correct code, F3).
const ERR_WAVE_GUARD := "ChainResolver.resolve: max_waves_guard exceeded"
## push_error text when a face's crew has no ability entry (rule 18).
const ERR_UNKNOWN_CREW := "ChainResolver.resolve: crew has no ability"


## Resolves one placement. See class description.
static func resolve(board: BoardState, piece: PieceInstance, anchor: Vector2i, ctx: ResolveContext) -> ChainResult:
	var result := ChainResult.new()
	if not BoardRules.can_place(board, piece, anchor):
		push_error(ERR_INVALID_PLACEMENT)
		result.error = ERR_INVALID_PLACEMENT
		result.final_board = board.copy()
		result.events.make_read_only()
		result.summary.make_read_only()
		return result

	var hooks: ChainHooks = ctx.hooks if ctx.hooks != null else ChainHooks.defaults()
	var depth_cap := ctx.rules.depth_cap
	var guard := ctx.rules.max_waves_guard()
	var elog := _EventLog.new()

	# 6.1 place
	var b := BoardRules.place(board, piece, anchor, ctx.placement_id)
	var placed_cells: Array = []
	for cell: Vector2i in BoardRules.piece_cells(piece, anchor):
		placed_cells.append(cell)
	var face_cell := ChainEvent.NO_CELL
	if piece.has_face():
		face_cell = anchor + piece.shape.offsets[piece.face_index]
	elog.add(ChainEvent.Type.PLACED, -1, {
		ChainEvent.K_CREW_ID: piece.crew_id,
		ChainEvent.K_ANCHOR: anchor,
		ChainEvent.K_CELLS: placed_cells,
		ChainEvent.K_FACE_CELL: face_cell,
	})

	# 6.2 first pending set
	var lines := _effective_full_lines(b)
	var line_set := _index_set(BoardRules.line_cells(b, lines))
	var ability_set := {}  # cell index -> earliest source order_index
	var causes: Array = [ChainEvent.CAUSE_LINE] if not lines.is_empty() else []

	var k := 0
	var waves := 0
	var chain_depth := 0
	var order_index := 0
	var cells_cleared_total := 0
	var lines_cleared_total := 0
	var faces_activated := 0
	var faces_fizzled := 0
	var eggs_laid := 0
	var cap_reached := false

	while not line_set.is_empty() or not ability_set.is_empty():
		if waves >= guard:
			push_error(ERR_WAVE_GUARD)
			break
		waves += 1
		lines_cleared_total += lines.count()
		# 6.3 wave begin
		elog.add(ChainEvent.Type.WAVE_BEGIN, k, {
			ChainEvent.K_WAVE: k,
			ChainEvent.K_CAUSES: causes,
			ChainEvent.K_ROWS: Array(lines.rows),
			ChainEvent.K_COLS: Array(lines.cols),
		})

		# 6.4 pre_clear hook, then clear
		var pending := _union_sorted(line_set, ability_set, b.cell_count())
		var pre_wave := b
		var to_clear := PackedInt32Array()
		var kept: Array = []
		# b is the resolver's own working board (never the caller's), so KEEP
		# modifier updates are written in place (ADR-0001 Decision 2).
		var working := b
		for idx: int in pending:
			if working.kind[idx] == CellKind.EMPTY:
				continue
			if not working.removable_by_clear(idx):
				kept.append(working.cell_of(idx))
				continue
			var hook := hooks.run_pre_clear(pre_wave, idx)
			if hook[&"keep"]:
				var before := working.modifiers_at(idx)
				var after: PackedInt32Array = hook[&"modifiers"]
				working.set_modifiers(idx, after)
				kept.append(working.cell_of(idx))
				elog.add(ChainEvent.Type.CELL_MODIFIED, k, {
					ChainEvent.K_CELL: working.cell_of(idx),
					ChainEvent.K_MODIFIERS_BEFORE: before.duplicate(),
					ChainEvent.K_MODIFIERS_AFTER: after.duplicate(),
				})
			else:
				to_clear.append(idx)
		var cleared_res := BoardRules.clear_cells(working, to_clear)
		b = cleared_res.board
		var cleared_entries: Array = []
		var line_count := 0
		var ability_count := 0
		var faces: Array[ClearedCell] = []
		for cc: ClearedCell in cleared_res.cleared:
			var in_line := line_set.has(cc.index)
			var in_ability := ability_set.has(cc.index)
			var by := ChainEvent.BY_BOTH if in_line and in_ability else (ChainEvent.BY_LINE if in_line else ChainEvent.BY_ABILITY)
			if in_line:
				line_count += 1
			else:
				ability_count += 1
			cleared_entries.append({
				ChainEvent.K_R: cc.row,
				ChainEvent.K_C: cc.col,
				ChainEvent.K_CREW_ID: cc.crew_id,
				ChainEvent.K_IS_FACE: cc.is_face,
				ChainEvent.K_ORIGIN: cc.origin,
				ChainEvent.K_BY: by,
				ChainEvent.K_SOURCE_ORDER: int(ability_set.get(cc.index, -1)),
			})
			if cc.is_face and cc.crew_id != &"":
				faces.append(cc)
		cells_cleared_total += cleared_res.cleared.size()
		elog.add(ChainEvent.Type.CELLS_CLEARED, k, {
			ChainEvent.K_WAVE: k,
			ChainEvent.K_CELLS: cleared_entries,
			ChainEvent.K_LINE_CELL_COUNT: line_count,
			ChainEvent.K_ABILITY_CELL_COUNT: ability_count,
			ChainEvent.K_KEPT: kept,
		})

		# 6.5 faces (row-major: clear_cells order)
		if faces.is_empty():
			break
		# 6.6 depth cap
		if k >= depth_cap:
			for f: ClearedCell in faces:
				faces_fizzled += 1
				elog.add(ChainEvent.Type.FACE_FIZZLED, k, {
					ChainEvent.K_CELL: Vector2i(f.row, f.col),
					ChainEvent.K_CREW_ID: f.crew_id,
					ChainEvent.K_REASON: ChainEvent.REASON_DEPTH_CAP,
				})
			elog.add(ChainEvent.Type.DEPTH_CAP_REACHED, k, {ChainEvent.K_WAVE: k})
			cap_reached = true
			break

		# 6.7 activation — CLEAR on the snapshot, FILL sequential on b
		var snapshot := b
		var next_ability := {}
		var activated := 0
		for f: ClearedCell in faces:
			if not hooks.run_can_activate(pre_wave, f.index):
				faces_fizzled += 1
				elog.add(ChainEvent.Type.FACE_FIZZLED, k, {
					ChainEvent.K_CELL: Vector2i(f.row, f.col),
					ChainEvent.K_CREW_ID: f.crew_id,
					ChainEvent.K_REASON: ChainEvent.REASON_SUPPRESSED,
				})
				continue
			if ctx.abilities == null or not ctx.abilities.has_crew(f.crew_id):
				push_error(ERR_UNKNOWN_CREW)
				continue
			order_index += 1
			activated += 1
			faces_activated += 1
			elog.add(ChainEvent.Type.FACE_ACTIVATED, k, {
				ChainEvent.K_ORDER_INDEX: order_index,
				ChainEvent.K_CELL: Vector2i(f.row, f.col),
				ChainEvent.K_CREW_ID: f.crew_id,
				ChainEvent.K_ABILITY_ID: ctx.abilities.ability_id_for(f.crew_id),
				ChainEvent.K_STAGE: k + 1,
			})
			for step: Dictionary in ctx.abilities.steps_for(f.crew_id):
				var prim: StringName = step[AbilityTable.K_PRIMITIVE]
				var params: Dictionary = step[AbilityTable.K_PARAMS]
				var kind := PrimitiveLibrary.kind_of(prim)
				var effect := PackedInt32Array()
				if kind == PrimitiveLibrary.KIND_CLEAR:
					for idx: int in PrimitiveLibrary.execute(prim, params, snapshot, f.index, ctx):
						if snapshot.kind[idx] == CellKind.EMPTY:
							continue
						if not hooks.run_target_filter(snapshot, idx, prim):
							continue
						effect.append(idx)
						if not next_ability.has(idx):
							next_ability[idx] = order_index
				elif kind == PrimitiveLibrary.KIND_FILL:
					effect = PrimitiveLibrary.execute(prim, params, b, f.index, ctx)
					if not effect.is_empty():
						b = BoardRules.fill_cells(b, effect, BoardState.ORIGIN_EGG, f.crew_id, ctx.placement_id)
						eggs_laid += effect.size()
				else:
					continue
				var effect_cells: Array = []
				for idx: int in effect:
					effect_cells.append(b.cell_of(idx))
				elog.add(ChainEvent.Type.ABILITY_EFFECT, k, {
					ChainEvent.K_ORDER_INDEX: order_index,
					ChainEvent.K_PRIMITIVE: prim,
					ChainEvent.K_KIND: ChainEvent.KIND_CLEAR if kind == PrimitiveLibrary.KIND_CLEAR else ChainEvent.KIND_FILL,
					ChainEvent.K_CELLS: effect_cells,
				})
		if activated == 0:
			break
		chain_depth += 1

		# 6.8 next wave = ability targets ∪ lines completed (by eggs)
		lines = _effective_full_lines(b)
		line_set = _index_set(BoardRules.line_cells(b, lines))
		ability_set = next_ability
		causes = []
		if not lines.is_empty():
			causes.append(ChainEvent.CAUSE_LINE)
		if not ability_set.is_empty():
			causes.append(ChainEvent.CAUSE_ABILITY)
		k += 1

	# 6.9 end
	var crew_keys: Dictionary = ctx.abilities.crew_keys() if ctx.abilities != null else {}
	var summary := {
		ChainEvent.K_CHAIN_DEPTH: chain_depth,
		ChainEvent.K_WAVES: waves,
		ChainEvent.K_CELLS_CLEARED_TOTAL: cells_cleared_total,
		ChainEvent.K_LINES_CLEARED_TOTAL: lines_cleared_total,
		ChainEvent.K_FACES_ACTIVATED: faces_activated,
		ChainEvent.K_FACES_FIZZLED: faces_fizzled,
		ChainEvent.K_EGGS_LAID: eggs_laid,
		ChainEvent.K_CAP_REACHED: cap_reached,
		ChainEvent.K_BOARD_HASH: b.board_hash(crew_keys),
	}
	var end_event := elog.add(ChainEvent.Type.CHAIN_END, -1, summary)
	result.events = elog.events
	result.events.make_read_only()
	result.final_board = b
	result.summary = end_event.data
	return result


## chain-resolver rule 11: full lines that contain at least one removable cell.
static func _effective_full_lines(b: BoardState) -> LineSet:
	var raw := BoardRules.full_lines(b)
	var out := LineSet.new()
	for r: int in raw.rows:
		if _line_has_removable(b, BoardRules.AXIS_ROW, r):
			out.rows.append(r)
	for c: int in raw.cols:
		if _line_has_removable(b, BoardRules.AXIS_COL, c):
			out.cols.append(c)
	return out


static func _line_has_removable(b: BoardState, axis: int, index: int) -> bool:
	var n := b.height if axis == BoardRules.AXIS_COL else b.width
	for i: int in n:
		var idx := b.index_of(i, index) if axis == BoardRules.AXIS_COL else b.index_of(index, i)
		if b.removable_by_clear(idx):
			return true
	return false


static func _index_set(cells: PackedInt32Array) -> Dictionary:
	var d := {}
	for idx: int in cells:
		d[idx] = true
	return d


static func _union_sorted(a: Dictionary, b: Dictionary, cell_count: int) -> PackedInt32Array:
	var all := PackedInt32Array()
	for idx: int in a:
		all.append(idx)
	for idx: int in b:
		all.append(idx)
	return BoardRules.sorted_unique(all, cell_count)


## Sequential event builder; assigns gap-free seq numbers.
class _EventLog:
	extends RefCounted
	var events: Array[ChainEvent] = []

	func add(t: ChainEvent.Type, wave: int, payload: Dictionary) -> ChainEvent:
		var e := ChainEvent.make(events.size(), t, wave, payload)
		events.append(e)
		return e
