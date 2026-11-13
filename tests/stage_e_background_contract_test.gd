extends Node

## Stage E visual contract: every full-screen backdrop has a stable 1920x1080
## presentation footprint, event art keeps the 1024x768 source footprint, and
## combat selects a distinct act background without touching card layout.

const BATTLE_PATH := "res://ui/battle/battle_screen.gd" # path-ok: reads source text
const MAP_PATH := "res://ui/map/map_scene.gd" # path-ok: reads source text
const MENU_PATH := "res://ui/menus/main_menu.gd" # path-ok: reads source text
const REST_PATH := "res://ui/map/map_scene.gd" # path-ok: rest scene is built here
const BATTLE_BG_DIR := "res://battle_scene/assets/images/backgrounds/"
const FULLSCREEN_BACKDROPS := [
	"res://run_system/assets/images/map/wasteland_route_map_pixel_bg.png",
	"res://run_system/assets/images/shop/shop_interior_bg.png",
	"res://run_system/assets/images/ui/rest/campfire_scene_1920.png",
	"res://run_system/assets/images/ui/start_screen/bottlecap_hunter_start_background_1920.png",
	"res://run_system/assets/images/events/backdrops/act_1.png",
	"res://run_system/assets/images/events/backdrops/act_2.png",
	"res://run_system/assets/images/events/backdrops/act_3.png",
]
const EVENT_ILLUSTRATIONS := [
	"res://run_system/assets/images/events/buried_cache_1024x768.png",
	"res://run_system/assets/images/events/caravan_checkpoint_1024x768.png",
	"res://run_system/assets/images/events/collapsed_overpass_1024x768.png",
	"res://run_system/assets/images/events/cursed_safe_1024x768.png",
	"res://run_system/assets/images/events/fortune_shrine_1024x768.png",
	"res://run_system/assets/images/events/hooded_stranger_1024x768.png",
	"res://run_system/assets/images/events/mutant_bazaar_1024x768.png",
	"res://run_system/assets/images/events/rad_storm_1024x768.png",
	"res://run_system/assets/images/events/stranded_trader_1024x768.png",
]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var battle := FileAccess.get_file_as_string(BATTLE_PATH)
	var map := FileAccess.get_file_as_string(MAP_PATH)
	var menu := FileAccess.get_file_as_string(MENU_PATH)
	_expect(battle.contains("ACT_BATTLE_BACKGROUND") and battle.contains("current_act"), "battle chooses a background from the current act")
	_expect(battle.contains("wasteland_battlefield_act2_city.png") and battle.contains("wasteland_battlefield_act3_radiation.png"), "act 2 and act 3 use named background variants")
	_expect(map.contains("wasteland_route_map_pixel_bg.png"), "route map uses the quiet 1920x1080 background")
	_expect(menu.contains("1920") or menu.contains("bottlecap_hunter_start_background.png"), "main menu keeps an explicit full-screen backdrop")
	for path in FULLSCREEN_BACKDROPS:
		var tex := load(path) as Texture2D
		_expect(tex != null and tex.get_width() == 1920 and tex.get_height() == 1080, "full-screen backdrop is 1920x1080: %s" % path)
	for path in EVENT_ILLUSTRATIONS:
		var event_tex := load(path) as Texture2D
		_expect(event_tex != null and event_tex.get_width() == 1024 and event_tex.get_height() == 768, "event illustration is 1024x768: %s" % path)
	if failures.is_empty():
		print("[OK] Stage E background contract passed")
		get_tree().quit(0)
		return
	push_error("Stage E background contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
