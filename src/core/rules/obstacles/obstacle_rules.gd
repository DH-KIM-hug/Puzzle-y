## Cell kinds & obstacles (design/gdd/obstacles.md): the STONE kind, the ice
## modifier, the three resolver hooks (chain-resolver rule 21), load-time
## validation V1–V5 and the remaining-ice counts (F3).
##
## Pure static functions (ADR-0001). Hooks read only the cell they are given
## (kind flags + modifiers) — never RNG, time, tray, score or stage state (rule 10).
## [codeblock]
## var board := BoardState.create(8, 8, ObstacleRules.kind_table())
## ObstacleRules.set_ice(board, board.index_of(3, 3), 2)
## var ctx := ResolveContext.make(abilities, chain_rules, seed, ObstacleRules.hooks())
## [/codeblock]
##
## Modifier encoding (resolves stage-goals Q8 for the in-memory board): a cell's
## [code]modifiers[/code] [PackedInt32Array] is a flat list of
## [code](modifier_id, layers)[/code] pairs. MVP has one id, [constant MOD_ICE].
class_name ObstacleRules
extends RefCounted

## Modifier id of an ice entry (obstacles rule 6 kind "ice").
const MOD_ICE := 1
## Modifier kind name → id. Unknown names are load errors (rule 6).
const MODIFIER_IDS := {&"ice": MOD_ICE}
## Registered cell-kind names → kind id (rule 5 "CellTypeDef" registry, MVP).
const KIND_IDS := {&"EMPTY": CellKind.EMPTY, &"TILE": CellKind.TILE, &"STONE": CellKind.STONE}

const _HOOK_KEEP := &"keep"
const _HOOK_MODIFIERS := &"modifiers"


## The MVP kind table: default EMPTY/TILE plus STONE (blocks, counts, not removable — rule 1).
static func kind_table() -> PackedByteArray:
	return CellKind.with_kind(CellKind.default_table(), CellKind.STONE,
			CellKind.BLOCKS_PLACEMENT | CellKind.COUNTS_FOR_LINE)


## Hooks implementing rules 7–9: [code]pre_clear[/code] strips one ice layer,
## [code]can_activate[/code] stays default (rule 8 / D3), [code]target_filter[/code]
## = removable_by_clear.
static func hooks() -> ChainHooks:
	var h := ChainHooks.new()
	h.pre_clear = Callable(ObstacleRules, &"pre_clear")
	h.target_filter = Callable(ObstacleRules, &"target_filter")
	return h


## Rule 7: an iced cell is KEPT with one layer less (entry removed at 0); every
## other cell is CLEARed.
static func pre_clear(board: BoardState, cell: int) -> Dictionary:
	var mods := board.modifiers_at(cell)
	var layers := ice_in(mods)
	if layers < 1:
		return {_HOOK_KEEP: false, _HOOK_MODIFIERS: PackedInt32Array()}
	return {_HOOK_KEEP: true, _HOOK_MODIFIERS: with_ice(mods, layers - 1)}


## Rule 9: only removable cells are ability CLEAR targets (stones are skipped).
static func target_filter(board: BoardState, cell: int, _primitive: StringName) -> bool:
	return board.removable_by_clear(cell)


## Ice layers in a modifier list (0 when none).
static func ice_in(mods: PackedInt32Array) -> int:
	var i := 0
	while i + 1 < mods.size():
		if mods[i] == MOD_ICE:
			return mods[i + 1]
		i += 2
	return 0


## True when [param mods] holds an entry of modifier [param mod_id].
static func has_modifier(mods: PackedInt32Array, mod_id: int) -> bool:
	var i := 0
	while i + 1 < mods.size():
		if mods[i] == mod_id:
			return true
		i += 2
	return false


