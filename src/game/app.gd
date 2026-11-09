## T1 app root (main scene): owns the shared data (StageEnv, StageCatalog,
## crew looks, font, [PlayerProgress]) and switches between the screens:
## stage select (title) → team select → play ([GameScreen]) → result (overlay in
## the play screen) → retry / next stage / stage select. "연습" opens the endless
## T0 free-play round.
##
## Persistence: [PlayerProgress] in [code]user://progress.json[/code] (minimal step;
## full save GDD later). Written when a stage is cleared and when a team is confirmed.
##
## Debug args (after [code]--[/code]): [code]--autoplay[/code] attaches [DebugAutoplay];
## [code]--save=<path>[/code] overrides the save path; [code]--fresh-save[/code]
## ignores and overwrites the file; [code]--own-all[/code] owns all 6 crews (debug);
## [code]--unlock-all[/code] opens every stage (in memory only).
class_name App
extends Node

const CATALOG_PATH := "res://assets/data/stages/catalog.tres"

## Shared stage environment (registry + rules).
var env: StageEnv
## Ordered stages.
var catalog: StageCatalog
## Crew look table.
var visuals: CrewVisuals
## UI font.
var font: Font
## UI theme (font + default size).
var theme: Theme
## Player progress (stars, owned crews, team memory).
var progress: PlayerProgress
## Save path.
var save_path: String = PlayerProgress.DEFAULT_PATH
## Debug: every stage selectable.
var unlock_all: bool = false
## Current screen node.
var current: Node
## Index of the stage being played / edited (-1 = practice).
var stage_index: int = -1

## Emitted after a screen switch (autoplay hook).
signal screen_changed(screen: Node)


func _ready() -> void:
	font = GameScreen._make_font()
	ThemeDB.fallback_font = font
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	TranslationServer.set_locale("ko")
	env = StageEnv.load_default()
	catalog = load(CATALOG_PATH)
	for l: StageLoad in StageLoader.load_catalog(catalog, env):
		if not l.errors.is_empty():
			push_error("App: stage data errors: %s" % ", ".join(l.errors))
	visuals = CrewVisuals.from_registry(env.registry)
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--save="):
			save_path = a.get_slice("=", 1)
	if "--fresh-save" in args:
		progress = PlayerProgress.fresh(env.registry)
	else:
		progress = PlayerProgress.load_file(save_path, env.registry)
	if "--own-all" in args:
		progress.owned = OwnedCrews.all_of(env.registry).owned_crew_ids()
	unlock_all = "--unlock-all" in args
	show_stage_select()
	if "--autoplay" in args:
		var bot := DebugAutoplay.new()
		bot.app = self
		add_child(bot)


## True when stage [param index] can be played.
func is_unlocked(index: int) -> bool:
	return unlock_all or progress.is_unlocked(catalog, index)


## Title / stage select.
func show_stage_select() -> void:
	var s := StageSelectScreen.new()
	s.app = self
	s.stage_chosen.connect(show_team_select)
	s.practice_chosen.connect(start_practice)
	_switch(s)


## Team select for stage [param index] (F2 default team pre-filled).
func show_team_select(index: int) -> void:
	if index < 0 or index >= catalog.stages.size() or not is_unlocked(index):
		return
	stage_index = index
	var s := TeamSelectScreen.new()
	s.app = self
	s.stage = catalog.stages[index]
	s.confirmed.connect(func(team: Array[StringName]) -> void: _confirm_team(index, team))
	s.back_requested.connect(show_stage_select)
	_switch(s)


## Starts stage [param index] with [param team] (already valid).
func start_stage(index: int, team: Array[StringName]) -> void:
	stage_index = index
	var g := GameScreen.new()
	g.app = self
	g.stage = catalog.stages[index]
	g.team = team.duplicate()
	_wire_game(g)
	_switch(g)


## Endless free-play round (T0 mode) with the remembered global team.
func start_practice() -> void:
	stage_index = -1
	var g := GameScreen.new()
	g.app = self
	g.stage = null
	var team := progress.memory.last_global.duplicate()
	if team.size() != 3:
		team = TeamRules.resolve_default_team(TeamRule.make(), env.registry, progress.owned_crews(env.registry), progress.memory, &"")
	g.team = team
	_wire_game(g)
	_switch(g)


## Saves progress (errors are logged, never fatal).
func save() -> void:
	var err := progress.save_file(save_path)
	if err != OK:
		push_warning("App: progress not saved (%s)" % error_string(err))


func _confirm_team(index: int, team: Array[StringName]) -> void:
	var stage := catalog.stages[index]
	progress.memory = TeamRules.remember(progress.memory, stage.id, team, stage.effective_team_rule(), progress.owned_crews(env.registry))
	save()
	start_stage(index, team)


func _wire_game(g: GameScreen) -> void:
	g.round_ended.connect(_on_round_ended)
	g.exit_requested.connect(show_stage_select)
	g.next_requested.connect(func() -> void: show_team_select(stage_index + 1))
	g.team_change_requested.connect(func() -> void: show_team_select(stage_index))


func _on_round_ended(result: RoundResult) -> void:
	if stage_index < 0 or result.outcome != RoundResult.Outcome.CLEARED:
		return
	if progress.record_result(result.stage_id, result.stars, result.final_score):
		save()


func _switch(next: Node) -> void:
	if current != null:
		current.queue_free()
	current = next
	add_child(next)
	screen_changed.emit(next)


## True when a stage after [param index] exists and is unlocked.
func has_next(index: int) -> bool:
	return index >= 0 and index + 1 < catalog.stages.size() and is_unlocked(index + 1)
