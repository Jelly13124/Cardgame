extends Node

const RESULT_SCREEN_PATH := "res://run_system/ui/result_screen.gd"
const META_PROGRESS_PATH := "res://run_system/core/meta_progress.gd"
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.gd"
const BUILDING_SCREEN_BASE_PATH := "res://run_system/ui/buildings/building_screen_base.gd"
const CLINIC_SCREEN_PATH := "res://run_system/ui/buildings/clinic_screen.gd"
const MARKET_SCREEN_PATH := "res://run_system/ui/buildings/market_screen.gd"
const OUTPOST_SCREEN_PATH := "res://run_system/ui/buildings/outpost_screen.gd"
const WASTELAND_THEME_PATH := "res://run_system/ui/theme/wasteland_theme.gd"
const BUILDING_UPGRADE_POPOVER_PATH := (
	"res://run_system/ui/buildings/building_upgrade_popover.gd"
)
const FORGE_WINDOW_PATH := "res://run_system/ui/window/forge_window.gd"
const MAIN_MENU_PATH := "res://run_system/ui/main_menu.gd"
const UI_COMMON_PATH := "res://assets/translations/ui_common.csv"
const UI_HOME_PATH := "res://assets/translations/ui_home.csv"
const NORMAL_BUTTON_PATH := "res://run_system/assets/images/ui/start_screen/button_main_normal_v2.png"
const SELECTED_BUTTON_PATH := "res://run_system/assets/images/ui/start_screen/button_main_selected_v2.png"
const BOUNTY_BOARD_FRAME_PATH := "res://run_system/assets/images/home/base_hud/bounty_board_frame_exact.png"
const BUILDING_UPGRADE_FRAME_PATH := (
	"res://run_system/assets/images/ui/buildings/building_upgrade_popover_frame.png"
)
const PRICE_PLAQUE_PATHS := [
	"res://run_system/assets/images/ui_kit_lightline/price_plaque_olive_concept.png",
	"res://run_system/assets/images/ui_kit_lightline/price_plaque_orange_concept.png",
]
const FORGE_WORKBENCH_PATH := (
	"res://run_system/assets/images/ui/forge/forge_blacksmith_workbench.png"
)
const FORGE_BACKDROP_PATH := "res://run_system/assets/images/buildings/forge_bg.png"
const BUILDING_STAGE_ART_PATHS := [
	"res://run_system/assets/images/ui/clinic/npc_cyber_doctor.png",
	"res://run_system/assets/images/ui/forge/forge_blacksmith_workbench.png",
]
const BUILDING_INTERIOR_PATHS := [
	"res://run_system/assets/images/buildings/clinic_bg.png",
	"res://run_system/assets/images/ui/market/market_interior_bg.png",
	"res://run_system/assets/images/buildings/outpost_bg.png",
]
const MARKET_COMPONENT_SIZES := {
	"res://run_system/assets/images/ui/market/market_shelf_panel_frame.png": Vector2i(1309, 329),
	"res://run_system/assets/images/ui/market/market_tool_card_frame.png": Vector2i(238, 254),
	"res://run_system/assets/images/ui/market/market_equip_card_common.png": Vector2i(238, 301),
	"res://run_system/assets/images/ui/market/market_equip_card_uncommon.png": Vector2i(238, 301),
	"res://run_system/assets/images/ui/market/market_equip_card_rare.png": Vector2i(238, 301),
	"res://run_system/assets/images/ui/market/market_exchange_row_frame.png": Vector2i(609, 80),
}
const BUILDING_BADGE_PATHS := [
	"res://run_system/assets/images/home/base_hud/badge_forge.png",
	"res://run_system/assets/images/home/base_hud/badge_clinic.png",
	"res://run_system/assets/images/home/base_hud/badge_market.png",
	"res://run_system/assets/images/home/base_hud/badge_outpost.png",
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
	_test_generated_assets()
	_test_defeat_returns_to_base()
	_test_building_upgrades_spend_scrap()
	_test_building_upgrade_lives_inside()
	_test_clinic_cap_is_binary()
	_test_concept_purchase_buttons()
	_test_home_icon_only_and_bounty_contract()
	_test_main_menu_uses_native_wide_buttons()
	if failures.is_empty():
		print("[OK] Base upgrade and result routing contract passed")
		get_tree().quit(0)
		return
	push_error("Base upgrade/result contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_generated_assets() -> void:
	for path in [NORMAL_BUTTON_PATH, SELECTED_BUTTON_PATH]:
		_expect(ResourceLoader.exists(path), "generated UI component exists: %s" % path)
	var normal := load(NORMAL_BUTTON_PATH) as Texture2D
	var selected := load(SELECTED_BUTTON_PATH) as Texture2D
	for texture in [normal, selected]:
		if texture == null:
			continue
		var ratio := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
		_expect(absf(ratio - 4.375) < 0.25, "main-menu button asset keeps native 420:96 ratio")

	_expect(ResourceLoader.exists(BOUNTY_BOARD_FRAME_PATH), "exact bounty-board frame component exists")
	if ResourceLoader.exists(BOUNTY_BOARD_FRAME_PATH):
		var bounty_frame := load(BOUNTY_BOARD_FRAME_PATH) as Texture2D
		_expect(bounty_frame != null, "exact bounty-board frame imports as a texture")
		if bounty_frame != null:
			var bounty_ratio := float(bounty_frame.get_width()) / maxf(1.0, float(bounty_frame.get_height()))
			_expect(absf(bounty_ratio - (360.0 / 226.0)) < 0.12, "bounty-board frame preserves the compact 360:226 silhouette")

	for path in BUILDING_BADGE_PATHS:
		_expect(ResourceLoader.exists(path), "replacement building badge exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var badge := load(path) as Texture2D
		_expect(badge != null, "replacement building badge imports as a texture: %s" % path)
		if badge == null:
			continue
		_expect(
			badge.get_width() == 128 and badge.get_height() == 128,
			"replacement building badge keeps the 128x128 runtime contract: %s" % path
		)
		var image := badge.get_image()
		_expect(
			image != null and image.get_pixel(0, 0).a < 0.05,
			"replacement building badge keeps transparent corners: %s" % path
		)

	for path in [BUILDING_UPGRADE_FRAME_PATH, FORGE_WORKBENCH_PATH]:
		_expect(ResourceLoader.exists(path), "generated building UI component exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		_expect(texture != null, "generated building UI component imports: %s" % path)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(
			image != null and image.get_pixel(0, 0).a < 0.05,
			"generated building UI component keeps transparent corners: %s" % path
		)
	_expect(ResourceLoader.exists(FORGE_BACKDROP_PATH), "forge interior background exists")
	if ResourceLoader.exists(FORGE_BACKDROP_PATH):
		var forge_bg := load(FORGE_BACKDROP_PATH) as Texture2D
		_expect(
			forge_bg != null and forge_bg.get_width() == 1920 and forge_bg.get_height() == 1080,
			"forge interior background imports at the 1080p stage size"
		)

	for path in PRICE_PLAQUE_PATHS:
		_expect(ResourceLoader.exists(path), "concept-matched price plaque exists: %s" % path)
		if ResourceLoader.exists(path):
			var plaque := load(path) as Texture2D
			_expect(plaque != null, "concept-matched price plaque imports: %s" % path)
			if plaque != null:
				var image := plaque.get_image()
				_expect(
					image != null and image.get_pixel(0, 0).a < 0.05,
					"concept-matched price plaque keeps transparent chamfer corners: %s" % path
				)

	for path in BUILDING_STAGE_ART_PATHS:
		_expect(ResourceLoader.exists(path), "building stage art exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var npc := load(path) as Texture2D
		_expect(npc != null, "building stage art imports as a texture: %s" % path)
		if npc == null:
			continue
		var npc_image := npc.get_image()
		_expect(
			npc_image != null
			and npc_image.get_pixel(0, 0).a < 0.05
			and npc_image.get_pixel(npc_image.get_width() - 1, 0).a < 0.05,
			"building stage art keeps clean transparent top corners: %s" % path
		)
		_expect(
			npc.get_width() >= 512 and npc.get_height() >= 384,
			"building stage art keeps enough source resolution for the 1080p stage: %s" % path
		)

	for path in BUILDING_INTERIOR_PATHS:
		_expect(ResourceLoader.exists(path), "regenerated building interior exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var interior := load(path) as Texture2D
		_expect(interior != null, "regenerated building interior imports: %s" % path)
		if interior == null:
			continue
		_expect(
			interior.get_width() == 1920 and interior.get_height() == 1080,
			"regenerated building interior keeps the 1080p 16:9 stage: %s" % path
		)
		var interior_image := interior.get_image()
		_expect(
			interior_image != null and interior_image.get_pixel(0, 0).a > 0.95,
			"regenerated building interior is a complete opaque background: %s" % path
		)

	for path_variant in MARKET_COMPONENT_SIZES:
		var path := str(path_variant)
		_expect(ResourceLoader.exists(path), "exact Market UI component exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var component := load(path) as Texture2D
		_expect(component != null, "exact Market UI component imports: %s" % path)
		if component == null:
			continue
		var expected_size: Vector2i = MARKET_COMPONENT_SIZES[path]
		_expect(
			Vector2i(component.get_width(), component.get_height()) == expected_size,
			"Market UI component keeps its measured concept footprint: %s" % path
		)
		var component_image := component.get_image()
		_expect(
			component_image != null and component_image.get_pixel(0, 0).a < 0.05,
			"Market UI component keeps transparent corners for nine-slice composition: %s" % path
		)


func _test_defeat_returns_to_base() -> void:
	var source := FileAccess.get_file_as_string(RESULT_SCREEN_PATH)
	var copy := FileAccess.get_file_as_string(UI_COMMON_PATH)
	_expect(
		source.contains('const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"'),
		"result screen declares the home-base destination"
	)
	_expect(
		source.contains('back.text = tr("RESULT_BACK_TO_MENU") if is_win else tr("RESULT_BACK_TO_BASE")'),
		"defeat returns to base while demo completion retains Back to Menu copy"
	)
	_expect(
		source.contains('var destination := MAIN_MENU_PATH if mode == "demo_complete" else HOME_BASE_PATH'),
		"result route selects home base only for defeat"
	)
	_expect(source.contains("SceneTransition.change_to(destination)"), "result action uses its selected route")
	_expect(copy.contains("RESULT_BACK_TO_BASE,Back to Base,返回基地"), "Back to Base is translated")


func _test_building_upgrades_spend_scrap() -> void:
	var source := FileAccess.get_file_as_string(META_PROGRESS_PATH)
	_expect(
		source.contains('func building_cost_currency(_id: String) -> String:\n\treturn "scrap"'),
		"all building unlock and tier actions report Scrap"
	)
	var start := source.find("func upgrade_building(id: String) -> bool:")
	var finish := source.find("func building_can", start)
	var body := source.substr(start, finish - start) if start >= 0 and finish > start else ""
	_expect(body.contains("if scrap < cost:"), "building tier upgrade checks Scrap balance")
	_expect(body.contains("scrap -= cost"), "building tier upgrade deducts Scrap")
	_expect(body.contains('emit_signal("scrap_changed", scrap)'), "building tier upgrade emits Scrap change")
	_expect(not body.contains("caps -= cost"), "building tier upgrade never deducts Caps")


func _test_building_upgrade_lives_inside() -> void:
	_expect(
		ResourceLoader.exists(BUILDING_UPGRADE_POPOVER_PATH),
		"shared building upgrade popover exists"
	)
	var popover_source := FileAccess.get_file_as_string(BUILDING_UPGRADE_POPOVER_PATH)
	var base_source := FileAccess.get_file_as_string(BUILDING_SCREEN_BASE_PATH)
	var forge_source := FileAccess.get_file_as_string(FORGE_WINDOW_PATH)
	var home_source := FileAccess.get_file_as_string(HOME_BASE_PATH)
	var home_copy := FileAccess.get_file_as_string(UI_HOME_PATH)
	for marker in [
		'name = "BuildingUpgradePopover"',
		"building_upgrade_popover_frame.png",
		'T.ll_button_dark("normal")',
		"MetaProgress.unlock_building(building_id)",
		"MetaProgress.upgrade_building(building_id)",
	]:
		_expect(
			popover_source.contains(marker),
			"upgrade popover owns the confirmed Scrap upgrade behavior: %s" % marker
		)
	_expect(
		base_source.contains("BUILDING_UPGRADE_POPOVER.new()"),
		"normal building interiors open the shared upgrade popover"
	)
	_expect(
		forge_source.contains("BUILDING_UPGRADE_POPOVER.new()"),
		"forge opens the same shared upgrade popover"
	)
	_expect(
		base_source.contains('name = "BuildingTopBar"')
		and base_source.contains('name = "BuildingUpgradeButton"')
		and base_source.contains('name = "BuildingTopBarCentre"'),
		"normal building interiors use the approved integrated top bar"
	)
	_expect(
		base_source.contains('T.currency_row(MetaProgress.caps, "caps"'),
		"building top bar shows Caps while the popover owns Scrap cost"
	)
	_expect(
		forge_source.contains('name = "ForgeHeader"')
		and forge_source.contains('name = "ForgeUpgradeButton"')
		and forge_source.contains("forge_blacksmith_workbench.png"),
		"forge keeps its distinct top bar and generated workbench illustration"
	)
	_expect(
		home_source.contains('name = "ForgeBackdrop"')
		and home_source.contains('res://run_system/assets/images/buildings/forge_bg.png'),
		"dual forge windows mount the forge interior behind their drag workspace"
	)
	_expect(
		not base_source.contains("BUILDING_TIER_PANEL.new()")
		and not forge_source.contains("BUILDING_TIER_PANEL.new()"),
		"building interiors no longer embed the obsolete full-width tier panel"
	)
	_expect(not home_source.contains("func _show_tier_confirm"), "home overview has no separate upgrade modal")
	_expect(not home_source.contains("func _add_tier_button"), "home overview has no upgrade control")
	_expect(not home_source.contains("BaseUpgradeModal"), "home overview never builds an upgrade window")
	_expect(home_copy.contains("Upgrade T{n} — {c} Scrap,升级 T{n} —— {c} 废料"), "building upgrade copy says Scrap")


func _test_clinic_cap_is_binary() -> void:
	var source := FileAccess.get_file_as_string(CLINIC_SCREEN_PATH)
	var cap_body := _function_body(source, "func _build_cap_card")
	_expect(
		cap_body.contains('tr("UI_CLINIC_CAP_T3_UNLOCK")')
		and cap_body.contains('tr("UI_CLINIC_CAP_UNLOCKED")'),
		"clinic cap card exposes only locked and unlocked states"
	)
	_expect(
		cap_body.contains("HIGH_CAP_LEVEL")
		and not cap_body.contains("_perk_dots(")
		and not cap_body.contains("_cyan_dots("),
		"clinic cap unlock displays fixed cap 5 without a progress-dot track"
	)


func _test_concept_purchase_buttons() -> void:
	var theme_source := FileAccess.get_file_as_string(WASTELAND_THEME_PATH)
	var clinic_source := FileAccess.get_file_as_string(CLINIC_SCREEN_PATH)
	var market_source := FileAccess.get_file_as_string(MARKET_SCREEN_PATH)
	var outpost_source := FileAccess.get_file_as_string(OUTPOST_SCREEN_PATH)
	var popover_source := FileAccess.get_file_as_string(BUILDING_UPGRADE_POPOVER_PATH)

	_expect(
		theme_source.contains("static func centered_currency_button_content(")
		and theme_source.contains('holder.name = "CenteredCurrencyContent"')
		and theme_source.contains('button.set_meta("concept_price_button", true)')
		and theme_source.contains("price_plaque_olive_concept")
		and theme_source.contains("price_plaque_orange_concept"),
		"building price plaques share one centered icon/amount implementation"
	)
	_expect(
		clinic_source.contains("Vector2(146, 60)")
		and clinic_source.contains("Vector2(184, 65)")
		and clinic_source.contains('T.apply_concept_price_button(buy, "orange")')
		and clinic_source.contains(
			'T.centered_currency_button_content(buy, cost, "caps", 23, 29, true, 8)'
		),
		"clinic preserves the concept's separate row and vitals CTA geometry"
	)
	_expect(
		market_source.contains("_price_footer(MARKET_TOOL_PRICE, 175.0, 47.0)")
		and market_source.contains("_price_footer(price, 184.0, 50.0)")
		and market_source.contains('T.apply_concept_price_button(btn, "olive")')
		and market_source.contains(
			'T.centered_currency_button_content(btn, price, "caps", 20, 22, false, 10)'
		),
		"market preserves the concept's measured tool/equipment plaque geometry"
	)
	_expect(
		market_source.contains('name = "MarketMerchantSceneSpacer"')
		and not market_source.contains("MarketMutantVendorArt")
		and not market_source.contains("MARKET_VENDOR_COUNTER_PATH")
		and not market_source.contains("market_vendor_counter_grenade.png"),
		"market bakes its merchant and counter into the background without a duplicate NPC layer"
	)
	var market_pool_body := _function_body(market_source, "func _list_equipment_by_slot")
	_expect(
		market_pool_body.contains('str(data.get("set_id", "")) != ""'),
		"market stock excludes set bases instead of displaying them as ordinary gear"
	)
	for asset_name in [
		"market_shelf_panel_frame.png",
		"market_tool_card_frame.png",
		"market_equip_card_common.png",
		"market_equip_card_uncommon.png",
		"market_equip_card_rare.png",
		"market_exchange_row_frame.png",
	]:
		_expect(
			market_source.contains(asset_name),
			"market source wires the generated exact-match component: %s" % asset_name
		)
	_expect(
		market_source.contains("_market_texture_style("),
		"market applies generated full-card and shelf textures through its texture style helper"
	)
	_expect(
		market_source.contains('tr("UI_MARKET_REFRESH_VERB")')
		and not _function_body(market_source, "func _refresh_button").contains(
			"overlay_cost_badge"
		),
		"market refresh stays a short icon/text control with its cost in the tooltip"
	)
	_expect(
		outpost_source.contains("Vector2(134, 57)")
		and outpost_source.contains("Vector2(157, 63)")
		and outpost_source.contains("Vector2(199, 65)")
		and outpost_source.count('T.apply_concept_price_button(') >= 3,
		"outpost preserves distinct permanent, safe-cell, and bounty CTA geometry"
	)
	_expect(
		not outpost_source.contains("npc_robot_commander")
		and not outpost_source.contains("_build_npc_art_stage("),
		"outpost keeps the accepted NPC-free service composition"
	)
	_expect(
		popover_source.contains('T.ll_button_dark("normal")')
		and popover_source.contains('T.apply_concept_price_button(button, "orange")'),
		"upgrade popover keeps the concept's dark cancel / orange confirm hierarchy"
	)


func _test_home_icon_only_and_bounty_contract() -> void:
	var source := FileAccess.get_file_as_string(HOME_BASE_PATH)
	var bounty_body := _function_body(source, "func _add_bounty_board_panel")
	var building_icon_body := _function_body(source, "func _add_building_icon")
	for marker in [
		'icon_button.name = "BuildingIconOnly_%s" % building_id',
		'row.name = "BountyProgressRow"',
		'pickup_row.name = "BountyPickupHint"',
	]:
		_expect(source.contains(marker), "home overview exposes approved compact surface: %s" % marker)
	for removed in [
		"BuildingNameText",
		"BuildingLevelText",
		"BuildingUpgradeLevelRow",
	]:
		_expect(not source.contains(removed), "home overview removes obsolete element: %s" % removed)
	_expect(
		not building_icon_body.contains('T.lightline_tex("base_medallion")'),
		"floating facility badge has no second medallion ring"
	)
	_expect(
		building_icon_body.contains("StyleBoxEmpty.new()"),
		"floating facility badge uses an invisible click surface"
	)
	_expect(
		building_icon_body.contains("Vector2(84, 84)"),
		"the single facility badge fills the original click target"
	)
	_expect(source.contains(BOUNTY_BOARD_FRAME_PATH), "home loads the exact bounty-board raster component")
	_expect(bounty_body.contains("BOUNTY_BOARD_FRAME"), "bounty-board construction applies the exact raster frame")
	_expect(not source.contains("BountyRefreshCountdown"), "bounty board hides the refresh countdown")
	_expect(not source.contains("BountyRefreshTimer"), "bounty board has no visible-countdown timer")
	_expect(not source.contains("BountyRewardSeal"), "bounty rows omit the three reward seals")
	_expect(not source.contains("BOUNTY_REWARD_SEAL"), "home no longer loads reward-seal art")
	_expect(not source.contains("_daily_refresh_time()"), "home has no dead countdown formatter")
	_expect(_bounty_panel_has_target_size(bounty_body), "bounty board keeps the reference 360x226 footprint")
	_expect(source.contains("新悬赏请进入前哨站领取"), "bounty board keeps the Outpost pickup hint")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _bounty_panel_has_target_size(body: String) -> bool:
	if body.contains("Vector2(360, 226)") or body.contains("Vector2(360.0, 226.0)"):
		return true
	var left := _float_assignment(body, "panel.offset_left")
	var top := _float_assignment(body, "panel.offset_top")
	var right := _float_assignment(body, "panel.offset_right")
	var bottom := _float_assignment(body, "panel.offset_bottom")
	if is_nan(left) or is_nan(top) or is_nan(right) or is_nan(bottom):
		return false
	return absf((right - left) - 360.0) <= 2.0 and absf((bottom - top) - 226.0) <= 2.0


func _float_assignment(source: String, key: String) -> float:
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*%s\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)" % key.replace(".", "\\."))
	var matched := regex.search(source)
	return float(matched.get_string(1)) if matched != null else NAN


func _test_main_menu_uses_native_wide_buttons() -> void:
	var source := FileAccess.get_file_as_string(MAIN_MENU_PATH)
	var save_strip_body := _function_body(source, "func _start_save_info_button")
	_expect(source.contains("button_main_normal_v2.png"), "main menu uses native-wide normal button")
	_expect(source.contains("button_main_selected_v2.png"), "main menu uses native-wide selected button")
	_expect(
		source.contains("save_info_strip_clean.png"),
		"start-screen save strip uses the clean gear-free component"
	)
	_expect(
		save_strip_body.contains("NinePatchRect.new()")
		and save_strip_body.contains('name = "SaveStripBackground"'),
		"save strip preserves its border with a named nine-patch background"
	)
	_expect(
		not save_strip_body.contains("TextureRect.STRETCH_SCALE"),
		"save strip never scales its border artwork out of proportion"
	)
