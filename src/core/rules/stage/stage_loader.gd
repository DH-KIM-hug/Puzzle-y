## Stage loading and load-time validation (design/gdd/stage-goals.md rules 1–2;
## obstacles rule 16; team-composition rule 6; tray-supply rule 22). Pure static
## functions: a [StageDef] + [StageEnv] in, a [StageLoad] out.
## [codeblock]
## var loaded := StageLoader.load_stage(stage, env)
## if not loaded.is_valid(): push_error("\n".join(loaded.errors))
## [/codeblock]
##
## Spec ambiguities resolved here (logged per task brief):
## [br]- Free play (`piece_limit = -1`) skips the goal / star checks and requires
##   both lists empty (rule 2); its stage_seed may be unset (PER_ATTEMPT).
## [br]- Tray-script validation needs a team: a fixed team is validated with its
##   locked crews; a free team with the starter crews (registry order) — a free
##   stage's script may then only use team-slot / "*" specs, as tray-supply rule 22 says.
## [br]- "piece_limit outside the F8 guide" lint is design-time (needs autoplay
##   data) and is not evaluated at load.
class_name StageLoader
extends RefCounted

## Character reserved for EMPTY.
const EMPTY_CHAR := "."
## Largest stage seed (0 – 2^31-1).
const MAX_SEED := 0x7FFFFFFF


## Builds the start board and validates the whole stage.
static func load_stage(stage: StageDef, env: StageEnv) -> StageLoad:
	var out := StageLoad.new()
	out.stage = stage
	if stage == null:
		out.errors.append("stage: null")
		return out
	var tag := "stage %s: " % stage.id
	var e := out.errors
	if String(stage.id).is_empty():
		e.append(tag + "id is empty")
	out.board = _build_board(stage, env, e, tag)
	if out.board != null:
		for msg: String in BoardRules.validate_board(out.board, env.registry.board_config):
			e.append(tag + "board_rows: " + msg)
		for msg: String in ObstacleRules.validate_obstacles(out.board, env.obstacles, env.crew_ids()):
			e.append(tag + "board_rows: " + msg)
	_validate_goals(stage, env, out, tag)
	_validate_limits(stage, env, out, tag)
	var rule := stage.effective_team_rule()
	for msg: String in TeamRules.validate_rule(rule, env.registry):
		e.append(tag + msg)
	_validate_tray(stage, env, out, tag)
	_lint(stage, env, out, tag)
	return out


## Loads every stage of [param catalog]; ids must be unique. Returns one
## [StageLoad] per stage plus duplicate-id errors on the first offending entry.
static func load_catalog(catalog: StageCatalog, env: StageEnv) -> Array[StageLoad]:
	var out: Array[StageLoad] = []
	var seen := {}
	for s: StageDef in catalog.stages:
		var l := load_stage(s, env)
		if s != null:
			if seen.has(s.id):
				l.errors.append("stage %s: id is not unique in the catalog" % s.id)
			seen[s.id] = true
		out.append(l)
	return out


static func _build_board(stage: StageDef, env: StageEnv, e: PackedStringArray, tag: String) -> BoardState:
	var cfg := env.registry.board_config
	if stage.board_rows.size() != cfg.board_height:
		e.append(tag + "board_rows has %d rows, board_height is %d" % [stage.board_rows.size(), cfg.board_height])
		return null
	for r: int in stage.board_rows.size():
		if stage.board_rows[r].length() != cfg.board_width:
			e.append(tag + "board_rows[%d] has %d chars, board_width is %d" % [r, stage.board_rows[r].length(), cfg.board_width])
			return null
	if stage.cell_legend.has(EMPTY_CHAR):
		e.append(tag + "cell_legend redefines the reserved '.'")
	var known := env.crew_ids()
	var b := BoardState.create(cfg.board_width, cfg.board_height, ObstacleRules.kind_table())
	var bad_chars := {}
	for r: int in cfg.board_height:
		var line := stage.board_rows[r]
		for c: int in cfg.board_width:
			var ch := line[c]
			if ch == EMPTY_CHAR:
				continue
			if not stage.cell_legend.has(ch):
				if not bad_chars.has(ch):
					e.append(tag + "cell_legend has no entry for '%s' (board_rows[%d])" % [ch, r])
				bad_chars[ch] = true
				continue
			_write_cell(b, b.index_of(r, c), ch, stage.cell_legend[ch], known, e, tag)
	return b


