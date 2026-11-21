## Offline solver for the MVP stages (stage-goals AC-SG19/AC-SG20 harness):
## a deterministic beam search over real [RoundFlow] states (same resolver, same
## FIXED seed, same tray) that looks for a placement list clearing each stage
## with the starter team (fixed-team stages: their locked team). Writes
## tests/fixtures/stages/solutions.json; the integration test replays it.
##   godot --headless --path . -s res://tests/fixtures/generators/solve_stages.gd [-- --only=1-9]
## Review the diff and commit. The search is tooling only — it never runs in the game.
extends SceneTree

const OUT := "res://tests/fixtures/stages/solutions.json"
const CATALOG := "res://assets/data/stages/catalog.tres"
const BEAM := 10
## Wider beam for --beam=N runs (hard stages).
var beam_width := BEAM
var _best := 0
## Children kept per parent before the global cut (diversity).
const PER_PARENT := 4


func _init() -> void:
	var env := StageEnv.load_default()
	var catalog: StageCatalog = load(CATALOG)
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a.begins_with("--beam="):
			beam_width = int(a.substr(7))
	var existing := {}
	if FileAccess.file_exists(OUT):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if parsed is Dictionary:
			for s: Dictionary in parsed.get("stages", []):
				existing[s["id"]] = s
	var out := []
	for stage: StageDef in catalog.stages:
		if only != "" and String(stage.id) != only:
			if existing.has(String(stage.id)):
				out.append(existing[String(stage.id)])
			continue
		var loaded := StageLoader.load_stage(stage, env)
		if not loaded.is_valid():
			print("%s LOAD ERRORS %s" % [stage.id, loaded.errors])
			continue
		var team := _team(stage, env)
		var t0 := Time.get_ticks_msec()
		var sol := _solve(env, stage, team)
		var ms := Time.get_ticks_msec() - t0
		if sol.is_empty():
			print("%s team %s: NO SOLUTION (%d ms)" % [stage.id, team, ms])
			continue
		print("%s team %s: cleared in %d placements, stage_score %d final %d stars %d (%d ms)" % [stage.id, team, sol["moves"].size(),
				sol["stage_score"], sol["final_score"], sol["stars"], ms])
		out.append(sol)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "stages": out}, " ", false) + "\n")
	f.close()
	quit()


## Starter team via F2 (no memory) — fixed teams resolve to their locks.
static func _team(stage: StageDef, env: StageEnv) -> Array[StringName]:
	return TeamRules.resolve_default_team(stage.effective_team_rule(), env.registry, OwnedCrews.starter(env.registry), TeamMemory.new(), stage.id)


func _solve(env: StageEnv, stage: StageDef, team: Array[StringName]) -> Dictionary:
	var root := RoundFlow.for_stage(env, stage, team)
	root.start_attempt()
	var beam: Array = [{&"flow": root, &"moves": []}]
	var limit := stage.piece_limit
	for depth: int in limit:
		var children: Array = []
		var seen := {}
		for node: Dictionary in beam:
			var flow: RoundFlow = node[&"flow"]
			var local: Array = []
			for mv: Array in _moves(flow):
				var child := _clone(flow)
				child.commit(mv[0], mv[1])
				child.playback_finished()
				var moves: Array = (node[&"moves"] as Array).duplicate()
				moves.append([mv[0], mv[1].x, mv[1].y])
				if child.outcome == RoundResult.Outcome.CLEARED:
					return _record(stage, team, moves, child)
				if child.is_ended():
					_best = maxi(_best, child.stage_score())
					continue
				var key := "%d|%s" % [child.board().board_hash(), _tray_key(child)]
				if seen.has(key):
					continue
				seen[key] = true
				local.append({&"flow": child, &"moves": moves, &"v": _value(child)})
			local.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[&"v"] > b[&"v"])
			children.append_array(local.slice(0, PER_PARENT * 3))
		if children.is_empty():
			print("  beam died at depth %d; best ended stage_score %d" % [depth, _best])
			return {}
		children.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[&"v"] > b[&"v"])
		beam = children.slice(0, beam_width)
	var best := 0
	for node: Dictionary in beam:
		best = maxi(best, (node[&"flow"] as RoundFlow).stage_score())
	print("  out of pieces; best stage_score in beam %d" % best)
	return {}


static func _record(stage: StageDef, team: Array[StringName], moves: Array, flow: RoundFlow) -> Dictionary:
	var r := flow.result
	return {"id": String(stage.id), "team": team.map(func(x: StringName) -> String: return String(x)), "moves": moves,
			"stage_score": r.stage_score, "final_score": r.final_score, "stars": r.stars, "pieces_left": r.pieces_left}


## Legal (slot, anchor) pairs; identical pieces in two slots are expanded once.
static func _moves(flow: RoundFlow) -> Array:
	var out := []
	var done := {}
	for slot: int in flow.slot_count():
		var p := flow.piece_at(slot)
		if p == null:
			continue
		var k := "%s|%s|%d" % [p.shape.id, p.crew_id, p.face_index]
		if done.has(k):
			continue
		done[k] = true
		for r: int in flow.board().height:
			for c: int in flow.board().width:
				if flow.can_place(slot, Vector2i(r, c)):
					out.append([slot, Vector2i(r, c)])
	return out


## Heuristic: goal completion dominates; then chain depth seen, score, free space.
static func _value(flow: RoundFlow) -> int:
	var v := 0
	var g := flow.goals
	for i: int in g.goals.size():
		var req := maxi(1, g.required(i))
		v += 10000 * mini(g.progress(i), req) / req
		if g.goals[i].type == GoalDef.Type.CHAIN:
			v += 2500 * mini(flow.max_chain_depth, g.goals[i].depth) / maxi(1, g.goals[i].depth)
	v += flow.stage_score() / 2
	v -= flow.board().filled_count() * 30
	return v


static func _tray_key(flow: RoundFlow) -> String:
	var parts := []
	for p: Variant in flow.tray.slots:
		parts.append("-" if p == null else "%s%s%d" % [(p as PieceInstance).shape.id, (p as PieceInstance).crew_id, (p as PieceInstance).face_index])
	return ",".join(parts)


## Search-only state copy (not a game feature — the round has no undo).
static func _clone(f: RoundFlow) -> RoundFlow:
	var c := RoundFlow.for_stage(f.env, f.stage, f.team)
	c.attempt = f.attempt
	var core := RoundCore.new()
	core.board = f.core.board.copy()
	core.abilities = f.core.abilities
	core.chain_rules = f.core.chain_rules
	core.scoring_rules = f.core.scoring_rules
	core.hooks = f.core.hooks
	core.stage_seed = f.core.stage_seed
	core.placement_index = f.core.placement_index
	core.board_version = f.core.board_version
	core.tally = f.core.tally
	c.core = core
	c.tray = f.tray.copy()
	c.goals = f.goals.copy()
	c.state = f.state
	c.pieces_dealt = f.pieces_dealt
	c.placements_used = f.placements_used
	c.max_chain_depth = f.max_chain_depth
	c.outcome = f.outcome
	c.phase = f.phase
	return c
