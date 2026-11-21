## Chain-resolver test fixtures: the test-only ability table from the
## chain-resolver AC preamble (nyangi clear_cross(−1), gomgom clear_area(1),
## piyak lay_eggs_in_own_line(3, fuller, nearest)) and named fixture boards.
## Real crew data can change without breaking resolver tests.
class_name ChainFixture
extends RefCounted

## AC-03 "domino_ng": row 7 missing only (7,3); nyangi (7,5); gomgom (4,5).
## Column 5 keeps (0,5) empty so the stable-board invariant holds (see scoring test).
const DOMINO_NG: Array = [
	"........",
	".....#..",
	".....#..",
	"....###.",
	"....#G#.",
	"....###.",
	".....#..",
	"###.#N##",
]

## AC-08 depth chain: seven gomgom faces on a diagonal, row 7 missing (7,7).
const DEPTH_CHAIN: Array = [
	"........",
	"......G.",
	".....G..",
	"....G...",
	"...G....",
	"..G.....",
	".G......",
	"G######.",
]

## Prototype domino (prototypes/sticker-place-concept README): a piyak piece at
## (7,3) completes row 7 → nyangi cross → gomgom 3×3 → piyak eggs → row 3.
const PROTOTYPE_DOMINO: Array = [
	"........",
	"........",
	"........",
	"####.GP#",
	"........",
	"........",
	"........",
	"###.#N##",
]


## The test-only ability table.
static func abilities() -> AbilityTable:
	return AbilityTable.create({
		BoardFixture.NYANGI: {&"ability_id": &"test_cross", &"steps": [{&"primitive": &"clear_cross", &"params": {&"reach": -1}}]},
		BoardFixture.GOMGOM: {&"ability_id": &"test_area", &"steps": [{&"primitive": &"clear_area", &"params": {&"radius": 1}}]},
		BoardFixture.PIYAK: {&"ability_id": &"test_eggs", &"steps": [{&"primitive": &"lay_eggs_in_own_line", &"params": {&"count": 3, &"prefer": &"fuller", &"order": &"nearest"}}]},
	})


## Chain rules with the given depth cap.
static func rules(depth_cap: int = 6) -> ChainRules:
	var r := ChainRules.new()
	r.depth_cap = depth_cap
	return r


## A resolve context over the test ability table.
static func ctx(depth_cap: int = 6, rng_seed: int = 0, hooks: ChainHooks = null) -> ResolveContext:
	return ResolveContext.make(abilities(), rules(depth_cap), rng_seed, hooks)


## Resolves a faceless 1-cell piece at [param anchor] on [param rows].
static func resolve_single(rows: Array, anchor: Vector2i, context: ResolveContext = null) -> ChainResult:
	var c := context if context != null else ctx()
	return ChainResolver.resolve(BoardFixture.board(rows), BoardFixture.single(), anchor, c)


## FACE_ACTIVATED events as [cell, stage, order_index] triples.
static func activations(result: ChainResult) -> Array:
	var out := []
	for e: ChainEvent in result.events_of(ChainEvent.Type.FACE_ACTIVATED):
		out.append([e.data[ChainEvent.K_CELL], e.data[ChainEvent.K_STAGE], e.data[ChainEvent.K_ORDER_INDEX]])
	return out


## Event type names in order.
static func type_names(result: ChainResult) -> Array:
	var out := []
	for e: ChainEvent in result.events:
		out.append(e.type_name())
	return out


## Stable text form of the events (golden / determinism comparison).
static func signature(result: ChainResult) -> String:
	return var_to_str(result.events_as_dicts())


## Cells (Vector2i) of a CELLS_CLEARED event.
static func cleared_cells(e: ChainEvent) -> Array:
	var out := []
	for c: Dictionary in e.data[ChainEvent.K_CELLS]:
		out.append(Vector2i(c[ChainEvent.K_R], c[ChainEvent.K_C]))
	return out
