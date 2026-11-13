extends Node

## Focused Stage B regression contract. This keeps the reward and result
## overlays on the readable pre-overnight structure while preserving the
## persistent run top bar clearance.

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

	# Rewards keep the earlier readable VBox structure: one centered content
	# column, compact list rows and a normal-sized continue action. The backdrop
	# and content still start below the persistent top bar.
	_expect(loot.contains("T.fade_in(self)"), "rewards use the readable fade-in entrance")
	_expect(loot.contains("loot_root.offset_top = RUN_TOP_BAR.BAR_HEIGHT"), "rewards clear the full top bar")
	_expect(loot.contains("Vector2(700, 80)"), "reward rows keep the readable hit geometry")
	_expect(loot.contains("Vector2(220, 54)"), "continue keeps the compact hit geometry")
	_expect(not loot.contains("REWARD_PANEL_SIZE"), "rewards do not add an oversized absolute panel")
	_expect(not scene.contains("RewardPanel") and not scene.contains("RewardBanner"), "reward scene keeps the simple content stack")

	# Card picks remain card-native and use the same top-bar-safe VBox overlay.
	_expect(loot.contains("draft_overlay.offset_top = RUN_TOP_BAR.BAR_HEIGHT"), "card draft clears the full top bar")
	_expect(not loot.contains("CARD_REWARD_CENTER_Y") and not loot.contains("CARD_REWARD_PITCH"), "card draft avoids the oversized absolute layout")

	# Rest/campfire choices use source art plus a shape-hugging outline, and a
	# full-health run reads 已满血 instead of 回复0.
	_expect(map.contains("RestChoiceOutline"), "rest choices have a dedicated outline layer")
	_expect(map.contains("Vector2(256, 169)"), "rest option art keeps the 256x169 source contract")
	_expect(map.contains("1.1") and map.contains("Expo"), "rest hover scales to 1.1 and recovers Expo-Out")
	_expect(map.contains("UI_ROUTE_HEAL_FULL"), "full-health rest copy uses the explicit 已满血 key")
	_expect(map.contains("RUN_TOP_BAR.BAR_HEIGHT"), "rest content starts below the complete top bar")

	# Result and extract return to their compact centered panels while retaining
	# the full top-bar clearance introduced before the overnight visual pass.
	_expect(not result.contains("banner_short.png") and not result.contains("ResultPanel"), "result keeps the compact centered panel")
	_expect(not extract.contains("banner_short.png") and not extract.contains("ModalPanel"), "extract keeps the compact centered panel")
	_expect(result.contains("RUN_TOP_BAR.BAR_HEIGHT"), "result keeps the run top bar clearance")
	_expect(extract.contains("RUN_TOP_BAR.BAR_HEIGHT"), "extract keeps the run top bar clearance")

	if failures.is_empty():
		print("[OK] Stage B overlay contract passed")
		get_tree().quit(0)
		return
	push_error("Stage B overlay contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)

