## board-rules AC-07, AC-08, AC-09, AC-12, AC-14 (F4/F5) — lines, clear, fill.
extends GdUnitTestSuite


## Row 7 and column 3 full except (7,3).
func _cross_gap_board() -> BoardState:
	var rows: Array = []
	for r: int in 7:
		rows.append("...#....")
	rows.append("###.####")
	return BoardFixture.board(rows)


func test_full_lines_rows_first_and_union_counted_once() -> void:
	# Arrange (AC-07)
	var b := BoardRules.place(_cross_gap_board(), BoardFixture.single(), Vector2i(7, 3), 1)
	# Act
	var lines := BoardRules.full_lines(b)
	var cells := BoardRules.line_cells(b, lines)
	# Assert
	assert_array(Array(lines.rows)).is_equal([7])
	assert_array(Array(lines.cols)).is_equal([3])
	assert_int(cells.size()).is_equal(15)
	var sorted := cells.duplicate()
	sorted.sort()
	assert_array(Array(cells)).is_equal(Array(sorted))


func test_clear_full_row_reports_single_face() -> void:
	# AC-08
	var b := BoardFixture.board([
		"........", "........", "........", "........",
		"........", "........", "........", "##N#####",
	])
	var res := BoardRules.clear_cells(b, BoardRules.line_cells(b, BoardRules.full_lines(b)))
	assert_int(res.cleared.size()).is_equal(8)
	assert_int(res.board.filled_count()).is_equal(0)
	var faces := res.cleared.filter(func(c: ClearedCell) -> bool: return c.is_face)
	assert_int(faces.size()).is_equal(1)
	assert_str(String((faces[0] as ClearedCell).crew_id)).is_equal("nyangi")
	assert_int(b.filled_count()).is_equal(8)


func test_clear_row_and_column_intersection_face_listed_once() -> void:
	# AC-08 AND: intersection (7,3) is a face, two more faces on the lines.
	var rows: Array = []
	for r: int in 7:
		rows.append("...G...." if r == 2 else "...#....")
	rows.append("#P#N####")
	var b := BoardFixture.board(rows)
	var res := BoardRules.clear_cells(b, BoardRules.line_cells(b, BoardRules.full_lines(b)))
	var faces := res.cleared.filter(func(c: ClearedCell) -> bool: return c.is_face)
	assert_int(faces.size()).is_equal(3)
	assert_int(res.cleared.size()).is_equal(15)


func test_clear_range_with_empty_cells_skips_them() -> void:
	var b := BoardFixture.board([
		"#.#.....", "........", "........", "........",
		"........", "........", "........", "........",
	])
	var res := BoardRules.clear_cells(b, PackedInt32Array([0, 1, 2, 3]))
	assert_int(res.cleared.size()).is_equal(2)
	assert_int(res.cleared[0].index).is_equal(0)
	assert_int(res.cleared[1].index).is_equal(2)


func test_fill_eggs_completes_row() -> void:
	# AC-09
	var b := BoardFixture.board([
		"........", "........", "........", "##.##.##",
		"........", "........", "........", "........",
	])
	var targets := PackedInt32Array([b.index_of(3, 2), b.index_of(3, 5)])
	var out := BoardRules.fill_cells(b, targets, BoardState.ORIGIN_EGG, BoardFixture.PIYAK)
	assert_int(out.origin(targets[0])).is_equal(BoardState.ORIGIN_EGG)
	assert_bool(out.is_face(targets[1])).is_false()
	assert_array(Array(BoardRules.full_lines(out).rows)).is_equal([3])


func test_fill_occupied_cell_reports_error_and_changes_nothing() -> void:
	var b := BoardFixture.board([
		"#.......", "........", "........", "........",
		"........", "........", "........", "........",
	])
	var before := b.copy()
	var holder := {}
	await assert_error(func() -> void:
		holder.out = BoardRules.fill_cells(b, PackedInt32Array([1, 0]), BoardState.ORIGIN_EGG, BoardFixture.PIYAK)
	).is_push_error(BoardRules.ERR_FILL_OCCUPIED)
	assert_bool((holder.out as BoardState).equals(before)).is_true()
	assert_bool(b.equals(before)).is_true()


func test_data_only_stone_kind_survives_line_clear() -> void:
	# AC-12: TEST_STONE (blocks, counts, not removable) registered as data.
	var b := BoardFixture.board([
		"........", "........", "........", "........",
		"........", "........", "........", "###S####",
	])
	var res := BoardRules.clear_cells(b, BoardRules.line_cells(b, BoardRules.full_lines(b)))
	assert_int(res.cleared.size()).is_equal(7)
	assert_int(res.board.filled_count()).is_equal(1)
	assert_int(res.board.kind[res.board.index_of(7, 3)]).is_equal(BoardFixture.TEST_STONE)


func test_formula_values_line_cell_count_and_fill_count() -> void:
	# AC-14: F4 R=2,C=1 → 22 ; R=1,C=1 → 15 ; F5 six-filled row → 6.
	var b := BoardFixture.board([
		"######..", "........", "........", "........",
		"........", "........", "........", "........",
	])
	assert_int(BoardRules.line_cell_count(b, 2, 1)).is_equal(22)
	assert_int(BoardRules.line_cell_count(b, 1, 1)).is_equal(15)
	assert_int(BoardRules.line_fill_count(b, BoardRules.AXIS_ROW, 0)).is_equal(6)
	assert_int(BoardRules.empty_cells_in_line(b, BoardRules.AXIS_COL, 0).size()).is_equal(7)
