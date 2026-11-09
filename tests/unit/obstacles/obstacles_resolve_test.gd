## design/gdd/obstacles.md AC-O01–O10, O12, O14, O15: stones and ice through the
## resolver's hooks (rules 1–3, 7–9, 11–15, F1–F3).
extends GdUnitTestSuite

const EMPTY8 := "........"


func _rows_with(overrides: Dictionary) -> Array:
	var rows: Array = []
	for r: int in 8:
		rows.append(overrides.get(r, EMPTY8))
	return rows


func _cells_of(e: ChainEvent) -> Array:
	return ChainFixture.cleared_cells(e)


func test_stone_blocks_placement() -> void:
	# AC-O01
	var b := ObstacleFixture.board(_rows_with({3: "...S...."}))
	assert_bool(BoardRules.can_place(b, BoardFixture.single(), Vector2i(3, 3))).is_false()
	assert_bool(BoardRules.can_place(b, BoardFixture.single(), Vector2i(3, 4))).is_true()


func test_stone_row_completes_with_fewer_cells_and_stays() -> void:
	# AC-O02: row 3 = 3 stones + 4 tiles + 1 empty.
	var b := ObstacleFixture.board(_rows_with({3: "SSS####."}))
	var res := ObstacleFixture.resolve(b, Vector2i(3, 7))
	var wave0: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[0]
	assert_array(wave0.data[ChainEvent.K_ROWS]).is_equal([3])
	var cleared: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[0]
	assert_int(_cells_of(cleared).size()).is_equal(5)
	for c: Vector2i in _cells_of(cleared):
		assert_int(c.y).is_greater_equal(3)
	var fb := res.final_board
	for c: int in 3:
		assert_int(fb.kind[fb.index_of(3, c)]).is_equal(CellKind.STONE)
	assert_array(BoardRules.full_lines(fb).rows).is_empty()


func test_ability_skips_stones() -> void:
	# AC-O03: gomgom 3×3 over 2 stones + 3 tiles.
	var b := ObstacleFixture.board(_rows_with({5: "....S#S.", 6: "###.#G##", 7: "....##.."}))
	var res := ObstacleFixture.resolve(b, Vector2i(6, 3))
	var effects := res.events_of(ChainEvent.Type.ABILITY_EFFECT)
	assert_int(effects.size()).is_equal(1)
	assert_array(effects[0].data[ChainEvent.K_CELLS]).contains_exactly_in_any_order([Vector2i(5, 5), Vector2i(7, 4), Vector2i(7, 5)])
	var fb := res.final_board
	assert_int(fb.kind[fb.index_of(5, 4)]).is_equal(CellKind.STONE)
	assert_int(fb.kind[fb.index_of(5, 6)]).is_equal(CellKind.STONE)


func test_two_layer_ice_loses_one_layer_and_is_kept() -> void:
	# AC-O04
	var ice := Vector2i(7, 2)
	var b := ObstacleFixture.board(_rows_with({7: "#######."}), {ice: 2})
	var res := ObstacleFixture.resolve(b, Vector2i(7, 7))
	var mods := res.events_of(ChainEvent.Type.CELL_MODIFIED)
	assert_int(mods.size()).is_equal(1)
	assert_that(mods[0].data[ChainEvent.K_CELL]).is_equal(ice)
	assert_int(ObstacleRules.ice_in(mods[0].data[ChainEvent.K_MODIFIERS_BEFORE])).is_equal(2)
	assert_int(ObstacleRules.ice_in(mods[0].data[ChainEvent.K_MODIFIERS_AFTER])).is_equal(1)
	var cleared: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[0]
	assert_bool(_cells_of(cleared).has(ice)).is_false()
	assert_array(cleared.data[ChainEvent.K_KEPT]).contains([ice])
	assert_int(ObstacleRules.ice_layers(res.final_board, res.final_board.index_of_cell(ice))).is_equal(1)


func test_ice_at_row_column_crossing_loses_only_one_layer_per_wave() -> void:
	# AC-O05: L3 piece completes row 7 and column 0 whose crossing (7,0) is iced.
	var rows := _rows_with({0: "#.......", 1: "#.......", 2: "#.......", 3: "#.......", 4: "#.......", 5: "#.......", 7: "#.######"})
	var b := ObstacleFixture.board(rows, {Vector2i(7, 0): 2})
	var piece := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var res := ObstacleFixture.resolve(b, Vector2i(6, 0), piece)
	var wave0: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[0]
	assert_array(wave0.data[ChainEvent.K_ROWS]).is_equal([7])
	assert_array(wave0.data[ChainEvent.K_COLS]).is_equal([0])
	assert_int(res.events_of(ChainEvent.Type.CELL_MODIFIED).size()).is_equal(1)
	assert_int(ObstacleRules.ice_layers(res.final_board, res.final_board.index_of(7, 0))).is_equal(1)


