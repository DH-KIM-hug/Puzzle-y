## chain-resolver AC-12, AC-13, AC-21 — event schema, read-only output, hooks.
extends GdUnitTestSuite

const _WAVE_ORDER := {
	"WAVE_BEGIN": 0, "CELL_MODIFIED": 1, "CELLS_CLEARED": 2,
	"FACE_ACTIVATED": 3, "ABILITY_EFFECT": 3, "FACE_FIZZLED": 3, "DEPTH_CAP_REACHED": 4,
}


func _fixtures() -> Array[ChainResult]:
	return [
		ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3)),
		ChainFixture.resolve_single(ChainFixture.DEPTH_CHAIN, Vector2i(7, 7)),
		ChainFixture.resolve_single(ChainFixture.PROTOTYPE_DOMINO, Vector2i(7, 3)),
	]


func test_seq_is_gap_free_and_wave_internal_order_follows_rule_19() -> void:
	for res: ChainResult in _fixtures():
		var last_wave := -1
		var last_rank := -1
		for i: int in res.events.size():
			var e := res.events[i]
			assert_int(e.seq).is_equal(i)
			if not _WAVE_ORDER.has(e.type_name()):
				continue
			if e.wave != last_wave:
				assert_str(e.type_name()).is_equal("WAVE_BEGIN")
				assert_int(e.wave).is_equal(last_wave + 1)
				last_wave = e.wave
				last_rank = -1
			var rank: int = _WAVE_ORDER[e.type_name()]
			assert_int(rank).is_greater_equal(last_rank)
			last_rank = rank
		assert_str(res.events[0].type_name()).is_equal("PLACED")
		assert_str(res.events[res.events.size() - 1].type_name()).is_equal("CHAIN_END")


func test_cleared_cells_row_major_and_never_twice() -> void:
	for res: ChainResult in _fixtures():
		var seen := {}
		for e: ChainEvent in res.events_of(ChainEvent.Type.CELLS_CLEARED):
			var prev := -1
			for c: Dictionary in e.data[ChainEvent.K_CELLS]:
				var idx: int = c[ChainEvent.K_R] * 8 + c[ChainEvent.K_C]
				assert_int(idx).is_greater(prev)
				prev = idx
				# A cell may be refilled by an egg and cleared again; track (cell, origin-wave).
				var key := "%d:%d" % [idx, e.wave]
				assert_bool(seen.has(key)).is_false()
				seen[key] = true


func test_domino_never_clears_a_cell_twice_across_waves() -> void:
	# AC-12 on the AC-03 fixture (no eggs → strict uniqueness).
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	var seen := {}
	for e: ChainEvent in res.events_of(ChainEvent.Type.CELLS_CLEARED):
		for cell: Vector2i in ChainFixture.cleared_cells(e):
			assert_bool(seen.has(cell)).is_false()
			seen[cell] = true


func test_cells_cleared_wave_matches_preceding_wave_begin_and_no_score_fields() -> void:
	# AC-21
	for res: ChainResult in _fixtures():
		var current := -1
		for e: ChainEvent in res.events:
			if e.type == ChainEvent.Type.WAVE_BEGIN:
				current = e.data[ChainEvent.K_WAVE]
			elif e.type == ChainEvent.Type.CELLS_CLEARED:
				assert_int(e.data[ChainEvent.K_WAVE]).is_equal(current)
				assert_int(e.wave).is_equal(current)
			for key: Variant in e.data.keys():
				assert_str(String(key)).not_contains("score")
				assert_str(String(key)).not_contains("points")


func test_result_events_and_payloads_are_read_only() -> void:
	# ADR-0001 Decision 4
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	assert_bool(res.events.is_read_only()).is_true()
	assert_bool(res.summary.is_read_only()).is_true()
	for e: ChainEvent in res.events:
		assert_bool(e.data.is_read_only()).is_true()
		for v: Variant in e.data.values():
			if v is Array:
				assert_bool((v as Array).is_read_only()).is_true()
	var cleared: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[0]
	var first: Dictionary = (cleared.data[ChainEvent.K_CELLS] as Array)[0]
	assert_bool(first.is_read_only()).is_true()


