extends Node

## Focused Stage B regression contract. This intentionally starts red against the
## legacy reward/rest/result surfaces, then turns green as the shared overlay
## structure and measured geometry land.

const LOOT_PATH := "res://ui/rewards/loot_reward.gd" # path-ok: reads source text
const LOOT_SCENE_PATH := "res://ui/rewards/loot_reward.tscn" # path-ok: reads scene text
const MAP_PATH := "res://ui/map/map_scene.gd" # path-ok: reads source text
const RESULT_PATH := "res://ui/rewards/result_screen.gd" # path-ok: reads source text
const EXTRACT_PATH := "res://ui/rewards/extract_choice_modal.gd" # path-ok: reads source text
const TOP_BAR := preload("uid://dd4fkkrkiwgrj") # res://ui/common/run_top_bar.gd
const TEST_SAVE_ROOT = preload("uid://c5pfll7nw68un") # res://tests/support/test_save_root.gd

var failures: PackedStringArray = []


func _ready() -> void:
	TEST_SAVE_ROOT.use("stage_b_overlay_contract")
	call_deferred("_run")


func _exit_tree() -> void:
	TEST_SAVE_ROOT.release()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var loot := FileAccess.get_file_as_string(LOOT_PATH)
	var scene := FileAccess.get_file_as_string(LOOT_SCENE_PATH)
	var map := FileAccess.get_file_as_string(MAP_PATH)
	var result := FileAccess.get_file_as_string(RESULT_PATH)
	var extract := FileAccess.get_file_as_string(EXTRACT_PATH)

	# Rewards and card draft share the battle scrim/banner/panel structure while
	# preserving the persistent top bar's full clearance.
	_expect(loot.contains("banner_long.png"), "rewards resolves the shared long banner")
	_expect(loot.contains("RewardPanel"), "rewards owns a measured body panel")
	_expect(loot.contains("Vector2(526, 640)"), "rewards body uses the 526x640 target footprint")
	_expect(loot.contains("Vector2(402, 86)"), "reward rows keep the 402x86 hit geometry")
	_expect(loot.contains("Vector2(269, 108)"), "continue keeps the 269x108 hit geometry")
	_expect(loot.contains("BACK_OUT") or loot.contains("TRANS_BACK"), "rewards entrance uses back-out motion")
	_expect(scene.contains("RewardPanel") and scene.contains("RewardBanner"), "reward scene declares panel and banner layers")

	# Card picks stay card-native, with the measured centre pitch and low action
	# band instead of a generic holder around the hand.
	_expect(loot.contains("CARD_REWARD_CENTER_Y"), "card reward exposes centre-y anchor")
	_expect(loot.contains("CARD_REWARD_PITCH"), "card reward exposes 350px card pitch")
	_expect(loot.contains("884.0") and loot.contains("957.0"), "card reward actions stay in the y=884..957 band")

	# Rest/campfire choices use source art plus a shape-hugging outline, and a
	# full-health run reads 已满血 instead of 回复0.
	_expect(map.contains("RestChoiceOutline"), "rest choices have a dedicated outline layer")
	_expect(map.contains("Vector2(256, 169)"), "rest option art keeps the 256x169 source contract")
	_expect(map.contains("1.1") and map.contains("Expo"), "rest hover scales to 1.1 and recovers Expo-Out")
	_expect(map.contains("UI_ROUTE_HEAL_FULL"), "full-health rest copy uses the explicit 已满血 key")
	_expect(map.contains("RUN_TOP_BAR.BAR_HEIGHT"), "rest content starts below the complete top bar")

	# Result, extract, and the shared modal all use the banner/panel hierarchy.
	_expect(result.contains("banner_short.png") and result.contains("ResultPanel"), "result uses shared banner and panel layers")
	_expect(extract.contains("banner_short.png") and extract.contains("ModalPanel"), "extract modal uses the shared modal hierarchy")
	_expect(result.contains("RUN_TOP_BAR.BAR_HEIGHT"), "result keeps the run top bar clearance")

	if failures.is_empty():
		print("[OK] Stage B overlay contract passed")
		get_tree().quit(0)
		return
	push_error("Stage B overlay contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

