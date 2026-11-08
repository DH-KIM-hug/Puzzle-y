## tray-supply AC-01 … AC-04 — tray structure (rules 1–6).
extends GdUnitTestSuite


func _full_tray() -> TrayState:
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, TrayFixture.registry())
	return TraySupplyRules.refill(s, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED).state


func test_consume_empties_only_that_slot_and_keeps_other_instances() -> void:
	# Arrange (AC-01)
	var full := _full_tray()
	var a: PieceInstance = full.slots[0]
	var c: PieceInstance = full.slots[2]
	# Act
	var after := TraySupplyRules.consume(full, 1)
	# Assert
	assert_object(after.slots[0]).is_same(a)
	assert_object(after.slots[1]).is_null()
	assert_object(after.slots[2]).is_same(c)
	assert_int(after.status).is_equal(TrayState.Status.PARTIAL)
	assert_object(full.slots[1]).is_not_null()  # input state untouched


func test_refill_on_non_empty_tray_is_refused_and_keeps_snapshot() -> void:
	# Arrange (AC-02): one piece left.
	var s := TraySupplyRules.consume(TraySupplyRules.consume(_full_tray(), 0), 1)
	var before := TrayFixture.describe_slots(s)
	var holder := {}
	# Act
	await assert_error(func() -> void:
		holder.r = TraySupplyRules.refill(s, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED)
	).is_push_error(TraySupplyRules.ERR_NOT_EMPTY)
	# Assert
	var r: TrayRefill = holder.r
	assert_str(r.error).is_equal(TraySupplyRules.ERR_NOT_EMPTY)
	assert_array(TrayFixture.describe_slots(r.state)).is_equal(before)
	assert_array(r.pieces).is_empty()


func test_refill_on_empty_tray_with_budget_three_fills_all_slots() -> void:
	# AC-02 AND
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 5, TrayFixture.registry())
	var r := TraySupplyRules.refill(s, BoardFixture.empty(), 3)
	assert_int(r.pieces.size()).is_equal(3)
	assert_int(r.state.status).is_equal(TrayState.Status.FULL)
	assert_int(s.status).is_equal(TrayState.Status.AWAITING_REFILL)


func test_budget_two_gives_partial_and_budget_zero_gives_exhausted() -> void:
	# AC-03
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 5, TrayFixture.registry())
	var two := TraySupplyRules.refill(s, BoardFixture.empty(), 2)
	assert_int(two.pieces.size()).is_equal(2)
	assert_object(two.state.slots[2]).is_null()
	assert_int(two.state.status).is_equal(TrayState.Status.PARTIAL)
	var zero := TraySupplyRules.refill(s, BoardFixture.empty(), 0)
	assert_array(zero.pieces).is_empty()
	assert_bool(zero.state.is_empty()).is_true()
	assert_int(zero.state.status).is_equal(TrayState.Status.EXHAUSTED)
	assert_int(zero.state.refill_index).is_equal(0)


func test_shown_pieces_never_change_until_consumed() -> void:
	# AC-04: after a placement leaves the other two unplaceable, continuing the
	# recorded placements never alters them (no mid-tray rescue).
	var registry := TrayFixture.registry()
	var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), 1201, registry)
	var full := TraySupplyRules.refill(s, BoardFixture.empty(), TraySupplyRules.BUDGET_UNLIMITED).state
	var tight := TrayFixture.board("isolated_singles.txt")
	var kept := [TrayFixture.describe(full.slots[1]), TrayFixture.describe(full.slots[2])]
	var refs := [full.slots[1], full.slots[2]]
	# Act: slot 0 is consumed; the board is now tight; the next placement consumes slot 1.
	var after0 := TraySupplyRules.consume(full, 0)
	assert_bool(BoardRules.any_fit(tight, after0.slots[1])).is_false()
	assert_bool(BoardRules.any_fit(tight, after0.slots[2])).is_false()
	var after1 := TraySupplyRules.consume(after0, 1)
	# Assert
	assert_str(TrayFixture.describe(after0.slots[1])).is_equal(kept[0])
	assert_str(TrayFixture.describe(after0.slots[2])).is_equal(kept[1])
	assert_object(after1.slots[2]).is_same(refs[1])
	assert_str(TrayFixture.describe(after1.slots[2])).is_equal(kept[1])


func test_consume_of_empty_slot_is_refused() -> void:
	var s := TraySupplyRules.consume(_full_tray(), 0)
	var holder := {}
	await assert_error(func() -> void:
		holder.s = TraySupplyRules.consume(s, 0)
	).is_push_error(TraySupplyRules.ERR_BAD_SLOT)
	assert_object(holder.s).is_same(s)
