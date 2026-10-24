extends RefCounted

## One canonical content entry (STS2 AbstractModel). `data` is the parsed JSON
## with references normalized to full IDs and made deep read-only; runtime code
## that needs to change it works on `to_mutable()`.

const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd

var id: String
var category: String
var ns: String
var entry: String
var data: Dictionary


func _init(p_category: String, p_ns: String, p_entry: String, p_data: Dictionary) -> void:
	category = p_category
	ns = p_ns
	entry = p_entry
	id = MODEL_ID.make(p_ns, p_entry)
	data = p_data


func to_mutable() -> Dictionary:
	return data.duplicate(true)
