extends Node

## The base card gallery shows the same generated text as the card face
## (one description generator), not the hand-written CARD_<id>_DESC rows.

const HOME = preload("uid://c6bvuu6kbx0pq")  # res://run_system/ui/home_base_scene.tscn
const CARD_DESCRIPTION = preload("uid://b4fkwjpel7452")  # res://battle_scene/card_description.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var home := HOME.instantiate()
	add_child(home)
	await get_tree().process_frame
	for card_id in ["base:strike", "base:reload", "base:hot_streak"]:
		MetaProgress.mark_card_seen(card_id)
		var slot: Control = home.call("_make_gallery_card_slot", card_id)
		var expected: String = CARD_DESCRIPTION.colorize(CARD_DESCRIPTION.build(MODEL_DB.data("card", card_id)))
		var label := slot.find_child("GalleryCardText", true, false) as RichTextLabel
		var found := label != null and label.text == expected
		_expect(found, "%s gallery shows the generated text '%s'" % [card_id, expected])
		var cost := str(int(MODEL_DB.data("card", card_id).get("cost", 0)))
		var cost_shown := false
		for l in slot.find_children("*", "Label", true, false):
			if (l as Label).text == cost:
				cost_shown = true
			_expect(not (l as Label).text.ends_with(".0"), "%s gallery shows no float cost: %s" % [card_id, (l as Label).text])
		_expect(cost_shown, "%s gallery shows cost %s" % [card_id, cost])
		slot.free()
	home.queue_free()
	if failures.is_empty():
		print("[OK] gallery text passed")
		get_tree().quit(0)
		return
	push_error("gallery text failed: %s" % "; ".join(failures))
	get_tree().quit(1)
