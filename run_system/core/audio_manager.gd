## AudioManager (autoload) — central SFX + BGM playback. SFX play through a small
## pool of players (so overlapping hits don't cut each other) on the "SFX" bus;
## music loops on the "Music" bus. Both buses route to Master; Settings controls
## per-bus volume. Reference directly as `AudioManager` (autoload convention).
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUS_DIR := "res://assets/audio/music/"
const SFX_POOL := 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _music: AudioStreamPlayer = null
var _sfx_cache: Dictionary = {}
var _current_music: String = ""
var _warned_missing: Dictionary = {}
var _music_fade: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while the tree is paused
	_ensure_buses()
	for _i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	# Buses now exist — (re)apply the saved volumes.
	Settings.apply_audio()


## Create the Music / SFX buses (routed to Master) if they don't exist yet.
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## Play a one-shot sound effect by name (file stem under assets/audio/sfx/).
## `pitch_vary` adds a small random ± to the pitch so repeated hits/clicks don't
## sound mechanically identical (set 0.0 to disable, e.g. for musical stingers).
func play_sfx(
	sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_vary: float = 0.06
) -> void:
	var stream = _sfx_cache.get(sfx_name)
	if stream == null:
		var path := SFX_DIR + sfx_name + ".wav"
		if not ResourceLoader.exists(path):
			# Key→file is an implicit folder convention, so a typo'd name is silent
			# forever with no error. Warn once per missing key to catch wiring slips.
			if not _warned_missing.has(sfx_name):
				_warned_missing[sfx_name] = true
				push_warning(
					"AudioManager: no SFX file for '%s' (%s) — call is silent." % [sfx_name, path]
				)
			return
		stream = load(path)
		_sfx_cache[sfx_name] = stream
	var p: AudioStreamPlayer = _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % SFX_POOL
	p.stream = stream
	p.volume_db = volume_db
	if pitch_vary > 0.0:
		p.pitch_scale = pitch * randf_range(1.0 - pitch_vary, 1.0 + pitch_vary)
	else:
		p.pitch_scale = pitch
	p.play()


## Start (looping) a music track by name. No-op if it's already the current track.
func play_music(track_name: String, fade_in: float = 1.0) -> void:
	if track_name == _current_music and _music and _music.playing:
		return
	var path := MUS_DIR + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_current_music = track_name
	_music.stream = stream
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	# Ease the new track up from near-silence so it doesn't blast in. The previous
	# track stops under the scene's fade-to-black, so there's no audible hard cut.
	if fade_in > 0.0:
		_music.volume_db = -36.0
		_music.play()
		_music_fade = create_tween()
		_music_fade.tween_property(_music, "volume_db", 0.0, fade_in)
	else:
		_music.volume_db = 0.0
		_music.play()


func stop_music() -> void:
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	if _music:
		_music.stop()
	_current_music = ""


## The currently-playing track name ("" if none). Lets a caller capture the current
## BGM and restore it later — e.g. the event modal swaps to event.ogg then restores map.
func current_track() -> String:
	return _current_music
