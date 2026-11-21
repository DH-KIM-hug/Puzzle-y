## Everything [method ChainResolver.resolve] reads besides board/piece/anchor
## (chain-resolver rule 1, ADR-0001 Decision 9). Treat as read-only after creation;
## preview and commit must use the same context.
class_name ResolveContext
extends RefCounted

## crew_id -> ability steps, for the whole registry (read-only).
var abilities: AbilityTable
## Depth cap and face order.
var rules: ChainRules
## Per-placement seed: [method SeedStreams.resolver_seed]. MVP primitives ignore it.
var rng_seed: int = 0
## Obstacle hooks (defaults when none).
var hooks: ChainHooks
## Placement number written into tiles and eggs (presentation / debug only).
var placement_id: int = 0


## Builds a context. [param p_hooks] null = [method ChainHooks.defaults].
static func make(p_abilities: AbilityTable, p_rules: ChainRules, p_rng_seed: int = 0, p_hooks: ChainHooks = null, p_placement_id: int = 0) -> ResolveContext:
	var ctx := ResolveContext.new()
	ctx.abilities = p_abilities
	ctx.rules = p_rules
	ctx.rng_seed = p_rng_seed
	ctx.hooks = p_hooks if p_hooks != null else ChainHooks.defaults()
	ctx.placement_id = p_placement_id
	return ctx