static func _write_cell(b: BoardState, idx: int, ch: String, spec_v: Variant, known: Dictionary, e: PackedStringArray, tag: String) -> void:
	var where := "cell_legend['%s']" % ch
	if typeof(spec_v) != TYPE_DICTIONARY:
		e.append(tag + where + " is not a Dictionary")
		return
	var spec: Dictionary = spec_v
	var type_name := StringName(_spec_get(spec, StageDef.L_TYPE, &"TILE"))
	if not ObstacleRules.KIND_IDS.has(type_name):
		e.append(tag + where + ".type '%s' is not a registered cell kind" % type_name)
		return
	var kind_id: int = ObstacleRules.KIND_IDS[type_name]
	if kind_id == CellKind.EMPTY:
		return
	var crew := StringName(_spec_get(spec, StageDef.L_CREW, &""))
	var face_v: Variant = _spec_get(spec, StageDef.L_FACE, false)
	if typeof(face_v) != TYPE_BOOL:
		e.append(tag + where + ".is_face must be a bool")
		return
	var face: bool = face_v
	var origin_name := StringName(_spec_get(spec, StageDef.L_ORIGIN, StageDef.ORIGIN_PIECE))
	if origin_name != StageDef.ORIGIN_PIECE and origin_name != StageDef.ORIGIN_EGG:
		e.append(tag + where + ".origin '%s' must be PIECE or EGG" % origin_name)
		return
	if crew != &"" and not known.has(crew):
		e.append(tag + where + ".crew_id '%s' is not in the crew registry" % crew)
		return
	if kind_id == CellKind.STONE and (crew != &"" or face):
		e.append(tag + where + ": STONE has no content (crew_id / is_face)")
		return
	var origin := BoardState.ORIGIN_EGG if origin_name == StageDef.ORIGIN_EGG else BoardState.ORIGIN_PIECE
	b.set_tile(idx, crew, face, origin, 0, kind_id)
	var mods_v: Variant = _spec_get(spec, StageDef.L_MODIFIERS, [])
	if typeof(mods_v) != TYPE_ARRAY:
		e.append(tag + where + ".modifiers must be an Array")
		return
	var mods := PackedInt32Array()
	for m_v: Variant in mods_v:
		if typeof(m_v) != TYPE_DICTIONARY:
			e.append(tag + where + ".modifiers entry is not a Dictionary")
			continue
		var m: Dictionary = m_v
		var kind := StringName(_spec_get(m, StageDef.M_KIND, &""))
		var layers_v: Variant = _spec_get(m, StageDef.M_LAYERS, null)
		if not ObstacleRules.MODIFIER_IDS.has(kind):
			e.append(tag + where + ".modifiers kind '%s' is unknown (obstacles rule 6)" % kind)
			continue
		if typeof(layers_v) != TYPE_INT:
			e.append(tag + where + ".modifiers layers must be an int (got %s)" % type_string(typeof(layers_v)))
			continue
		mods.append(ObstacleRules.MODIFIER_IDS[kind])
		mods.append(int(layers_v))
	if not mods.is_empty():
		b.set_modifiers(idx, mods)


static func _validate_goals(stage: StageDef, env: StageEnv, out: StageLoad, tag: String) -> void:
	var e := out.errors
	var rules := env.stage_rules
	if stage.is_free_play():
		if not stage.goals.is_empty():
			e.append(tag + "goals must be empty on a free-play stage (piece_limit -1)")
		if not stage.target_cells.is_empty():
			e.append(tag + "target_cells must be empty on a free-play stage")
		return
	if stage.goals.is_empty() or stage.goals.size() > rules.max_goals_per_stage:
		e.append(tag + "goals: %d goals, allowed 1..%d" % [stage.goals.size(), rules.max_goals_per_stage])
	var types := {}
	var has_cells_goal := false
	for i: int in stage.goals.size():
		var g := stage.goals[i]
		var gt := tag + "goals[%d] " % i
		if g == null:
			e.append(gt + "is null")
			continue
		if types.has(g.type):
			e.append(gt + "type %s duplicates another goal" % g.type_name())
		types[g.type] = true
		if g.required < 1:
			e.append(gt + "required %d < 1" % g.required)
		match g.type:
			GoalDef.Type.SCORE:
				if g.required > rules.score_target_max:
					e.append(gt + "required %d > score_target_max %d" % [g.required, rules.score_target_max])
			GoalDef.Type.CLEAR_CELLS:
				has_cells_goal = true
				_validate_targets(stage, out, g, gt)
			GoalDef.Type.CLEAR_OBSTACLES:
				if g.keys.is_empty():
					e.append(gt + "keys is empty")
				var count := 0
				var valid_keys := true
				for k: StringName in g.keys:
					if not ObstacleRules.MODIFIER_IDS.has(k):
						e.append(gt + "keys '%s' is not a registered modifier kind" % k)
						valid_keys = false
				if valid_keys and out.board != null:
					for idx: int in out.board.modifiers:
						var mods: PackedInt32Array = out.board.modifiers[idx]
						for k: StringName in g.keys:
							if ObstacleRules.has_modifier(mods, ObstacleRules.MODIFIER_IDS[k]):
								count += 1
								break
					if g.required > count:
						e.append(gt + "required %d > %d start cells with keys %s" % [g.required, count, g.keys])
			GoalDef.Type.CHAIN:
				if g.depth < 1 or g.depth > env.chain_rules.depth_cap:
					e.append(gt + "depth %d out of 1..depth_cap %d" % [g.depth, env.chain_rules.depth_cap])
	if not stage.target_cells.is_empty() and not has_cells_goal:
		e.append(tag + "target_cells set without a CLEAR_CELLS goal")


