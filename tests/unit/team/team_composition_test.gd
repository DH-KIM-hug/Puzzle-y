## design/gdd/team-composition.md rules 2, 5–13, F1–F3: pure team rules over the
## real registry with the starter / debug owned-crew providers.
extends GdUnitTestSuite

const N := &"nyangi"
const G := &"gomgom"
const P := &"piyak"
const X := &"gaegul"
const K := &"kkangchong"
const M := &"mongsil"

var _reg: CrewRegistry


func before() -> void:
	_reg = load("res://assets/data/crew/crew_registry.tres")
	_reg.load_and_validate()


func _team(ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(ids)
	return out


func test_starter_provider_owns_three_and_debug_owns_six() -> void:
	assert_array(OwnedCrews.starter(_reg).owned_crew_ids()).is_equal([N, G, P])
	assert_int(OwnedCrews.all_of(_reg).owned_crew_ids().size()).is_equal(6)
	assert_bool(OwnedCrews.starter(_reg).is_owned(X)).is_false()


func test_f1_reasons_in_priority_order() -> void:
	var owned := OwnedCrews.starter(_reg)
	var rule := TeamRule.make()
	assert_int(TeamRules.check_team(_team([N, G, P]), rule, _reg, owned)).is_equal(TeamRules.Reason.OK)
	assert_int(TeamRules.check_team(_team([N, G]), rule, _reg, owned)).is_equal(TeamRules.Reason.INCOMPLETE)
	assert_int(TeamRules.check_team(_team([N, G, &""]), rule, _reg, owned)).is_equal(TeamRules.Reason.INCOMPLETE)
	assert_int(TeamRules.check_team(_team([N, N, P]), rule, _reg, owned)).is_equal(TeamRules.Reason.DUPLICATE)
	assert_int(TeamRules.check_team(_team([N, &"nobody", P]), rule, _reg, owned)).is_equal(TeamRules.Reason.UNKNOWN_CREW)
	assert_int(TeamRules.check_team(_team([N, X, P]), rule, _reg, owned)).is_equal(TeamRules.Reason.NOT_OWNED)
	var banned := TeamRule.make(3, [], [G])
	assert_int(TeamRules.check_team(_team([N, G, P]), banned, _reg, owned)).is_equal(TeamRules.Reason.BANNED)
	var lock := TeamRule.make(3)
	lock.locked.append(TeamLock.make(2, N))
	assert_int(TeamRules.check_team(_team([N, G, P]), lock, _reg, owned)).is_equal(TeamRules.Reason.LOCK_MISMATCH)


func test_mvp_colours_never_clash_but_a_shared_slot_does() -> void:
	# F3: MVP slots 1–6 are unique.
	assert_bool(TeamRules.colour_clash(_team([N, G, P]), _reg)).is_false()
	assert_bool(TeamRules.colour_clash(_team([X, K, M]), _reg)).is_false()
	var reg2: CrewRegistry = _reg.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	reg2.load_and_validate()
	reg2.get_crew(X).colour_slot = reg2.get_crew(N).colour_slot
	assert_bool(TeamRules.colour_clash(_team([N, X, P]), reg2)).is_true()
	assert_int(TeamRules.check_team(_team([N, X, P]), TeamRule.make(), reg2, OwnedCrews.all_of(reg2))).is_equal(TeamRules.Reason.COLOUR_CLASH)


func test_locked_guest_is_valid_and_reported_as_guest() -> void:
	# Rule 7 / AC-SG16: 1-3 locks [nyangi, gomgom]; gomgom not owned → guest.
	var owned := OwnedCrews.of(_team([N, P]), _reg)
	var rule := TeamRule.make(2, [N, G])
	var team := TeamRules.resolve_default_team(rule, _reg, owned, TeamMemory.new(), &"1-3")
	assert_array(team).is_equal([N, G])
	assert_int(TeamRules.check_team(team, rule, _reg, owned)).is_equal(TeamRules.Reason.OK)
	assert_array(TeamRules.guests(team, rule, owned)).is_equal([G])
	assert_bool(owned.is_owned(G)).is_false()


func test_new_player_default_team_is_starters_in_registry_order() -> void:
	# Rule 9 / F2 fallback.
	var team := TeamRules.resolve_default_team(TeamRule.make(), _reg, OwnedCrews.starter(_reg), TeamMemory.new(), &"1-5")
	assert_array(team).is_equal([N, G, P])


func test_f2_example_global_memory_with_ban() -> void:
	# F2 example: global [gaegul, nyangi, piyak], nyangi banned → [gaegul, gomgom, piyak].
	var memory := TeamMemory.new()
	memory.last_global = _team([X, N, P])
	var rule := TeamRule.make(3, [], [N])
	var team := TeamRules.resolve_default_team(rule, _reg, OwnedCrews.all_of(_reg), memory, &"1-6")
	assert_array(team).is_equal([X, G, P])


func test_stage_memory_beats_global_memory() -> void:
	var memory := TeamMemory.new()
	memory.last_global = _team([X, K, M])
	memory.by_stage[&"1-7"] = _team([M, N, G])
	var team := TeamRules.resolve_default_team(TeamRule.make(), _reg, OwnedCrews.all_of(_reg), memory, &"1-7")
	assert_array(team).is_equal([M, N, G])
	var other := TeamRules.resolve_default_team(TeamRule.make(), _reg, OwnedCrews.all_of(_reg), memory, &"1-8")
	assert_array(other).is_equal([X, K, M])


func test_remember_keeps_guest_teams_out_of_global_memory() -> void:
	# Rules 10–11.
	var owned := OwnedCrews.of(_team([N]), _reg)
	var rule := TeamRule.make(2, [N, G])
	var m := TeamRules.remember(TeamMemory.new(), &"1-3", _team([N, G]), rule, owned)
	assert_array(m.stage_team(&"1-3")).is_equal([N, G])
	assert_array(m.last_global).is_empty()
	var m2 := TeamRules.remember(m, &"1-5", _team([P, G, N]), TeamRule.make(), OwnedCrews.starter(_reg))
	assert_array(m2.last_global).is_equal([P, G, N])
	assert_array(m.last_global).is_empty()


func test_retry_team_is_the_last_team_unchanged() -> void:
	# Rule 13.
	var last := _team([P, N, G])
	assert_array(TeamRules.team_for_retry(last)).is_equal([P, N, G])


func test_rule_validation_errors() -> void:
	# Rule 6.
	var bad := TeamRule.make(3, [N], [N])
	bad.locked.append(TeamLock.make(3, G))
	var errors := " | ".join(TeamRules.validate_rule(bad, _reg))
	assert_str(errors).contains("also banned")
	assert_str(errors).contains("slot 3")
	assert_array(TeamRules.validate_rule(TeamRule.make(2, [N, G]), _reg)).is_empty()
	assert_str(" | ".join(TeamRules.validate_rule(TeamRule.make(1), _reg))).contains("must lock every slot")
