## Authoring helper for the 10 MVP stages (design/gdd/stage-goals.md rule G
## table). Writes assets/data/stages/stage_1_N.tres and catalog.tres. The .tres
## files are the source of truth once written — rerun only to re-author, then
## review the diff and re-solve (tests/fixtures/generators/solve_stages.gd).
##   godot --headless --path . -s res://tools/stages/gen_mvp_stages.gd
## All goal / piece / star values are the GDD's tuning targets (‡); deviations
## are commented at the stage that has them.
extends SceneTree

const OUT_DIR := "res://assets/data/stages/"

const T := {&"type": &"TILE"}
const STONE := {&"type": &"STONE"}


func _init() -> void:
	var stages: Array[StageDef] = [_s1_1(), _s1_2(), _s1_3(), _s1_4(), _s1_5(), _s1_6(), _s1_7(), _s1_8(), _s1_9(), _s1_10()]
	var catalog := StageCatalog.new()
	for i: int in stages.size():
		var path := OUT_DIR + "stage_1_%d.tres" % (i + 1)
		var err := ResourceSaver.save(stages[i], path)
		if err != OK:
			push_error("save %s failed: %d" % [path, err])
		catalog.stages.append(load(path))
	ResourceSaver.save(catalog, OUT_DIR + "catalog.tres")
	print("wrote %d stages" % stages.size())
	quit()


static func _face(crew: StringName) -> Dictionary:
	return {&"type": &"TILE", &"crew_id": crew, &"is_face": true}


static func _tile(crew: StringName) -> Dictionary:
	return {&"type": &"TILE", &"crew_id": crew}


static func _ice(layers: int, base: Dictionary = T) -> Dictionary:
	var d := base.duplicate()
	d[&"modifiers"] = [{&"kind": &"ice", &"layers": layers}]
	return d


static func _base(id: String, rows: Array, legend: Dictionary, goals: Array[GoalDef], limit: int, stars: Array, number: int) -> StageDef:
	var s := StageDef.new()
	s.id = StringName(id)
	s.name_key = "STAGE_%s_NAME" % id.replace("-", "_")
	s.board_rows = PackedStringArray(rows)
	s.cell_legend = legend
	s.goals = goals
	s.piece_limit = limit
	s.star_points = PackedInt32Array(stars)
	s.stage_seed = 1100 + number  # rule G common value: 1100 + number
	s.tray_seed_mode = TrayRules.SeedMode.FIXED
	s.rescue_enabled = true
	s.preview_detail = PreviewSettings.Detail.FULL
	s.goal_markers = true
	s.team_rule = TeamRule.make()
	s.recommended_team = [&"nyangi", &"gomgom", &"piyak"]
	return s


static func _fixed(ids: Array[StringName]) -> TeamRule:
	return TeamRule.make(ids.size(), ids)


func _s1_1() -> StageDef:
	# Lines clear when full: faceless pieces only, two 6-cell rows.
	var s := _base("1-1", ["........", "........", "........", "........", "........", "........", "###..###", "#..#####"],
			{"#": T}, [GoalDef.make(GoalDef.Type.SCORE, 160)], 8, [600, 750], 1)
	s.team_rule = _fixed([&"nyangi"])
	s.recommended_team = [&"nyangi"]
	s.allow_faceless_pieces = true
	s.tray_script = [[{&"shape": &"I3_H", &"crew": null, &"face": null}, {&"shape": &"D2_H", &"crew": null, &"face": null}, {&"shape": &"D1", &"crew": null, &"face": null}]]
	s.after_script = TrayRules.AfterScript.LOOP
	s.show_predicted_score = true  # rule G: only 1-1
	return s


func _s1_2() -> StageDef:
	# Faces are switches: row 7 has 5 cells, column 3 scattered cells for the cross.
	var s := _base("1-2", ["........", "...#....", "........", "...#....", "........", "...#....", "........", "#####..."],
			{"#": T}, [GoalDef.make(GoalDef.Type.CHAIN, 2, [], 1)], 8, [700, 1000], 2)
	s.team_rule = _fixed([&"nyangi"])
	s.recommended_team = [&"nyangi"]
	s.tray_script = [[{&"shape": &"I3_H", &"crew": 0, &"face": 1}, {&"shape": &"*", &"crew": 0, &"face": -1}, {&"shape": &"*", &"crew": 0, &"face": -1}]]
	s.after_script = TrayRules.AfterScript.GENERATE
	return s


