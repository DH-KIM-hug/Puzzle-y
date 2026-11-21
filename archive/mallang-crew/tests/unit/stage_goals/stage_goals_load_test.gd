## design/gdd/stage-goals.md AC-SG01–SG03 (rules 1–2): StageDef → board, load
## errors naming the field, lint warnings.
extends GdUnitTestSuite

var _env: StageEnv


func before() -> void:
	_env = StageEnv.load_default()


func _ok_stage() -> StageDef:
	return GoalEventFixture.stage([GoalDef.make(GoalDef.Type.CHAIN, 1, [], 3)])


func test_gdd_example_board_loads() -> void:
	# AC-SG01: the 1-3 example rows / legend.
	var s := _ok_stage()
	s.board_rows = PackedStringArray(["........", "........", "...ggG..", "...ggg..", "........", "........", "nnnnn.nn", "........"])
	s.cell_legend = {"g": {&"type": &"TILE", &"crew_id": &"gomgom"}, "G": {&"type": &"TILE", &"crew_id": &"gomgom", &"is_face": true},
			"n": {&"type": &"TILE", &"crew_id": &"nyangi"}}
	var loaded := StageLoader.load_stage(s, _env)
	assert_array(loaded.errors).is_empty()
	var b := loaded.board
	var g := b.index_of(2, 5)
	assert_int(b.kind[g]).is_equal(CellKind.TILE)
	assert_str(String(b.crew_at(g))).is_equal("gomgom")
	assert_bool(b.is_face(g)).is_true()
	assert_int(b.kind[b.index_of(6, 5)]).is_equal(CellKind.EMPTY)
	for i: int in b.cell_count():
		assert_int(b.placement_id[i]).is_equal(0)
	assert_bool(BoardRules.full_lines(b).is_empty()).is_true()


func _variants() -> Array:
	# [label, field fragment expected in the error, mutator]
	return [
		["unknown legend char", "cell_legend", func(s: StageDef) -> void: s.board_rows[0] = "Q......."],
		["7-row board", "board_rows", func(s: StageDef) -> void: s.board_rows.remove_at(7)],
		["no goals", "goals", func(s: StageDef) -> void: s.goals.clear()],
		["three goals", "goals", func(s: StageDef) -> void:
			s.goals.append(GoalDef.make(GoalDef.Type.SCORE, 100))
			s.goals.append(GoalDef.make(GoalDef.Type.CLEAR_CELLS, 1))
			s.target_cells.append(Vector2i(0, 0))],
		["CHAIN depth 7", "depth", func(s: StageDef) -> void: s.goals[0].depth = 7],
		["CLEAR_CELLS without targets", "target_cells", func(s: StageDef) -> void: s.goals[0] = GoalDef.make(GoalDef.Type.CLEAR_CELLS, 1)],
		["target off board", "target_cells", func(s: StageDef) -> void:
			s.goals[0] = GoalDef.make(GoalDef.Type.CLEAR_CELLS, 1)
			s.target_cells.append(Vector2i(8, 0))],
		["target on STONE", "target_cells", func(s: StageDef) -> void:
			s.goals[0] = GoalDef.make(GoalDef.Type.CLEAR_CELLS, 1)
			s.board_rows[0] = "S......."
			s.cell_legend["S"] = {&"type": &"STONE"}
			s.target_cells.append(Vector2i(0, 0))],
		["ice 5 with 4 iced cells", "required", func(s: StageDef) -> void:
			s.goals[0] = GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 5, [&"ice"])
			s.board_rows[2] = "II.II..."
			s.cell_legend["I"] = {&"type": &"TILE", &"modifiers": [{&"kind": &"ice", &"layers": 1}]}],
		["star_points reversed", "star_points", func(s: StageDef) -> void: s.star_points = PackedInt32Array([700, 600])],
		["FIXED without stage_seed", "stage_seed", func(s: StageDef) -> void: s.stage_seed = StageDef.NO_SEED],
		["team_size 2 with one lock", "team_rule.locked", func(s: StageDef) -> void: s.team_rule = TeamRule.make(2, [&"nyangi"])],
	]


func test_each_rule_violation_is_a_load_error_naming_the_field() -> void:
	# AC-SG02: 12 variants.
	var variants := _variants()
	assert_int(variants.size()).is_equal(12)
	assert_array(StageLoader.load_stage(_ok_stage(), _env).errors).is_empty()
	for v: Array in variants:
		var s := _ok_stage()
		(v[2] as Callable).call(s)
		var loaded := StageLoader.load_stage(s, _env)
		assert_bool(loaded.is_valid()).override_failure_message("%s loaded" % v[0]).is_false()
		assert_str(" | ".join(loaded.errors)).override_failure_message("%s: %s" % [v[0], loaded.errors]).contains(v[1])


func test_obstacle_violation_is_a_stage_load_error() -> void:
	# obstacles AC-O11 through the stage path: 4 stones in a row.
	var s := _ok_stage()
	s.board_rows[1] = "SSSS...."
	s.cell_legend["S"] = {&"type": &"STONE"}
	assert_str(" | ".join(StageLoader.load_stage(s, _env).errors)).contains("V1")


func test_s2_at_or_below_score_goal_is_a_lint_warning() -> void:
	# AC-SG03
	var s := GoalEventFixture.stage([GoalDef.make(GoalDef.Type.SCORE, 1500)])
	s.star_points = PackedInt32Array([1400, 2000])
	var loaded := StageLoader.load_stage(s, _env)
	assert_array(loaded.errors).is_empty()
	assert_int(loaded.warnings.size()).is_equal(1)
	assert_str(loaded.warnings[0]).contains("S2")


func test_free_play_stage_loads_without_goals() -> void:
	# round-flow rule 24 (a)
	var loaded := StageLoader.load_stage(StageDef.free_play(1201), _env)
	assert_array(loaded.errors).is_empty()
	assert_int(loaded.board.filled_count()).is_equal(0)
