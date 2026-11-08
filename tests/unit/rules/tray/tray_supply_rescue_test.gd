## tray-supply AC-11 … AC-13 — minimal pre-reveal rescue (rules 13–15, F5).
extends GdUnitTestSuite


func test_f5_board_rescues_exactly_one_nyangi_or_piyak_slot() -> void:
	# Arrange (AC-11): committed seed whose candidates are [nyangi I4_H, gomgom O4, piyak D2_V].
	var g: Dictionary = TrayFixture.golden("rescue_f5.golden.json")
	var board := TrayFixture.board(g["board"])
	var team := TrayFixture.team(g["team"])
	var stage_seed := int(g["stage_seed"])
	var off := TrayFixture.cfg()
	off.rescue_enabled = false
	var cand := TraySupplyRules.refill(TraySupplyRules.init_state(team, off, stage_seed, TrayFixture.registry()), board, TraySupplyRules.BUDGET_UNLIMITED)
	assert_array(TrayFixture.describe_slots(cand.state)).is_equal(g["candidates"])
	for p: PieceInstance in cand.pieces:
		assert_bool(BoardRules.any_fit(board, p)).is_false()
	# Act
	var r := TraySupplyRules.refill(TraySupplyRules.init_state(team, TrayFixture.cfg(), stage_seed, TrayFixture.registry()), board, TraySupplyRules.BUDGET_UNLIMITED)
	# Assert
	var changed := []
	for x: int in 3:
		if TrayFixture.describe(r.state.slots[x]) != TrayFixture.describe(cand.state.slots[x]):
			changed.append(x)
	assert_int(changed.size()).is_equal(1)
	var slot: int = changed[0]
	var swapped: PieceInstance = r.state.slots[slot]
	assert_bool([&"nyangi", &"piyak"].has(swapped.crew_id)).is_true()
	assert_bool(BoardRules.any_fit(board, swapped)).is_true()
	for x: int in 3:
		if (r.state.slots[x] as PieceInstance).crew_id == &"gomgom":
			assert_str(String((r.state.slots[x] as PieceInstance).shape.id)).is_equal("O4")
	assert_int(r.rescued.size()).is_equal(1)
	var rec: Dictionary = r.rescued[0]
	assert_int(rec[TrayRefill.K_SLOT]).is_equal(int(g["rescued"]["slot"]))
	assert_str(String(rec[TrayRefill.K_FROM_SHAPE])).is_equal(g["rescued"]["from_shape"])
	assert_str(String(rec[TrayRefill.K_TO_SHAPE])).is_equal(g["rescued"]["to_shape"])
	assert_int(rec[TrayRefill.K_REFILL_INDEX]).is_equal(0)
	assert_array(TrayFixture.describe_slots(r.state)).is_equal(g["tray"])


func test_no_team_shape_fits_means_no_rescue_and_no_moves() -> void:
	# AC-12: isolated single empties, team without a 1-cell shape.
	var board := TrayFixture.board("isolated_singles.txt")
	var team := TrayFixture.team([&"nyangi", &"gomgom", &"gaegul"])
	var before_cfg := TrayFixture.cfg()
	before_cfg.rescue_enabled = false
	var plain := TraySupplyRules.refill(TraySupplyRules.init_state(team, before_cfg, 11, TrayFixture.registry()), board, TraySupplyRules.BUDGET_UNLIMITED)
	var r := TraySupplyRules.refill(TraySupplyRules.init_state(team, TrayFixture.cfg(), 11, TrayFixture.registry()), board, TraySupplyRules.BUDGET_UNLIMITED)
	assert_array(TrayFixture.describe_slots(r.state)).is_equal(TrayFixture.describe_slots(plain.state))
	assert_array(r.rescued).is_empty()
	assert_bool(BoardRules.no_moves(board, r.state.pieces())).is_true()


func test_rescue_on_third_refill_leaves_later_refills_unchanged() -> void:
	# AC-13: run B rescues on refill index 2; refills 3.. equal run A.
	var registry := TrayFixture.registry()
	var tight := TrayFixture.board("isolated_singles.txt")
	var trays_a := []
	var trays_b := []
	var rescued_b := 0
	var a := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, registry)
	var b := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, registry)
	for i: int in 8:
		var ra := TraySupplyRules.refill(a, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
		var rb := TraySupplyRules.refill(b, tight if i == 2 else BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
		trays_a.append(TrayFixture.describe_slots(ra.state))
		trays_b.append(TrayFixture.describe_slots(rb.state))
		rescued_b += rb.rescued.size()
		a = TrayFixture.consume_all(ra.state)
		b = TrayFixture.consume_all(rb.state)
	assert_int(rescued_b).is_equal(1)
	assert_array(trays_b[2]).is_not_equal(trays_a[2])
	assert_array(trays_b.slice(3)).is_equal(trays_a.slice(3))


func test_rescue_disabled_keeps_unplaceable_candidates() -> void:
	# rule F table: rescue_enabled = false → pure supply.
	var g: Dictionary = TrayFixture.golden("rescue_f5.golden.json")
	var cfg := TrayFixture.cfg()
	cfg.rescue_enabled = false
	var r := TraySupplyRules.refill(TraySupplyRules.init_state(TrayFixture.team(g["team"]), cfg, int(g["stage_seed"]), TrayFixture.registry()),
			TrayFixture.board(g["board"]), TraySupplyRules.BUDGET_UNLIMITED)
	assert_array(r.rescued).is_empty()