func _s1_3() -> StageDef:
	# First two-step chain: the GDD example board (nyangi cross wakes gomgom).
	var s := _base("1-3", ["........", "........", "...ggG..", "...ggg..", "........", "........", "nnnnn.nn", "........"],
			{"g": _tile(&"gomgom"), "G": _face(&"gomgom"), "n": _tile(&"nyangi")},
			[GoalDef.make(GoalDef.Type.CHAIN, 1, [], 2)], 10, [900, 1300], 3)
	s.team_rule = _fixed([&"nyangi", &"gomgom"])
	s.recommended_team = [&"nyangi", &"gomgom"]
	s.tray_script = [[{&"shape": &"I3_V", &"crew": 0, &"face": 2}, {&"shape": &"*", &"crew": 1, &"face": -1}, {&"shape": &"*", &"crew": 0, &"face": -1}]]
	s.after_script = TrayRules.AfterScript.GENERATE
	return s


func _s1_4() -> StageDef:
	# Target cells: 6 near two corners, on the top and bottom rows.
	var s := _base("1-4", ["...#####", "........", "........", "...#....", "....#...", "........", "........", "#####..."],
			{"#": T}, [GoalDef.make(GoalDef.Type.CLEAR_CELLS, 6)], 12, [1200, 1700], 4)
	s.target_cells = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7)]
	s.team_rule = _fixed([&"nyangi", &"gomgom"])
	s.recommended_team = [&"nyangi", &"gomgom"]
	return s


func _s1_5() -> StageDef:
	# Three-crew team, piyak eggs: almost empty board with two 7-cell rows.
	# Faces seeded in the two rows so a chain is available early (bot reached only
	# 1332 / 1500 on the bare GDD board — beam 40; see solve_stages.gd).
	return _base("1-5", ["........", "........", "........", "#N#.##G#", "........", "##P##.##", "........", "........"],
			{"#": T, "N": _face(&"nyangi"), "G": _face(&"gomgom"), "P": _face(&"piyak")},
			[GoalDef.make(GoalDef.Type.SCORE, 1500)], 18, [2000, 2600], 5)


func _s1_6() -> StageDef:
	# Eggs re-ignite a line: several 7-cell rows, a nyangi → gomgom → piyak domino waiting.
	# Row 7 needs four scattered cells (no single piece) so the waiting domino costs a build-up (T3).
	return _base("1-6", ["........", "........", "........", "####.GP#", "........", "#.######", "........", "#.#..N.#"],
			{"#": T, "G": _face(&"gomgom"), "P": _face(&"piyak"), "N": _face(&"nyangi")},
			[GoalDef.make(GoalDef.Type.CHAIN, 1, [], 3)], 15, [1500, 2100], 6)


func _s1_7() -> StageDef:
	# Target cells vs the big chain: 8 targets around the four corners.
	var s := _base("1-7", ["###..###", "........", "........", "..G.....", ".....N..", "........", "........", "##..####"],
			{"#": T, "G": _face(&"gomgom"), "N": _face(&"nyangi")},
			[GoalDef.make(GoalDef.Type.CLEAR_CELLS, 8)], 16, [1700, 2400], 7)
	s.target_cells = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 6), Vector2i(0, 7), Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 6), Vector2i(7, 7)]
	return s


func _s1_8() -> StageDef:
	# First obstacle: six 1-layer ice tiles mixed into three rows.
	return _base("1-8", ["........", "........", "........", "........", "........", "#I##I#..", ".I##.#I#", "##I#I#.."],
			{"#": T, "I": _ice(1)}, [GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 6, [&"ice"])], 16, [1800, 2500], 8)


func _s1_9() -> StageDef:
	# Frozen faces (one out-of-team gaegul) + two 2-layer ice tiles; thaw then fire.
	return _base("1-9", ["........", "........", "..D##D..", "........", "....z...", "#.###y##", "........", "#x##w##."],
			{"#": T, "D": _ice(2), "z": _ice(1, _face(&"gaegul")), "y": _ice(1, _face(&"piyak")),
				"x": _ice(1, _face(&"nyangi")), "w": _ice(1, _face(&"gomgom"))},
			[GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 6, [&"ice"]), GoalDef.make(GoalDef.Type.CHAIN, 1, [], 3)], 18, [2000, 2800], 9)


func _s1_10() -> StageDef:
	# Graduation: 4 stones (terrain), 6 target cells and 4 ice tiles in separate zones.
	var s := _base("1-10", ["S......S", "........", "........", "#......#", "#......#", "..I##I..", ".I####I.", "S......S"],
			{"#": T, "S": STONE, "I": _ice(1)},
			[GoalDef.make(GoalDef.Type.CLEAR_CELLS, 6), GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 4, [&"ice"])], 20, [2400, 3300], 10)
	s.target_cells = [Vector2i(0, 3), Vector2i(0, 4), Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 7), Vector2i(4, 7)]
	return s
