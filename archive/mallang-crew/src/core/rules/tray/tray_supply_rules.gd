## Tray supply rules (design/gdd/tray-supply.md, ADR-0001 Decisions 6–7).
##
## Stateless static functions over [TrayState] values: [method init_state] at
## round start, [method refill] when every slot is empty, [method consume] when a
## placement commits. Every draw is a fresh [DetRng] seeded from
## [code]hash32([stage_seed, SeedStreams.TRAY_*, index…])[/code] (F3), so the
## order depends only on (stage_seed, team, config, registry) and a rescue never
## shifts later trays (rule 13.5, D10).
## [codeblock]
## var tray := TraySupplyRules.init_state(team, cfg, stage_seed, registry)
## var r := TraySupplyRules.refill(tray, board, TraySupplyRules.BUDGET_UNLIMITED)
## tray = TraySupplyRules.consume(r.state, 1)
## [/codeblock]
class_name TraySupplyRules
extends RefCounted

## [method refill] budget meaning "no piece limit".
const BUDGET_UNLIMITED := -1
## Script spec keys (rule 19).
const K_SHAPE := &"shape"
const K_CREW := &"crew"
const K_FACE := &"face"
## Script shape value: draw from that crew's shape bag (rule 19).
const SHAPE_FROM_BAG := &"*"
## Script face value: uniform face cell (rule 10).
const FACE_RANDOM := -1
## Denominator of [member TrayRules.faceless_share_permille].
const PERMILLE := 1000
## Mask applied to a derived PER_ATTEMPT stage seed (F3 range 0 .. 2^31 - 1).
const STAGE_SEED_MASK := 0x7FFFFFFF

const ERR_NOT_EMPTY := "TraySupplyRules.refill: tray is not empty (rule 3)"
const ERR_INVALID_STATE := "TraySupplyRules.refill: tray state has load errors"
const ERR_BAD_SLOT := "TraySupplyRules.consume: slot is empty or out of range"


## Round start (rule 7). Validates [param cfg] against [param team] and
## [param registry] (rule 22, Edge Cases): problems land in
## [member TrayState.errors] (load errors) and [member TrayState.warnings] (lint).
static func init_state(team: Array[StringName], cfg: TrayRules, stage_seed: int, registry: CrewRegistry) -> TrayState:
	var s := TrayState.new()
	s.team = team.duplicate()
	s.cfg = cfg
	s.registry = registry
	s.stage_seed = stage_seed
	s.errors = validate_config(team, cfg, registry)
	s.warnings = lint_config(team, cfg, registry) if s.errors.is_empty() else PackedStringArray()
	var size := cfg.tray_size if cfg != null else 0
	s.slots.resize(maxi(size, 0))
	return s


## Rule 18 seed policy: FIXED → [param stage_base_seed];
## PER_ATTEMPT → [code]hash32(stage_base_seed, STREAM_ATTEMPT, attempt_index)[/code] (31 bits).
static func stage_seed_for(mode: TrayRules.SeedMode, stage_base_seed: int, attempt_index: int) -> int:
	if mode == TrayRules.SeedMode.FIXED:
		return stage_base_seed
	var parts: Array[int] = [stage_base_seed, SeedStreams.ATTEMPT, attempt_index]
	return SeedHash.hash32(parts) & STAGE_SEED_MASK


