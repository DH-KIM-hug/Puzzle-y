## tray-supply AC-05 … AC-10 — generation (rules 7–12, F1, F2, F4, F7) and the
## committed golden sequences (tests/fixtures/tray/*.golden.json).
extends GdUnitTestSuite


## Crew id of a described slot ("SHAPE:crew:face").
func _crew_of(text: String) -> String:
	return text.split(":")[1]


func _shape_of(text: String) -> String:
	return text.split(":")[0]


## All pieces of [param trays] in order, as text.
func _flatten(trays: Array) -> Array:
	var out := []
	for t: Array in trays:
		for p: String in t:
			if p != TrayFixture.EMPTY_SLOT:
				out.append(p)
	return out


func test_every_tray_holds_each_team_crew_exactly_once() -> void:
	# Arrange (AC-05): team of 3, k = 1, empty board (no rescue).
	var played := TrayFixture.play(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, 100)
	# Act / Assert
	for t: Array in played[&"trays"]:
		var crews := t.map(_crew_of)
		crews.sort()
		assert_array(crews).is_equal(["gomgom", "nyangi", "piyak"])
	assert_array(played[&"rescued"]).is_empty()


func test_two_copies_per_bag_keep_counts_and_bound_gaps() -> void:
	# AC-06: k = 2 → every aligned 6-piece window has 2 per crew; gap ≤ 8.
	var cfg := TrayFixture.cfg()
	cfg.crew_bag_copies = 2
	var pieces := _flatten(TrayFixture.play(TrayFixture.DEFAULT_TEAM, cfg, 77, 100)[&"trays"])
	assert_int(pieces.size()).is_equal(300)
	for w: int in 50:
		var counts := {}
		for p: String in pieces.slice(w * 6, w * 6 + 6):
			counts[_crew_of(p)] = counts.get(_crew_of(p), 0) + 1
		assert_dict(counts).is_equal({"nyangi": 2, "gomgom": 2, "piyak": 2})
	var last := {}
	for i: int in pieces.size():
		var c := _crew_of(pieces[i])
		if last.has(c):
			assert_int(i - last[c] - 1).is_less_equal(8)
		last[c] = i


func test_solo_nyangi_shape_bag_keeps_exact_weights_per_cycle() -> void:
	# AC-07: 120 pieces, every 12-piece window = I3_H 3 · I3_V 3 · I4_H 2 · L3_A 2 · L4_A 1 · J4_A 1.
	var pieces := _flatten(TrayFixture.play(TrayFixture.team([&"nyangi"]), TrayFixture.cfg(), 9, 40)[&"trays"])
	assert_int(pieces.size()).is_equal(120)
	for w: int in 10:
		var counts := {}
		for p: String in pieces.slice(w * 12, w * 12 + 12):
			counts[_shape_of(p)] = counts.get(_shape_of(p), 0) + 1
		assert_dict(counts).is_equal({"I3_H": 3, "I3_V": 3, "I4_H": 2, "L3_A": 2, "L4_A": 1, "J4_A": 1})


func test_face_cell_is_uniform_or_fixed() -> void:
	# AC-08: 5-cell shape, face_cell -1, seeds 0–999 → each face 200 ± 50; face_cell 2 → always 2.
	var cross := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]
	var team := TrayFixture.team([&"tc"])
	var counts := [0, 0, 0, 0, 0]
	var fixed := 0
	var free_reg := TrayFixture.registry_of([TrayFixture.test_crew(&"tc", cross, -1)])
	var fixed_reg := TrayFixture.registry_of([TrayFixture.test_crew(&"tc", cross, 2)])
	for stage_seed: int in 1000:
		var a := TraySupplyRules.refill(TraySupplyRules.init_state(team, TrayFixture.cfg(), stage_seed, free_reg), BoardFixture.empty(), 1)
		counts[a.pieces[0].face_index] += 1
		var b := TraySupplyRules.refill(TraySupplyRules.init_state(team, TrayFixture.cfg(), stage_seed, fixed_reg), BoardFixture.empty(), 1)
		if b.pieces[0].face_index == 2:
			fixed += 1
	for n: int in counts:
		assert_int(n).is_between(150, 250)
	assert_int(fixed).is_equal(1000)


func test_faceless_share_ignored_unless_stage_allows_it() -> void:
	# AC-09
	var cfg := TrayFixture.cfg()
	cfg.faceless_share_permille = 1000
	var state := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, cfg, 3, TrayFixture.registry())
	assert_int(state.warnings.size()).is_equal(1)
	var none := _flatten(TrayFixture.play(TrayFixture.DEFAULT_TEAM, cfg, 3, 10)[&"trays"])
	assert_int(none.filter(func(p: String) -> bool: return p.ends_with("::-1")).size()).is_equal(0)
	cfg.allow_faceless_pieces = true
	var all := _flatten(TrayFixture.play(TrayFixture.DEFAULT_TEAM, cfg, 3, 10)[&"trays"])
	assert_int(all.size()).is_equal(30)
	assert_int(all.filter(func(p: String) -> bool: return p.ends_with("::-1")).size()).is_equal(30)
	assert_int(TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, cfg, 3, TrayFixture.registry()).warnings.size()).is_equal(0)


func test_twenty_piece_limit_gives_six_or_seven_per_crew() -> void:
	# AC-10 (F7): limit 20, team 3, k 1 → each crew 6 or 7, sum 20, last refill PARTIAL (2).
	var state := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, TrayFixture.registry())
	var remaining := 20
	var counts := {}
	var last: TrayRefill
	while remaining > 0:
		last = TraySupplyRules.refill(state, BoardFixture.empty(), remaining)
		remaining -= last.pieces.size()
		for p: PieceInstance in last.pieces:
			counts[p.crew_id] = counts.get(p.crew_id, 0) + 1
		state = TrayFixture.consume_all(last.state)
	var total := 0
	for c: StringName in counts:
		assert_int(counts[c]).is_between(6, 7)
		total += counts[c]
	assert_int(total).is_equal(20)
	assert_int(last.pieces.size()).is_equal(2)
	assert_int(last.state.status).is_equal(TrayState.Status.PARTIAL)
	assert_int(TraySupplyRules.refill(state, BoardFixture.empty(), remaining).state.status).is_equal(TrayState.Status.EXHAUSTED)


func test_generated_sequences_match_committed_goldens() -> void:
	# F3 golden sequences: same (stage_seed, team, config, registry) → same trays.
	for file_name: String in ["default_team_1201.golden.json", "eight_way_team_7.golden.json", "dig_fill_team_42.golden.json"]:
		var g: Dictionary = TrayFixture.golden(file_name)
		var team := TrayFixture.team(g["team"])
		var trays: Array = g["trays"]
		var played := TrayFixture.play(team, TrayFixture.cfg(), int(g["stage_seed"]), trays.size())
		assert_array(played[&"trays"]).override_failure_message(file_name).is_equal(trays)
