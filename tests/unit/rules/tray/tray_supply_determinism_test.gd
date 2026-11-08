## tray-supply AC-17 … AC-20 — determinism and replay (rules 16–18, F3).
extends GdUnitTestSuite


## Replays a round: each refill's pieces are placed at their first row-major
## anchor through the real resolver ([param rng_seed_base] feeds the resolver
## seed only). Returns every refill snapshot.
func _replay(stage_seed: int, rng_seed_base: int, refills: int) -> Array:
	var registry := TrayFixture.registry()
	var ctx_rules: ChainRules = load("res://assets/data/rules/chain_rules.tres")
	var board := BoardFixture.empty()
	var tray := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), stage_seed, registry)
	var snaps := []
	var placement := 0
	for i: int in refills:
		var r := TraySupplyRules.refill(tray, board, TraySupplyRules.BUDGET_UNLIMITED)
		snaps.append(TrayFixture.describe_slots(r.state))
		tray = r.state
		for x: int in tray.slots.size():
			var piece: PieceInstance = tray.slots[x]
			var anchor := _first_anchor(board, piece)
			if anchor.x >= 0:
				var ctx := ResolveContext.make(registry.abilities(), ctx_rules, SeedStreams.resolver_seed(rng_seed_base, placement))
				board = ChainResolver.resolve(board, piece, anchor, ctx).final_board
				placement += 1
			tray = TraySupplyRules.consume(tray, x)
	return snaps


func _first_anchor(board: BoardState, piece: PieceInstance) -> Vector2i:
	for r: int in board.height:
		for c: int in board.width:
			if BoardRules.can_place(board, piece, Vector2i(r, c)):
				return Vector2i(r, c)
	return Vector2i(-1, -1)


func test_same_inputs_replay_identically_and_resolver_seed_is_separate() -> void:
	# AC-17
	var a := _replay(1201, 1201, 10)
	var b := _replay(1201, 1201, 10)
	var c := _replay(1201, 999, 10)
	assert_array(b).is_equal(a)
	assert_array(c).is_equal(a)


func test_fixed_restarts_repeat_first_tray_and_slot_order_keeps_shapes() -> void:
	# AC-18
	var firsts := []
	for attempt: int in 3:
		var seed_a := TraySupplyRules.stage_seed_for(TrayRules.SeedMode.FIXED, 1201, attempt)
		firsts.append(TrayFixture.play(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), seed_a, 1)[&"trays"][0])
	assert_array(firsts[1]).is_equal(firsts[0])
	assert_array(firsts[2]).is_equal(firsts[0])
	var swapped := TrayFixture.team([&"piyak", &"nyangi", &"gomgom"])
	var x := _per_crew_shapes(TrayFixture.play(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, 10)[&"trays"])
	var y := _per_crew_shapes(TrayFixture.play(swapped, TrayFixture.cfg(), 1201, 10)[&"trays"])
	assert_dict(y).is_equal(x)


func test_per_attempt_seeds_differ_between_attempts_and_repeat_per_attempt() -> void:
	# AC-19
	var mode := TrayRules.SeedMode.PER_ATTEMPT
	var s0 := TraySupplyRules.stage_seed_for(mode, 1201, 0)
	var s1 := TraySupplyRules.stage_seed_for(mode, 1201, 1)
	var s2 := TraySupplyRules.stage_seed_for(mode, 1201, 2)
	assert_int(s0).is_not_equal(s1)
	assert_int(s1).is_not_equal(s2)
	assert_int(s0).is_not_equal(s2)
	assert_int(TraySupplyRules.stage_seed_for(mode, 1201, 1)).is_equal(s1)
	assert_int(s1).is_between(0, TraySupplyRules.STAGE_SEED_MASK)


func test_tray_sources_use_no_global_randomness() -> void:
	# AC-20
	var dir := "res://src/core/rules/tray"
	var hits := []
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + f)
		for token: String in ["randi(", "randf(", "randomize(", "RandomNumberGenerator"]:
			if text.contains(token):
				hits.append("%s %s" % [f, token])
	assert_array(hits).is_empty()
	assert_int(DirAccess.get_files_at(dir).size()).is_greater_equal(4)


## crew → shape sequence (slot positions ignored).
func _per_crew_shapes(trays: Array) -> Dictionary:
	var out := {}
	for t: Array in trays:
		for p: String in t:
			var parts := p.split(":")
			if not out.has(parts[1]):
				out[parts[1]] = []
			out[parts[1]].append(parts[0])
	return out
