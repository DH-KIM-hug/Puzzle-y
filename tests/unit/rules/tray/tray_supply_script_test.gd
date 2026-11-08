## tray-supply AC-14 … AC-16 — stage override tray_script (rules 19–22).
extends GdUnitTestSuite

const K_SHAPE := TraySupplyRules.K_SHAPE
const K_CREW := TraySupplyRules.K_CREW
const K_FACE := TraySupplyRules.K_FACE


func _tutorial_cfg() -> TrayRules:
	var cfg := TrayFixture.cfg()
	cfg.allow_faceless_pieces = true
	cfg.tray_script = [
		[{K_SHAPE: &"D1", K_CREW: null, K_FACE: null}],
		[{K_SHAPE: &"I3_H", K_CREW: 0, K_FACE: 1}],
		[{K_SHAPE: &"*", K_CREW: 1}, {K_SHAPE: &"*", K_CREW: 2}],
	]
	return cfg


func test_script_entry_fills_as_written_without_rescue() -> void:
	# Arrange (AC-14): nothing in the scripted entry fits the board.
	var cfg := TrayFixture.cfg()
	cfg.tray_script = [[{K_SHAPE: &"I4_H", K_CREW: 0, K_FACE: 0}, {K_SHAPE: &"O4", K_CREW: 1, K_FACE: 3}, {K_SHAPE: &"D2_V", K_CREW: 2, K_FACE: 1}]]
	var board := TrayFixture.board("isolated_singles.txt")
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, cfg, 1, TrayFixture.registry())
	# Act
	var r := TraySupplyRules.refill(s, board, TraySupplyRules.BUDGET_UNLIMITED)
	# Assert
	assert_bool(r.scripted).is_true()
	assert_array(r.rescued).is_empty()
	assert_array(TrayFixture.describe_slots(r.state)).is_equal(["I4_H:nyangi:0", "O4:gomgom:3", "D2_V:piyak:1"])
	assert_bool(BoardRules.no_moves(board, r.state.pieces())).is_true()


func test_tutorial_script_then_generation_from_crew_bag_zero() -> void:
	# Arrange (AC-15)
	var registry := TrayFixture.registry()
	var team := TrayFixture.DEFAULT_TEAM
	var stage_seed := 31
	var s := TraySupplyRules.init_state(team, _tutorial_cfg(), stage_seed, registry)
	assert_array(Array(s.errors)).is_empty()
	# Act
	var trays := []
	var states := []
	for i: int in 4:
		var r := TraySupplyRules.refill(s, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
		trays.append(r)
		states.append(TrayFixture.describe_slots(r.state))
		s = TrayFixture.consume_all(r.state)
	# Assert: refills 1–3 are the script.
	assert_array(states[0]).is_equal(["D1::-1", "-", "-"])
	assert_int((trays[0] as TrayRefill).state.status).is_equal(TrayState.Status.PARTIAL)
	assert_array(states[1]).is_equal(["I3_H:nyangi:1", "-", "-"])
	var gom := registry.get_crew(&"gomgom")
	var bag := DetRng.shuffle(_entry_tokens(gom), TraySupplyRules.shape_bag_seed(stage_seed, &"gomgom", 0))
	var third: TrayRefill = trays[2]
	assert_str(String(third.pieces[0].crew_id)).is_equal("gomgom")
	assert_str(String(third.pieces[0].shape.id)).is_equal(String(gom.shapes[bag[0]].shape.id))
	assert_str(String(third.pieces[1].crew_id)).is_equal("piyak")
	assert_bool((trays[2] as TrayRefill).scripted).is_true()
	# Refill 4 = generated, crew bag 0 (scripts do not consume the crew bag) and
	# gomgom's shape bag continues after the '*' draw.
	var fourth: TrayRefill = trays[3]
	assert_bool(fourth.scripted).is_false()
	var expected_crews := DetRng.shuffle([&"nyangi", &"gomgom", &"piyak"], TraySupplyRules.crew_bag_seed(stage_seed, 0))
	assert_array(fourth.pieces.map(func(p: PieceInstance) -> StringName: return p.crew_id)).is_equal(expected_crews)
	for p: PieceInstance in fourth.pieces:
		if p.crew_id == &"gomgom":
			assert_str(String(p.shape.id)).is_equal(String(gom.shapes[bag[1]].shape.id))


func test_loop_after_script_repeats_the_script() -> void:
	# rule 20 LOOP
	var cfg := TrayFixture.cfg()
	cfg.tray_script = [[{K_SHAPE: &"I3_H", K_CREW: 0, K_FACE: 0}], [{K_SHAPE: &"O4", K_CREW: 1, K_FACE: 0}]]
	cfg.after_script = TrayRules.AfterScript.LOOP
	var played := TrayFixture.play(TrayFixture.DEFAULT_TEAM, cfg, 2, 5)
	assert_array(played[&"trays"].map(func(t: Array) -> String: return t[0])).is_equal(
			["I3_H:nyangi:0", "O4:gomgom:0", "I3_H:nyangi:0", "O4:gomgom:0", "I3_H:nyangi:0"])


func test_invalid_script_specs_are_load_errors() -> void:
	# AC-16 (+ rule 22 / Edge Cases): each case alone is a load error.
	var cases := {
		"team_slot_3": [[{K_SHAPE: &"I3_H", K_CREW: 3, K_FACE: 0}]],
		"null_crew_without_faceless": [[{K_SHAPE: &"D1", K_CREW: null, K_FACE: null}]],
		"unknown_shape": [[{K_SHAPE: &"Q9", K_CREW: 0, K_FACE: 0}]],
		"direct_crew_without_fixed_team": [[{K_SHAPE: &"I3_H", K_CREW: &"nyangi", K_FACE: 0}]],
		"face_out_of_range": [[{K_SHAPE: &"I3_H", K_CREW: 0, K_FACE: 3}]],
	}
	for name: String in cases:
		var cfg := TrayFixture.cfg()
		cfg.tray_script = cases[name]
		var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, cfg, 1, TrayFixture.registry())
		assert_bool(s.is_valid()).override_failure_message(name).is_false()
	var loop := TrayFixture.cfg()
	loop.after_script = TrayRules.AfterScript.LOOP
	assert_bool(TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, loop, 1, TrayFixture.registry()).is_valid()).is_false()
	assert_bool(TraySupplyRules.init_state(TrayFixture.team([]), TrayFixture.cfg(), 1, TrayFixture.registry()).is_valid()).is_false()


func test_team_slot_shape_outside_crew_pool_is_a_lint_warning() -> void:
	# rule 22 lint
	var cfg := TrayFixture.cfg()
	cfg.tray_script = [[{K_SHAPE: &"O4", K_CREW: 0, K_FACE: 0}]]
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, cfg, 1, TrayFixture.registry())
	assert_bool(s.is_valid()).is_true()
	assert_int(s.warnings.size()).is_equal(1)


func _entry_tokens(def: CrewDef) -> Array:
	var items := []
	for i: int in def.shapes.size():
		for w: int in def.shapes[i].weight:
			items.append(i)
	return items
