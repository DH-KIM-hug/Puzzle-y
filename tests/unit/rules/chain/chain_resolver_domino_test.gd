## Port of the prototype's verified domino scenario
## (prototypes/sticker-place-concept/README.md "헤드리스 검증 v1"): a piyak piece
## completes a line → nyangi cross → gomgom 3×3 → piyak eggs → line. Expected:
## chain depth 3 with 4 ability activations. Rewritten from the README description,
## not from prototype code.
extends GdUnitTestSuite


func _piyak_piece() -> PieceInstance:
	return BoardFixture.piece([Vector2i(0, 0)], BoardFixture.PIYAK, 0)


func _assert_domino(res: ChainResult) -> void:
	assert_int(res.summary[ChainEvent.K_CHAIN_DEPTH]).is_equal(3)
	assert_int(res.summary[ChainEvent.K_FACES_ACTIVATED]).is_equal(4)
	assert_int(res.summary[ChainEvent.K_WAVES]).is_equal(4)
	var crews := []
	for e: ChainEvent in res.events_of(ChainEvent.Type.FACE_ACTIVATED):
		crews.append([String(e.data[ChainEvent.K_CREW_ID]), e.data[ChainEvent.K_STAGE]])
	assert_array(crews).is_equal([["piyak", 1], ["nyangi", 1], ["gomgom", 2], ["piyak", 3]])
	var last_wave: ChainEvent = res.events_of(ChainEvent.Type.WAVE_BEGIN)[3]
	assert_array(last_wave.data[ChainEvent.K_CAUSES]).is_equal([ChainEvent.CAUSE_LINE])
	assert_array(last_wave.data[ChainEvent.K_ROWS]).is_equal([3])
	var eggs: ChainEvent = res.events_of(ChainEvent.Type.ABILITY_EFFECT)[3]
	assert_array(eggs.data[ChainEvent.K_CELLS]).is_equal([Vector2i(3, 6), Vector2i(3, 5), Vector2i(3, 4)])
	assert_int(BoardRules.full_lines(res.final_board).count()).is_equal(0)


func test_prototype_domino_with_test_ability_table_reaches_depth_three() -> void:
	# Arrange
	var b := BoardFixture.board(ChainFixture.PROTOTYPE_DOMINO)
	# Act
	var res := ChainResolver.resolve(b, _piyak_piece(), Vector2i(7, 3), ChainFixture.ctx())
	# Assert
	_assert_domino(res)


func test_prototype_domino_with_real_starter_crew_data_reaches_depth_three() -> void:
	# Arrange — real .tres crew data (ADR-0001: assets/data/crew/).
	var registry: CrewRegistry = load("res://assets/data/crew/crew_registry.tres")
	assert_array(Array(registry.load_and_validate())).is_empty()
	var rules: ChainRules = load("res://assets/data/rules/chain_rules.tres")
	var ctx := ResolveContext.make(registry.abilities(), rules, SeedStreams.resolver_seed(1201, 0))
	# Act
	var res := ChainResolver.resolve(BoardFixture.board(ChainFixture.PROTOTYPE_DOMINO), _piyak_piece(), Vector2i(7, 3), ctx)
	# Assert
	_assert_domino(res)
	assert_str(String(res.events_of(ChainEvent.Type.FACE_ACTIVATED)[1].data[ChainEvent.K_ABILITY_ID])).is_equal("nyangi_cross_scratch")
