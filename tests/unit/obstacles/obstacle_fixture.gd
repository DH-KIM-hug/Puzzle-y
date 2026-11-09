## Obstacle test fixtures (design/gdd/obstacles.md AC preamble). Board rows use
## [BoardFixture] characters ([code]S[/code] = STONE, kind 2 on the obstacle kind
## table); ice is added per cell from a {Vector2i(row, col): layers} map.
class_name ObstacleFixture
extends RefCounted


## Board from rows on the MVP obstacle kind table, with [param ice] layers applied.
static func board(rows: Array, ice: Dictionary = {}) -> BoardState:
	var b := BoardFixture.board(rows, ObstacleRules.kind_table())
	for cell: Vector2i in ice:
		ObstacleRules.set_ice(b, b.index_of_cell(cell), int(ice[cell]))
	return b


## Resolve context over the test ability table with the obstacle hooks.
static func ctx(depth_cap: int = 6) -> ResolveContext:
	return ChainFixture.ctx(depth_cap, 0, ObstacleRules.hooks())


## Resolves [param piece] (default: faceless single) at [param anchor] with obstacle hooks.
static func resolve(b: BoardState, anchor: Vector2i, piece: PieceInstance = null) -> ChainResult:
	return ChainResolver.resolve(b, piece if piece != null else BoardFixture.single(), anchor, ctx())


## Default MVP obstacle config (ice 2, frozen face 1, stones 3).
static func cfg() -> ObstacleConfig:
	return ObstacleConfig.new()


## Every registered crew id of the test ability table → true.
static func known_crews() -> Dictionary:
	return {BoardFixture.NYANGI: true, BoardFixture.GOMGOM: true, BoardFixture.PIYAK: true}
