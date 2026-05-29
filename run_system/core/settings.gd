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
					}
				)
			)
		)
	)


func _apply_all() -> void:
	TranslationServer.set_locale(language)
	_apply_fullscreen()
	_apply_volume()


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
	_apply_volume()
	save_settings()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


## Content-translation helper. Returns the localized string for `key`, or
## `fallback` (the English source) when the key has no translation — so a
## missing zh value degrades to English, never a raw key.
func t(key: String, fallback: String = "") -> String:
	var s := tr(key)
	if s == key:
		return fallback if fallback != "" else key
	return s
