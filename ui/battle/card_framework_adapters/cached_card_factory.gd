## Project card factory: behaves like the vendored JsonCardFactory but takes card
## info from ModelDb instead of scanning card JSON on each battle/shop factory
## build. Cards are keyed by full content id ("base:reload"), which becomes the
## card node's `card_name`. The vendored addon is left untouched; this override
## lives in the project.
##
## No `class_name` (project convention) — referenced via the my_card_factory.tscn script slot.
extends "res://addons/card-framework/json_card_factory.gd"

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


func preload_card_data() -> void:
	for card_id in MODEL_DB.ids("card"):
		_preload_from_db(card_id)


## The addon names the node from `card_info.name`; content cards carry `id`.
## Ids injected after this factory preloaded (tests, mods) load on demand.
func create_card(card_name: String, target: CardContainer) -> Card:
	if not preloaded_cards.has(card_name):
		if not MODEL_DB.has("card", card_name):
			push_error("Card info not found for card: %s" % card_name)
			return null
		_preload_from_db(card_name)
	var entry: Dictionary = preloaded_cards[card_name]
	return _create_card_node(card_name, entry["texture"], target, entry["info"])


func _preload_from_db(card_id: String) -> void:
	# Each factory gets its own writable copy so per-battle card mutation can't
	# reach the canonical data.
	var info: Dictionary = MODEL_DB.mutable("card", card_id)
	var tex: Texture2D = null
	if info.has("front_image"):
		# load() is resource-cached by Godot, so this is cheap on the 2nd+ build.
		tex = _load_image(card_asset_dir + "/" + str(info["front_image"]))
	preloaded_cards[card_id] = {"info": info, "texture": tex}
