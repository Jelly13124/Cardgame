extends Node

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MARKET = preload("uid://brturtmxacges")  # res://core/meta/market.gd
const MAIN_MENU = preload("uid://d211ta0xyw0wr")  # res://ui/menus/main_menu.gd
const BUILDING_UPGRADE_POPOVER = preload("uid://c12ycj00td76a")  # res://ui/base/building_upgrade_popover.gd

const RESULT_SCREEN_PATH := "res://ui/rewards/result_screen.gd"  # path-ok: reads source text
const META_PROGRESS_PATH := "res://autoload/meta_progress.gd"  # path-ok: reads source text
const HOME_BASE_PATH := "res://ui/base/home_base_scene.gd"  # path-ok: reads source text
const BUILDING_SCREEN_BASE_PATH := "res://ui/base/building_screen_base.gd"  # path-ok: reads source text
const CLINIC_SCREEN_PATH := "res://ui/base/clinic_screen.gd"  # path-ok: reads source text
const MARKET_SCREEN_PATH := "res://ui/base/market_screen.gd"  # path-ok: reads source text
const OUTPOST_SCREEN_PATH := "res://ui/base/outpost_screen.gd"  # path-ok: reads source text
const WASTELAND_THEME_PATH := "res://ui/common/theme/wasteland_theme.gd"  # path-ok: reads source text
const BUILDING_UPGRADE_POPOVER_PATH := (
	"res://ui/base/building_upgrade_popover.gd"  # path-ok: reads source text
)
const FORGE_WINDOW_PATH := "res://ui/windows/forge_window.gd"  # path-ok: reads source text
const MAIN_MENU_PATH := "res://ui/menus/main_menu.gd"  # path-ok: reads source text
const UI_COMMON_PATH := "res://assets/translations/ui_common.csv"
const UI_HOME_PATH := "res://assets/translations/ui_home.csv"
const NORMAL_BUTTON_PATH := "res://run_system/assets/images/ui/kit/button_primary_base.png"
const SELECTED_BUTTON_PATH := "res://run_system/assets/images/ui/kit/button_primary_outline.png"
const BOUNTY_BOARD_FRAME_PATH := "res://run_system/assets/images/ui/kit/panel_hard_9slice.png"
const BUILDING_UPGRADE_FRAME_PATH := (
	"res://run_system/assets/images/ui/kit/panel_hard_9slice.png"
)
const PRICE_PLAQUE_PATHS := [
	"res://run_system/assets/images/ui/kit/button_secondary_base.png",
	"res://run_system/assets/images/ui/kit/button_primary_base.png",
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
	"res://run_system/assets/images/ui/kit/panel_hard_9slice.png": Vector2i(96, 96),
	"res://run_system/assets/images/ui/kit/panel_soft_9slice.png": Vector2i(96, 96),
	"res://run_system/assets/images/ui/kit/input_9slice.png": Vector2i(192, 64),
	"res://run_system/assets/images/ui/kit/button_secondary_base.png": Vector2i(320, 96),
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
	_test_main_menu_uses_shared_buttons()
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
		_expect(
			Vector2i(texture.get_width(), texture.get_height()) == Vector2i(320, 96),
			"main-menu buttons use the shared source canvas before nine-slice layout"
		)

	_expect(ResourceLoader.exists(BOUNTY_BOARD_FRAME_PATH), "shared bounty-board panel exists")
	if ResourceLoader.exists(BOUNTY_BOARD_FRAME_PATH):
		var bounty_frame := load(BOUNTY_BOARD_FRAME_PATH) as Texture2D
		_expect(bounty_frame != null, "shared bounty-board panel imports as a texture")
		if bounty_frame != null:
			_expect(
				Vector2i(bounty_frame.get_width(), bounty_frame.get_height()) == Vector2i(96, 96),
				"bounty-board frame uses the shared panel source canvas"
			)

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
		_expect(ResourceLoader.exists(path), "shared base UI component exists: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var component := load(path) as Texture2D
		_expect(component != null, "shared base UI component imports: %s" % path)
		if component == null:
			continue
		var expected_size: Vector2i = MARKET_COMPONENT_SIZES[path]
		_expect(
			Vector2i(component.get_width(), component.get_height()) == expected_size,
			"base UI component keeps the shared source dimensions: %s" % path
		)
		var component_image := component.get_image()
		_expect(
			component_image != null and component_image.get_pixel(0, 0).a < 0.05,
			"base UI component keeps transparent corners for nine-slice composition: %s" % path
		)


func _test_defeat_returns_to_base() -> void:
	var source := FileAccess.get_file_as_string(RESULT_SCREEN_PATH)
	var copy := FileAccess.get_file_as_string(UI_COMMON_PATH)
	_expect(
		source.contains('const HOME_BASE_PATH := "%s"' % ResourceUID.path_to_uid("res://ui/base/home_base_scene.tscn")),  # path-ok: derives the expected uid
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
		'T.kit_box("panel_hard_9slice")',
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
		cap_body.contains("MetaProgress.HIGH_PERK_CAP")
		and not cap_body.contains("_perk_dots(")
		and not cap_body.contains("_cyan_dots("),
		"clinic cap unlock displays fixed cap 5 without a progress-dot track"
	)


func _test_concept_purchase_buttons() -> void:
	var theme_source := FileAccess.get_file_as_string(WASTELAND_THEME_PATH)
	var clinic_source := FileAccess.get_file_as_string(CLINIC_SCREEN_PATH)
	var market_source := FileAccess.get_file_as_string(MARKET_SCREEN_PATH)
	var outpost_source := FileAccess.get_file_as_string(OUTPOST_SCREEN_PATH)

	_expect(
		theme_source.contains("static func centered_currency_button_content(")
		and theme_source.contains('holder.name = "CenteredCurrencyContent"')
		and theme_source.contains('button.set_meta("concept_price_button", true)')
		and theme_source.contains("button_secondary_")
		and theme_source.contains("button_primary_"),
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
		market_source.contains("_price_footer(MARKET.tool_price(), 175.0, 47.0)")
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
	var set_bases_on_shelf: Array = []
	for slot_entries in MARKET.equipment_by_slot().values():
		for entry in slot_entries:
			if str(MODEL_DB.data("equipment", str(entry["id"])).get("set_id", "")) != "":
				set_bases_on_shelf.append(entry["id"])
	_expect(
		set_bases_on_shelf.is_empty(),
		"market stock excludes set bases instead of displaying them as ordinary gear (%s)" % [set_bases_on_shelf]
	)
	_expect(
		market_source.contains('T.kit_box("panel_hard_9slice")')
		and market_source.contains('T.state_box("normal", 0, RARITY_COLORS.get(rarity, Color.WHITE))'),
		"market shelves and offers share the common skin while preserving rarity tint"
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
	var popover := BUILDING_UPGRADE_POPOVER.new()
	for primary in [false, true]:
		var action := Button.new()
		popover.call("_style_action_button", action, primary)
		var visuals := action.get_node_or_null("ActionVisuals") as Control
		var role := "primary" if primary else "secondary"
		_expect(visuals != null and visuals.get("role") == role,
			"upgrade popover preserves the shared %s action hierarchy" % role)
		var face := action.get_node_or_null("ActionVisuals/Face") as NinePatchRect
		_expect(face != null and face.texture != null
			and face.texture.resource_path.ends_with("/button_%s_base.png" % role),
			"upgrade popover resolves %s feedback through the shared layered skin" % role)
		var style := action.get_theme_stylebox("normal")
		var padding := Vector4(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP),
			style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM))
		_expect(padding == (Vector4(14, 8, 14, 9) if primary else Vector4(18, 10, 18, 12)),
			"upgrade popover preserves the %s action's content geometry" % role)
		action.free()
	popover.free()


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
	_expect(
		bounty_body.contains('T.kit_box("panel_hard_9slice")'),
		"bounty-board construction applies the shared hard panel"
	)
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


func _test_main_menu_uses_shared_buttons() -> void:
	var menu := MAIN_MENU.new()
	var action := menu.call("_start_menu_button", "New game", func() -> void: pass) as Button
	_expect(action != null, "main menu constructs a native action button")
	if action != null:
		var visuals := action.get_node_or_null("ActionVisuals") as Control
		_expect(visuals != null and visuals.get("role") == "menu",
			"main menu keeps its actions in the shared text-first menu role")
		_expect(action.text == "New game", "main menu preserves live text above its feedback")
		action.free()
	var save_strip := menu.call("_start_save_info_button") as Button
	_expect(save_strip != null, "save strip remains a native action button")
	if save_strip != null:
		var visuals := save_strip.get_node_or_null("ActionVisuals") as Control
		_expect(visuals != null and visuals.get("role") == "list",
			"save strip uses the shared fixed-layout list surface")
		var face := save_strip.get_node_or_null("ActionVisuals/Face") as NinePatchRect
		_expect(face != null and face.texture != null
			and face.texture.resource_path.ends_with("/button_secondary_base.png"),
			"save strip retains a shared nine-slice backing without distorting its border")
		_expect(save_strip.find_children("*", "Label", true, false).size() == 2,
			"save strip keeps its slot and version information separate from its surface")
		save_strip.free()
	menu.free()
