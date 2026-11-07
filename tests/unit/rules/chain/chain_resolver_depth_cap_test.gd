## chain-resolver AC-08, AC-09, AC-10 (fixture subset), AC-18 — depth cap as data.
extends GdUnitTestSuite


func _resolve(depth_cap: int) -> ChainResult:
	return ChainFixture.resolve_single(ChainFixture.DEPTH_CHAIN, Vector2i(7, 7), ChainFixture.ctx(depth_cap))


func test_cap_six_fizzles_wave_six_and_stops() -> void:
	# Act (AC-08)
	var res := _resolve(6)
	# Assert
	var stages := ChainFixture.activations(res).map(func(a: Array) -> int: return a[1])
	assert_array(stages).is_equal([1, 2, 3, 4, 5, 6])
	var fizz := res.events_of(ChainEvent.Type.FACE_FIZZLED)
	assert_int(fizz.size()).is_equal(1)
	assert_int(fizz[0].wave).is_equal(6)
	assert_str(String(fizz[0].data[ChainEvent.K_REASON])).is_equal("DEPTH_CAP")
	assert_that(fizz[0].data[ChainEvent.K_CELL]).is_equal(Vector2i(1, 6))
	assert_int(res.events_of(ChainEvent.Type.DEPTH_CAP_REACHED).size()).is_equal(1)
	assert_bool(res.summary[ChainEvent.K_CAP_REACHED]).is_true()
	assert_int(BoardRules.full_lines(res.final_board).count()).is_equal(0)
	# AC-18
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(6)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(7)


func test_depth_cap_reached_is_last_wave_event() -> void:
	var res := _resolve(6)
	var n := res.events.size()
	assert_str(res.events[n - 2].type_name()).is_equal("DEPTH_CAP_REACHED")
	assert_str(res.events[n - 3].type_name()).is_equal("FACE_FIZZLED")
	assert_int(res.events[n - 2].data[ChainEvent.K_WAVE]).is_equal(6)


func test_cap_seven_is_one_past_the_chain_and_not_reached() -> void:
	# AC-08 AND: boundary just above the chain length.
	var res := _resolve(7)
	assert_bool(res.summary[ChainEvent.K_CAP_REACHED]).is_false()
	assert_int(res.events_of(ChainEvent.Type.DEPTH_CAP_REACHED).size()).is_equal(0)
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(7)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(7)


func test_cap_three_from_data_only() -> void:
	# AC-09
	var res := _resolve(3)
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(3)
	var fizz := res.events_of(ChainEvent.Type.FACE_FIZZLED)
	assert_int(fizz.size()).is_equal(1)
	assert_int(fizz[0].wave).is_equal(3)


func test_cap_zero_fizzles_every_wave_zero_face() -> void:
	# AC-09 AND
	var res := _resolve(0)
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(0)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(1)
	assert_int(res.events_of(ChainEvent.Type.FACE_ACTIVATED).size()).is_equal(0)
	assert_int(res.events_of(ChainEvent.Type.FACE_FIZZLED).size()).is_equal(1)


func test_all_stages_equal_wave_plus_one() -> void:
	# AC-18
	for res: ChainResult in [_resolve(6), ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))]:
		for e: ChainEvent in res.events_of(ChainEvent.Type.FACE_ACTIVATED):
			assert_int(e.data[ChainEvent.K_STAGE]).is_equal(e.wave + 1)


func test_wave_count_bounded_by_faces_and_cap_over_named_fixtures() -> void:
	# AC-10 (subset): waves <= min(depth_cap, F_board) + 1 and the guard never trips.
	var cases := [
		[ChainFixture.DEPTH_CHAIN, Vector2i(7, 7)],
		[ChainFixture.DOMINO_NG, Vector2i(7, 3)],
		[ChainFixture.PROTOTYPE_DOMINO, Vector2i(7, 3)],
	]
	for cap: int in [0, 1, 2, 3, 6, 7, 10]:
		for c: Array in cases:
			var b := BoardFixture.board(c[0])
			var faces := 0
			for i: int in b.cell_count():
				if b.kind[i] != CellKind.EMPTY and b.is_face(i):
					faces += 1
			var res := ChainResolver.resolve(b, BoardFixture.single(), c[1], ChainFixture.ctx(cap))
			assert_int(res.summary[ChainEvent.K_WAVES]).is_less_equal(mini(cap, faces) + 1)
			assert_int(res.summary[ChainEvent.K_WAVES]).is_less_equal(ChainFixture.rules(cap).max_waves_guard())
