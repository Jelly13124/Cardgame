extends Node

## Card text numbers come from the shared pipeline: in battle, a Shoot card
## with 3 Strength, 2 Loaded and Weak reads 4 (floor((3 + 3 + 2) × 0.5)) —
## the same number the targeting preview and the hit use.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd
const CARD_FACTORY = preload("uid://diap3gdfbqvjv")  # res://ui/battle/card_framework_adapters/my_card_factory.tscn
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://core/run/card_upgrade.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const CARD_DESCRIPTION = preload("uid://b4fkwjpel7452")  # res://core/content/card_description.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var previous_locale := TranslationServer.get_locale()
	var previous_hero := RunManager.current_hero_id
	RunManager.current_hero_id = "base:cowboy_bill"
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)  # current_scene must be a child of the root
	var previous_scene := get_tree().current_scene
	get_tree().current_scene = battle
	for _i in range(4):
		await get_tree().process_frame
	battle.player.strength = 3
	battle.player.constitution = 3
	battle.player.creature.add_status("weak", 1)
	battle.player.creature.add_status("loaded", 2)
	battle.player.creature.add_status("frail", 1)
	var attack = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:strike"))
	var block = battle.hand_view.node_of(battle.combat.add_card_to_hand("base:defend"))
	await get_tree().process_frame
	await _check_combat_description(battle, attack, "UI_BATTLE_DESC_DEAL", 4)
	await _check_combat_description(battle, block, "UI_BATTLE_DESC_BLOCK", 6)
	await _check_pile_previews(battle, attack, block)
	await _check_card_fit()
	get_tree().current_scene = previous_scene
	battle.queue_free()
	await get_tree().process_frame
	await _check_preview_descriptions()
	await _check_card_fit()
	TranslationServer.set_locale(previous_locale)
	RunManager.current_hero_id = previous_hero
	if failures.is_empty():
		print("[OK] card text pipeline contract passed")
		get_tree().quit(0)
		return
	push_error("card text pipeline contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _check_combat_description(battle, card, key: String, expected: int) -> void:
	_expect(card != null, "%s card joins the hand" % key)
	if card == null:
		return
	var values := COMBAT_EFFECTS.preview_effect_values(battle.combat, card.instance)
	_expect(int(values.get(0, -1)) == expected, "%s pipeline previews %d (got %s)" % [key, expected, values])
	for locale in ["en", "zh"]:
		TranslationServer.set_locale(locale)
		card.update_display()
		await get_tree().process_frame
		var parsed: String = card.desc_label.get_parsed_text()
		var concise := tr(key).format({"val": expected})
		_expect(parsed.strip_edges() == concise, "%s shows concise %s text (got %s)" % [locale, concise, parsed])
		var bbcode: String = card._build_description(card.card_info)
		_expect(bbcode.contains("[color=#ff4444]%d[/color]" % expected), "%s keeps the negative modifier tint" % key)
		var breakdown: String = card._build_description(card.card_info, true)
		_expect(breakdown.contains("("), "%s still exposes scaling through the debug view" % key)
		_expect(card.generated_shell.visible, "%s uses the Cowboy Bill shell" % key)
		_expect(card.desc_label.get_theme_font_size("normal_font_size") >= 16, "%s uses at least 16 px for short copy" % key)


func _check_card_fit() -> void:
	var factory = CARD_FACTORY.instantiate()
	add_child(factory)
	await get_tree().process_frame
	for locale in ["en", "zh"]:
		TranslationServer.set_locale(locale)
		for card_id in MODEL_DB.ids("card"):
			var card = factory.create_card(card_id, null)
			var data := MODEL_DB.mutable("card", card_id)
			for info in [data, CARD_UPGRADE.resolve(data)]:
				card.set_card_data(info)
				await get_tree().process_frame
				var label: RichTextLabel = card.desc_label
				var fitted := label.get_rect()
				card.update_display()
				var bounds := Rect2(Vector2(8, 8), Vector2(165, 92))
				var key := "%s %s" % [locale, card_id]
				_expect(label.get_content_height() <= label.size.y, "%s text fits after refresh" % key)
				_expect(bounds.encloses(label.get_rect()), "%s stays inside the description opening" % key)
				_expect(label.get_rect().is_equal_approx(fitted), "%s keeps its fitted position on refresh" % key)
				if locale == "zh" and card_id == "base:arc_flash":
					_expect(label.get_line_count() == 2, "Arc Flash keeps its damage phrase together")
					_expect(label.get_theme_font_size("normal_font_size") == 17, "Arc Flash keeps large text")
			card.free()
	factory.queue_free()


func _check_pile_previews(battle, attack, block) -> void:
	for card in [attack, block]:
		battle.ui_manager.show_run_deck_viewer("Preview", [
			{"card_id": card.card_name, "card_info": card.card_info.duplicate(true)},
		])
		await get_tree().process_frame
		var grid := battle.find_child("CardGrid", true, false) as GridContainer
		_expect(grid != null and grid.get_child_count() == 1, "pile preview contains the requested card")
		if grid != null and grid.get_child_count() == 1:
			var preview = grid.get_child(0).get_child(0)
			_expect(preview.desc_label.get_parsed_text() == card.desc_label.get_parsed_text(),
				"pile preview keeps the hand's live combat numbers")
		battle.ui_manager.hide_pile_viewer()
		await get_tree().process_frame

	var upgraded := CARD_UPGRADE.resolve(MODEL_DB.mutable("card", "base:strike"))
	battle.ui_manager.show_run_deck_viewer("Upgrade", [{"card_id": "base:strike", "upgraded": true}])
	await get_tree().process_frame
	var grid := battle.find_child("CardGrid", true, false) as GridContainer
	if grid != null and grid.get_child_count() == 1:
		var preview = grid.get_child(0).get_child(0)
		_expect(preview.card_info.get("effects") == upgraded.get("effects"), "run deck retains upgraded effects")
		_expect(preview.desc_label.get_parsed_text() == _strip_markup(preview._build_description(upgraded)),
			"upgraded preview recomputes its text while attached")
	battle.ui_manager.hide_pile_viewer()
	await get_tree().process_frame


func _strip_markup(text: String) -> String:
	var parser := RichTextLabel.new()
	parser.bbcode_enabled = true
	parser.text = text
	var plain := parser.get_parsed_text()
	parser.free()
	return plain


func _check_preview_descriptions() -> void:
	var factory = CARD_FACTORY.instantiate()
	add_child(factory)
	await get_tree().process_frame
	for locale in ["en", "zh"]:
		TranslationServer.set_locale(locale)
		for spec in [["base:strike", "UI_BATTLE_DESC_DEAL"], ["base:defend", "UI_BATTLE_DESC_BLOCK"]]:
			var card_id: String = spec[0]
			var data := MODEL_DB.mutable("card", card_id)
			var card = factory.create_card(card_id, null)
			for info in [data, CARD_UPGRADE.resolve(data)]:
				card.set_card_data(info)
				await get_tree().process_frame
				var amount := int(info["effects"][0]["amount"])
				var concise := tr(spec[1]).format({"val": amount})
				_expect(card.desc_label.get_parsed_text() == concise, "%s %s preview uses concise text" % [locale, card_id])
				_expect(CARD_DESCRIPTION.build(info) == concise, "%s shared description is concise by default" % card_id)
				_expect(card._build_description(info, true).contains("("), "%s preview can request the diagnostic breakdown" % card_id)
			card.free()
	factory.queue_free()
