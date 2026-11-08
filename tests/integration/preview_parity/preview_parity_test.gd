## chain-preview AC-P02 (+ AC-P03, scoring AC-S12, crew-definition AC-14 AND):
## the preview = runtime = score invariant over the committed cases in
## tests/fixtures/parity/cases.json (named boundary boards + 24 offline-generated
## boards × their tray pieces × every legal anchor, row-major). The test never
## generates boards; regenerate the file with
## tests/fixtures/generators/gen_parity_cases.gd and review the diff.
extends GdUnitTestSuite

## Named boundary fixtures the file must contain (AC-P02 (i)).
const NAMED := ["no_line_empty_board", "domino_ng", "prototype_domino", "depth_cap_6", "depth_cap_0",
		"row_three_faces", "row_new_crews", "row_col_cross"]
const MIN_BOARDS := 20


var _cases: Array = []
var _registry: CrewRegistry
var _shapes: Dictionary
var _scoring: ScoringRules


func before() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ParityFixture.CASES_PATH))
	_cases = data["cases"]
	_registry = ParityFixture.registry()
	_shapes = ParityFixture.catalog(_registry)
	_scoring = load(ParityFixture.SCORING_PATH)


## Runs every case; returns {records: id → records per piece, failures, crews}.
func _run_all() -> Dictionary:
	var records := {}
	var failures: Array[String] = []
	var crews := {}
	for c: Dictionary in _cases:
		var id: String = c["id"]
		var board := BoardFixture.board(c["board"])
		var rules := ParityFixture.chain_rules(int(c["depth_cap"]))
		var per_piece := []
		for i: int in (c["pieces"] as Array).size():
			var p := ParityFixture.piece(c["pieces"][i], _shapes, i + 1)
			var expected: Array = c["expected"][i]
			var anchors := ParityFixture.legal_anchors(board, p)
			if anchors.size() != expected.size():
				failures.append("%s piece %d: %d legal anchors, committed %d" % [id, i, anchors.size(), expected.size()])
			var recs := []
			for k: int in anchors.size():
				var out := ParityFixture.run_anchor(board, p, anchors[k], int(c["stage_seed"]), int(c["placement_index"]),
						rules, _registry.abilities(), _scoring)
				var rec: Array = out[&"record"]
				recs.append(rec)
				for crew_id: String in out[&"activated"]:
					crews[crew_id] = true
				if out[&"mismatch"] != "":
					failures.append("%s piece %d anchor %s: %s" % [id, i, anchors[k], out[&"mismatch"]])
				elif k < expected.size():
					var diff := _first_diff(rec, expected[k])
					if diff != "":
						failures.append("%s piece %d anchor %s: committed %s" % [id, i, anchors[k], diff])
			per_piece.append(recs)
		records[id] = per_piece
	return {&"records": records, &"failures": failures, &"crews": crews}


func _first_diff(rec: Array, committed: Array) -> String:
	const FIELDS := ["row", "col", "board_hash", "chain_depth", "waves", "cap_reached", "score_total", "model_digest"]
	for f: int in FIELDS.size():
		if int(rec[f]) != int(committed[f]):
			return "%s %d != %d" % [FIELDS[f], int(rec[f]), int(committed[f])]
	return ""


func test_committed_cases_cover_named_fixtures_and_enough_boards() -> void:
	# Arrange / Act
	var ids := _cases.map(func(c: Dictionary) -> String: return c["id"])
	var anchors := 0
	for c: Dictionary in _cases:
		for recs: Array in c["expected"]:
			anchors += recs.size()
	# Assert
	for name: String in NAMED:
		assert_bool(ids.has(name)).override_failure_message("missing named fixture " + name).is_true()
	assert_int(_cases.size()).is_greater_equal(MIN_BOARDS)
	assert_int(anchors).is_greater(400)


func test_preview_equals_commit_equals_score_for_every_legal_anchor() -> void:
	# Arrange: committed cases (before()). Act
	var run := _run_all()
	# Assert: (1) ChainResult A == B, (2) PreviewModel A == build(B) and outline ==
	# cleared cells, (3) breakdown A == B == stage_score delta == predicted total,
	# and every record equals the committed placement result.
	var failures: Array[String] = run[&"failures"]
	assert_array(failures.slice(0, 20)).override_failure_message("%d parity failures, first: %s" % [failures.size(), failures.slice(0, 5)]).is_empty()


func test_all_six_mvp_crews_activate_somewhere_in_the_cases() -> void:
	# crew-definition AC-14 AND: each MVP crew's face activates at least once.
	var crews: Dictionary = _run_all()[&"crews"]
	for id: String in ["nyangi", "gomgom", "piyak", "gaegul", "kkangchong", "mongsil"]:
		assert_bool(crews.has(id)).override_failure_message("never activated: " + id).is_true()


func test_two_full_runs_give_identical_records() -> void:
	# AC-P02 AND: determinism across runs.
	var a: Dictionary = _run_all()[&"records"]
	var b: Dictionary = _run_all()[&"records"]
	assert_str(var_to_str(b)).is_equal(var_to_str(a))


func test_seed_mismatch_between_preview_and_commit_is_detected() -> void:
	# Seeing the gate fail (AC-P02 AND, AC-P04 reduced): a preview context whose
	# rng_seed differs from the commit's must be caught by the parity comparison.
	# MVP primitives ignore rng_seed, so the mismatch is injected where it is
	# observable: the placement id written into the placed tiles (no line clears
	# them on the empty board).
	var c: Dictionary = _cases[_cases.map(func(x: Dictionary) -> String: return x["id"]).find("no_line_empty_board")]
	var board := BoardFixture.board(c["board"])
	var p := ParityFixture.piece(c["pieces"][0], _shapes, 1)
	var round_b := RoundCore.start(board, _registry.abilities(), ParityFixture.chain_rules(6), _scoring, 1201)
	var good := round_b.context_for_next_placement()
	var bad := ResolveContext.make(good.abilities, good.rules, good.rng_seed + 1, good.hooks, good.placement_id + 1)
	var preview_bad := PreviewModel.preview(round_b.board, p, Vector2i(0, 0), bad)
	var preview_good := PreviewModel.preview(round_b.board, p, Vector2i(0, 0), round_b.context_for_next_placement())
	var commit := round_b.commit(p, Vector2i(0, 0))
	assert_bool(preview_good.result.final_board.equals(commit.result.final_board)).is_true()
	assert_bool(preview_bad.result.final_board.equals(commit.result.final_board)).is_false()
