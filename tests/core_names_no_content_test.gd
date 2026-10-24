extends Node

## Phase-3 acceptance: the combat flow files broadcast phases and never name a
## status or a relic. `bullet` is exempt: it is the attack-allowance badge the
## battle mirrors for display, not a status with behaviour.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const FILES := [
	"res://battle_scene/battle_scene.gd",  # path-ok: read as source text
	"res://battle_scene/combat_engine.gd",  # path-ok: read as source text
	"res://battle_scene/player.gd",  # path-ok: read as source text
]
const EXEMPT := ["bullet"]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var names := {}
	for id in MODEL_DB.ids("status"):
		names[MODEL_ID.key_entry(id)] = "status"
	for id in MODEL_DB.ids("relic"):
		names[MODEL_ID.entry_of(id)] = "relic"
	for exempt in EXEMPT:
		names.erase(exempt)
	var literal := RegEx.create_from_string("\"(?:base:)?([a-z0-9_]+)\"")
	for path in FILES:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code: String = lines[i].get_slice("#", 0)
			for m in literal.search_all(code):
				var key := m.get_string(1)
				if names.has(key):
					failures.append("%s:%d names %s '%s'" % [path, i + 1, names[key], key])
	if failures.is_empty():
		print("[OK] core names no content")
		get_tree().quit(0)
		return
	push_error("core names content: %s" % "; ".join(failures))
	get_tree().quit(1)