## Rule 3: fills an all-empty tray with [code]m = min(tray_size, budget)[/code]
## pieces (script entry, else generated + rule 13 rescue). [param budget] is the
## stage's remaining piece limit or [constant BUDGET_UNLIMITED]; 0 → EXHAUSTED,
## nothing drawn. A non-empty tray is refused with a pushed error and the state
## returned unchanged (rule 4: shown pieces never change).
static func refill(state: TrayState, board: BoardState, budget: int) -> TrayRefill:
	var out := TrayRefill.new()
	out.state = state
	if not state.is_valid():
		push_error(ERR_INVALID_STATE)
		out.error = ERR_INVALID_STATE
		return out
	if not state.is_empty():
		push_error(ERR_NOT_EMPTY)
		out.error = ERR_NOT_EMPTY
		return out
	var s := state.copy()
	out.state = s
	var cfg := s.cfg
	var m := cfg.tray_size if budget == BUDGET_UNLIMITED else mini(cfg.tray_size, maxi(budget, 0))
	if m == 0:
		s.status = TrayState.Status.EXHAUSTED
		return out
	var entry: Variant = _script_entry(s)
	if entry != null:
		out.scripted = true
		var specs: Array = entry
		for x: int in mini(specs.size(), m):
			var piece := _script_piece(s, specs[x])
			s.slots[x] = piece
			out.pieces.append(piece)
	else:
		var token_crews: Array[StringName] = []
		for x: int in m:
			var crew_id := _draw_crew(s)
			token_crews.append(crew_id)
			var e := _draw_shape_entry(s, crew_id)
			var face := _face(s.stage_seed, s.piece_index, e.shape, e.face_cell)
			var piece: PieceInstance
			if _is_faceless_draw(s):
				piece = PieceInstance.make(e.shape, &"", PieceInstance.NO_FACE, s.piece_index + 1)
			else:
				piece = PieceInstance.make(e.shape, crew_id, face, s.piece_index + 1)
			s.piece_index += 1
			s.slots[x] = piece
			out.pieces.append(piece)
		if cfg.rescue_enabled:
			_rescue(s, board, token_crews, out)
	s.status = TrayState.Status.FULL if s.pieces().size() == cfg.tray_size else TrayState.Status.PARTIAL
	s.refill_index += 1
	return out


## Rule 2: empties [param slot]; the other pieces keep their slot and instance.
## An empty or out-of-range slot pushes an error and returns [param state] unchanged.
static func consume(state: TrayState, slot: int) -> TrayState:
	if slot < 0 or slot >= state.slots.size() or state.slots[slot] == null:
		push_error(ERR_BAD_SLOT)
		return state
	var s := state.copy()
	s.slots[slot] = null
	s.status = TrayState.Status.AWAITING_REFILL if s.is_empty() else TrayState.Status.PARTIAL
	return s


## Rule 22 load validation (empty = valid). Messages name the field.
static func validate_config(team: Array[StringName], cfg: TrayRules, registry: CrewRegistry) -> PackedStringArray:
	var errors := PackedStringArray()
	if cfg == null:
		errors.append("tray: cfg is null")
		return errors
	if registry == null:
		errors.append("tray: registry is null")
		return errors
	if cfg.tray_size < 1:
		errors.append("tray: tray_size %d < 1" % cfg.tray_size)
	if cfg.crew_bag_copies < 1:
		errors.append("tray: crew_bag_copies %d < 1" % cfg.crew_bag_copies)
	if cfg.faceless_share_permille < 0 or cfg.faceless_share_permille > PERMILLE:
		errors.append("tray: faceless_share_permille %d out of 0..%d" % [cfg.faceless_share_permille, PERMILLE])
	var seen := {}
	for crew_id: StringName in team:
		if seen.has(crew_id):
			errors.append("tray: team: duplicate crew %s" % crew_id)
		seen[crew_id] = true
		if _crew_def(registry, crew_id) == null:
			errors.append("tray: team: unknown crew %s" % crew_id)
	var script_loops := not cfg.tray_script.is_empty() and cfg.after_script == TrayRules.AfterScript.LOOP
	if team.is_empty() and not script_loops:
		errors.append("tray: team: empty team needs a looping tray_script")
	if cfg.after_script == TrayRules.AfterScript.LOOP and cfg.tray_script.is_empty():
		errors.append("tray: after_script: LOOP with an empty tray_script")
	var catalog := _catalog(registry, cfg)
	for r: int in cfg.tray_script.size():
		var entry: Variant = cfg.tray_script[r]
		if not (entry is Array) or (entry as Array).is_empty() or (entry as Array).size() > cfg.tray_size:
			errors.append("tray: tray_script[%d]: entry must hold 1..%d specs" % [r, cfg.tray_size])
			continue
		for x: int in (entry as Array).size():
			_validate_spec(errors, "tray: tray_script[%d][%d]" % [r, x], (entry as Array)[x], team, cfg, registry, catalog)
	return errors