## [param mods] with the ice entry set to [param layers] (removed when 0). Other
## entries keep their order; a new ice entry is appended.
static func with_ice(mods: PackedInt32Array, layers: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var placed := false
	var i := 0
	while i + 1 < mods.size():
		if mods[i] == MOD_ICE:
			if layers > 0 and not placed:
				out.append(MOD_ICE)
				out.append(layers)
				placed = true
		else:
			out.append(mods[i])
			out.append(mods[i + 1])
		i += 2
	if layers > 0 and not placed:
		out.append(MOD_ICE)
		out.append(layers)
	return out


## Ice layers of the cell at [param index].
static func ice_layers(board: BoardState, index: int) -> int:
	return ice_in(board.modifiers_at(index))


## Fixture / stage-load helper: sets the cell's ice layers (copy-then-write only).
static func set_ice(board: BoardState, index: int, layers: int) -> void:
	board.set_modifiers(index, with_ice(board.modifiers_at(index), layers))


## F3: total ice layers on the board.
static func ice_remaining(board: BoardState) -> int:
	var n := 0
	for idx: int in board.modifiers:
		n += ice_layers(board, idx)
	return n


## F3: cells with at least one ice layer.
static func iced_cells(board: BoardState) -> int:
	var n := 0
	for idx: int in board.modifiers:
		if ice_layers(board, idx) >= 1:
			n += 1
	return n


## F4: stone count limit for a line of length [param length].
static func stone_line_ok(stones: int, length: int, cfg: ObstacleConfig) -> bool:
	return stones <= mini(cfg.max_stones_per_line, length - 1)


## Rule 16 load-time validation (empty = valid). Every message names the rule
## (V1–V5) and the offending cell / line. [param known_crews] maps every
## registry crew id → true (V5). Also rejects malformed modifier lists (rule 6).
static func validate_obstacles(board: BoardState, cfg: ObstacleConfig, known_crews: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	# V1: stones per line.
	for r: int in board.height:
		var n := 0
		for c: int in board.width:
			if board.kind[board.index_of(r, c)] == CellKind.STONE:
				n += 1
		if not stone_line_ok(n, board.width, cfg):
			errors.append("V1: row %d has %d stones (max %d)" % [r, n, mini(cfg.max_stones_per_line, board.width - 1)])
	for c: int in board.width:
		var n := 0
		for r: int in board.height:
			if board.kind[board.index_of(r, c)] == CellKind.STONE:
				n += 1
		if not stone_line_ok(n, board.height, cfg):
			errors.append("V1: column %d has %d stones (max %d)" % [c, n, mini(cfg.max_stones_per_line, board.height - 1)])
	var keys: Array = board.modifiers.keys()
	keys.sort()
	for idx: int in keys:
		var cell := board.cell_of(idx)
		var mods: PackedInt32Array = board.modifiers[idx]
		if mods.size() % 2 != 0:
			errors.append("rule 6: cell %s has a malformed modifier list" % cell)
			continue
		var seen := {}
		var i := 0
		var bad := false
		while i < mods.size():
			if mods[i] != MOD_ICE:
				errors.append("rule 6: cell %s has unknown modifier id %d" % [cell, mods[i]])
				bad = true
			elif seen.has(mods[i]):
				errors.append("rule 6: cell %s has more than one ice entry" % cell)
				bad = true
			seen[mods[i]] = true
			i += 2
		if bad:
			continue
		var layers := ice_in(mods)
		if not has_modifier(mods, MOD_ICE):
			continue
		# V2: ice only on TILE.
		if board.kind[idx] != CellKind.TILE:
			errors.append("V2: cell %s has ice on a non-TILE cell (kind %d)" % [cell, board.kind[idx]])
			continue
		# V3: layer range; faces exactly frozen_face_layers.
		if board.is_face(idx):
			if layers != cfg.frozen_face_layers:
				errors.append("V3: frozen face %s has %d ice layers (must be %d)" % [cell, layers, cfg.frozen_face_layers])
		elif layers < 1 or layers > cfg.ice_max_layers:
			errors.append("V3: cell %s has %d ice layers (allowed 1..%d)" % [cell, layers, cfg.ice_max_layers])
		# V4: no ice on eggs.
		if board.origin(idx) == BoardState.ORIGIN_EGG:
			errors.append("V4: egg cell %s has ice" % cell)
		# V5: frozen face crew registered.
		if board.is_face(idx) and not known_crews.has(board.crew_at(idx)):
			errors.append("V5: frozen face %s has unregistered crew_id '%s'" % [cell, board.crew_at(idx)])
	return errors
