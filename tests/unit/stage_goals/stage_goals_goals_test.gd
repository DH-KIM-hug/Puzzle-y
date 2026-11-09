## design/gdd/stage-goals.md AC-SG05–SG10, SG17, SG18 (rules 3–8, 14; F1, F3, F4):
## goal progress counted only from ChainResult events.
extends GdUnitTestSuite

const ICE: Array[StringName] = [&"ice"]


func _tracker(goals: Array[GoalDef], targets: Array[Vector2i] = [], board: BoardState = null, cell_points: int = 10) -> GoalTracker:
	var b := board if board != null else BoardState.create(8, 8)
	return GoalTracker.start(GoalEventFixture.stage(goals, targets), b, cell_points, 10)


func test_score_goal_uses_f1_scaled_threshold() -> void:
	# AC-SG05
	var t := _tracker([GoalDef.make(GoalDef.Type.SCORE, 160)])
	var empty := GoalEventFixture.new().result()
	t.apply(empty, null, 159)
	assert_bool(t.is_met()).is_false()
	t.apply(empty, null, 165)
	assert_bool(t.is_met()).is_true()
	assert_int(_tracker([GoalDef.make(GoalDef.Type.SCORE, 160)], [], null, 20).required(0)).is_equal(320)


func test_target_cells_count_cleared_cells_once_and_ignore_kept() -> void:
	# AC-SG06: (0,7) cleared BOTH, then again in wave 2; (7,0) only kept.
	var t := _tracker([GoalDef.make(GoalDef.Type.CLEAR_CELLS, 2)], [Vector2i(0, 7), Vector2i(7, 0)])
	var res := GoalEventFixture.new().cleared(0, [Vector2i(0, 7)], Vector2i(7, 0), ChainEvent.BY_BOTH).cleared(2, [Vector2i(0, 7)]).result()
	t.apply(res, null, 0)
	assert_int(t.progress(0)).is_equal(1)
	assert_bool(t.done.has(Vector2i(0, 7))).is_true()
	assert_bool(t.done.has(Vector2i(7, 0))).is_false()


func test_obstacle_goal_counts_freed_cells_not_layers() -> void:
	# AC-SG07: A 1-layer, B 2-layer, C frozen face; CLEAR_OBSTACLES ice 3.
	var a := Vector2i(1, 1)
	var b := Vector2i(2, 2)
	var c := Vector2i(3, 3)
	var board := BoardState.create(8, 8, ObstacleRules.kind_table())
	for cell: Vector2i in [a, b, c]:
		board.set_tile(board.index_of_cell(cell), &"nyangi" if cell == c else &"", cell == c, BoardState.ORIGIN_PIECE, 0)
	ObstacleRules.set_ice(board, board.index_of_cell(a), 1)
	ObstacleRules.set_ice(board, board.index_of_cell(b), 2)
	ObstacleRules.set_ice(board, board.index_of_cell(c), 1)
	var t := _tracker([GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 3, ICE)], [], board)
	t.apply(GoalEventFixture.new().thawed(0, a, 1, 0).thawed(0, b, 2, 1).result(), null, 0)
	assert_int(t.progress(0)).is_equal(1)
	t.apply(GoalEventFixture.new().thawed(0, b, 1, 0).thawed(0, c, 1, 0, true).result(2), null, 0)
	assert_int(t.progress(0)).is_equal(3)
	assert_bool(t.is_met()).is_true()
	t.apply(GoalEventFixture.new().cleared(0, [a]).result(), null, 0)
	assert_int(t.progress(0)).is_equal(3)


func test_chain_goal_counts_placements_at_or_above_depth() -> void:
	# AC-SG08: depth 3 × 2 with depths 2, 3, 6, 0.
	var t := _tracker([GoalDef.make(GoalDef.Type.CHAIN, 2, [], 3)])
	var seen: Array[int] = []
	var met: Array[bool] = []
	for d: int in [2, 3, 6, 0]:
		t.apply(GoalEventFixture.new().result(d), null, 0)
		seen.append(t.progress(0))
		met.append(t.is_met())
	assert_array(seen).is_equal([0, 1, 2, 2])
	assert_array(met).is_equal([false, false, true, true])


