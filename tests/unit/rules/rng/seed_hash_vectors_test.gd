## SeedHash golden vectors (ADR-0001 Decision 7, Validation Criteria).
## Vectors are public MurmurHash3_x86_32 / FNV-1a 32 values, cross-checked
## offline against an independent reference implementation.
extends GdUnitTestSuite


func _h(parts: Array[int]) -> int:
	return SeedHash.hash32(parts)


func test_hash32_single_zero_matches_adr_reference_vector() -> void:
	# Arrange
	var parts: Array[int] = [0]
	# Act
	var h := _h(parts)
	# Assert
	assert_int(h).is_equal(593689054)


func test_hash32_public_murmur3_vectors_match() -> void:
	# Arrange / Act / Assert — boundary vectors: the exact numbers are the point.
	var empty: Array[int] = []
	var all_ones: Array[int] = [0xFFFFFFFF]
	var minus_one: Array[int] = [-1]
	var word: Array[int] = [0x87654321]
	assert_int(_h(empty)).is_equal(0)
	assert_int(_h(all_ones)).is_equal(0x76293B50)
	assert_int(_h(minus_one)).is_equal(0x76293B50)
	assert_int(_h(word)).is_equal(0xF55B516B)


func test_hash32_multi_part_vectors_match_reference() -> void:
	var a: Array[int] = [1, 2, 3]
	var b: Array[int] = [0, 0]
	var c: Array[int] = [1201, SeedStreams.RESOLVER, 2]
	assert_int(_h(a)).is_equal(3923217110)
	assert_int(_h(b)).is_equal(1669671676)
	assert_int(_h(c)).is_equal(1399170064)


func test_hash32_result_is_always_unsigned_32_bit() -> void:
	for i: int in 200:
		var parts: Array[int] = [i, -i, i * 7919]
		var h := _h(parts)
		assert_int(h).is_between(0, SeedHash.MASK32)


func test_mul32_matches_masked_product_at_boundaries() -> void:
	# (a*b) & MASK32 computed in pieces that never overflow int64.
	assert_int(SeedHash.mul32(0xFFFFFFFF, 0xFFFFFFFF)).is_equal(1)
	assert_int(SeedHash.mul32(0xFFFFFFFF, 2)).is_equal(0xFFFFFFFE)
	assert_int(SeedHash.mul32(0x10000, 0x10000)).is_equal(0)
	assert_int(SeedHash.mul32(12345, 6789)).is_equal(83810205)


func test_rotl32_wraps_high_bits() -> void:
	assert_int(SeedHash.rotl32(0x80000000, 1)).is_equal(1)
	assert_int(SeedHash.rotl32(0x12345678, 8)).is_equal(0x34567812)


func test_str32_matches_fnv1a_vectors() -> void:
	assert_int(SeedHash.str32("")).is_equal(0x811C9DC5)
	assert_int(SeedHash.str32("a")).is_equal(0xE40C292C)
	assert_int(SeedHash.str32("foobar")).is_equal(0xBF9CF968)
	assert_int(SeedHash.str32("nyangi")).is_equal(3027572035)
	assert_int(SeedHash.str32("냥이")).is_equal(3271259883)


func test_resolver_seed_same_inputs_give_same_value() -> void:
	# chain-resolver AC-22: preview side and commit side derive the same seed.
	var preview_seed := SeedStreams.resolver_seed(1201, 2)
	var commit_seed := SeedStreams.resolver_seed(1201, 2)
	assert_int(preview_seed).is_equal(commit_seed)
	assert_int(preview_seed).is_equal(1399170064)


func test_resolver_seed_hundred_placement_indices_are_distinct() -> void:
	var seen := {}
	for i: int in 100:
		seen[SeedStreams.resolver_seed(1201, i)] = true
	assert_int(seen.size()).is_equal(100)
