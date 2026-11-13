extends Node

## Stage C regression contract for the route map and merchant inventory.
## The checks are intentionally small and visual: they pin the hierarchy and
## measured values that make the map title/card previews and shop prices legible.

const MAP_PATH := "res://ui/map/map_scene.gd" # path-ok: reads source text
const ROUTE_PATH := "res://ui/map/route_choice_card.gd" # path-ok: reads source text
const REMOVAL_PATH := "res://ui/shop/merchant_card_removal.gd" # path-ok: reads source text
const SLOT_PATH := "res://ui/shop/merchant_slot.gd" # path-ok: reads source text

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var map := FileAccess.get_file_as_string(MAP_PATH)
	var route := FileAccess.get_file_as_string(ROUTE_PATH)
	var removal := FileAccess.get_file_as_string(REMOVAL_PATH)
	var slot := FileAccess.get_file_as_string(SLOT_PATH)

	# The route is the parchment node map (node_map_view.gd, covered by its own
	# tests) below the persistent top bar, with no three-card holder.
	_expect(map.contains("NODE_MAP_VIEW"), "map shows the parchment node map view")
	_expect(map.contains("RUN_TOP_BAR.BAR_HEIGHT"), "map content remains below the persistent top bar")
	_expect(not map.contains("RouteChoicesPanel"), "map has no outer card frame")

	# The old card implementation remains available to legacy content tests, but
	# the map scene no longer depends on it for route selection.
	_expect(not map.contains("ROUTE_CHOICE_CARD"), "map does not instantiate choice cards")

	# Removal is a product in the same shelf language: icon, title and currency
	# price are independent children, rather than a two-line bare button label.
	_expect(removal.contains("iconb_cards_fan.png"), "removal slot has a card-service icon")
	_expect(removal.contains("RemoveCardIcon"), "removal slot names its product icon")
	_expect(removal.contains("RemoveCardTitle"), "removal slot names its product title")
	_expect(removal.contains("centered_currency_button_content"), "removal price uses shared currency content")
	_expect(removal.contains("54") and removal.contains("39") and removal.contains("15"), "removal price keeps the 54px icon and 39/15 typography")

	# Relics and prices use the same shared tooltip/currency conventions as the
	# rest of the shop, including the relic description on hover.
	_expect(slot.contains("Tooltip.bind_hover"), "relic slot binds the shared hover tooltip")
	_expect(slot.contains("RELIC_%s_DESC"), "relic tooltip includes the localized description")
	_expect(slot.contains("54") and slot.contains("39") and slot.contains("15"), "shop prices keep the 54px icon and 39/15 typography")

	if failures.is_empty():
		print("[OK] Stage C map/shop contract passed")
		get_tree().quit(0)
		return
	push_error("Stage C map/shop contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

