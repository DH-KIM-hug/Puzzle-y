## crew-definition AC-02 … AC-09 — registry load-time validation and lint,
## using in-memory test crews (no files).
extends GdUnitTestSuite

const I3_H: Array = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
const I3_V: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const O4: Array = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]

var _slot := 0


## Builds a crew with two unique (signature) shapes unless [param shapes] is given.
## [param shapes]: Array of [shape_id, offsets, weight, face_cell].
func _crew(id: StringName, prim: StringName = &"clear_cross", params: Dictionary = {&"reach": -1}, shapes: Array = []) -> CrewDef:
	_slot += 1
	var c := CrewDef.new()
	c.id = id
	c.colour_slot = _slot
	c.silhouette_feature = StringName("sil_%s" % id)
	c.body_pattern = StringName("pat_%s" % id)
	c.ability_name_key = "X"
	var list := shapes
	if list.is_empty():
		list = [[StringName("%s_h" % id), I3_H, 1, -1], [StringName("%s_o" % id), O4, 1, -1]]
	var entries: Array[CrewShapeEntry] = []
	for s: Array in list:
		var e := CrewShapeEntry.new()
		e.shape = PieceShape.make(s[0], s[1])
		e.weight = s[2]
		e.face_cell = s[3]
		entries.append(e)
	c.shapes = entries
	var step := AbilityStep.new()
	step.primitive = prim
	step.params = params
	var ab := CrewAbility.new()
	ab.ability_id = StringName("%s_ability" % id)
	var steps: Array[AbilityStep] = [step]
	ab.steps = steps
	c.ability = ab
	return c


func _registry(list: Array) -> CrewRegistry:
	var r := CrewRegistry.new()
	var typed: Array[CrewDef] = []
	for c: CrewDef in list:
		typed.append(c)
	r.crews = typed
	return r


func before_test() -> void:
	_slot = 0


func test_valid_two_crew_registry_loads_clean() -> void:
	var r := _registry([_crew(&"aa"), _crew(&"bb", &"clear_area", {&"radius": 1})])
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_array(Array(r.warnings())).is_empty()
	assert_object(r.abilities()).is_not_null()


func test_unknown_primitive_names_crew_and_field() -> void:
	# AC-02
	var errs := _registry([_crew(&"spiral", &"clear_spiral", {})]).load_and_validate()
	var joined := " | ".join(errs)
	assert_str(joined).contains("spiral").contains("primitive").contains("clear_spiral")


func test_bad_shapes_are_load_errors() -> void:
	# AC-03: 7 cells / disconnected / not normalised.
	var seven := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6)]
	var split := [Vector2i(0, 0), Vector2i(0, 2)]
	var unnorm := [Vector2i(1, 1), Vector2i(1, 2)]
	for offs: Array in [seven, split, unnorm]:
		_slot = 0
		var c := _crew(&"bad", &"clear_cross", {&"reach": -1}, [[&"bad_x", offs, 1, -1], [&"bad_o", O4, 1, -1]])
		assert_int(_registry([c]).load_and_validate().size()).is_greater(0)


func test_duplicate_shape_zero_weight_and_face_cell_bounds() -> void:
	# AC-04
	var dup := _crew(&"dup", &"clear_cross", {&"reach": -1}, [[&"dup_h", I3_H, 1, -1], [&"dup_h2", I3_H, 1, -1]])
	assert_str(" ".join(_registry([dup]).load_and_validate())).contains("duplicate shape")
	var zero := _crew(&"zero", &"clear_cross", {&"reach": -1}, [[&"zero_h", I3_H, 0, -1], [&"zero_o", O4, 1, -1]])
	assert_str(" ".join(_registry([zero]).load_and_validate())).contains("weight")
	var face_n := _crew(&"facen", &"clear_cross", {&"reach": -1}, [[&"facen_h", I3_H, 1, 3], [&"facen_o", O4, 1, -1]])
	assert_str(" ".join(_registry([face_n]).load_and_validate())).contains("face_cell")
	var face_last := _crew(&"facel", &"clear_cross", {&"reach": -1}, [[&"facel_h", I3_H, 1, 2], [&"facel_o", O4, 1, -1]])
	assert_array(Array(_registry([face_last]).load_and_validate())).is_empty()


func test_each_duplicated_identity_field_is_a_load_error() -> void:
	# AC-05: id / colour_slot / silhouette_feature / body_pattern, one at a time.
	for field: String in ["id", "colour_slot", "silhouette_feature", "body_pattern"]:
		_slot = 0
		var a := _crew(&"aa")
		var b := _crew(&"bb", &"clear_area", {&"radius": 1})
		b.set(field, a.get(field))
		var errs := _registry([a, b]).load_and_validate()
		assert_str(" | ".join(errs)).override_failure_message(field).contains(field)


func test_fill_step_requires_fill_visual() -> void:
	# AC-06
	var c := _crew(&"chick", &"lay_eggs_in_own_line", {&"count": 3})
	assert_str(" ".join(_registry([c]).load_and_validate())).contains("fill_visual")
	c.fill_visual = &"egg"
	assert_array(Array(_registry([c]).load_and_validate())).is_empty()


func test_size_only_difference_across_rarity_is_error_same_rarity_is_one_warning() -> void:
	# AC-07
	var common := _crew(&"aa", &"clear_cross", {&"reach": -1})
	var rare := _crew(&"bb", &"clear_cross", {&"reach": 2})
	rare.rarity = CrewDef.Rarity.RARE
	assert_str(" ".join(_registry([common, rare]).load_and_validate())).contains("size parameters")
	rare.rarity = CrewDef.Rarity.COMMON
	var r := _registry([common, rare])
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_int(r.warnings().size()).is_equal(1)


func test_single_signature_shape_is_lint_warning() -> void:
	# AC-08: crew aa shares "shared" with bb and owns only one other shape.
	var a := _crew(&"aa", &"clear_cross", {&"reach": -1}, [[&"shared", I3_V, 1, -1], [&"aa_o", O4, 1, -1]])
	var b := _crew(&"bb", &"clear_area", {&"radius": 1}, [[&"shared", I3_V, 1, -1], [&"bb_h", I3_H, 1, -1], [&"bb_o", O4, 1, -1]])
	var r := _registry([a, b])
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_int(r.warnings().size()).is_equal(1)
	assert_str(r.warnings()[0]).contains("signature shapes < 2").contains("aa")


func test_ability_table_covers_whole_registry() -> void:
	# AC-09: table holds every crew, not only a team of three.
	var list := [_crew(&"aa"), _crew(&"bb", &"clear_area", {&"radius": 1}), _crew(&"cc", &"clear_diagonals", {&"reach": -1}),
		_crew(&"dd", &"clear_line", {&"axis": &"row"})]
	var r := _registry(list)
	assert_array(Array(r.load_and_validate())).is_empty()
	assert_array(r.abilities().crew_ids()).is_equal([&"aa", &"bb", &"cc", &"dd"])
	var steps: Array = r.abilities().steps_for(&"cc")
	assert_str(String(steps[0][AbilityTable.K_PRIMITIVE])).is_equal("clear_diagonals")
	assert_bool(steps.is_read_only()).is_true()


func test_invalid_registry_exposes_no_ability_table() -> void:
	var r := _registry([_crew(&"Bad-Id")])
	assert_str(" ".join(r.load_and_validate())).contains("id")
	assert_object(r.abilities()).is_null()
