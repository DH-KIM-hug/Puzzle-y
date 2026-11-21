## design/gdd/obstacles.md AC-O11 (rule 16, V1–V5) and rule 6 (modifier schema).
extends GdUnitTestSuite

const EMPTY8 := "........"


func _rows(overrides: Dictionary) -> Array:
	var rows: Array = []
	for r: int in 8:
		rows.append(overrides.get(r, EMPTY8))
	return rows


func _errors(b: BoardState) -> PackedStringArray:
	return ObstacleRules.validate_obstacles(b, ObstacleFixture.cfg(), ObstacleFixture.known_crews())


func _assert_rejected(b: BoardState, rule: String, cell_text: String) -> void:
	var errs := _errors(b)
	assert_int(errs.size()).override_failure_message("%s not rejected" % rule).is_greater(0)
	var joined := " | ".join(errs)
	assert_str(joined).contains(rule)
	assert_str(joined).contains(cell_text)


func test_valid_obstacle_board_passes() -> void:
	# Arrange: 3 stones in a row, 2-layer ice, frozen nyangi face.
	var b := ObstacleFixture.board(_rows({2: "SSS.....", 5: "..#N...."}), {Vector2i(5, 2): 2, Vector2i(5, 3): 1})
	# Act / Assert
	assert_array(_errors(b)).is_empty()


func test_four_stones_in_a_row_is_v1() -> void:
	_assert_rejected(ObstacleFixture.board(_rows({4: "SSSS...."})), "V1", "row 4")


func test_ice_on_stone_is_v2() -> void:
	var b := ObstacleFixture.board(_rows({1: "S......."}))
	b.set_modifiers(b.index_of(1, 0), PackedInt32Array([ObstacleRules.MOD_ICE, 1]))
	_assert_rejected(b, "V2", "(1, 0)")


func test_three_layer_ice_is_v3() -> void:
	_assert_rejected(ObstacleFixture.board(_rows({6: "...#...."}), {Vector2i(6, 3): 3}), "V3", "(6, 3)")


func test_two_layer_frozen_face_is_v3() -> void:
	_assert_rejected(ObstacleFixture.board(_rows({6: "...G...."}), {Vector2i(6, 3): 2}), "V3", "(6, 3)")


func test_ice_on_egg_is_v4() -> void:
	_assert_rejected(ObstacleFixture.board(_rows({0: ".E......"}), {Vector2i(0, 1): 1}), "V4", "(0, 1)")


func test_frozen_face_of_unregistered_crew_is_v5() -> void:
	# 'X' = gaegul, absent from the test registry ids.
	_assert_rejected(ObstacleFixture.board(_rows({3: "..X....."}), {Vector2i(3, 2): 1}), "V5", "(3, 2)")


func test_unknown_or_duplicate_modifier_is_rule_6() -> void:
	var b := ObstacleFixture.board(_rows({3: "##......"}))
	b.set_modifiers(b.index_of(3, 0), PackedInt32Array([9, 1]))
	b.set_modifiers(b.index_of(3, 1), PackedInt32Array([ObstacleRules.MOD_ICE, 1, ObstacleRules.MOD_ICE, 1]))
	var joined := " | ".join(_errors(b))
	assert_str(joined).contains("unknown modifier")
	assert_str(joined).contains("more than one ice")


func test_pre_clear_hook_strips_one_layer_and_target_filter_skips_stones() -> void:
	# Rules 7, 9 directly on the hooks.
	var b := ObstacleFixture.board(_rows({0: "S##....."}), {Vector2i(0, 1): 2})
	var keep := ObstacleRules.pre_clear(b, b.index_of(0, 1))
	assert_bool(keep[&"keep"]).is_true()
	assert_int(ObstacleRules.ice_in(keep[&"modifiers"])).is_equal(1)
	assert_bool(ObstacleRules.pre_clear(b, b.index_of(0, 2))[&"keep"]).is_false()
	assert_bool(ObstacleRules.target_filter(b, b.index_of(0, 0), &"clear_area")).is_false()
	assert_bool(ObstacleRules.target_filter(b, b.index_of(0, 1), &"clear_area")).is_true()


func test_config_resource_has_gdd_start_values() -> void:
	var cfg: ObstacleConfig = load("res://assets/data/rules/obstacle_rules.tres")
	assert_int(cfg.ice_max_layers).is_equal(2)
	assert_int(cfg.frozen_face_layers).is_equal(1)
	assert_int(cfg.max_stones_per_line).is_equal(3)
	assert_array(cfg.validate()).is_empty()
