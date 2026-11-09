## Pooled SFX player (design/gdd/audio.md rules 4, 7–9, 12; F3, F4, F6;
## States DISARMED → ARMED ⇄ SUSPENDED). Pre-builds [member AudioTuning.pool_size]
## [AudioStreamPlayer]s on the [code]SFX[/code] bus, drops every request until
## the first user press (web audio policy — nothing sounds at boot), limits
## repeats / voices per sound and steals the oldest lowest-priority voice when
## the pool is full. Display-only: nothing here affects rules or timing.
## [codeblock]
## var sfx := SfxPlayer.new()
## sfx.tuning = load("res://assets/data/audio/audio_tuning.tres")
## add_child(sfx)                    # loads streams, builds the pool
## sfx.arm()                         # or: first InputEvent press arms it
## sfx.play(&"chain_hit", SfxRules.chain_pitch(3, sfx.tuning))
## [/codeblock]
class_name SfxPlayer
extends Node

## GDD state table.
enum State { DISARMED, ARMED, SUSPENDED }

## Bus every SFX voice plays on.
const BUS := &"SFX"

## Tuning (sound list, gains, limits).
var tuning: AudioTuning
## Current state.
var state: State = State.DISARMED
## Audio clock (s), advanced in [method _process]; tests may set it.
var now: float = 0.0
## Voices started since creation (observation for tests / debug).
var started_count: int = 0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_id: Array[StringName] = []
var _voice_prio: Array[int] = []
var _voice_start: Array[float] = []
var _last_play: Dictionary = {}
var _pending: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	AudioBuses.ensure()
	_rng.seed = tuning.jitter_seed
	_load_streams()
	for i: int in maxi(tuning.pool_size, 1):
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_voices.append(p)
		_voice_id.append(&"")
		_voice_prio.append(0)
		_voice_start.append(-INF)


func _load_streams() -> void:
	var missing: Array[String] = []
	for id: StringName in tuning.sounds:
		var path := tuning.sfx_dir + String(id) + ".wav"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s == null:
			missing.append(String(id))
		else:
			_streams[id] = s
	if not missing.is_empty():
		push_warning("SfxPlayer: missing sounds (ignored): %s" % ", ".join(missing))


## True when [param id] has a loaded stream.
func has_sound(id: StringName) -> bool:
	return _streams.has(id)


## ARMED: requests play from now on (rule 4). Idempotent.
func arm() -> void:
	if state == State.DISARMED:
		state = State.ARMED


## App went to the background: stop voices, drop requests and pending delays.
func suspend() -> void:
	if state == State.DISARMED:
		return
	state = State.SUSPENDED
	_pending.clear()
	for p: AudioStreamPlayer in _voices:
		p.stop()


## Back from the background (no retroactive sounds).
func resume() -> void:
	if state == State.SUSPENDED:
		state = State.ARMED


## Requests [param id] at [param pitch], after [param delay] seconds.
## [param extra_db] adds to the sound's gain; [param fast] applies rule 12.
## Returns true if the request was accepted (started or scheduled).
func play(id: StringName, pitch: float = 1.0, delay: float = 0.0, fast: bool = false, extra_db: float = 0.0) -> bool:
	if state != State.ARMED or not _streams.has(id):
		return false
	if not SfxRules.admit_fast(id, fast, tuning):
		return false
	var db := SfxRules.voice_db(id, fast, tuning) + extra_db
	if delay > 0.0:
		_pending.append({&"id": id, &"pitch": pitch, &"db": db, &"at": now + delay})
		return true
	return _start(id, pitch, db)


## Stops every voice (e.g. tests); keeps the state.
func stop_all() -> void:
	_pending.clear()
	for p: AudioStreamPlayer in _voices:
		p.stop()


func _start(id: StringName, pitch: float, db: float) -> bool:
	if not SfxRules.admit_repeat(now, float(_last_play.get(id, -INF)), tuning.min_repeat_gap_s):
		return false
	var busy: Array[bool] = []
	var active := 0
	for i: int in _voices.size():
		var b := _voices[i].playing
		busy.append(b)
		if b and _voice_id[i] == id:
			active += 1
	if active >= tuning.max_voices(id):
		return false
	var prio := tuning.priority(id)
	var v := SfxRules.pick_voice(busy, _voice_prio, _voice_start, prio)
	if v < 0:
		return false
	var p := _voices[v]
	p.stop()
	p.stream = _streams[id]
	p.volume_db = db
	var cents := tuning.jitter_cents(id)
	p.pitch_scale = clampf(pitch * (SfxRules.jitter(_rng.randf_range(-1.0, 1.0), cents) if cents > 0.0 else 1.0), 0.25, 4.0)
	p.play()
	_voice_id[v] = id
	_voice_prio[v] = prio
	_voice_start[v] = now
	_last_play[id] = now
	started_count += 1
	return true


func _process(delta: float) -> void:
	now += delta
	if _pending.is_empty():
		return
	var due: Array[Dictionary] = []
	for r: Dictionary in _pending:
		if float(r[&"at"]) <= now:
			due.append(r)
	for r: Dictionary in due:
		_pending.erase(r)
		if state == State.ARMED:
			_start(r[&"id"], r[&"pitch"], r[&"db"])


func _input(event: InputEvent) -> void:
	if is_press(event):
		arm()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			suspend()
		NOTIFICATION_APPLICATION_RESUMED:
			resume()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("mobile") or OS.has_feature("web"):
				suspend()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			resume()


## True for a user press that may unlock audio (touch, click, key).
static func is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false
