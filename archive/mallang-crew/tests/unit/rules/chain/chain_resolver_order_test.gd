## chain-resolver AC-04, AC-04b — simultaneous faces resolve row-major, once each.
extends GdUnitTestSuite


func test_three_faces_in_one_row_activate_row_major_same_stage() -> void:
	# Arrange (AC-04): (7,6) gomgom, (7,1) nyangi, (7,4) piyak in one cleared row.
	var rows: Array = ["........", "........", "........", "........",
		"........", "........", "........", "#N##P#G."]
	# Act
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 7))
	# Assert
	var wave0 := ChainFixture.activations(res).filter(func(a: Array) -> bool: return a[1] == 1)
	assert_array(wave0).is_equal([
		[Vector2i(7, 1), 1, 1],
		[Vector2i(7, 4), 1, 2],
		[Vector2i(7, 6), 1, 3],
	])


func test_face_ability_effects_follow_activation_order() -> void:
	# Rule 19: FACE_ACTIVATED → its ABILITY_EFFECTs, then the next face.
	var rows: Array = ["........", "........", "........", "........",
		"........", "........", "........", "#N##P#G."]
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 7))
	var orders := []
	for e: ChainEvent in res.events:
		if e.wave == 0 and (e.type == ChainEvent.Type.FACE_ACTIVATED or e.type == ChainEvent.Type.ABILITY_EFFECT):
			orders.append([e.type_name(), e.data[ChainEvent.K_ORDER_INDEX]])
	assert_array(orders).is_equal([
		["FACE_ACTIVATED", 1], ["ABILITY_EFFECT", 1],
		["FACE_ACTIVATED", 2], ["ABILITY_EFFECT", 2],
		["FACE_ACTIVATED", 3], ["ABILITY_EFFECT", 3],
	])


func test_intersection_face_of_row_and_column_activates_once() -> void:
	# Arrange (AC-04b): nyangi 1-cell piece completes row 7 and column 3 at (7,3).
	var rows: Array = []
	for r: int in 7:
		rows.append("...#....")
	rows.append("###.####")
	var piece := BoardFixture.piece([Vector2i(0, 0)], BoardFixture.NYANGI, 0)
	# Act
	var res := ChainResolver.resolve(BoardFixture.board(rows), piece, Vector2i(7, 3), ChainFixture.ctx())
	# Assert
	var at := ChainFixture.activations(res).filter(func(a: Array) -> bool: return a[0] == Vector2i(7, 3))
	assert_int(at.size()).is_equal(1)
	var w0: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[0]
	assert_array(w0.data[ChainEvent.K_ROWS]).is_equal([7])
	assert_array(w0.data[ChainEvent.K_COLS]).is_equal([3])
	assert_int((res.events_of(ChainEvent.Type.CELLS_CLEARED)[0].data[ChainEvent.K_CELLS] as Array).size()).is_equal(15)


func test_face_in_line_and_ability_range_is_both_and_activates_once() -> void:
	# Arrange (AC-04b AND): gomgom (7,4) targets nyangi (6,5); piyak (7,5) lays
	# eggs that complete column 5 in the same wave, so (6,5) is LINE and ABILITY.
	var rows: Array = [
		".....#..", ".....#..", ".....#..", "........",
		".....#..", ".....#..", ".....N..", "####GP#.",
	]
	# Act
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 7))
	# Assert
	var w1: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[1]
	var entry: Dictionary = {}
	for c: Dictionary in w1.data[ChainEvent.K_CELLS]:
		if c[ChainEvent.K_R] == 6 and c[ChainEvent.K_C] == 5:
			entry = c
	assert_str(String(entry[ChainEvent.K_BY])).is_equal("BOTH")
	assert_int(entry[ChainEvent.K_SOURCE_ORDER]).is_equal(1)
	var n_act := ChainFixture.activations(res).filter(func(a: Array) -> bool: return a[0] == Vector2i(6, 5))
	assert_array(n_act).is_equal([[Vector2i(6, 5), 2, 3]])
	var wb1: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[1]
	assert_array(wb1.data[ChainEvent.K_CAUSES]).is_equal([ChainEvent.CAUSE_LINE, ChainEvent.CAUSE_ABILITY])
	assert_array(wb1.data[ChainEvent.K_COLS]).is_equal([5])


func test_overlapping_targets_cleared_once_with_earliest_source() -> void:
	# Edge Cases: gomgom (7,1) and gomgom (7,2) both cover (6,1)/(6,2) → union,
	# cleared once, source_order = earliest face.
	var rows: Array = ["........", "........", "........", "........",
		"........", "........", ".##.....", "#GG####."]
	var res := ChainFixture.resolve_single(rows, Vector2i(7, 7))
	var w1: ChainEvent = res.events_of(ChainEvent.Type.CELLS_CLEARED)[1]
	assert_array(ChainFixture.cleared_cells(w1)).is_equal([Vector2i(6, 1), Vector2i(6, 2)])
	for c: Dictionary in w1.data[ChainEvent.K_CELLS]:
		assert_int(c[ChainEvent.K_SOURCE_ORDER]).is_equal(1)
