## Offline generator for tests/fixtures/parity/cases.json (chain-preview AC-P02:
## boards are generated once offline and committed; the test never generates).
## Run, review the diff, commit:
##   godot --headless --path . -s res://tests/fixtures/generators/gen_parity_cases.gd
extends SceneTree

const OUT := "res://tests/fixtures/parity/cases.json"
## Generated boards (seeds 1..N). AC-P02 asks for 50; 24 keeps the suite fast.
const GENERATED_BOARDS := 24
## Generated obstacle boards (seeds 101..). Each gets stones and ice on tiles.
const GENERATED_OBSTACLE_BOARDS := 6
const FACE_LETTERS := ["N", "G", "P", "X", "K", "M"]
const TILE_LETTERS := ["#", "n", "g", "p", "x", "k", "m"]
const TEAMS := [
	[&"nyangi", &"gomgom", &"piyak"], [&"nyangi", &"gaegul", &"piyak"],
	[&"gomgom", &"kkangchong", &"mongsil"], [&"gaegul", &"kkangchong", &"mongsil"],
]


func _init() -> void:
	var registry := ParityFixture.registry()
	var shapes := ParityFixture.catalog(registry)
	var scoring: ScoringRules = load(ParityFixture.SCORING_PATH)
	var cases := []
	var d1_face := {"shape": "D1", "crew": "", "face": -1}
	cases.append(_named("no_line_empty_board", _empty_rows(), [{"shape": "I3_H", "crew": "nyangi", "face": 1}], 6))
	cases.append(_named("domino_ng", ChainFixture.DOMINO_NG, [d1_face], 6))
	cases.append(_named("prototype_domino", ChainFixture.PROTOTYPE_DOMINO, [{"shape": "D1", "crew": "piyak", "face": 0}], 6))
	cases.append(_named("depth_cap_6", ChainFixture.DEPTH_CHAIN, [d1_face], 6))
	cases.append(_named("depth_cap_0", ChainFixture.DEPTH_CHAIN, [d1_face], 0))
	cases.append(_named("row_three_faces", ["........", "........", "........", "........", "........", "........", "........", "N#G#P##."], [d1_face], 6))
	cases.append(_named("row_new_crews", ["...#....", "..#.#...", "........", "........", "...#....", "....#...", "........", "X#K#M##."], [d1_face], 6))
	cases.append(_named("row_col_cross", [".......#", ".......#", ".......#", ".......#", ".......#", ".......#", ".......N", "######G."], [d1_face], 6))
	for s: int in range(1, GENERATED_BOARDS + 1):
		var rows := _random_rows(s)
		var board := BoardFixture.board(rows)
		var errs := BoardRules.validate_board(board, registry.board_config)
		if not errs.is_empty():
			push_error("board %d invalid: %s" % [s, errs])
		var team: Array[StringName] = []
		team.assign(TEAMS[s % TEAMS.size()])
		var tray := TraySupplyRules.init_state(team, TrayFixture.cfg(), s, registry)
		var refill := TraySupplyRules.refill(tray, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
		var pieces := []
		for p: PieceInstance in refill.pieces:
			pieces.append({"shape": String(p.shape.id), "crew": String(p.crew_id), "face": p.face_index})
		var c := _named("gen_%02d" % s, rows, pieces, 6)
		c["stage_seed"] = s
		c["placement_index"] = s % 5
		cases.append(c)
	# Obstacle cases (obstacles AC-O13): stones + ice through the obstacle hooks.
	var e7 := ["........", "........", "........", "........", "........", "........", "........"]
	cases.append(_obstacle(_named("obst_stone_row", ["........", "........", "........", "SSS####.", "........", "........", "........", "........"], [d1_face], 6), []))
	cases.append(_obstacle(_named("obst_ice_cross", ["#.......", "#.......", "#.......", "#.......", "#.......", "#.......", "........", "#.######"],
			[{"shape": "L3_A", "crew": "", "face": -1}, d1_face], 6), [[7, 0, 2]]))
	cases.append(_obstacle(_named("obst_frozen_domino", e7 + ["#GN####."], [d1_face], 6), [[7, 2, 1]]))
	cases.append(_obstacle(_named("obst_ice_two_waves", e7 + ["#G#####."], [d1_face], 6), [[7, 2, 1]]))
	for s: int in range(1, GENERATED_OBSTACLE_BOARDS + 1):
		var seed_value := 100 + s
		var ob := _obstacle_rows(seed_value)
		var team: Array[StringName] = []
		team.assign(TEAMS[s % TEAMS.size()])
		var tray := TraySupplyRules.init_state(team, TrayFixture.cfg(), seed_value, registry)
		var refill := TraySupplyRules.refill(tray, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
		var pieces := [d1_face]
		for p: PieceInstance in refill.pieces:
			pieces.append({"shape": String(p.shape.id), "crew": String(p.crew_id), "face": p.face_index})
		var c := _obstacle(_named("gen_obst_%02d" % s, ob["rows"], pieces, 6), ob["ice"])
		c["stage_seed"] = seed_value
		c["placement_index"] = s % 3
		var oerr := ObstacleRules.validate_obstacles(ParityFixture.case_board(c), ObstacleConfig.new(), _crew_ids(registry))
		oerr.append_array(BoardRules.validate_board(ParityFixture.case_board(c), registry.board_config))
		if not oerr.is_empty():
			push_error("obstacle board %d invalid: %s" % [s, oerr])
		cases.append(c)
	var total := 0
	var crews := {}
	for c: Dictionary in cases:
		var board := ParityFixture.case_board(c)
		var hooks := ParityFixture.case_hooks(c)
		var rules := ParityFixture.chain_rules(int(c["depth_cap"]))
		var expected := []
		for i: int in (c["pieces"] as Array).size():
			var p := ParityFixture.piece(c["pieces"][i], shapes, i + 1)
			var recs := []
			for a: Vector2i in ParityFixture.legal_anchors(board, p):
				var out := ParityFixture.run_anchor(board, p, a, int(c["stage_seed"]), int(c["placement_index"]), rules, registry.abilities(), scoring, hooks)
				if out[&"mismatch"] != "":
					push_error("%s piece %d %s: %s" % [c["id"], i, a, out[&"mismatch"]])
				recs.append(out[&"record"])
				for id: String in out[&"activated"]:
					crews[id] = true
				total += 1
			expected.append(recs)
		c["expected"] = expected
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "cases": cases}, " ", false) + "\n")
	f.close()
	print("wrote %d cases, %d anchors, crews activated: %s" % [cases.size(), total, crews.keys()])
	quit()


