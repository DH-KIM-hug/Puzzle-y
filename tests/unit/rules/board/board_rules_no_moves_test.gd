## board-rules AC-10, AC-16 — "no moves" detection.
extends GdUnitTestSuite


func _checker() -> BoardState:
	# Isolated single empty cells: no two empties adjacent.
	var rows: Array = []
	for r: int in 8:
		rows.append(".#.#.#.#" if r % 2 == 0 else "#.#.#.#.")
	return BoardFixture.board(rows)


func _pieces(list: Array) -> Array[PieceInstance]:
	var out: Array[PieceInstance] = []
	for p: PieceInstance in list:
		out.append(p)
	return out


func _domino() -> PieceInstance:
	return BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1)])


func _square() -> PieceInstance:
	return BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)])


func test_checkerboard_with_domino_and_square_is_stuck() -> void:
	assert_bool(BoardRules.no_moves(_checker(), _pieces([_domino(), _square()]))).is_true()


func test_adding_single_cell_piece_unblocks() -> void:
	assert_bool(BoardRules.no_moves(_checker(), _pieces([_domino(), _square(), BoardFixture.single()]))).is_false()


func test_empty_piece_list_is_not_stuck() -> void:
	assert_bool(BoardRules.no_moves(_checker(), _pieces([]))).is_false()


func test_full_board_with_single_piece_is_stuck() -> void:
	var rows: Array = []
	for r: int in 8:
		rows.append("########")
	assert_bool(BoardRules.no_moves(BoardFixture.board(rows), _pieces([BoardFixture.single()]))).is_true()


func test_refill_boundary_cases() -> void:
	# AC-16: (a) awaiting refill, (b) none of three fit, (c) one of three fits.
	var b := _checker()
	var bar := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	assert_bool(BoardRules.no_moves(b, _pieces([]))).is_false()
	assert_bool(BoardRules.no_moves(b, _pieces([_domino(), _square(), bar]))).is_true()
	assert_bool(BoardRules.no_moves(b, _pieces([_domino(), BoardFixture.single(), bar]))).is_false()


func test_no_moves_does_not_modify_board() -> void:
	var b := _checker()
	var before := b.copy()
	BoardRules.no_moves(b, _pieces([_domino()]))
	assert_bool(b.equals(before)).is_true()
