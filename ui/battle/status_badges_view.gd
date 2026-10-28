extends RefCounted

## Status badges under a creature's health bar (STS2 NPowerContainer): one icon
## per active status with its stack count and a tooltip. Rebuilt from the
## creature's statuses whenever it announces `status_changed`.

const STATUS_EFFECTS = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd
const STATUS_ICON_DIR := "res://battle_scene/assets/images/ui/status/"
const STATUS_ICON_SIZE := 30.0


## Replace the badges in `container` with one per status in `statuses`
## (runtime key -> stacks).
static func rebuild(container: Node, statuses: Dictionary) -> void:
	if container == null or not is_instance_valid(container):
		return
	for child in container.get_children():
		child.queue_free()
	for status_name in statuses:
		var stacks: int = int(statuses[status_name])
		if stacks <= 0:
			continue
		var badge := _make_status_badge(status_name, stacks)
		var tip := _tooltip(status_name, stacks)
		var badge_ref: Control = badge
		var badge_id: int = badge.get_instance_id()
		badge.mouse_entered.connect(
			func():
				if not is_instance_valid(badge_ref):
					return
				Tooltip.show(
					tip, badge_ref.global_position + Vector2(badge_ref.size.x * 0.5, 0), badge_id
				)
		)
		badge.mouse_exited.connect(Tooltip.hide_if_owner.bind(badge_id))
		badge.tree_exited.connect(Tooltip.hide_if_owner.bind(badge_id))
		container.add_child(badge)


static func _tooltip(status_name: String, stacks: int) -> String:
	var human_name: String = STATUS_EFFECTS.format_name_localized(status_name)
	var desc_key := "UI_COMBAT_STATUS_%s_DESC" % str(status_name).to_upper()
	var desc: String = TranslationServer.translate(desc_key)
	if desc == desc_key:
		desc = STATUS_EFFECTS.status_description(status_name)
	if desc != "":
		return TranslationServer.translate("UI_COMBAT_STATUS_TIP").format(
			{"name": human_name, "n": stacks, "desc": desc}
		)
	return TranslationServer.translate("UI_COMBAT_STATUS_TIP_NO_DESC").format(
		{"name": human_name, "n": stacks}
	)


static func _make_status_badge(status_name: String, stacks: int) -> Control:
	var badge = Control.new()
	badge.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	badge.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon_texture := _load_status_icon(status_name)
	if icon_texture:
		var icon = TextureRect.new()
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(icon)
	else:
		var fallback = Label.new()
		fallback.text = STATUS_EFFECTS.status_label(status_name)
		fallback.add_theme_font_size_override("font_size", 18)
		fallback.add_theme_color_override("font_color", STATUS_EFFECTS.status_color(status_name))
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(fallback)

	var stack_label = Label.new()
	stack_label.text = str(stacks)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.add_theme_font_size_override("font_size", 13)
	stack_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	stack_label.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.012, 1.0))
	stack_label.add_theme_constant_override("outline_size", 3)
	stack_label.anchor_left = 0.0
	stack_label.anchor_top = 0.0
	stack_label.anchor_right = 1.0
	stack_label.anchor_bottom = 1.0
	stack_label.offset_left = 0.0
	stack_label.offset_top = 0.0
	stack_label.offset_right = 3.0
	stack_label.offset_bottom = 2.0
	badge.add_child(stack_label)
	return badge


static func _load_status_icon(status_name: String) -> Texture2D:
	var path := "%s%s.png" % [STATUS_ICON_DIR, status_name]
	if not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded is Texture2D:
		return loaded
	return null
