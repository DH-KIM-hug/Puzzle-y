## Pure core of the round flow's placement path (ADR-0001 Decision 9; the
## "CommitHarness" of chain-preview AC-P02 until the Node RoundFlow exists).
##
## Holds the live stable board, the stage seed, the placement counter and the
## score tally, and is the only place a [ResolveContext] is made:
## [method context_for_next_placement] serves preview and commit alike. No Node,
## no globals; a RoundFlow Node wraps one of these.
## [codeblock]
## var round := RoundCore.start(board, registry.abilities(), chain_rules, scoring_rules, stage_seed)
## var model := PreviewModel.preview(round.board, piece, anchor, round.context_for_next_placement())
## var commit := round.commit(piece, anchor)
## [/codeblock]
class_name RoundCore
extends RefCounted

## Live stable board (replaced, never mutated, on commit).
var board: BoardState
## Resolver ability table (whole registry).
var abilities: AbilityTable
## Chain rules (depth cap).
var chain_rules: ChainRules
## Scoring rules (same resource for preview and commit).
var scoring_rules: ScoringRules
## Obstacle hooks; null = defaults.
var hooks: ChainHooks
## Round seed (chain-resolver F7 / tray-supply F3).
var stage_seed: int = 0
## Placements committed so far this round.
var placement_index: int = 0
## Bumped on every commit (preview cache key, chain-preview rule 8).
var board_version: int = 0
## Running stage score.
var tally: StageScoreTally


## Round start. [param first_placement_index] lets fixtures resume mid-round.
static func start(p_board: BoardState, p_abilities: AbilityTable, p_chain_rules: ChainRules, p_scoring_rules: ScoringRules,
		p_stage_seed: int, first_placement_index: int = 0, p_hooks: ChainHooks = null) -> RoundCore:
	var r := RoundCore.new()
	r.board = p_board.copy()
	r.abilities = p_abilities
	r.chain_rules = p_chain_rules
	r.scoring_rules = p_scoring_rules
	r.stage_seed = p_stage_seed
	r.placement_index = first_placement_index
	r.hooks = p_hooks
	r.tally = StageScoreTally.started()
	return r


## The context for the next placement: abilities, rules, hooks and
## [code]rng_seed = hash32(stage_seed, STREAM_RESOLVER, placement_index)[/code].
## Preview and commit must both use this (chain-preview rule 1).
func context_for_next_placement() -> ResolveContext:
	return ResolveContext.make(abilities, chain_rules, SeedStreams.resolver_seed(stage_seed, placement_index), hooks, placement_index + 1)


## Authoritative commit (chain-preview rule 9): independent resolve with
## [method context_for_next_placement], board ← final_board, score, tally.
func commit(piece: PieceInstance, anchor: Vector2i) -> RoundCommit:
	var out := RoundCommit.new()
	out.result = ChainResolver.resolve(board, piece, anchor, context_for_next_placement())
	if not out.result.is_valid():
		out.error = out.result.error
		return out
	out.breakdown = ScoreCalculator.score_placement(out.result.events, scoring_rules)
	var before := tally.stage_score
	tally = StageScoreTally.committed(tally, out.breakdown.total)
	out.score_delta = tally.stage_score - before
	board = out.result.final_board.copy()
	placement_index += 1
	board_version += 1
	return out