## Lint warnings (rule 22, Edge Cases): ignored faceless share; a team-slot spec
## whose shape is not in that crew's pool.
static func lint_config(team: Array[StringName], cfg: TrayRules, registry: CrewRegistry) -> PackedStringArray:
	var warnings := PackedStringArray()
	if cfg.faceless_share_permille > 0 and not cfg.allow_faceless_pieces:
		warnings.append("tray: faceless_share_permille %d ignored: allow_faceless_pieces = false" % cfg.faceless_share_permille)
	for r: int in cfg.tray_script.size():
		var entry: Array = cfg.tray_script[r]
		for x: int in entry.size():
			var spec: Dictionary = entry[x]
			var crew_v: Variant = spec.get(K_CREW, null)
			var shape_id := StringName(spec.get(K_SHAPE, &""))
			if typeof(crew_v) != TYPE_INT or shape_id == SHAPE_FROM_BAG:
				continue
			var def := _crew_def(registry, team[int(crew_v)])
			if _entry_index(def, shape_id) < 0:
				warnings.append("tray: tray_script[%d][%d]: shape %s is not in crew %s's shapes" % [r, x, shape_id, def.id])
	return warnings


# --- seeds (F3) -----------------------------------------------------------------

## [code]seed_crew(j) = hash32(stage_seed, STREAM_TRAY_CREW, j)[/code].
static func crew_bag_seed(stage_seed: int, bag_index: int) -> int:
	var parts: Array[int] = [stage_seed, SeedStreams.TRAY_CREW, bag_index]
	return SeedHash.hash32(parts)


## [code]seed_shape(c, q) = hash32(stage_seed, STREAM_TRAY_SHAPE, crew_key(c), q)[/code].
static func shape_bag_seed(stage_seed: int, crew_id: StringName, cycle: int) -> int:
	var parts: Array[int] = [stage_seed, SeedStreams.TRAY_SHAPE, SeedHash.str32(String(crew_id)), cycle]
	return SeedHash.hash32(parts)


## [code]seed_face(i) = hash32(stage_seed, STREAM_TRAY_FACE, i)[/code].
static func face_seed(stage_seed: int, piece_index: int) -> int:
	var parts: Array[int] = [stage_seed, SeedStreams.TRAY_FACE, piece_index]
	return SeedHash.hash32(parts)


## [code]seed_faceless(i) = hash32(stage_seed, STREAM_TRAY_FACELESS, i)[/code].
static func faceless_seed(stage_seed: int, piece_index: int) -> int:
	var parts: Array[int] = [stage_seed, SeedStreams.TRAY_FACELESS, piece_index]
	return SeedHash.hash32(parts)


## [code]seed_rescue(r) = hash32(stage_seed, STREAM_TRAY_RESCUE, r)[/code].
static func rescue_seed(stage_seed: int, refill_index: int) -> int:
	var parts: Array[int] = [stage_seed, SeedStreams.TRAY_RESCUE, refill_index]
	return SeedHash.hash32(parts)


# --- internals --------------------------------------------------------------------

static func _script_entry(s: TrayState) -> Variant:
	var script := s.cfg.tray_script
	if script.is_empty():
		return null
	if s.refill_index < script.size():
		return script[s.refill_index]
	if s.cfg.after_script == TrayRules.AfterScript.LOOP:
		return script[s.refill_index % script.size()]
	return null


## Rule 19 spec → piece. Consumes the crew's shape bag only for [code]shape = *[/code].
static func _script_piece(s: TrayState, spec: Dictionary) -> PieceInstance:
	var crew_v: Variant = spec.get(K_CREW, null)
	var crew_id := &""
	if typeof(crew_v) == TYPE_INT:
		crew_id = s.team[int(crew_v)]
	elif crew_v != null:
		crew_id = StringName(crew_v)
	var face_v: Variant = spec.get(K_FACE, FACE_RANDOM)
	var shape_id := StringName(spec.get(K_SHAPE, &""))
	var shape: PieceShape
	var face_cell := -1
	if shape_id == SHAPE_FROM_BAG:
		var e := _draw_shape_entry(s, crew_id)
		shape = e.shape
		face_cell = e.face_cell
	else:
		shape = _catalog(s.registry, s.cfg)[shape_id]
	var piece: PieceInstance
	if crew_id == &"" or face_v == null:
		piece = PieceInstance.make(shape, &"", PieceInstance.NO_FACE, s.piece_index + 1)
	else:
		var face := int(face_v)
		if face == FACE_RANDOM:
			face = _face(s.stage_seed, s.piece_index, shape, face_cell)
		piece = PieceInstance.make(shape, crew_id, face, s.piece_index + 1)
	s.piece_index += 1
	return piece


