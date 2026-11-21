## crew-definition AC-01 / AC-15, AC-10 (read-only), rule 14 (MVP crews 1–6) and
## ADR-0001 Verification 3 — the real .tres data under assets/data/.
extends GdUnitTestSuite

const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"


func _registry() -> CrewRegistry:
	return load(REGISTRY_PATH)


func test_mvp_registry_loads_without_errors_or_warnings() -> void:
	# AC-01: the six MVP crews load with 0 errors and 0 lint warnings.
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_array(Array(r.warnings())).is_empty()
	assert_int(r.all().size()).is_equal(6)
	assert_array(r.starter_ids()).is_equal([&"gomgom", &"nyangi", &"piyak"])
	assert_array(r.obtainable_ids()).is_equal([&"gaegul", &"gomgom", &"kkangchong", &"mongsil", &"nyangi", &"piyak"])


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
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"gaegul"))).is_equal(375)
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"kkangchong"))).is_equal(400)
	assert_int(CrewRegistry.expected_cells_x100(r.get_crew(&"mongsil"))).is_equal(325)
	var total := 0
	var i3h := 0
	for e: CrewShapeEntry in r.get_crew(&"nyangi").shapes:
		total += e.weight
		if e.shape.id == &"I3_H":
			i3h = e.weight
	assert_int(i3h * 100 / total).is_equal(25)


func test_all_mvp_shapes_pass_board_rules_and_faces_are_tray_chosen() -> void:
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


# --- crews 4–6 (crew-definition rule 14 table) -------------------------------

## Shape pool of [param crew_id] as {shape id: weight}.
func _weights(r: CrewRegistry, crew_id: StringName) -> Dictionary:
	var out := {}
	for e: CrewShapeEntry in r.get_crew(crew_id).shapes:
		out[String(e.shape.id)] = e.weight
	return out


func test_gaegul_matches_rule_14_row() -> void:
	# Arrange
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	# Act
	var c := r.get_crew(&"gaegul")
	var step: Dictionary = r.abilities().steps_for(&"gaegul")[0]
	# Assert
	assert_int(c.colour_slot).is_equal(4)
	assert_int(c.rarity).is_equal(CrewDef.Rarity.RARE)
	assert_bool(c.starter).is_false()
	assert_str(String(r.abilities().ability_id_for(&"gaegul"))).is_equal("gaegul_x_leap")
	assert_str(String(step[AbilityTable.K_PRIMITIVE])).is_equal("clear_diagonals")
	assert_int(step[AbilityTable.K_PARAMS][&"reach"]).is_equal(-1)
	assert_dict(_weights(r, &"gaegul")).is_equal({"S4_H": 2, "Z4_H": 2, "L3_D": 2, "S4_V": 1, "Z4_V": 1})
	assert_str(String(c.silhouette_feature)).is_equal("lily_pad")
	assert_str(String(c.body_pattern)).is_equal("waves")


func test_kkangchong_matches_rule_14_row() -> void:
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	var c := r.get_crew(&"kkangchong")
	var step: Dictionary = r.abilities().steps_for(&"kkangchong")[0]
	assert_int(c.colour_slot).is_equal(5)
	assert_int(c.rarity).is_equal(CrewDef.Rarity.SPECIAL)
	assert_str(String(r.abilities().ability_id_for(&"kkangchong"))).is_equal("kkangchong_double_hop")
	assert_str(String(step[AbilityTable.K_PRIMITIVE])).is_equal("clear_pattern")
	assert_array(step[AbilityTable.K_PARAMS][&"offsets"]).is_equal([
		Vector2i(-2, -2), Vector2i(-2, 0), Vector2i(-2, 2), Vector2i(0, -2),
		Vector2i(0, 2), Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2)])
	assert_dict(_weights(r, &"kkangchong")).is_equal({"I4_V": 2, "T4_U": 2, "U5": 1, "I3_V": 1})
	assert_str(String(c.silhouette_feature)).is_equal("long_ears")
	assert_str(String(c.body_pattern)).is_equal("checks")


