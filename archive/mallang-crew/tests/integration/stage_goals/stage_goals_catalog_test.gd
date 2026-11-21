## design/gdd/stage-goals.md AC-SG04 (catalog loads clean) and AC-SG19/AC-SG20
## (reduced): every MVP stage is winnable with the starter crews (fixed-team
## stages: their locked team) — the committed placement list in
## tests/fixtures/stages/solutions.json (found offline by
## tests/fixtures/generators/solve_stages.gd) is replayed through the real
## RoundFlow (same FIXED seed → same trays) and must end CLEARED with ≥ 1 star.
## Every replayed placement is also previewed first; preview must equal commit.
extends GdUnitTestSuite

const CATALOG := "res://assets/data/stages/catalog.tres"
const SOLUTIONS := "res://tests/fixtures/stages/solutions.json"
const IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "1-8", "1-9", "1-10"]

var _env: StageEnv
var _catalog: StageCatalog


func before() -> void:
	_env = StageEnv.load_default()
	_catalog = load(CATALOG)


func test_mvp_catalog_loads_without_errors_or_lint() -> void:
	# AC-SG04
	var ids := []
	var loads := StageLoader.load_catalog(_catalog, _env)
	for l: StageLoad in loads:
		ids.append(String(l.stage.id))
		assert_array(l.errors).override_failure_message("%s errors %s" % [l.stage.id, l.errors]).is_empty()
		assert_array(l.warnings).override_failure_message("%s warnings %s" % [l.stage.id, l.warnings]).is_empty()
		assert_int(l.stage.preview_detail).is_equal(PreviewSettings.Detail.FULL)
		assert_int(l.stage.tray_seed_mode).is_equal(TrayRules.SeedMode.FIXED)
	assert_array(ids).is_equal(IDS)


func test_catalog_uses_the_gdd_obstacles_and_teams() -> void:
	# Rule G table: fixed teams 1-1..1-4, free 1-5..1-10; ice from 1-8, stones only in 1-10.
	for l: StageLoad in StageLoader.load_catalog(_catalog, _env):
		var n := IDS.find(String(l.stage.id)) + 1
		assert_bool(l.stage.effective_team_rule().is_fixed()).is_equal(n <= 4)
		var stones := 0
		for i: int in l.board.cell_count():
			if l.board.kind[i] == CellKind.STONE:
				stones += 1
		assert_int(stones).is_equal(4 if n == 10 else 0)
		assert_bool(ObstacleRules.iced_cells(l.board) > 0).is_equal(n >= 8)


func test_every_stage_is_cleared_by_its_committed_solution() -> void:
	# AC-SG19 / AC-SG20 (one fixed-seed run per stage, starter team).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOLUTIONS))
	var by_id := {}
	for s: Dictionary in data["stages"]:
		by_id[s["id"]] = s
	for id: String in IDS:
		assert_bool(by_id.has(id)).override_failure_message("no solution for " + id).is_true()
		if not by_id.has(id):
			continue
		var sol: Dictionary = by_id[id]
		var stage := _catalog.find(StringName(id))
		var owned := OwnedCrews.starter(_env.registry)
		var team := TeamRules.resolve_default_team(stage.effective_team_rule(), _env.registry, owned, TeamMemory.new(), stage.id)
		assert_int(TeamRules.check_team(team, stage.effective_team_rule(), _env.registry, owned)).is_equal(TeamRules.Reason.OK)
		assert_array(team.map(func(x: StringName) -> String: return String(x))).is_equal(sol["team"])
		var flow := RoundFlow.for_stage(_env, stage, team)
		assert_array(flow.start_attempt()).is_empty()
		var moves: Array = sol["moves"]
		for i: int in moves.size():
			var mv: Array = moves[i]
			var slot := int(mv[0])
			var anchor := Vector2i(int(mv[1]), int(mv[2]))
			assert_bool(flow.can_place(slot, anchor)).override_failure_message("%s move %d illegal" % [id, i]).is_true()
			var preview := PreviewModel.preview(flow.board(), flow.piece_at(slot), anchor, flow.context_for_next_placement())
			var commit := flow.commit(slot, anchor)
			assert_int(commit.result.summary[ChainEvent.K_BOARD_HASH]).is_equal(preview.result.summary[ChainEvent.K_BOARD_HASH])
			flow.playback_finished()
			if i < moves.size() - 1:
				assert_int(flow.outcome).override_failure_message("%s ended early at %d" % [id, i]).is_equal(RoundResult.Outcome.CONTINUE)
		assert_int(flow.outcome).override_failure_message("%s not cleared" % id).is_equal(RoundResult.Outcome.CLEARED)
		assert_int(flow.result.stars).is_greater_equal(1)
		assert_int(flow.result.final_score).is_equal(int(sol["final_score"]))
		assert_int(flow.result.pieces_left).is_equal(stage.piece_limit - moves.size())


func test_out_of_team_frozen_face_and_guest_free_starters() -> void:
	# 1-9 has a frozen gaegul face (out of the starter team — registry-wide abilities);
	# rule 13: every MVP stage is playable by starters + guests (lint passes).
	var stage := _catalog.find(&"1-9")
	var b := StageLoader.load_stage(stage, _env).board
	var found := false
	for idx: int in b.modifiers:
		if b.is_face(idx) and b.crew_at(idx) == &"gaegul":
			found = true
	assert_bool(found).is_true()
	for s: StageDef in _catalog.stages:
		assert_bool(TeamRules.starter_can_play(s.effective_team_rule(), _env.registry)).is_true()
