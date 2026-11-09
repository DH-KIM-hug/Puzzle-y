## design/gdd/obstacles.md rule 14 / AC-O13: the preview model predicts ice
## cracks, freed ice and thawing faces from the resolver's events only.
extends GdUnitTestSuite

const E7 := ["........", "........", "........", "........", "........", "........", "........"]


func test_two_layer_ice_is_predicted_as_cracked() -> void:
	# Arrange
	var b := ObstacleFixture.board(E7 + ["#######."], {Vector2i(7, 2): 2})
	# Act
	var m := PreviewModel.preview(b, BoardFixture.single(), Vector2i(7, 7), ObstacleFixture.ctx())
	# Assert
	assert_array(m.cracked).is_equal([Vector2i(7, 2)])
	assert_array(m.freed).is_empty()
	assert_array(m.thawed).is_empty()
	assert_bool(m.clear_waves.has(Vector2i(7, 2))).is_false()


func test_frozen_face_is_predicted_as_thawed_and_badged_when_it_fires() -> void:
	# Arrange: AC-O08 board.
	var b := ObstacleFixture.board(E7 + ["#GN####."], {Vector2i(7, 2): 1})
	# Act
	var m := PreviewModel.preview(b, BoardFixture.single(), Vector2i(7, 7), ObstacleFixture.ctx())
	# Assert
	assert_array(m.thawed).is_equal([Vector2i(7, 2)])
	var staged := m.badges.filter(func(x: Dictionary) -> bool: return x[PreviewModel.K_CELL] == Vector2i(7, 2))
	assert_int(staged.size()).is_equal(1)
	assert_int(staged[0][PreviewModel.K_STAGE]).is_equal(2)
	assert_bool(m.to_dict().has(&"obstacles")).is_true()


func test_plain_ice_freed_then_cleared_in_the_next_wave() -> void:
	# Arrange: AC-O06 board.
	var b := ObstacleFixture.board(E7 + ["#G#####."], {Vector2i(7, 2): 1})
	# Act
	var m := PreviewModel.preview(b, BoardFixture.single(), Vector2i(7, 7), ObstacleFixture.ctx())
	# Assert
	assert_array(m.freed).is_equal([Vector2i(7, 2)])
	assert_array(m.clear_waves[Vector2i(7, 2)]).is_equal([1])


func test_obstacle_free_model_has_no_obstacle_key() -> void:
	# Keeps the committed parity digests of obstacle-free cases unchanged.
	var m := PreviewModel.preview(BoardFixture.board(ChainFixture.DOMINO_NG), BoardFixture.single(), Vector2i(7, 3), ObstacleFixture.ctx())
	assert_bool(m.to_dict().has(&"obstacles")).is_false()