func test_mongsil_matches_rule_14_row() -> void:
	var r := _registry()
	assert_array(Array(r.load_and_validate())).is_empty()
	var c := r.get_crew(&"mongsil")
	var step: Dictionary = r.abilities().steps_for(&"mongsil")[0]
	assert_int(c.colour_slot).is_equal(6)
	assert_int(c.rarity).is_equal(CrewDef.Rarity.RARE)
	assert_str(String(r.abilities().ability_id_for(&"mongsil"))).is_equal("mongsil_wool_cushion")
	assert_str(String(step[AbilityTable.K_PRIMITIVE])).is_equal("lay_eggs_pattern")
	assert_array(step[AbilityTable.K_PARAMS][&"offsets"]).is_equal([
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0)])
	assert_dict(_weights(r, &"mongsil")).is_equal({"X5": 1, "P5_A": 1, "L3_B": 2, "I3_H": 2, "D2_H": 2})
	assert_str(String(c.fill_visual)).is_equal("wool_puff")
	assert_str(String(c.silhouette_feature)).is_equal("wool_curl")
	assert_str(String(c.body_pattern)).is_equal("curls")


func test_new_catalog_shapes_match_gdd_offsets() -> void:
	# crew-definition shape catalog (MVP) rows used only by crews 4–6.
	var expected := {
		"i4_v": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"l3_d": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)],
		"t4_u": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"s4_h": [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1)],
		"z4_h": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"s4_v": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"z4_v": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)],
		"u5": [Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"x5": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)],
		"p5_a": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)],
	}
	for file: String in expected:
		var shape: PieceShape = load("res://assets/data/shapes/%s.tres" % file)
		assert_str(String(shape.id)).is_equal(file.to_upper())
		assert_array(shape.offsets).override_failure_message(file).is_equal(expected[file])


func test_clear_targets_on_full_board_match_ac_11() -> void:
	# AC-11: face (3,3) empty, other 63 filled → targets nyangi 14 · gaegul 13 ·
	# gomgom 8 · kkangchong 8, and kkangchong never hits a distance-1 cell.
	var r := _registry()
	r.load_and_validate()
	var board := BoardState.create(8, 8)
	for i: int in 64:
		board.set_tile(i, &"", false, BoardState.ORIGIN_PIECE, 0)
	var face := board.index_of(3, 3)
	board.set_empty(face)
	var ctx := ResolveContext.make(r.abilities(), load("res://assets/data/rules/chain_rules.tres"))
	var counts := {}
	var hop := PackedInt32Array()
	for crew_id: StringName in [&"nyangi", &"gaegul", &"gomgom", &"kkangchong"]:
		var step: Dictionary = r.abilities().steps_for(crew_id)[0]
		var cells := PrimitiveLibrary.execute(step[AbilityTable.K_PRIMITIVE], step[AbilityTable.K_PARAMS], board, face, ctx)
		var n := 0
		for idx: int in cells:
			if board.kind[idx] != CellKind.EMPTY:
				n += 1
		counts[crew_id] = n
		if crew_id == &"kkangchong":
			hop = cells
	assert_dict(counts).is_equal({&"nyangi": 14, &"gaegul": 13, &"gomgom": 8, &"kkangchong": 8})
	for idx: int in hop:
		var cell := board.cell_of(idx)
		assert_int(maxi(absi(cell.x - 3), absi(cell.y - 3))).is_equal(2)


func test_mongsil_corner_wool_lays_in_offset_order() -> void:
	# AC-12: mongsil face (0,0) cleared, (0,1)/(1,0) empty → wool at (0,0),(0,1),(1,0)
	# in offsets order, TILE(origin EGG, crew mongsil); off-board offsets dropped.
	var r := _registry()
	r.load_and_validate()
	var board := BoardState.create(8, 8)
	var ctx := ResolveContext.make(r.abilities(), load("res://assets/data/rules/chain_rules.tres"))
	var step: Dictionary = r.abilities().steps_for(&"mongsil")[0]
	var cells := PrimitiveLibrary.execute(step[AbilityTable.K_PRIMITIVE], step[AbilityTable.K_PARAMS], board, 0, ctx)
	assert_array(Array(cells)).is_equal([0, 1, 8])
	var after := BoardRules.fill_cells(board, cells, BoardState.ORIGIN_EGG, &"mongsil")
	for idx: int in cells:
		assert_int(after.origin(idx)).is_equal(BoardState.ORIGIN_EGG)
		assert_str(String(after.crew_at(idx))).is_equal("mongsil")