func test_two_goals_are_met_only_together() -> void:
	# AC-SG09: 1-10 goals — 6 target cells first, then ice 3 → 4.
	var targets: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 4), Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 7), Vector2i(4, 7)]
	var board := BoardState.create(8, 8, ObstacleRules.kind_table())
	var ice: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 5), Vector2i(6, 1), Vector2i(6, 6)]
	for cell: Vector2i in ice:
		board.set_tile(board.index_of_cell(cell), &"", false, BoardState.ORIGIN_PIECE, 0)
		ObstacleRules.set_ice(board, board.index_of_cell(cell), 1)
	var t := _tracker([GoalDef.make(GoalDef.Type.CLEAR_CELLS, 6), GoalDef.make(GoalDef.Type.CLEAR_OBSTACLES, 4, ICE)], targets, board)
	t.apply(GoalEventFixture.new().cleared(0, targets).result(), null, 0)
	t.apply(GoalEventFixture.new().thawed(0, ice[0], 1, 0).thawed(0, ice[1], 1, 0).thawed(0, ice[2], 1, 0).result(), null, 0)
	assert_bool(t.is_met()).is_false()
	var snap := t.snapshot()
	assert_bool(snap[0][GoalTracker.S_MET]).is_true()
	assert_int(snap[1][GoalTracker.S_PROGRESS]).is_equal(3)
	assert_int(snap[1][GoalTracker.S_REQUIRED]).is_equal(4)
	t.apply(GoalEventFixture.new().thawed(0, ice[3], 1, 0).result(), null, 0)
	assert_bool(t.is_met()).is_true()


func test_same_events_give_same_monotonic_snapshots() -> void:
	# AC-SG10
	var goals: Array[GoalDef] = [GoalDef.make(GoalDef.Type.CLEAR_CELLS, 2), GoalDef.make(GoalDef.Type.CHAIN, 1, [], 1)]
	var targets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	var seq := [GoalEventFixture.new().cleared(0, [Vector2i(0, 0)]).result(1), GoalEventFixture.new().result(0),
			GoalEventFixture.new().cleared(0, [Vector2i(0, 0), Vector2i(1, 1)]).result(2)]
	var a := _tracker(goals, targets)
	var b := _tracker(goals, targets)
	var prev := [0, 0]
	for res: ChainResult in seq:
		a.apply(res, null, 0)
		b.apply(res, null, 0)
		assert_str(var_to_str(a.snapshot())).is_equal(var_to_str(b.snapshot()))
		for g: int in 2:
			assert_int(a.progress(g)).is_greater_equal(prev[g])
			prev[g] = a.progress(g)


func test_preview_marks_targets_without_changing_state() -> void:
	# AC-SG17
	var t := _tracker([GoalDef.make(GoalDef.Type.CLEAR_CELLS, 2)], [Vector2i(3, 3), Vector2i(5, 5)])
	var res := GoalEventFixture.new().cleared(0, [Vector2i(3, 3), Vector2i(3, 4)]).result()
	var before := var_to_str(t.snapshot())
	var p := t.preview(res)
	assert_array(p.target_cells_hit).is_equal([Vector2i(3, 3)])
	assert_str(var_to_str(t.snapshot())).is_equal(before)
	t.apply(res, null, 0)
	assert_int(t.progress(0)).is_equal(p.target_cells_hit.size())


func test_preview_completes_stage_and_hides_score_goal() -> void:
	# AC-SG18
	var t := _tracker([GoalDef.make(GoalDef.Type.CHAIN, 1, [], 2)])
	assert_bool(t.preview(GoalEventFixture.new().result(2)).completes_stage).is_true()
	assert_array(t.preview(GoalEventFixture.new().result(2)).chain_goal_hit).is_equal([0])
	var s := _tracker([GoalDef.make(GoalDef.Type.SCORE, 100)])
	var p := s.preview(GoalEventFixture.new().cleared(0, [Vector2i(0, 0)]).result(1))
	assert_bool(p.is_empty()).is_true()
	assert_bool(s.preview(GoalEventFixture.new().result(1), 150).completes_stage).is_true()


func test_pieces_out_only_when_zero_left_and_unmet() -> void:
	# Rule 9.2
	var t := _tracker([GoalDef.make(GoalDef.Type.CHAIN, 1, [], 1)])
	assert_bool(t.pieces_out(1)).is_false()
	assert_bool(t.pieces_out(0)).is_true()
	assert_bool(t.pieces_out(StageDef.UNLIMITED)).is_false()
	t.apply(GoalEventFixture.new().result(1), null, 0)
	assert_bool(t.pieces_out(0)).is_false()
