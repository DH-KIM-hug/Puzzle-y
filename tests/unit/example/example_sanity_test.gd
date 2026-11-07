# GdUnit generated TestSuite
## Example test proving the gdUnit4 runner works. Safe to delete once real
## unit tests exist under tests/unit/.
extends GdUnitTestSuite


func test_addition_returns_expected_sum() -> void:
	# Arrange
	var a := 2
	var b := 3
	# Act
	var result := a + b
	# Assert
	assert_int(result).is_equal(5)
