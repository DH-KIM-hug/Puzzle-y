## Audio bus layout + volume settings (design/gdd/audio.md rules 5–6, F4).
## The layout ships as [code]res://default_bus_layout.tres[/code]
## (Master ← SFX, Master ← Music); [method ensure] recreates the two buses if a
## platform started without it so no request ever hits a missing bus.
## [codeblock]
## AudioBuses.ensure()
## var s := AudioBuses.Settings.from_tuning(tuning)
## s.load_from(tuning.settings_path)
## s.apply()
## [/codeblock]
class_name AudioBuses
extends RefCounted

## Bus names (rule 5).
const MASTER := &"Master"
const SFX := &"SFX"
const MUSIC := &"Music"


## Adds SFX / Music (sending to Master) when missing. Idempotent.
static func ensure() -> void:
	for name: StringName in [SFX, MUSIC]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, MASTER)


## Sets one bus from a 0..1 volume (0 mutes it).
static func set_volume(bus: StringName, volume: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	var db := SfxRules.bus_db(volume)
	AudioServer.set_bus_mute(i, is_inf(db))
	if not is_inf(db):
		AudioServer.set_bus_volume_db(i, db)


## Player volume settings (provisional home until the Settings GDD, audio Q2).
class Settings:
	extends RefCounted
	## Master 0..1.
	var master_volume: float = 1.0
	## SFX 0..1.
	var sfx_volume: float = 0.8
	## Music 0..1.
	var music_volume: float = 0.7
	## Master mute.
	var muted: bool = false

	## Defaults from the tuning resource.
	static func from_tuning(t: AudioTuning) -> Settings:
		var s := Settings.new()
		s.master_volume = t.master_volume
		s.sfx_volume = t.sfx_volume
		s.music_volume = t.music_volume
		s.muted = t.muted
		return s

	## Reads values present in [param cfg] (section "audio"); absent keys keep their value.
	func read(cfg: ConfigFile) -> void:
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", muted))

	## Writes the values into [param cfg].
	func write(cfg: ConfigFile) -> void:
		cfg.set_value("audio", "master_volume", master_volume)
		cfg.set_value("audio", "sfx_volume", sfx_volume)
		cfg.set_value("audio", "music_volume", music_volume)
		cfg.set_value("audio", "muted", muted)

	## Loads [param path] if it exists (missing file = defaults, not an error).
	func load_from(path: String) -> void:
		var cfg := ConfigFile.new()
		if FileAccess.file_exists(path) and cfg.load(path) == OK:
			read(cfg)

	## Saves to [param path]. Returns the engine error code.
	func save_to(path: String) -> Error:
		var cfg := ConfigFile.new()
		write(cfg)
		return cfg.save(path)

	## Pushes the values to the buses (F4; [member muted] mutes Master).
	func apply() -> void:
		AudioBuses.ensure()
		AudioBuses.set_volume(MASTER, master_volume)
		AudioBuses.set_volume(SFX, sfx_volume)
		AudioBuses.set_volume(MUSIC, music_volume)
		if muted:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER), true)
