## Round flow for the T0 greybox (ADR-0001 Decision 9 "RoundFlow").
##
## Owns the live [RoundCore] (board, placement counter, score tally) and the
## [TrayState]; it is the only object that hands out a [ResolveContext]
## ([method context_for_next_placement]) — the preview and the commit both use
## it. Kept as a [RefCounted] (no Node) so the whole placement loop runs in
## integration tests without a scene tree; the game scene wraps one.
## Never re-implements rules: every judgement goes through Rules Core.
## [codeblock]
## var flow := RoundFlow.create(registry, chain_rules, scoring_rules, tray_rules, team, 1201)
## flow.start_attempt()
## var ctx := flow.context_for_next_placement()          # preview
## var commit := flow.commit(slot, anchor)               # authoritative
## flow.finish_placement()                               # after playback: refill + no_moves
## [/codeblock]
class_name RoundFlow
extends RefCounted

## Round phase (T0 subset of the round-flow states).
enum Phase { PLAYING, NO_MOVES }

## Validated crew registry.
var registry: CrewRegistry
## Chain rules (depth cap).
var chain_rules: ChainRules
## Scoring rules (preview and commit share it).
var scoring_rules: ScoringRules
## Tray rules (size 3, rescue).
var tray_rules: TrayRules
## Fixed team (crew ids).
var team: Array[StringName] = []
## Base seed; each attempt derives its stage seed from it (tray-supply rule 18).
var base_seed: int = 0
## 0-based attempt index ("한 판 더" increments it).
var attempt: int = 0
## Live round core (board, tally, placement index).
var core: RoundCore
## Live tray.
var tray: TrayState
## Current phase.
var phase: Phase = Phase.PLAYING
## Board as it was before the last commit (read-only copy for the replay).
var last_pre_board: BoardState


## Builds a flow; call [method start_attempt] before use.
static func create(p_registry: CrewRegistry, p_chain_rules: ChainRules, p_scoring_rules: ScoringRules,
		p_tray_rules: TrayRules, p_team: Array[StringName], p_base_seed: int) -> RoundFlow:
	var f := RoundFlow.new()
	f.registry = p_registry
	f.chain_rules = p_chain_rules
	f.scoring_rules = p_scoring_rules
	f.tray_rules = p_tray_rules
	f.team = p_team.duplicate()
	f.base_seed = p_base_seed
	return f


## Stage seed of the current attempt (PER_ATTEMPT so a retry deals a new tray order).
func stage_seed() -> int:
	return TraySupplyRules.stage_seed_for(TrayRules.SeedMode.PER_ATTEMPT, base_seed, attempt)


## Starts (or restarts) the current attempt: empty board, fresh tally, first tray.
## Returns load errors (empty = ok).
func start_attempt() -> PackedStringArray:
	var seed_value := stage_seed()
	var board := BoardState.from_config(registry.board_config)
	core = RoundCore.start(board, registry.abilities(), chain_rules, scoring_rules, seed_value)
	tray = TraySupplyRules.init_state(team, tray_rules, seed_value, registry)
	if not tray.is_valid():
		return tray.errors
	_refill_if_empty()
	return PackedStringArray()


## "한 판 더": next attempt, everything reset.
func retry() -> PackedStringArray:
	attempt += 1
	return start_attempt()


## The context the next placement will use (preview and commit alike).
func context_for_next_placement() -> ResolveContext:
	return core.context_for_next_placement()


## Live stable board (read-only for callers).
func board() -> BoardState:
	return core.board


## Piece in [param slot], or null.
func piece_at(slot: int) -> PieceInstance:
	if slot < 0 or slot >= tray.slots.size():
		return null
	return tray.slots[slot]


## Tray slot count.
func slot_count() -> int:
	return tray.slots.size()


## Board-rules legality of placing [param slot]'s piece at [param anchor].
func can_place(slot: int, anchor: Vector2i) -> bool:
	var p := piece_at(slot)
	return p != null and BoardRules.can_place(core.board, p, anchor)


## Authoritative commit (chain-preview rule 9): re-checks [method can_place],
## resolves independently, scores, consumes the tray slot. Returns null when refused.
func commit(slot: int, anchor: Vector2i) -> RoundCommit:
	if phase != Phase.PLAYING or not can_place(slot, anchor):
		return null
	last_pre_board = core.board.copy()
	var out := core.commit(piece_at(slot), anchor)
	if out.error != "":
		return null
	tray = TraySupplyRules.consume(tray, slot)
	return out


## Placement id the last commit used (display-board replay writes it).
func last_placement_id() -> int:
	return core.placement_index


## After playback: refill an empty tray, then judge no_moves (board-rules).
func finish_placement() -> Phase:
	_refill_if_empty()
	var pieces := tray.pieces()
	if BoardRules.no_moves(core.board, pieces):
		phase = Phase.NO_MOVES
	else:
		phase = Phase.PLAYING
	return phase


## Running stage score.
func stage_score() -> int:
	return core.tally.stage_score


## Best single placement this attempt.
func best_placement() -> int:
	return core.tally.best_placement


func _refill_if_empty() -> void:
	if tray.is_empty() and tray.status != TrayState.Status.EXHAUSTED:
		var r := TraySupplyRules.refill(tray, core.board, TraySupplyRules.BUDGET_UNLIMITED)
		if r.error == "":
			tray = r.state
	phase = Phase.NO_MOVES if BoardRules.no_moves(core.board, tray.pieces()) else Phase.PLAYING