func test_ice_hit_in_two_waves_clears_in_the_second() -> void:
	# AC-O06: 1-layer ice in the wave-0 row and in gomgom's 3×3.
	var b := ObstacleFixture.board(_rows_with({7: "#G#####."}), {Vector2i(7, 2): 1})
	var res := ObstacleFixture.resolve(b, Vector2i(7, 7))
	var mods := res.events_of(ChainEvent.Type.CELL_MODIFIED)
	assert_int(mods.size()).is_equal(1)
	assert_int(mods[0].wave).is_equal(0)
	assert_int(ObstacleRules.ice_in(mods[0].data[ChainEvent.K_MODIFIERS_AFTER])).is_equal(0)
	var clears := res.events_of(ChainEvent.Type.CELLS_CLEARED)
	assert_int(clears.size()).is_equal(2)
	assert_bool(_cells_of(clears[1]).has(Vector2i(7, 2))).is_true()
	assert_int(res.final_board.kind[res.final_board.index_of(7, 2)]).is_equal(CellKind.EMPTY)


func test_frozen_face_first_hit_thaws_without_activation() -> void:
	# AC-O07
	var b := ObstacleFixture.board(_rows_with({7: "###N###."}), {Vector2i(7, 3): 1})
	var res := ObstacleFixture.resolve(b, Vector2i(7, 7))
	var mods := res.events_of(ChainEvent.Type.CELL_MODIFIED)
	assert_int(mods.size()).is_equal(1)
	assert_bool(mods[0].data[ChainEvent.K_IS_FACE]).is_true()
	assert_int(res.events_of(ChainEvent.Type.FACE_ACTIVATED).size()).is_equal(0)
	assert_int(res.events_of(ChainEvent.Type.FACE_FIZZLED).size()).is_equal(0)
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(0)
	var fb := res.final_board
	var idx := fb.index_of(7, 3)
	assert_bool(fb.is_face(idx)).is_true()
	assert_int(ObstacleRules.ice_layers(fb, idx)).is_equal(0)
	assert_bool(fb.modifiers.has(idx)).is_false()


func test_frozen_face_thaws_and_fires_in_the_same_chain() -> void:
	# AC-O08: AC-O06 with a frozen nyangi face instead of plain ice.
	var b := ObstacleFixture.board(_rows_with({7: "#GN####."}), {Vector2i(7, 2): 1})
	var res := ObstacleFixture.resolve(b, Vector2i(7, 7))
	var thaw_seq := -1
	var fire_seq := -1
	for e: ChainEvent in res.events:
		if e.type == ChainEvent.Type.CELL_MODIFIED and e.data[ChainEvent.K_CELL] == Vector2i(7, 2):
			thaw_seq = e.seq
		if e.type == ChainEvent.Type.FACE_ACTIVATED and e.data[ChainEvent.K_CREW_ID] == BoardFixture.NYANGI:
			fire_seq = e.seq
			assert_int(e.data[ChainEvent.K_STAGE]).is_equal(2)
	assert_int(thaw_seq).is_greater_equal(0)
	assert_int(fire_seq).is_greater(thaw_seq)


func test_thawed_face_fires_on_a_later_placement() -> void:
	# AC-O09: AC-O07's final board, row 7 refilled, the thawed nyangi is cleared.
	var b := ObstacleFixture.board(_rows_with({7: "###N###."}), {Vector2i(7, 3): 1})
	var after := ObstacleFixture.resolve(b, Vector2i(7, 7)).final_board.copy()
	for c: int in [1, 2, 4, 5, 6, 7]:
		after.set_tile(after.index_of(7, c), &"", false, BoardState.ORIGIN_PIECE, 0)
	var res := ObstacleFixture.resolve(after, Vector2i(7, 0))
	var acts := res.events_of(ChainEvent.Type.FACE_ACTIVATED)
	assert_int(acts.size()).is_equal(1)
	assert_that(acts[0].data[ChainEvent.K_CELL]).is_equal(Vector2i(7, 3))


## 100 fixed-seed obstacle boards (DetRng, no randomness at test time beyond the
## committed seeds): tiles, faces, stones and ice, no complete line.
func _seeded_boards() -> Array[BoardState]:
	var out: Array[BoardState] = []
	var faces: Array[StringName] = [BoardFixture.NYANGI, BoardFixture.GOMGOM, BoardFixture.PIYAK]
	for s: int in 100:
		var rng := DetRng.new(SeedHash.hash32([4242, s]))
		var b := BoardState.create(8, 8, ObstacleRules.kind_table())
		for idx: int in 64:
			var roll := rng.below(100)
			if roll < 6:
				b.set_tile(idx, &"", false, BoardState.ORIGIN_PIECE, 0, CellKind.STONE)
			elif roll < 50:
				var face := rng.below(5) == 0
				var crew: StringName = faces[rng.below(3)] if face else &""
				b.set_tile(idx, crew, face, BoardState.ORIGIN_PIECE, 0)
				if rng.below(4) == 0:
					ObstacleRules.set_ice(b, idx, 1 if face else 1 + rng.below(2))
		# Break complete lines and over-stoned lines deterministically.
		var guard := 0
		while guard < 64:
			guard += 1
			var lines := BoardRules.full_lines(b)
			if lines.is_empty():
				break
			var idx := b.index_of(lines.rows[0], 0) if not lines.rows.is_empty() else b.index_of(0, lines.cols[0])
			b.set_empty(idx)
		out.append(b)
	return out