func _named(id: String, rows: Array, pieces: Array, depth_cap: int) -> Dictionary:
	return {"id": id, "board": rows, "pieces": pieces, "stage_seed": 1201, "placement_index": 0, "depth_cap": depth_cap}


func _empty_rows() -> Array:
	var rows := []
	for r: int in 8:
		rows.append("........")
	return rows


## Dense stable board: each row keeps 1–4 empties (mostly 2–3), every column at least one.
func _random_rows(s: int) -> Array:
	var parts: Array[int] = [s, 0x50415249]  # "PARI"
	var rng := DetRng.new(SeedHash.hash32(parts))
	var grid := []
	for r: int in 8:
		var row := []
		for c: int in 8:
			row.append(FACE_LETTERS[rng.below(6)] if rng.below(100) < 22 else TILE_LETTERS[rng.below(TILE_LETTERS.size())])
		var empties: int = [1, 2, 2, 3, 3, 4][rng.below(6)]
		var cols: Array = DetRng.shuffle([0, 1, 2, 3, 4, 5, 6, 7], rng.next_u32())
		for k: int in empties:
			row[cols[k]] = "."
		grid.append(row)
	for c: int in 8:
		var has_empty := false
		for r: int in 8:
			has_empty = has_empty or grid[r][c] == "."
		if not has_empty:
			grid[rng.below(8)][c] = "."
	var rows := []
	for row: Array in grid:
		rows.append("".join(row))
	return rows


func _obstacle(c: Dictionary, ice: Array) -> Dictionary:
	c["obstacles"] = true
	c["ice"] = ice
	return c


func _crew_ids(registry: CrewRegistry) -> Dictionary:
	var out := {}
	for c: CrewDef in registry.crews:
		out[c.id] = true
	return out


## A dense random board (see [method _random_rows]) with up to 3 tiles turned
## into stones (≤ 1 per row / column) and up to 6 tiles iced (faces 1 layer, others 1–2).
func _obstacle_rows(s: int) -> Dictionary:
	var rows := _random_rows(s)
	var grid := []
	for r: String in rows:
		grid.append(Array(r.split("")))
	var parts: Array[int] = [s, 0x4F425354]  # "OBST"
	var rng := DetRng.new(SeedHash.hash32(parts))
	var stone_rows := {}
	var stone_cols := {}
	var stones := 0
	var ice := []
	var iced := {}
	for k: int in 40:
		var r := rng.below(8)
		var c := rng.below(8)
		var ch: String = grid[r][c]
		if ch == "." or ch == "S" or iced.has(Vector2i(r, c)):
			continue
		if stones < 3 and not stone_rows.has(r) and not stone_cols.has(c) and rng.below(3) == 0:
			grid[r][c] = "S"
			stone_rows[r] = true
			stone_cols[c] = true
			stones += 1
		elif ice.size() < 6:
			var face := FACE_LETTERS.has(ch)
			ice.append([r, c, 1 if face else 1 + rng.below(2)])
			iced[Vector2i(r, c)] = true
	var out_rows := []
	for row: Array in grid:
		out_rows.append("".join(row))
	return {"rows": out_rows, "ice": ice}