## Rule 8: next crew token; a new bag (shuffled with F3 seed_crew) when empty.
static func _draw_crew(s: TrayState) -> StringName:
	if s.crew_bag.is_empty():
		var tokens: Array = []
		for crew_id: StringName in s.team:
			for k: int in s.cfg.crew_bag_copies:
				tokens.append(crew_id)
		s.crew_bag.assign(DetRng.shuffle(tokens, crew_bag_seed(s.stage_seed, s.crew_bag_index)))
		s.crew_bag_index += 1
	return s.crew_bag.pop_front()


## Rule 9: next shape entry of [param crew_id]; a new cycle (each entry ×weight,
## shuffled with F3 seed_shape) when the crew's bag is empty.
static func _draw_shape_entry(s: TrayState, crew_id: StringName) -> CrewShapeEntry:
	var def := _crew_def(s.registry, crew_id)
	var bag: Array = s.shape_bags.get(crew_id, [])
	if bag.is_empty():
		var q: int = s.shape_cycles.get(crew_id, 0)
		var items: Array = []
		for e_idx: int in def.shapes.size():
			for w: int in def.shapes[e_idx].weight:
				items.append(e_idx)
		bag = DetRng.shuffle(items, shape_bag_seed(s.stage_seed, crew_id, q))
		s.shape_cycles[crew_id] = q + 1
	var idx: int = bag.pop_front()
	s.shape_bags[crew_id] = bag
	return def.shapes[idx]


## Rule 10 / F4: fixed face cell, else uniform over the shape's cells.
static func _face(stage_seed: int, piece_index: int, shape: PieceShape, face_cell: int) -> int:
	if face_cell >= 0:
		return face_cell
	return DetRng.new(face_seed(stage_seed, piece_index)).below(shape.cell_count())


## Rule 11: faceless draw for the piece at [member TrayState.piece_index].
static func _is_faceless_draw(s: TrayState) -> bool:
	var share := s.cfg.faceless_share_permille
	if not s.cfg.allow_faceless_pieces or share <= 0:
		return false
	return DetRng.new(faceless_seed(s.stage_seed, s.piece_index)).below(PERMILLE) < share


## Rule 13 / F5: when every new candidate is unplaceable, swap one slot whose
## crew has a placeable shape. Never touches the bags; at most one swap.
static func _rescue(s: TrayState, board: BoardState, token_crews: Array[StringName], out: TrayRefill) -> void:
	for p: PieceInstance in out.pieces:
		if BoardRules.any_fit(board, p):
			return
	var slots_r: Array[int] = []
	var fits := {}
	for x: int in token_crews.size():
		var def := _crew_def(s.registry, token_crews[x])
		var f: Array[int] = []
		for e_idx: int in def.shapes.size():
			var probe := PieceInstance.make(def.shapes[e_idx].shape, def.id, PieceInstance.NO_FACE)
			if BoardRules.any_fit(board, probe):
				f.append(e_idx)
		if not f.is_empty():
			slots_r.append(x)
			fits[x] = f
	if slots_r.is_empty():
		return
	var rng := DetRng.new(rescue_seed(s.stage_seed, s.refill_index))
	var slot := slots_r[rng.below(slots_r.size())]
	var def := _crew_def(s.registry, token_crews[slot])
	var total := 0
	for e_idx: int in fits[slot]:
		total += def.shapes[e_idx].weight
	var t := rng.below(total)
	var chosen: CrewShapeEntry = null
	for e_idx: int in fits[slot]:
		t -= def.shapes[e_idx].weight
		if t < 0:
			chosen = def.shapes[e_idx]
			break
	var old: PieceInstance = s.slots[slot]
	var piece: PieceInstance
	if old.has_face():
		var face := chosen.face_cell if chosen.face_cell >= 0 else rng.below(chosen.shape.cell_count())
		piece = PieceInstance.make(chosen.shape, old.crew_id, face, old.instance_id)
	else:
		piece = PieceInstance.make(chosen.shape, &"", PieceInstance.NO_FACE, old.instance_id)
	s.slots[slot] = piece
	out.pieces[slot] = piece
	out.rescued.append({
		TrayRefill.K_REFILL_INDEX: s.refill_index,
		TrayRefill.K_SLOT: slot,
		TrayRefill.K_FROM_SHAPE: old.shape.id,
		TrayRefill.K_TO_SHAPE: chosen.shape.id,
	})


