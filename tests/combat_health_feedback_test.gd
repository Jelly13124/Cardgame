extends Node

const HUD = preload("uid://dqn0nfitycf2d")  # res://ui/battle/character_hud.gd
const STATUS_BADGES = preload("uid://3i0uuprky2dc")  # res://ui/battle/status_badges_view.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_initial_health_does_not_animate()
	_test_bootstrap_snap_discards_fake_damage_and_block_entry()
	_test_snap_cancels_healing_and_break_feedback()
	_test_damage_holds_then_catches_up()
	_test_healing_visibly_fills_over_one_second()
	_test_healing_restarts_from_displayed_hp_and_damage_interrupts()
	_test_max_health_preserves_visible_healing_progress()
	_test_interruptions_keep_the_visible_echo()
	_test_max_health_rebases_the_live_echo()
	_test_block_break_requires_positive_to_zero()
	_test_block_stays_at_its_own_health_bar_left_edge()
	_test_status_stack_counts_and_replacement()
	await _test_many_statuses_stay_within_the_health_width()
	if failures.is_empty():
		print("[OK] combat health feedback")
		get_tree().quit(0)
		return
	push_error("combat health feedback failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _hud_at(hp: int = 100, block: int = 0) -> Control:
	var hud := HUD.new()
	hud.current_health = hp
	hud.current_block = block
	add_child(hud)
	return hud


func _test_initial_health_does_not_animate() -> void:
	var hud := _hud_at(72, 8)
	var loss := hud.get_node_or_null("HpFrame/HpLoss") as TextureProgressBar
	_expect(loss != null, "HP exposes an independent delayed loss layer")
	if loss:
		_expect(is_equal_approx(loss.ratio, 0.72), "initial loss layer starts at real HP")
	_expect(hud.get("_hp_echo_tween") == null, "initial health has no transition")
	_expect(hud.get_node_or_null("BlockBreak") == null or not hud.get_node("BlockBreak").visible,
		"initial positive Block does not break")
	hud.free()


func _test_bootstrap_snap_discards_fake_damage_and_block_entry() -> void:
	var hud := _hud_at()
	hud.update_stats(37, 50, 8)
	_expect(hud.has_method("snap_stats"), "HUD exposes an explicit initial-state synchronization API")
	if not hud.has_method("snap_stats"):
		hud.free()
		return
	var old_echo := hud.get("_hp_echo_tween") as Tween
	var old_entry := hud.get("_block_appear_tween") as Tween
	hud.call("snap_stats", 37, 50, 8)
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var loss := hud.get_node("HpFrame/HpLoss") as TextureProgressBar
	var block := hud.get_node("BlockBadge") as TextureRect
	_expect(is_equal_approx(fill.ratio, 0.74) and is_equal_approx(loss.ratio, 0.74),
		"bootstrap from 100/100 to 37/50 displays real HP without a fake damage tail")
	_expect(hud.get_node("HpFrame/HpLabel").get("text") == "37/50"
		and hud.current_health == 37 and hud.max_health == 50 and hud.current_block == 8,
		"bootstrap synchronizes the real stats and numeric HP")
	_expect(hud.get("_hp_fill_tween") == null and hud.get("_hp_echo_tween") == null
		and hud.get("_block_appear_tween") == null and hud.get("_block_break_tween") == null,
		"bootstrap leaves no health or Block transition running")
	_expect(block.visible and is_equal_approx(block.modulate.a, 1.0)
		and block.position == Vector2(-21, -21) and block.get_node("BlockLabel").text == "8",
		"bootstrap restores the complete shield at its settled position and opacity")
	if old_echo:
		old_echo.custom_step(3.0)
	if old_entry:
		old_entry.custom_step(1.0)
	_expect(is_equal_approx(fill.ratio, 0.74) and is_equal_approx(loss.ratio, 0.74)
		and block.position == Vector2(-21, -21) and is_equal_approx(block.modulate.a, 1.0),
		"cancelled bootstrap feedback cannot overwrite the synchronized visuals")
	hud.update_stats(25, 50, 8)
	_expect(is_equal_approx(fill.ratio, 0.5) and is_equal_approx(loss.ratio, 0.74)
		and hud.get("_hp_echo_tween") != null,
		"real damage after bootstrap still updates red HP and starts its normal delayed tail")
	hud.free()


func _test_snap_cancels_healing_and_break_feedback() -> void:
	var hud := _hud_at(20, 8)
	if not hud.has_method("snap_stats"):
		_expect(false, "mid-feedback initialization can explicitly synchronize HUD state")
		hud.free()
		return
	hud.update_stats(80, 100, 0)
	var healing := hud.get("_hp_fill_tween") as Tween
	healing.pause()
	healing.custom_step(0.15)
	hud.call("snap_stats", 37, 50, 3)
	healing.custom_step(1.0)
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var loss := hud.get_node("HpFrame/HpLoss") as TextureProgressBar
	_expect(is_equal_approx(fill.ratio, 0.74) and is_equal_approx(loss.ratio, 0.74)
		and hud.get("_hp_fill_tween") == null and hud.get("_block_break_tween") == null,
		"snap cancels visible healing and shield fragments without stale callbacks")
	_expect(hud.get_node("BlockBadge").visible and hud.get_node_or_null("BlockBreak") == null,
		"snap displays the restored compact shield without fragment nodes")
	hud.update_stats(45, 50, 3)
	_expect(is_equal_approx(fill.ratio, 0.74) and hud.get("_hp_fill_tween") != null,
		"real healing after synchronization retains its visible one-second transition")
	hud.free()


func _test_damage_holds_then_catches_up() -> void:
	var hud := _hud_at()
	hud.update_stats(60, 100, 0)
	var loss := hud.get_node_or_null("HpFrame/HpLoss") as TextureProgressBar
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var tween := hud.get("_hp_echo_tween") as Tween
	_expect(is_equal_approx(fill.ratio, 0.6), "damage updates current HP immediately")
	_expect(loss != null and tween != null, "damage creates a delayed echo transition")
	if loss and tween:
		tween.pause()
		tween.custom_step(0.99)
		_expect(is_equal_approx(loss.ratio, 1.0), "damage echo holds the old HP for a full second")
		tween.custom_step(0.51)
		_expect(loss.ratio > 0.6 and loss.ratio < 0.625,
			"echo catches up quickly with Expo-Out halfway through its second second")
		tween.custom_step(0.51)
		_expect(is_equal_approx(loss.ratio, 0.6), "echo reaches current HP after two seconds")
	hud.free()


func _test_healing_visibly_fills_over_one_second() -> void:
	var hud := _hud_at(20)
	hud.update_stats(80, 100, 0)
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	_expect(is_equal_approx(fill.ratio, 0.2), "healing leaves the red fill at displayed HP at time zero")
	_expect(hud.get_node("HpFrame/HpLabel").get("text") == "80/100",
		"healing updates the numeric HP immediately")
	var tween := hud.get("_hp_fill_tween") as Tween
	_expect(tween != null, "healing animates the visible red foreground")
	if tween:
		tween.pause()
		tween.custom_step(0.5)
		_expect(fill.ratio > 0.77 and fill.ratio < 0.8,
			"red healing fill is visibly between old and actual HP after half a second")
		tween.custom_step(0.51)
		_expect(is_equal_approx(fill.ratio, 0.8), "red healing fill reaches actual HP after one second")
	hud.free()


func _test_healing_restarts_from_displayed_hp_and_damage_interrupts() -> void:
	var hud := _hud_at(40)
	hud.update_stats(80, 100, 0)
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var tween := hud.get("_hp_fill_tween") as Tween
	if tween == null:
		_expect(false, "healing interruption has a visible foreground tween")
		hud.free()
		return
	tween.pause()
	tween.custom_step(0.15)
	var displayed_hp := fill.ratio
	hud.update_stats(80, 100, 3)
	_expect(is_equal_approx(fill.ratio, displayed_hp) and hud.get("_hp_fill_tween") == tween,
		"a Block-only refresh preserves the visible healing and its clock")
	hud.update_stats(95, 100, 3)
	_expect(is_equal_approx(fill.ratio, displayed_hp), "another heal starts from the currently visible red fill")
	tween = hud.get("_hp_fill_tween") as Tween
	tween.pause()
	tween.custom_step(0.1)
	_expect(fill.ratio > displayed_hp and fill.ratio < 0.95, "another heal continues towards its latest endpoint")
	hud.update_stats(50, 100, 3)
	_expect(is_equal_approx(fill.ratio, 0.5), "damage interrupts healing and sets actual red HP immediately")
	tween.custom_step(2.0)
	_expect(is_equal_approx(fill.ratio, 0.5), "an interrupted heal cannot overwrite the latest damage")
	hud.free()


func _test_max_health_preserves_visible_healing_progress() -> void:
	var hud := _hud_at(40)
	hud.update_stats(80, 100, 0)
	var fill := hud.get_node("HpFrame/HpBar") as TextureProgressBar
	var tween := hud.get("_hp_fill_tween") as Tween
	if tween == null:
		_expect(false, "max-HP reprojection has a visible healing tween")
		hud.free()
		return
	tween.pause()
	tween.custom_step(0.2)
	var displayed_fraction := fill.ratio
	hud.update_stats(80, 200, 0)
	_expect(is_equal_approx(fill.ratio, displayed_fraction * 0.5)
		and hud.get("_hp_fill_tween") == tween,
		"doubling max HP halves the displayed fraction without restarting healing")
	tween.custom_step(0.3)
	_expect(fill.ratio > 0.393 and fill.ratio < 0.395,
		"visible healing keeps its original half-second progress")
	displayed_fraction = fill.ratio
	hud.update_stats(80, 125, 0)
	_expect(is_equal_approx(fill.ratio, displayed_fraction * 1.6),
		"changing max HP from 200 to 125 preserves the displayed absolute HP")
	tween.custom_step(0.51)
	_expect(is_equal_approx(fill.ratio, 0.64), "healing finishes on its original clock using the latest max HP")
	hud.free()


func _test_interruptions_keep_the_visible_echo() -> void:
	var hud := _hud_at()
	hud.update_stats(60, 100, 0)
	var loss := hud.get_node_or_null("HpFrame/HpLoss") as TextureProgressBar
	var tween := hud.get("_hp_echo_tween") as Tween
	if loss == null or tween == null:
		_expect(false, "interrupted damage has a real echo to preserve")
		hud.free()
		return
	tween.pause()
	tween.custom_step(1.15)
	var visible_echo := loss.ratio
	hud.update_stats(40, 100, 0)
	_expect(is_equal_approx(loss.ratio, visible_echo), "a second hit never resets the echo upward")
	tween = hud.get("_hp_echo_tween") as Tween
	tween.pause()
	tween.custom_step(0.8)
	_expect(is_equal_approx(loss.ratio, visible_echo), "a second hit restarts the one-second hold")
	hud.update_stats(65, 100, 0)
	_expect(is_equal_approx(loss.ratio, visible_echo), "healing starts from the visible echo")
	tween = hud.get("_hp_echo_tween") as Tween
	tween.pause()
	tween.custom_step(0.5)
	_expect(absf(loss.ratio - 0.65) < 0.01, "healing starts its one-second Expo-Out without a delay")
	tween.custom_step(0.51)
	_expect(is_equal_approx(loss.ratio, 0.65), "interrupted damage cannot overwrite healing")
	hud.update_stats(80, 100, 0)
	tween = hud.get("_hp_echo_tween") as Tween
	tween.pause()
	tween.custom_step(0.1)
	visible_echo = loss.ratio
	hud.update_stats(50, 100, 0)
	_expect(is_equal_approx(loss.ratio, visible_echo), "damage during healing preserves the displayed echo")
	tween = hud.get("_hp_echo_tween") as Tween
	tween.pause()
	tween.custom_step(2.01)
	_expect(is_equal_approx(loss.ratio, 0.5), "latest damage owns the final echo endpoint")
	hud.free()


func _test_max_health_rebases_the_live_echo() -> void:
	var hud := _hud_at()
	hud.update_stats(60, 100, 0)
	var loss := hud.get_node_or_null("HpFrame/HpLoss") as TextureProgressBar
	var tween := hud.get("_hp_echo_tween") as Tween
	if loss == null or tween == null:
		_expect(false, "max-HP update has a live echo to rebase")
		hud.free()
		return
	tween.pause()
	tween.custom_step(0.6)
	hud.update_stats(60, 200, 0)
	_expect(is_equal_approx(loss.ratio, 0.5), "max-HP growth preserves the absolute pending damage")
	_expect(is_equal_approx(hud.get_node("HpFrame/HpBar").ratio, 0.3),
		"max-HP growth updates the real HP fraction immediately")
	tween.custom_step(1.41)
	_expect(is_equal_approx(loss.ratio, 0.3), "max-HP change leaves no stale ratio endpoint")
	hud.free()


func _test_block_break_requires_positive_to_zero() -> void:
	var hud := _hud_at(80, 0)
	var split := hud.get_node_or_null("BlockBreak") as Control
	_expect(split == null or not split.visible, "compact shield has no decorative split effect at startup")
	hud.update_stats(80, 100, 8)
	_expect(hud.get_node("BlockBadge").visible, "positive Block shows the approved compact shield")
	hud.update_stats(80, 100, 0)
	_expect(not hud.get_node("BlockBadge").visible, "zero Block hides the compact shield")
	_expect(split == null or not split.visible, "zero Block does not show the rejected split shield")
	hud.free()


func _test_block_stays_at_its_own_health_bar_left_edge() -> void:
	var hud := _hud_at(100, 8)
	var shield := hud.get_node("BlockBadge") as Control
	_expect(shield.size == Vector2(42, 49), "Block uses the approved compact 42x49 badge")
	_expect(shield.position == Vector2(-21, -21),
		"Block stays anchored to the left edge of its own health bar")
	hud.free()


func _test_status_stack_counts_and_replacement() -> void:
	var holder := HBoxContainer.new()
	add_child(holder)
	STATUS_BADGES.rebuild(holder, {"burn": 12, "weak": 0, "frail": -1})
	_expect(holder.get_child_count() == 1, "only positive status stacks are visible")
	if holder.get_child_count() == 1:
		var badge := holder.get_child(0) as Control
		var icon := badge.get_node_or_null("Icon") as TextureRect
		var count := badge.get_node_or_null("StackCount") as Label
		_expect(icon != null and count != null, "status icon and count are independent layers")
		if icon and count:
			_expect(icon.size == Vector2(40, 40) and icon.texture.get_size() == Vector2(64, 64),
				"status keeps native 64px art in a readable 40px icon")
			_expect(badge.custom_minimum_size == Vector2(48, 40) and count.text == "12",
				"status badge reserves a count gutter for multi-digit stacks")
			_expect(count.get_theme_font_size("font_size") == 18
				and count.get_theme_constant("outline_size") == 10,
				"status stacks stay legible at 18px with a 10px outline")
	STATUS_BADGES.rebuild(holder, {"weak": 3})
	_expect(holder.get_child_count() == 1, "same-frame refresh replaces badges without stale copies")
	if holder.get_child_count() == 1:
		var count := holder.get_child(0).get_node_or_null("StackCount") as Label
		_expect(count != null and count.text == "3", "replacement status shows its current count")
	holder.free()


func _test_many_statuses_stay_within_the_health_width() -> void:
	var hud := _hud_at()
	var holder := hud.get_node("StatusBadges") as Container
	STATUS_BADGES.rebuild(holder, {
		"burn": 12, "weak": 2, "frail": 2, "vulnerable": 2,
		"bullet": 3, "loaded": 2, "deadeye": 1,
	})
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(holder.size.x <= 250.0, "many active statuses never widen beyond the 250px health bar")
	_expect(holder.get_child_count() == 7, "wrapping retains every active status")
	var has_second_row := false
	for badge in holder.get_children():
		_expect(badge.position.x >= 0.0 and badge.position.x + badge.size.x <= 250.0,
			"each status hitbox stays inside its own creature's health width")
		if badge.position.y >= 40.0:
			has_second_row = true
	_expect(has_second_row, "more than five 48px statuses wrap onto another row")
	hud.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("[FAIL] ", message)
