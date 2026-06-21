## Project card factory: behaves exactly like the vendored JsonCardFactory but
## reads parsed card-info from the MetaProgress session cache instead of
## re-scanning + re-parsing every card JSON on each battle/shop factory build
## (~50 file reads + JSON parses per battle). ADR-0005: the vendored addon is left
## untouched — this override lives in the project. Falls back to the stock
## per-file scan if the cache is somehow unavailable, so cards always load.
##
## No `class_name` (ADR-0006) — referenced via the my_card_factory.tscn script slot.
extends "res://addons/card-framework/json_card_factory.gd"


func preload_card_data() -> void:
	var cache: Dictionary = MetaProgress.get_card_info_cache()
	if cache.is_empty():
		# Cache unavailable — fall back to the stock per-file scan (never break cards).
		super.preload_card_data()
		return
	for card_name in cache:
		var info: Dictionary = cache[card_name]
		var tex: Texture2D = null
		if info.has("front_image"):
			# load() is resource-cached by Godot, so this is cheap on the 2nd+ build.
			tex = _load_image(card_asset_dir + "/" + str(info["front_image"]))
		# Deep-copy the cached info so per-battle card mutation can't corrupt the
		# shared cache (each battle still gets an independent info dict).
		preloaded_cards[card_name] = {"info": info.duplicate(true), "texture": tex}
