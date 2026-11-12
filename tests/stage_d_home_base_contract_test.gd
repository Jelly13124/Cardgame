extends Node

## Stage D visual contract for the home base.  The checks pin the shared
## structure and state language without asserting any borrowed artwork.

const HOME_PATH := "res://ui/base/home_base_scene.gd" # path-ok: reads source text
const HOME_SCENE_PATH := "res://ui/base/home_base_scene.tscn" # path-ok: reads scene text

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var source := FileAccess.get_file_as_string(HOME_PATH)
	var scene := FileAccess.get_file_as_string(HOME_SCENE_PATH)
	_expect(source.contains("Vector2(1920, 1080)"), "home art uses the 1920x1080 stage contract")
	_expect(source.contains("HOME_BACKGROUND_PATH"), "home uses a dedicated base background")
	_expect(source.contains('BUILDING_ORDER := [\"forge\", \"clinic\", \"market\", \"outpost\"]'), "home declares all four buildings")
	_expect(source.contains("BUILDING_IMAGE_DIR") and source.contains("_hover.png") and source.contains("_pressed.png"), "buildings expose normal hover and pressed art")
	_expect(source.contains("LOCKED_DESAT_SHADER") and source.contains("get_building_tier(asset_id) <= 0"), "locked buildings use a distinct state")
	_expect(source.contains("BuildingIconOnly_") and source.contains("Tooltip.bind_hover(icon_button"), "building badges float above each building")
	_expect(source.contains('T.panel_textured(BASE_UI_PANEL_STYLE)'), "base panels use the shared material skin")
	_expect(source.contains("BountyBoardPanel") and source.contains("DifficultyPopup"), "base keeps bounty and difficulty surfaces")
	_expect(source.contains("SeedField") and source.contains("StartRunButton"), "base keeps seed and depart controls")
	_expect(source.contains("icon_warehouse") and source.contains("icon_character") and source.contains("icon_gallery"), "base keeps the three bottom entries")
	_expect(source.contains('T.apply_action_button(button, "primary"'), "depart uses the shared primary button skin")
	_expect(scene.contains("HomeBase"), "home scene remains the base entry scene")
	if failures.is_empty():
		print("[OK] Stage D home base contract passed")
		get_tree().quit(0)
		return
	push_error("Stage D home base contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
