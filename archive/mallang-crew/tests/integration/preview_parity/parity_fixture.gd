## Shared logic for the preview = runtime = score invariant (chain-preview AC-P02):
## case loading, the two execution paths, and the per-anchor record that is
## committed in [code]tests/fixtures/parity/cases.json[/code].
class_name ParityFixture
extends RefCounted

const CASES_PATH := "res://tests/fixtures/parity/cases.json"
const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"
const SCORING_PATH := "res://assets/data/rules/scoring_rules.tres"


## The real MVP registry, validated.
static func registry() -> CrewRegistry:
	var r: CrewRegistry = load(REGISTRY_PATH)
	r.load_and_validate()
	return r


## Shape id → PieceShape over the whole registry.
static func catalog(r: CrewRegistry) -> Dictionary:
	var out := {}
	for c: CrewDef in r.crews:
		for e: CrewShapeEntry in c.shapes:
			out[String(e.shape.id)] = e.shape
	return out


## Piece from a case spec {shape, crew, face}.
static func piece(spec: Dictionary, shapes: Dictionary, instance_id: int) -> PieceInstance:
	return PieceInstance.make(shapes[spec["shape"]], StringName(spec["crew"]), int(spec["face"]), instance_id)


## Board of a case: row strings on the obstacle kind table (same flags as
## [method BoardFixture.stone_table] for [code]S[/code]) plus the optional
## [code]"ice"[/code] list of [code][row, col, layers][/code] (obstacles AC-O13).
static func case_board(c: Dictionary) -> BoardState:
	var b := BoardFixture.board(c["board"], ObstacleRules.kind_table())
	for e: Array in c.get("ice", []):
		ObstacleRules.set_ice(b, b.index_of(int(e[0]), int(e[1])), int(e[2]))
	return b


## Hooks of a case: the obstacle hooks when [code]"obstacles": true[/code], else defaults (null).
static func case_hooks(c: Dictionary) -> ChainHooks:
	return ObstacleRules.hooks() if bool(c.get("obstacles", false)) else null


## Chain rules with [param depth_cap].
static func chain_rules(depth_cap: int) -> ChainRules:
	var r := ChainRules.new()
	r.depth_cap = depth_cap
	return r


## Every legal anchor of [param p] on [param board], row-major.
static func legal_anchors(board: BoardState, p: PieceInstance) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: int in board.height:
		for c: int in board.width:
			if BoardRules.can_place(board, p, Vector2i(r, c)):
				out.append(Vector2i(r, c))
	return out


## Runs one (board, piece, anchor) through (A) the preview path and (B) the commit
## path. Returns {record, mismatch, activated}: [code]record[/code] =
## [r, c, board_hash, chain_depth, waves, cap_reached 0/1, total, model_digest];
## [code]mismatch[/code] = first differing field ("" = parity holds).
static func run_anchor(board: BoardState, p: PieceInstance, anchor: Vector2i, stage_seed: int, placement_index: int,
		rules: ChainRules, abilities: AbilityTable, scoring: ScoringRules, hooks: ChainHooks = null) -> Dictionary:
	var settings := PreviewSettings.with_score(scoring)
	var round_a := RoundCore.start(board, abilities, rules, scoring, stage_seed, placement_index, hooks)
	var hash_before := round_a.board.board_hash()
	var model_a := PreviewModel.preview(round_a.board, p, anchor, round_a.context_for_next_placement(), settings)
	var round_b := RoundCore.start(board, abilities, rules, scoring, stage_seed, placement_index, hooks)
	var commit_b := round_b.commit(p, anchor)
	var res_a := model_a.result
	var res_b := commit_b.result
	var mismatch := ""
	if round_a.board.board_hash() != hash_before:
		mismatch = "preview mutated the live board"
	elif var_to_str(res_a.events_as_dicts()) != var_to_str(res_b.events_as_dicts()):
		mismatch = _first_event_diff(res_a, res_b)
	elif not res_a.final_board.equals(res_b.final_board):
		mismatch = "final_board"
	elif not round_b.board.equals(res_b.final_board):
		mismatch = "committed board != final_board"
	else:
		var model_b := PreviewModel.build_preview_model(res_b, settings)
		if var_to_str(model_a.to_dict()) != var_to_str(model_b.to_dict()):
			mismatch = "preview model"
		elif not _same_cells(model_a.outlined_cells(), _cleared_in(res_b)):
			mismatch = "outline != cleared cells"
		elif var_to_str(model_a.breakdown.to_dict()) != var_to_str(commit_b.breakdown.to_dict()):
			mismatch = "score breakdown"
		elif commit_b.score_delta != commit_b.breakdown.total or model_a.predicted_score != commit_b.breakdown.total:
			mismatch = "stage_score delta / predicted total"
	var s := res_b.summary
	var record := [anchor.x, anchor.y, int(s[ChainEvent.K_BOARD_HASH]), int(s[ChainEvent.K_CHAIN_DEPTH]), int(s[ChainEvent.K_WAVES]),
			1 if s[ChainEvent.K_CAP_REACHED] else 0, commit_b.breakdown.total, SeedHash.str32(var_to_str(model_a.to_dict()))]
	var activated := []
	for e: ChainEvent in res_b.events_of(ChainEvent.Type.FACE_ACTIVATED):
		activated.append(String(e.data[ChainEvent.K_CREW_ID]))
	return {&"record": record, &"mismatch": mismatch, &"activated": activated}


static func _cleared_in(res: ChainResult) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: ChainEvent in res.events_of(ChainEvent.Type.CELLS_CLEARED):
		for c: Dictionary in e.data[ChainEvent.K_CELLS]:
			out.append(Vector2i(c[ChainEvent.K_R], c[ChainEvent.K_C]))
	return out


## Set equality (a cell refilled by an egg can be cleared in two waves).
static func _same_cells(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	var x: Array = []
	var y: Array = []
	for v: Vector2i in a:
		if not x.has(v):
			x.append(v)
	for v: Vector2i in b:
		if not y.has(v):
			y.append(v)
	x.sort()
	y.sort()
	return x == y


static func _first_event_diff(a: ChainResult, b: ChainResult) -> String:
	var da := a.events_as_dicts()
	var db := b.events_as_dicts()
	for i: int in mini(da.size(), db.size()):
		if var_to_str(da[i]) != var_to_str(db[i]):
			return "events[%d] %s" % [i, da[i].get(&"type", "?")]
	return "events length %d != %d" % [da.size(), db.size()]
