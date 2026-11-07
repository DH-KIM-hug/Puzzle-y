## chain-resolver AC-01, AC-02, AC-03, AC-18 (domino_ng part), AC-23.
extends GdUnitTestSuite


func test_placement_without_lines_emits_placed_and_chain_end_only() -> void:
	# Arrange (AC-01)
	var b := BoardFixture.empty()
	# Act
	var res := ChainResolver.resolve(b, BoardFixture.single(), Vector2i(0, 0), ChainFixture.ctx())
	# Assert
	assert_array(ChainFixture.type_names(res)).is_equal(["PLACED", "CHAIN_END"])
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(0)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(0)
	assert_bool(res.final_board.equals(BoardRules.place(b, BoardFixture.single(), Vector2i(0, 0), 0))).is_true()


func test_resolve_does_not_mutate_input_and_repeats_identically() -> void:
	# Arrange (AC-02)
	var b := BoardFixture.board(ChainFixture.DOMINO_NG)
	var before := b.copy()
	var piece := BoardFixture.single()
	var ctx := ChainFixture.ctx()
	# Act
	var first := ChainResolver.resolve(b, piece, Vector2i(7, 3), ctx)
	var second := ChainResolver.resolve(b, piece, Vector2i(7, 3), ctx)
	# Assert
	assert_bool(b.equals(before)).is_true()
	assert_str(ChainFixture.signature(first)).is_equal(ChainFixture.signature(second))
	assert_bool(first.final_board.equals(second.final_board)).is_true()


func test_domino_nyangi_then_gomgom_gives_depth_two_three_waves() -> void:
	# Arrange (AC-03)
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	# Assert
	assert_array(ChainFixture.activations(res)).is_equal([
		[Vector2i(7, 5), 1, 1],
		[Vector2i(4, 5), 2, 2],
	])
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(2)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(3)
	var cleared := res.events_of(ChainEvent.Type.CELLS_CLEARED)
	assert_int(cleared.size()).is_equal(3)
	assert_int((cleared[0].data[ChainEvent.K_CELLS] as Array).size()).is_equal(8)
	assert_array(ChainFixture.cleared_cells(cleared[1])).is_equal([
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)])
	assert_array(ChainFixture.cleared_cells(cleared[2])).is_equal([
		Vector2i(3, 4), Vector2i(3, 6), Vector2i(4, 4), Vector2i(4, 6), Vector2i(5, 4), Vector2i(5, 6)])
	assert_int(res.final_board.filled_count()).is_equal(0)


func test_domino_golden_event_sequence() -> void:
	# AC-03 golden (inline): exact type/wave sequence.
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	var seq := []
	for e: ChainEvent in res.events:
		seq.append("%s@%d" % [e.type_name(), e.wave])
	assert_array(seq).is_equal([
		"PLACED@-1",
		"WAVE_BEGIN@0", "CELLS_CLEARED@0", "FACE_ACTIVATED@0", "ABILITY_EFFECT@0",
		"WAVE_BEGIN@1", "CELLS_CLEARED@1", "FACE_ACTIVATED@1", "ABILITY_EFFECT@1",
		"WAVE_BEGIN@2", "CELLS_CLEARED@2",
		"CHAIN_END@-1",
	])
	var w1: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[1]
	assert_array(w1.data[ChainEvent.K_CAUSES]).is_equal([ChainEvent.CAUSE_ABILITY])
	assert_int(res.summary[ChainEvent.K_CELLS_CLEARED_TOTAL]).is_equal(20)
	assert_int(res.summary[ChainEvent.K_LINES_CLEARED_TOTAL]).is_equal(1)
	assert_bool(res.summary[ChainEvent.K_CAP_REACHED]).is_false()
	assert_int(res.summary[ChainEvent.K_BOARD_HASH]).is_equal(res.final_board.board_hash())


func test_invalid_placement_overlap_reports_error_and_keeps_board() -> void:
	# AC-23 overlap
	var b := BoardFixture.board(ChainFixture.DOMINO_NG)
	var before := b.copy()
	var holder := {}
	await assert_error(func() -> void:
		holder.res = ChainResolver.resolve(b, BoardFixture.single(), Vector2i(7, 0), ChainFixture.ctx())
	).is_push_error(ChainResolver.ERR_INVALID_PLACEMENT)
	var res: ChainResult = holder.res
	assert_bool(res.is_valid()).is_false()
	assert_array(res.events).is_empty()
	assert_bool(b.equals(before)).is_true()


func test_invalid_placement_off_board_reports_error() -> void:
	# AC-23 off-board
	var b := BoardFixture.empty()
	var bar := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1)])
	await assert_error(func() -> void:
		ChainResolver.resolve(b, bar, Vector2i(0, 7), ChainFixture.ctx())
	).is_push_error(ChainResolver.ERR_INVALID_PLACEMENT)
	assert_int(b.filled_count()).is_equal(0)
