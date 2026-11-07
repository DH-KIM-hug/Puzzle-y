## DetRng determinism and range (ADR-0001 Decision 7).
extends GdUnitTestSuite


func test_next_u32_equals_hash_of_seed_and_counter() -> void:
	# Arrange
	var rng := DetRng.new(42)
	var first: Array[int] = [42, 0]
	var second: Array[int] = [42, 1]
	# Act / Assert
	assert_int(rng.next_u32()).is_equal(SeedHash.hash32(first))
	assert_int(rng.next_u32()).is_equal(SeedHash.hash32(second))
	assert_int(rng.get_counter()).is_equal(2)


func test_same_seed_gives_same_sequence() -> void:
	var a := DetRng.new(1201)
	var b := DetRng.new(1201)
	for i: int in 50:
		assert_int(a.next_u32()).is_equal(b.next_u32())


func test_negative_seed_is_masked_to_32_bits() -> void:
	var rng := DetRng.new(-1)
	assert_int(rng.get_seed()).is_equal(SeedHash.MASK32)


func test_below_stays_in_range() -> void:
	var rng := DetRng.new(7)
	for n: int in [1, 2, 3, 10, 64, 0x7FFFFFFF]:
		for i: int in 20:
			assert_int(rng.below(n)).is_between(0, n - 1)


func test_below_maximum_bound_does_not_overflow() -> void:
	# (0xFFFFFFFF * 0x7FFFFFFF) >> 32 = 2147483646 — no int64 overflow.
	assert_int((0xFFFFFFFF * 0x7FFFFFFF) >> 32).is_equal(2147483646)


func test_shuffle_is_deterministic_and_leaves_input_untouched() -> void:
	# Arrange
	var items := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var before := items.duplicate()
	# Act
	var a := DetRng.shuffle(items, 99)
	var b := DetRng.shuffle(items, 99)
	# Assert
	assert_array(items).is_equal(before)
	assert_array(a).is_equal(b)
	assert_array(a).contains_exactly_in_any_order(before)
	assert_int(a.size()).is_equal(before.size())


func test_shuffle_different_seeds_give_different_orders() -> void:
	var items := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var a := DetRng.shuffle(items, 1)
	var b := DetRng.shuffle(items, 2)
	assert_bool(a == b).is_false()
