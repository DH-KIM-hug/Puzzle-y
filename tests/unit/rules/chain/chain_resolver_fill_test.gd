## chain-resolver AC-05, AC-06, AC-07, AC-20 — FILL primitives and egg re-ignition.
extends GdUnitTestSuite


func test_egg_laid_in_same_wave_cross_range_is_not_cleared_next_wave() -> void:
	# Arrange (AC-05): nyangi (7,2) and piyak (7,5) activate together; piyak's eggs
	# land in row 7, which is inside nyangi's cross but empty on the snapshot.
	var rows: Array = ["..#.....", "........", "........", "........",
		"........", "........", "........", "#.N##P##"]
	# Act
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 1))
	# Assert
	var fills := res.events_of(ChainEvent.Type.ABILITY_EFFECT).filter(
		func(e: ChainEvent) -> bool: return e.data[ChainEvent.K_KIND] == ChainEvent.KIND_FILL)
	assert_array(fills[0].data[ChainEvent.K_CELLS]).is_equal([Vector2i(7, 5), Vector2i(7, 4), Vector2i(7, 6)])
	var w1: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[1]
	assert_array(ChainFixture.cleared_cells(w1)).is_equal([Vector2i(0, 2)])
	var fb := res.final_board
	assert_int(fb.origin(fb.index_of(7, 4))).is_equal(BoardState.ORIGIN_EGG)


func test_two_piyaks_lay_sequentially_without_overlap() -> void:
	# Arrange (AC-06)
	var rows: Array = ["........", "........", "........", "........",
		"........", "........", "........", "#.P##P##"]
	# Act
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 1))
	# Assert
	var fills := res.events_of(ChainEvent.Type.ABILITY_EFFECT)
	assert_int(fills.size()).is_equal(2)
	assert_array(fills[0].data[ChainEvent.K_CELLS]).is_equal([Vector2i(7, 2), Vector2i(7, 1), Vector2i(7, 3)])
	assert_array(fills[1].data[ChainEvent.K_CELLS]).is_equal([Vector2i(7, 5), Vector2i(7, 4), Vector2i(7, 6)])
	assert_int(res.summary[ChainEvent.K_EGGS_LAID]).is_equal(6)


func test_eggs_completing_row_reignite_next_wave() -> void:
	# Arrange (AC-07): column 5 completes, piyak (3,5) lays 2 eggs, row 3 completes,
	# nyangi (3,2) fires at stage 2.
	var rows: Array = ["........", ".....#..", ".....#..", "#.N##P##",
		".....#..", ".....#..", ".....#..", ".....#.."]
	# Act
	var res := ChainFixture.resolve_single(rows, Vector2i(0, 5))
	# Assert
	var eggs: ChainEvent = res.events_of(ChainEvent.Type.ABILITY_EFFECT)[0]
	assert_array(eggs.data[ChainEvent.K_CELLS]).is_equal([Vector2i(3, 5), Vector2i(3, 1)])
	var wb1: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[1]
	assert_array(wb1.data[ChainEvent.K_CAUSES]).contains([ChainEvent.CAUSE_LINE])
	assert_array(wb1.data[ChainEvent.K_ROWS]).is_equal([3])
	assert_array(ChainFixture.activations(res)).contains([[Vector2i(3, 2), 2, 2]])
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(2)


func test_lay_eggs_picks_fuller_line_nearest_first() -> void:
	# Arrange (AC-20 / F5): (3,5) cleared; row 3 empties {(3,1),(3,5)}; column 5 has 4 empties.
	var b := BoardFixture.board([
		".....#..", ".....#..", "........", "#.######",
		".....#..", ".....#..", "........", "........",
	])
	b.set_empty(b.index_of(3, 5))
	var params := {&"count": 3, &"prefer": &"fuller", &"order": &"nearest"}
	# Act
	var eggs := PrimitiveLibrary.execute(&"lay_eggs_in_own_line", params, b, b.index_of(3, 5), ChainFixture.ctx())
	# Assert
	assert_array(Array(eggs)).is_equal([b.index_of(3, 5), b.index_of(3, 1)])


func test_lay_eggs_tie_prefers_row() -> void:
	var b := BoardFixture.empty()
	var params := {&"count": 3, &"prefer": &"fuller", &"order": &"nearest"}
	var eggs := PrimitiveLibrary.execute(&"lay_eggs_in_own_line", params, b, b.index_of(3, 5), ChainFixture.ctx())
	assert_array(Array(eggs)).is_equal([b.index_of(3, 5), b.index_of(3, 4), b.index_of(3, 6)])


func test_lay_eggs_falls_back_to_other_line_when_chosen_is_full() -> void:
	# prefer = row but the row has no empty cell → column.
	var b := BoardFixture.board([
		"........", "........", "........", "########",
		"........", "........", "........", "........",
	])
	var params := {&"count": 2, &"prefer": &"row", &"order": &"row_major"}
	var eggs := PrimitiveLibrary.execute(&"lay_eggs_in_own_line", params, b, b.index_of(3, 5), ChainFixture.ctx())
	assert_array(Array(eggs)).is_equal([b.index_of(0, 5), b.index_of(1, 5)])
