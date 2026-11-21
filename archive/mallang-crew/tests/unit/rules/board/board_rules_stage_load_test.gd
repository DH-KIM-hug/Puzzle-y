## board-rules AC-11 — stage initial-board validation.
extends GdUnitTestSuite


func test_initial_board_with_full_row_zero_is_rejected() -> void:
	var rows: Array = ["########"]
	for r: int in 7:
		rows.append("........")
	var errs := BoardRules.validate_board(BoardFixture.board(rows), BoardConfig.new())
	assert_str(" | ".join(errs)).contains("row 0")


func test_initial_board_with_full_column_five_is_rejected() -> void:
	var rows: Array = []
	for r: int in 8:
		rows.append(".....#..")
	var errs := BoardRules.validate_board(BoardFixture.board(rows), BoardConfig.new())
	assert_str(" | ".join(errs)).contains("column 5")


func test_valid_initial_board_passes() -> void:
	var b := BoardFixture.board([
		"N.......", "........", "........", "........",
		"........", "........", "........", ".......E",
	])
	assert_array(Array(BoardRules.validate_board(b, BoardConfig.new()))).is_empty()


func test_size_mismatch_is_rejected() -> void:
	var errs := BoardRules.validate_board(BoardFixture.empty(7, 8), BoardConfig.new())
	assert_int(errs.size()).is_equal(1)