static func _validate_spec(errors: PackedStringArray, tag: String, spec_v: Variant, team: Array[StringName],
		cfg: TrayRules, registry: CrewRegistry, catalog: Dictionary) -> void:
	if not (spec_v is Dictionary):
		errors.append("%s: spec must be a Dictionary" % tag)
		return
	var spec: Dictionary = spec_v
	var shape_id := StringName(spec.get(K_SHAPE, &""))
	var crew_v: Variant = spec.get(K_CREW, null)
	var face_v: Variant = spec.get(K_FACE, FACE_RANDOM)
	if shape_id != SHAPE_FROM_BAG and not catalog.has(shape_id):
		errors.append("%s: shape: '%s' not in the shape catalog" % [tag, shape_id])
	if typeof(crew_v) == TYPE_INT:
		if int(crew_v) < 0 or int(crew_v) >= team.size():
			errors.append("%s: crew: team_slot %d out of range 0..%d" % [tag, int(crew_v), team.size() - 1])
	elif crew_v == null:
		if not cfg.allow_faceless_pieces:
			errors.append("%s: crew: null (faceless) needs allow_faceless_pieces" % tag)
		if shape_id == SHAPE_FROM_BAG:
			errors.append("%s: shape: '*' needs a crew" % tag)
	elif typeof(crew_v) == TYPE_STRING_NAME or typeof(crew_v) == TYPE_STRING:
		if not cfg.team_fixed:
			errors.append("%s: crew: direct crew_id '%s' needs a stage with a fixed team" % [tag, crew_v])
		elif _crew_def(registry, StringName(crew_v)) == null:
			errors.append("%s: crew: unknown crew '%s'" % [tag, crew_v])
	else:
		errors.append("%s: crew: must be a team_slot int, a crew id or null" % tag)
	if face_v == null:
		if not cfg.allow_faceless_pieces:
			errors.append("%s: face: null (faceless) needs allow_faceless_pieces" % tag)
	elif typeof(face_v) != TYPE_INT or int(face_v) < FACE_RANDOM:
		errors.append("%s: face: must be an int >= -1 or null" % tag)
	elif int(face_v) >= 0 and catalog.has(shape_id) and int(face_v) >= (catalog[shape_id] as PieceShape).cell_count():
		errors.append("%s: face: %d out of the shape's cell range" % [tag, int(face_v)])
	elif int(face_v) >= 0 and shape_id == SHAPE_FROM_BAG:
		errors.append("%s: face: a fixed face needs a fixed shape" % tag)


static func _crew_def(registry: CrewRegistry, crew_id: StringName) -> CrewDef:
	if registry == null:
		return null
	for c: CrewDef in registry.crews:
		if c != null and c.id == crew_id:
			return c
	return null


static func _entry_index(def: CrewDef, shape_id: StringName) -> int:
	for i: int in def.shapes.size():
		if def.shapes[i].shape.id == shape_id:
			return i
	return -1


## Shape catalog for scripts: every registry shape plus [member TrayRules.extra_shapes].
static func _catalog(registry: CrewRegistry, cfg: TrayRules) -> Dictionary:
	var out := {}
	for c: CrewDef in registry.crews:
		if c == null:
			continue
		for e: CrewShapeEntry in c.shapes:
			if e != null and e.shape != null:
				out[e.shape.id] = e.shape
	for shape: PieceShape in cfg.extra_shapes:
		if shape != null:
			out[shape.id] = shape
	return out