static func _validate_targets(stage: StageDef, out: StageLoad, g: GoalDef, gt: String) -> void:
	var e := out.errors
	if stage.target_cells.is_empty():
		e.append(gt + "CLEAR_CELLS needs target_cells")
		return
	var seen := {}
	for cell: Vector2i in stage.target_cells:
		if out.board == null:
			break
		if not out.board.in_bounds(cell.x, cell.y):
			e.append(gt + "target_cells %s is off the board" % cell)
			continue
		if seen.has(cell):
			e.append(gt + "target_cells %s is listed twice" % cell)
		seen[cell] = true
		var idx := out.board.index_of_cell(cell)
		if out.board.kind[idx] != CellKind.EMPTY and not out.board.removable_by_clear(idx):
			e.append(gt + "target_cells %s starts on a non-removable cell (STONE)" % cell)
	if g.required > stage.target_cells.size():
		e.append(gt + "required %d > %d target_cells" % [g.required, stage.target_cells.size()])


static func _validate_limits(stage: StageDef, env: StageEnv, out: StageLoad, tag: String) -> void:
	var e := out.errors
	var rules := env.stage_rules
	if stage.is_free_play():
		if not stage.star_points.is_empty():
			e.append(tag + "star_points must be empty on a free-play stage")
		return
	if stage.piece_limit < rules.piece_limit_min or stage.piece_limit > rules.piece_limit_max:
		e.append(tag + "piece_limit %d out of %d..%d" % [stage.piece_limit, rules.piece_limit_min, rules.piece_limit_max])
	if stage.star_points.size() != 2:
		e.append(tag + "star_points must hold exactly [S2, S3] (got %d values)" % stage.star_points.size())
	elif not (0 < stage.star_points[0] and stage.star_points[0] < stage.star_points[1] and stage.star_points[1] <= rules.score_target_max):
		e.append(tag + "star_points [%d, %d] must satisfy 0 < S2 < S3 <= %d" % [stage.star_points[0], stage.star_points[1], rules.score_target_max])


static func _validate_tray(stage: StageDef, env: StageEnv, out: StageLoad, tag: String) -> void:
	var e := out.errors
	if stage.tray_seed_mode == TrayRules.SeedMode.FIXED and (stage.stage_seed < 0 or stage.stage_seed > MAX_SEED):
		e.append(tag + "stage_seed must be set (0..2^31-1) when tray_seed_mode is FIXED (got %d)" % stage.stage_seed)
	var rule := stage.effective_team_rule()
	var team: Array[StringName] = rule.fixed_team()
	if not rule.is_fixed():
		team.clear()
		var starters := TeamRules.starters_in_registry_order(env.registry)
		for i: int in mini(rule.team_size, starters.size()):
			team.append(starters[i])
	var tray := stage.tray_rules(env.tray_rules)
	for msg: String in TraySupplyRules.validate_config(team, tray, env.registry):
		e.append(tag + msg)
	if out.is_valid():
		for msg: String in TraySupplyRules.lint_config(team, tray, env.registry):
			out.warnings.append(tag + msg)


static func _lint(stage: StageDef, env: StageEnv, out: StageLoad, tag: String) -> void:
	var w := out.warnings
	var types := {}
	for g: GoalDef in stage.goals:
		if g == null:
			continue
		types[g.type] = true
		if g.type == GoalDef.Type.SCORE and stage.star_points.size() == 2 and stage.star_points[0] <= g.required:
			w.append(tag + "lint: S2 %d <= SCORE required %d (star 2 nearly automatic)" % [stage.star_points[0], g.required])
	if stage.goals.size() == 2 and types.has(GoalDef.Type.SCORE) and types.has(GoalDef.Type.CHAIN):
		w.append(tag + "lint: SCORE + CHAIN goals tend to finish together in one chain")
	if not stage.is_free_play() and not TeamRules.starter_can_play(stage.effective_team_rule(), env.registry):
		w.append(tag + "lint: starter crews + guests cannot form a valid team (team-composition rule 6)")


## Reads [param key] as a StringName key, falling back to the String spelling
## (hand-edited .tres may use either).
static func _spec_get(d: Dictionary, key: StringName, default: Variant) -> Variant:
	if d.has(key):
		return d[key]
	if d.has(String(key)):
		return d[String(key)]
	return default
