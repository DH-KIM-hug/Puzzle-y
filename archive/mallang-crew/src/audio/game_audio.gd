## Game SFX glue (design/gdd/audio.md Core Rules D–E, F5): turns
## [signal ChainPlayer.cue_fired] and the play screen's input / score / result
## events into [SfxPlayer] requests. Listens only — never changes the board,
## score or timing (rule 1); a screen without it plays identically.
## [codeblock]
## var audio := GameAudio.create(load(GameAudio.TUNING_PATH), presentation_tuning)
## add_child(audio)
## audio.attach(chain_player)
## audio.pick_up()
## [/codeblock]
class_name GameAudio
extends Node

## Default data path.
const TUNING_PATH := "res://assets/data/audio/audio_tuning.tres"

## Tuning.
var tuning: AudioTuning
## Pooled player (child).
var sfx: SfxPlayer
## Volume settings in effect.
var settings: AudioBuses.Settings
## Presentation sweep cascade (F2 delay; read from the presentation tuning).
var sweep_cascade_s: float = 0.05

var _chain: ChainPlayer
var _peel_waves: Dictionary = {}
var _tick_n: int = 0
var _last_tick: float = -INF


## Builds the node with its [SfxPlayer]; settings load from
## [member AudioTuning.settings_path], [code]-- --mute[/code] mutes this run.
static func create(t: AudioTuning, presentation: PresentationTuning) -> GameAudio:
	var a := GameAudio.new()
	a.name = "GameAudio"
	a.tuning = t
	if presentation != null:
		a.sweep_cascade_s = presentation.sweep_cascade_s
	a.sfx = SfxPlayer.new()
	a.sfx.name = "SfxPlayer"
	a.sfx.tuning = t
	a.add_child(a.sfx)
	a.settings = AudioBuses.Settings.from_tuning(t)
	return a


func _ready() -> void:
	settings.load_from(tuning.settings_path)
	if "--mute" in OS.get_cmdline_user_args():
		settings.muted = true
	settings.apply()


## Listens to a chain player's cues.
func attach(chain: ChainPlayer) -> void:
	_chain = chain
	chain.cue_fired.connect(on_cue)


## Forwards a raw input event (arms audio on the first press — rule 4). The
## screen calls this before handling the event so the press's own sound plays.
func on_input(event: InputEvent) -> void:
	if SfxPlayer.is_press(event):
		sfx.arm()


## One chain cue (see [method SfxRules.cue_requests]).
func on_cue(kind: int, level: int, index: int, species: StringName = &"") -> void:
	if kind == ChainTimeline.Kind.PLACE:
		_peel_waves.clear()
	var first_peel := false
	if kind == ChainTimeline.Kind.PEEL and not _peel_waves.has(index):
		_peel_waves[index] = true
		first_peel = true
	var fast := _chain != null and _chain.state == ChainPlayer.State.FAST
	for r: Dictionary in SfxRules.cue_requests(kind, level, index, species, first_peel, tuning, sweep_cascade_s):
		sfx.play(r[SfxRules.R_ID], r[SfxRules.R_PITCH], float(r[SfxRules.R_DELAY]) / (3.0 if fast else 1.0), fast)


## A tray piece was picked up.
func pick_up() -> void:
	sfx.play(&"pick_up")


## A dragged piece returns to the tray; quieter when it never touched the board.
func invalid_return(on_board: bool) -> void:
	sfx.play(&"invalid_return", 1.0, 0.0, false, 0.0 if on_board else tuning.off_board_return_db)


## Any UI tap (buttons, tap-to-skip).
func ui_tap() -> void:
	sfx.play(&"ui_tap")


## The shown score integer changed (F5 gap + rising pitch).
func score_tick() -> void:
	if sfx.now - _last_tick < tuning.tick_gap_s:
		return
	if sfx.play(&"score_tick", SfxRules.tick_pitch(_tick_n, tuning)):
		_last_tick = sfx.now
		_tick_n += 1


## The score roll-up reached its target (next roll-up starts low again).
func score_roll_done() -> void:
	_tick_n = 0


## The result panel opened.
func result() -> void:
	sfx.play(&"result_chime")
