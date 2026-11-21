## Everything a stage is loaded and played against, besides the stage itself:
## registry, global rule resources. Built once by the Node world and passed in
## (dependency injection, no globals — ADR-0001).
## [codeblock]
## var env := StageEnv.load_default()     # the shipped data
## var loaded := StageLoader.load_stage(stage, env)
## [/codeblock]
class_name StageEnv
extends RefCounted

const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"
const CHAIN_RULES_PATH := "res://assets/data/rules/chain_rules.tres"
const SCORING_RULES_PATH := "res://assets/data/rules/scoring_rules.tres"
const TRAY_RULES_PATH := "res://assets/data/rules/tray_rules.tres"
const STAGE_RULES_PATH := "res://assets/data/rules/stage_rules.tres"
const OBSTACLE_RULES_PATH := "res://assets/data/rules/obstacle_rules.tres"

## Validated crew registry.
var registry: CrewRegistry
## Depth cap (CHAIN goal validation, resolver).
var chain_rules: ChainRules
## cell_points (F1) and placement scoring.
var scoring_rules: ScoringRules
## Global tray values (tray_size, crew_bag_copies).
var tray_rules: TrayRules
## Global stage values (section H).
var stage_rules: StageRules
## Obstacle values (obstacles section F).
var obstacles: ObstacleConfig


## Builds an env from explicit resources.
static func make(p_registry: CrewRegistry, p_chain: ChainRules, p_scoring: ScoringRules, p_tray: TrayRules,
		p_stage: StageRules, p_obstacles: ObstacleConfig) -> StageEnv:
	var e := StageEnv.new()
	e.registry = p_registry
	e.chain_rules = p_chain
	e.scoring_rules = p_scoring
	e.tray_rules = p_tray
	e.stage_rules = p_stage
	e.obstacles = p_obstacles
	return e


## The shipped data resources; the registry is validated here.
static func load_default() -> StageEnv:
	var reg: CrewRegistry = load(REGISTRY_PATH)
	reg.load_and_validate()
	return make(reg, load(CHAIN_RULES_PATH), load(SCORING_RULES_PATH), load(TRAY_RULES_PATH), load(STAGE_RULES_PATH), load(OBSTACLE_RULES_PATH))


## crew_id → true for every registry crew.
func crew_ids() -> Dictionary:
	var out := {}
	for c: CrewDef in registry.crews:
		if c != null:
			out[c.id] = true
	return out
