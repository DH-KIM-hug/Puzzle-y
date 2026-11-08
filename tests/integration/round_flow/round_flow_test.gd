## T0 greybox round loop over the real data (registry, rules, tray): start →
## commit → refill → no_moves → retry, with the preview = commit invariant on the
## flow's single context factory (chain-preview rule 1/9, ADR-0001 Decision 9).
extends GdUnitTestSuite

const TEAM: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
const MAX_PLACEMENTS := 200


func _flow(seed_value: int = 1201) -> RoundFlow:
	var registry: CrewRegistry = load("res://assets/data/crew/crew_registry.tres")
	registry.load_and_validate()
	var f := RoundFlow.create(registry, load("res://assets/data/rules/chain_rules.tres"),
			load("res://assets/data/rules/scoring_rules.tres"), load("res://assets/data/rules/tray_rules.tres"), TEAM, seed_value)
	f.start_attempt()
	return f


## First legal (slot, anchor) row-major, or [] when none.
func _first_move(f: RoundFlow) -> Array:
	for slot: int in f.slot_count():
		if f.piece_at(slot) == null:
			continue
		for r: int in f.board().height:
			for c: int in f.board().width:
				if f.can_place(slot, Vector2i(r, c)):
					return [slot, Vector2i(r, c)]
	return []


func test_start_deals_one_piece_per_team_crew() -> void:
	# Arrange / Act
	var f := _flow()
	# Assert
	var crews: Array = []
	for slot: int in f.slot_count():
		crews.append(f.piece_at(slot).crew_id)
	assert_array(crews).contains_exactly_in_any_order([&"gomgom", &"nyangi", &"piyak"])
	assert_int(f.phase).is_equal(RoundFlow.Phase.PLAYING)
	assert_int(f.stage_score()).is_equal(0)


func test_commit_matches_preview_and_consumes_slot() -> void:
	# Arrange
	var f := _flow()
	var move := _first_move(f)
	var piece := f.piece_at(move[0])
	var model := PreviewModel.preview(f.board(), piece, move[1], f.context_for_next_placement())
	# Act
	var commit := f.commit(move[0], move[1])
	# Assert
	assert_object(commit).is_not_null()
	assert_int(commit.result.summary[ChainEvent.K_BOARD_HASH]).is_equal(model.result.summary[ChainEvent.K_BOARD_HASH])
	assert_object(f.piece_at(move[0])).is_null()
	assert_int(f.stage_score()).is_equal(commit.breakdown.total)
	assert_bool(f.last_pre_board.equals(f.board())).is_false()


func test_illegal_commit_is_refused_without_change() -> void:
	# Arrange
	var f := _flow()
	var before := f.board().board_hash()
	# Act
	var commit := f.commit(0, Vector2i(-3, -3))
	# Assert
	assert_object(commit).is_null()
	assert_int(f.board().board_hash()).is_equal(before)
	assert_object(f.piece_at(0)).is_not_null()


func test_play_until_no_moves_then_retry_resets() -> void:
	# Arrange
	var f := _flow()
	var first_tray: Array = []
	for slot: int in f.slot_count():
		first_tray.append(f.piece_at(slot).shape.id)
	# Act — always the first legal move (deterministic) until the flow says NO_MOVES.
	var n := 0
	while f.phase == RoundFlow.Phase.PLAYING and n < MAX_PLACEMENTS:
		var move := _first_move(f)
		assert_array(move).is_not_empty()
		f.commit(move[0], move[1])
		f.finish_placement()
		n += 1
	var final_score := f.stage_score()
	var stuck := BoardRules.no_moves(f.board(), f.tray.pieces())
	f.retry()
	# Assert
	assert_int(f.phase).is_equal(RoundFlow.Phase.PLAYING)
	assert_bool(stuck).is_true()
	assert_int(n).is_less(MAX_PLACEMENTS)
	assert_int(final_score).is_greater(0)
	assert_int(f.attempt).is_equal(1)
	assert_int(f.stage_score()).is_equal(0)
	assert_int(f.board().filled_count()).is_equal(0)
	assert_int(f.core.placement_index).is_equal(0)


func test_same_seed_same_attempt_is_deterministic() -> void:
	# Arrange
	var a := _flow(77)
	var b := _flow(77)
	# Act
	for i: int in 6:
		var ma := _first_move(a)
		var mb := _first_move(b)
		a.commit(ma[0], ma[1])
		b.commit(mb[0], mb[1])
		a.finish_placement()
		b.finish_placement()
	# Assert
	assert_int(a.board().board_hash()).is_equal(b.board().board_hash())
	assert_int(a.stage_score()).is_equal(b.stage_score())
