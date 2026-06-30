## App settings (language / display / audio) persisted to user://settings.json.
## Autoloaded BEFORE the main scene so the locale is applied on the first frame.
## Also hosts t(): the content-translation helper with English fallback.
##
## Per the project's autoload convention, reference this directly as `Settings`
## (never via get_node_or_null). See docs/conventions/gameplay-code.md.
extends Node

const SAVE_PATH := "user://settings.json"
const DEFAULT_LANGUAGE := "en"

var language: String = DEFAULT_LANGUAGE
var fullscreen: bool = false
var master_volume: float = 1.0
var music_volume: float = 0.45
var sfx_volume: float = 0.9
## Battle speed multiplier applied to Engine.time_scale during combat (1.0 / 1.5 / 2.0).
var game_speed: float = 1.0
## Active save slot (1..3), or 0 when none is chosen yet (fresh boot at the menu).
## Persisted so a relaunch can remember the last-played slot, but the slot-select
## screen always re-sets it on pick. MetaProgress / RunManager namespace their
## save files under user://slot_{active_slot}/ from this value.
var active_slot: int = 0

## Rebindable battle keys (action -> Godot keycode). Players remap these in
## Settings; battle_ui_manager reads them via get_key().
const DEFAULT_KEYS := {
	"end_turn": KEY_SPACE,
	"view_draw": KEY_Q,
	"view_discard": KEY_E,
	"view_exhaust": KEY_X,
	"view_attributes": KEY_I,
}
var key_bindings: Dictionary = {}

const TRANSLATIONS_DIR := "res://assets/translations"


func _ready() -> void:
	load_settings()
	_load_translations()
	_apply_all()


## Load every imported .translation under assets/translations and register it
## with the TranslationServer. Done programmatically (rather than via the
## project.godot locale/translations list) so newly-populated CSVs are picked
## up automatically after reimport, with no project-file churn.
func _load_translations() -> void:
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".translation"):
			continue
		var res = load(TRANSLATIONS_DIR + "/" + file_name)
		if res is Translation:
			TranslationServer.add_translation(res)


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	language = str(data.get("language", DEFAULT_LANGUAGE))
	fullscreen = bool(data.get("fullscreen", false))
	master_volume = float(data.get("master_volume", 1.0))
	music_volume = float(data.get("music_volume", 0.45))
	sfx_volume = float(data.get("sfx_volume", 0.9))
	game_speed = clampf(float(data.get("game_speed", 1.0)), 1.0, 2.0)
	active_slot = int(data.get("active_slot", 0))
	key_bindings = {}
	var kb = data.get("key_bindings", {})
	if typeof(kb) == TYPE_DICTIONARY:
		for a in kb:
			key_bindings[str(a)] = int(kb[a])


func save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: could not write %s" % SAVE_PATH)
		return
	(
		f
		. store_string(
			(
				JSON
				. stringify(
					{
						"language": language,
						"fullscreen": fullscreen,
						"master_volume": master_volume,
						"music_volume": music_volume,
						"sfx_volume": sfx_volume,
						"game_speed": game_speed,
						"active_slot": active_slot,
						"key_bindings": key_bindings,
					}
				)
			)
		)
	)


func _apply_all() -> void:
	TranslationServer.set_locale(language)
	_apply_fullscreen()
	apply_audio()


func set_language(loc: String) -> void:
	language = loc
	TranslationServer.set_locale(loc)
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save_settings()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


## Battle-speed multiplier (1.0 / 1.5 / 2.0). Applied to Engine.time_scale by
## battle_scene on enter; reset to 1.0 on exit so menus run at normal speed.
func set_game_speed(v: float) -> void:
	game_speed = clampf(v, 1.0, 2.0)
	save_settings()


## Set the active save slot (1..3) and persist. MetaProgress.set_active_slot wraps
## this and also (re)loads that slot's profile — prefer calling that.
func set_active_slot(n: int) -> void:
	active_slot = n
	save_settings()


## ── Key bindings ──────────────────────────────────────────────────────────────


## Current keycode for an action, falling back to the default when unbound.
func get_key(action: String) -> int:
	if key_bindings.has(action):
		return int(key_bindings[action])
	return int(DEFAULT_KEYS.get(action, KEY_NONE))


func set_key(action: String, keycode: int) -> void:
	key_bindings[action] = keycode
	save_settings()


func reset_keys() -> void:
	key_bindings = {}
	save_settings()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Apply all three audio bus volumes. Music / SFX buses are created by
## AudioManager; this no-ops on any bus that doesn't exist yet.
func apply_audio() -> void:
	_set_bus_db("Master", master_volume)
	_set_bus_db("Music", music_volume)
	_set_bus_db("SFX", sfx_volume)


func _set_bus_db(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


## Content-translation helper. Returns the localized string for `key`, or
## `fallback` (the English source) when the key has no translation — so a
## missing zh value degrades to English, never a raw key.
func t(key: String, fallback: String = "") -> String:
	var s := tr(key)
	if s == key:
		return fallback if fallback != "" else key
	return s
