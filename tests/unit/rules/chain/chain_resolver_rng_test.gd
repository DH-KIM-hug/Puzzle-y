## chain-resolver AC-15, AC-22 — MVP results independent of rng_seed; no global RNG.
extends GdUnitTestSuite


func test_result_identical_for_seeds_zero_one_and_max() -> void:
	# AC-15
	var base := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3), ChainFixture.ctx(6, 0))
	for s: int in [1, 0x7FFFFFFF]:
		var other := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3), ChainFixture.ctx(6, s))
		assert_str(ChainFixture.signature(other)).is_equal(ChainFixture.signature(base))
		assert_bool(other.final_board.equals(base.final_board)).is_true()


func test_resolver_sources_have_no_global_random_calls() -> void:
	# AC-15 AND (static check over the chain module, comments excluded).
	for path: String in ["res://src/core/rules/chain/chain_resolver.gd", "res://src/core/rules/chain/primitive_library.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_str(text).is_not_empty()
		for line: String in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for token: String in ["randi", "randf", "randomize", "RandomNumberGenerator"]:
				assert_str(code).override_failure_message("%s uses %s" % [path, token]).not_contains(token)


func test_seed_for_matches_between_preview_and_commit() -> void:
	# AC-22: both sides derive the context seed the same way.
	var preview_ctx := ChainFixture.ctx(6, SeedStreams.resolver_seed(1201, 2))
	var commit_ctx := ChainFixture.ctx(6, SeedStreams.resolver_seed(1201, 2))
	assert_int(preview_ctx.rng_seed).is_equal(commit_ctx.rng_seed)