func test_no_complete_line_survives_and_ice_count_drops_by_cell_modified() -> void:
	# AC-O10 (invariant), AC-O12 AND (ice_remaining_after = before − count), AC-O14 (no SUPPRESSED).
	var violations: Array[String] = []
	var resolved := 0
	var boards := _seeded_boards()
	for i: int in boards.size():
		var b := boards[i]
		for r: int in 8:
			for c: int in 8:
				if not BoardRules.can_place(b, BoardFixture.single(), Vector2i(r, c)):
					continue
				var res := ObstacleFixture.resolve(b, Vector2i(r, c))
				resolved += 1
				if not BoardRules.full_lines(res.final_board).is_empty():
					violations.append("board %d (%d,%d): complete line left" % [i, r, c])
				var before := ObstacleRules.ice_remaining(b)
				var after := ObstacleRules.ice_remaining(res.final_board)
				if after != before - res.events_of(ChainEvent.Type.CELL_MODIFIED).size():
					violations.append("board %d (%d,%d): ice %d -> %d" % [i, r, c, before, after])
				for f: ChainEvent in res.events_of(ChainEvent.Type.FACE_FIZZLED):
					if f.data[ChainEvent.K_REASON] == ChainEvent.REASON_SUPPRESSED:
						violations.append("board %d (%d,%d): SUPPRESSED" % [i, r, c])
	assert_int(resolved).is_greater(1000)
	assert_array(violations.slice(0, 10)).is_empty()


func test_ice_remaining_counts_layers_and_cells() -> void:
	# AC-O12: 3 two-layer cells + 2 frozen faces → 8 layers / 5 cells; one placement strips 3.
	var rows := _rows_with({0: "N......G", 7: "#######."})
	var ice := {Vector2i(7, 0): 2, Vector2i(7, 2): 2, Vector2i(7, 4): 2, Vector2i(0, 0): 1, Vector2i(0, 7): 1}
	var b := ObstacleFixture.board(rows, ice)
	assert_int(ObstacleRules.ice_remaining(b)).is_equal(8)
	assert_int(ObstacleRules.iced_cells(b)).is_equal(5)
	var res := ObstacleFixture.resolve(b, Vector2i(7, 7))
	assert_int(res.events_of(ChainEvent.Type.CELL_MODIFIED).size()).is_equal(3)
	assert_int(ObstacleRules.ice_remaining(res.final_board)).is_equal(5)
	assert_int(ObstacleRules.iced_cells(res.final_board)).is_equal(5)


func test_eggs_prefer_the_stone_row_and_never_land_on_obstacles() -> void:
	# AC-O15: piyak face cleared by column 4; its row (3 stones, 6 filled) beats its column (4 filled).
	var rows := _rows_with({0: "....S...", 1: "....S...", 2: "....S...", 3: "SSS#P##.", 4: "....#...", 5: "....#...", 6: "....#..."})
	var b := ObstacleFixture.board(rows, {Vector2i(4, 4): 1})
	var res := ObstacleFixture.resolve(b, Vector2i(7, 4))
	var fills: Array = []
	for e: ChainEvent in res.events_of(ChainEvent.Type.ABILITY_EFFECT):
		if e.data[ChainEvent.K_KIND] == ChainEvent.KIND_FILL:
			fills.append_array(e.data[ChainEvent.K_CELLS])
	assert_array(fills).is_not_empty()
	# Only row 3's free cells — (3,4) emptied by the clear, (3,7) empty — never a stone or ice tile.
	for cell: Vector2i in fills:
		assert_bool([Vector2i(3, 4), Vector2i(3, 7)].has(cell)).override_failure_message("egg at %s" % cell).is_true()
	# Stones still in place; the ice tile kept its cell (thawed, not cleared).
	var fb := res.final_board
	for c: int in 3:
		assert_int(fb.kind[fb.index_of(3, c)]).is_equal(CellKind.STONE)
	assert_int(fb.kind[fb.index_of(4, 4)]).is_equal(CellKind.TILE)


func test_hooks_do_not_change_obstacle_free_results() -> void:
	# obstacles rule 10 / chain-resolver AC-13 AND: on a board with no obstacles the
	# obstacle hooks give the exact default result.
	var plain := ChainFixture.resolve_single(ChainFixture.PROTOTYPE_DOMINO, Vector2i(7, 3))
	var hooked := ChainFixture.resolve_single(ChainFixture.PROTOTYPE_DOMINO, Vector2i(7, 3), ObstacleFixture.ctx())
	assert_str(ChainFixture.signature(hooked)).is_equal(ChainFixture.signature(plain))
