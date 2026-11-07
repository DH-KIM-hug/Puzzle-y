## crew-definition AC-01 / AC-15 (starter-crew subset), AC-10 (read-only) and
## ADR-0001 Verification 3 — the real .tres data under assets/data/.
extends GdUnitTestSuite

const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"


func _registry() -> CrewRegistry:
	return load(REGISTRY_PATH)


func test_starter_registry_loads_without_errors_or_warnings() -> void:
	# AC-01 (T0 scope: the three starter crews).
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_array(Array(r.warnings())).is_empty()
	assert_int(r.all().size()).is_equal(3)
	assert_array(r.starter_ids()).is_equal([&"gomgom", &"nyangi", &"piyak"])


func test_starter_abilities_match_gdd_table() -> void:
	# crew-definition rule 14.
	var r := _registry()
	r.load_and_validate()
	var t := r.abilities()
	assert_str(String(t.ability_id_for(&"nyangi"))).is_equal("nyangi_cross_scratch")
	assert_str(String(t.ability_id_for(&"gomgom"))).is_equal("gomgom_bear_hug")
	assert_str(String(t.ability_id_for(&"piyak"))).is_equal("piyak_lay_eggs")
	var n: Dictionary = t.steps_for(&"nyangi")[0]
	assert_str(String(n[AbilityTable.K_PRIMITIVE])).is_equal("clear_cross")
	assert_int(n[AbilityTable.K_PARAMS][&"reach"]).is_equal(-1)
	var p: Dictionary = t.steps_for(&"piyak")[0]
	assert_int(p[AbilityTable.K_PARAMS][&"count"]).is_equal(3)
	assert_str(String(p[AbilityTable.K_PARAMS][&"prefer"])).is_equal("fuller")
	assert_str(String(r.get_crew(&"piyak").fill_visual)).is_equal("egg")


func test_tres_integer_params_load_as_int() -> void:
	# ADR-0001 Verification Required 3: the validator relies on TYPE_INT.
	var r := _registry()
	for crew: CrewDef in r.all():
		for step: AbilityStep in crew.ability.steps:
			for key: Variant in step.params:
				var v: Variant = step.params[key]
				if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
					assert_int(typeof(v)).override_failure_message("%s.%s" % [crew.id, key]).is_equal(TYPE_INT)


func test_expected_piece_size_and_shape_probability() -> void:
	# AC-15 (starter subset): E = 3.33 / 4.75 / 2.00 → ×100 integer; p(I3_H | nyangi) = 3/12.
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"nyangi"))).is_equal(333)
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"gomgom"))).is_equal(475)
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"piyak"))).is_equal(200)
	var total := 0
	var i3h := 0
	for e: CrewShapeEntry in r.get_crew(&"nyangi").shapes:
		total += e.weight
		if e.shape.id == &"I3_H":
			i3h = e.weight
	assert_int(i3h * 100 / total).is_equal(25)


func test_all_starter_shapes_pass_board_rules_and_faces_are_tray_chosen() -> void:
	var r := _registry()
	var config: BoardConfig = load("res://assets/data/rules/board_rules.tres")
	for crew: CrewDef in r.all():
		for e: CrewShapeEntry in crew.shapes:
			assert_array(Array(BoardRules.validate_shape(e.shape, config))).is_empty()
			assert_int(e.face_cell).is_equal(-1)


func test_crew_resources_unchanged_after_resolving() -> void:
	# AC-10 (reduced to a unit check): resolving with the registry's table never
	# writes to the CrewDef resources.
	var r := _registry()
	r.load_and_validate()
	var before := []
	for c: CrewDef in r.all():
		before.append(var_to_str(c.ability.steps[0].params) + String(c.ability.ability_id))
	var ctx := ResolveContext.make(r.abilities(), load("res://assets/data/rules/chain_rules.tres"))
	var piece := BoardFixture.piece([Vector2i(0, 0)], &"piyak", 0)
	ChainResolver.resolve(BoardFixture.board(ChainFixture.PROTOTYPE_DOMINO), piece, Vector2i(7, 3), ctx)
	var after := []
	for c: CrewDef in r.all():
		after.append(var_to_str(c.ability.steps[0].params) + String(c.ability.ability_id))
	assert_array(after).is_equal(before)


func test_rule_resources_load_with_gdd_start_values() -> void:
	var board: BoardConfig = load("res://assets/data/rules/board_rules.tres")
	var chain: ChainRules = load("res://assets/data/rules/chain_rules.tres")
	assert_int(board.board_width).is_equal(8)
	assert_int(board.max_piece_cells).is_equal(6)
	assert_int(chain.depth_cap).is_equal(6)
	assert_int(chain.max_waves_guard()).is_equal(7)
	assert_array(Array(chain.validate())).is_empty()
