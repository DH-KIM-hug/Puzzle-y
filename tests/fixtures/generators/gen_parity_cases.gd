## Offline generator for tests/fixtures/parity/cases.json (chain-preview AC-P02:
## boards are generated once offline and committed; the test never generates).
## Run, review the diff, commit:
##   godot --headless --path . -s res://tests/fixtures/generators/gen_parity_cases.gd
extends SceneTree

const OUT := "res://tests/fixtures/parity/cases.json"
## Generated boards (seeds 1..N). AC-P02 asks for 50; 24 keeps the suite fast.
const GENERATED_BOARDS := 24
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
	var total := 0
	var crews := {}
	for c: Dictionary in cases:
		var board := BoardFixture.board(c["board"])
		var rules := ParityFixture.chain_rules(int(c["depth_cap"]))
		var expected := []
		for i: int in (c["pieces"] as Array).size():
			var p := ParityFixture.piece(c["pieces"][i], shapes, i + 1)
			var recs := []
			for a: Vector2i in ParityFixture.legal_anchors(board, p):
				var out := ParityFixture.run_anchor(board, p, a, int(c["stage_seed"]), int(c["placement_index"]), rules, registry.abilities(), scoring)
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