func test_consumers_cannot_change_result_hash() -> void:
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	var before := ChainFixture.signature(res)
	var scratch := res.final_board.copy()
	scratch.set_empty(0)
	assert_str(ChainFixture.signature(res)).is_equal(before)
	assert_int(res.final_board.board_hash()).is_equal(res.summary[ChainEvent.K_BOARD_HASH])


func test_can_activate_hook_suppresses_marked_face() -> void:
	# Arrange (AC-13): modifier 1 = "frozen" (test-only meaning).
	var b := BoardFixture.board(ChainFixture.DOMINO_NG)
	b.set_modifiers(b.index_of(7, 5), PackedInt32Array([1]))
	var hooks := ChainHooks.new()
	hooks.can_activate = func(board: BoardState, cell: int) -> bool:
		return not board.modifiers_at(cell).has(1)
	# Act
	var res := ChainResolver.resolve(b, BoardFixture.single(), Vector2i(7, 3), ChainFixture.ctx(6, 0, hooks))
	# Assert
	var fizz := res.events_of(ChainEvent.Type.FACE_FIZZLED)
	assert_int(fizz.size()).is_equal(1)
	assert_str(String(fizz[0].data[ChainEvent.K_REASON])).is_equal("SUPPRESSED")
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(0)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(1)


func test_default_hooks_match_unhooked_golden() -> void:
	# AC-13 AND
	var plain := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	var hooked := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3), ChainFixture.ctx(6, 0, ChainHooks.defaults()))
	assert_str(ChainFixture.signature(hooked)).is_equal(ChainFixture.signature(plain))


func test_pre_clear_keep_emits_cell_modified_and_keeps_cell() -> void:
	# Rule 21 pre_clear: modifier 2 = "ice layer" (test-only) is stripped instead of clearing.
	var rows: Array = ["........", "........", "........", "........",
		"........", "........", "........", "###.####"]
	var b := BoardFixture.board(rows)
	b.set_modifiers(b.index_of(7, 0), PackedInt32Array([2]))
	var hooks := ChainHooks.new()
	hooks.pre_clear = func(board: BoardState, cell: int) -> Dictionary:
		if board.modifiers_at(cell).has(2):
			return {&"keep": true, &"modifiers": PackedInt32Array()}
		return {&"keep": false}
	var res := ChainResolver.resolve(b, BoardFixture.single(), Vector2i(7, 3), ChainFixture.ctx(6, 0, hooks))
	var mods := res.events_of(ChainEvent.Type.CELL_MODIFIED)
	assert_int(mods.size()).is_equal(1)
	assert_that(mods[0].data[ChainEvent.K_CELL]).is_equal(Vector2i(7, 0))
	var cleared: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[0]
	assert_int((cleared.data[ChainEvent.K_CELLS] as Array).size()).is_equal(7)
	assert_array(cleared.data[ChainEvent.K_KEPT]).is_equal([Vector2i(7, 0)])
	var fb := res.final_board
	assert_int(fb.filled_count()).is_equal(1)
	assert_bool(fb.modifiers.has(fb.index_of(7, 0))).is_false()
	assert_bool(b.modifiers.has(b.index_of(7, 0))).is_true()


func test_target_filter_hook_excludes_cells_from_ability() -> void:
	# Rule 21 target_filter: modifier 3 = "line-only" cell (test-only).
	var b := BoardFixture.board(ChainFixture.DOMINO_NG)
	b.set_modifiers(b.index_of(4, 5), PackedInt32Array([3]))
	var hooks := ChainHooks.new()
	hooks.target_filter = func(board: BoardState, cell: int, _prim: StringName) -> bool:
		return not board.modifiers_at(cell).has(3)
	var res := ChainResolver.resolve(b, BoardFixture.single(), Vector2i(7, 3), ChainFixture.ctx(6, 0, hooks))
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(1)
	assert_int(res.final_board.kind[res.final_board.index_of(4, 5)]).is_equal(CellKind.TILE)
