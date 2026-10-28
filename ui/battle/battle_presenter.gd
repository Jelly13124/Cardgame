extends "res://core/combat/combat_presenter.gd"

## The battle screen's presenter (STS2 Nodes reacting to commands): plays every
## animation and pause the combat rules ask for, on the screen's views. Rules
## state has already changed when these run; nothing here changes it.

const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const GUNSHOT_FX = preload("res://ui/battle/gunshot_fx.gd")

## The battle screen (battle_scene.gd): views, hand view, animator, HUD.
var screen: Node = null


func _init(p_screen: Node) -> void:
	screen = p_screen


func wait(seconds: float) -> void:
	if _alive():
		await screen.get_tree().create_timer(seconds).timeout


func notify(text: String, color: Color = Color.WHITE) -> void:
	if _alive():
		screen.show_notification(text, color)


func sfx(name: String, volume_db := 0.0, pitch := 1.0, variance := 0.0) -> void:
	AudioManager.play_sfx(name, volume_db, pitch, variance)


func refresh() -> void:
	if _alive():
		screen._update_ui_labels()


func update_polarity() -> void:
	if _alive():
		screen.update_polarity_hud()


func set_callout(set_id: String, color: Color) -> void:
	if _alive():
		screen.show_set_callout(set_id, color)


func creature_added(creature: Object) -> void:
	if _alive() and not creature.is_player():
		screen.spawn_enemy_view(creature)


func creature_removed(creature: Object) -> void:
	var view = screen.view_of(creature) if _alive() else null
	if view != null:
		view.queue_free()


func card_windup(dealer: Object, target: Object) -> void:
	var shooter = screen.view_of(dealer) if _alive() else null
	var victim = screen.view_of(target) if _alive() else null
	if shooter == null or victim == null:
		return
	await GUNSHOT_FX.play(screen, shooter, victim)


func hit(target: Object, result: Object, tags: Dictionary) -> void:
	var view = screen.view_of(target) if _alive() else null
	if view == null:
		return
	if str(tags.get("source", "")) in COMBAT_SOURCE.DETACHED_FEEDBACK_KINDS:
		view.play_hit(result, tags)
	else:
		await view.play_hit(result, tags)
	if result.killed and is_instance_valid(view) and view.has_method("play_death"):
		view.play_death()


func hp_lost(creature: Object, amount: int) -> void:
	var view = screen.view_of(creature) if _alive() else null
	if view == null:
		return
	view.play_hp_loss(amount)
	if not creature.is_alive() and view.has_method("play_death"):
		view.play_death()


func pulse(creature: Object, property: String, peak: Variant, rest: Variant, seconds: float) -> void:
	var view = screen.view_of(creature) if _alive() else null
	if view == null or not view.is_inside_tree():
		return
	var tween: Tween = view.create_tween()
	tween.tween_property(view, property, peak, seconds)
	tween.tween_property(view, property, rest, seconds)
	await tween.finished


func enemy_attack(enemy: Object) -> void:
	var view = screen.view_of(enemy) if _alive() else null
	if view == null:
		return
	if view.has_method("play_attack") and view.has_attack_animation():
		view.play_attack()
		await view.attack_animation_finished
		return
	await wait(0.35)


func card_play_started(card: Object) -> void:
	var node = screen.hand_view.node_of(card) if _alive() else null
	if node == null:
		return
	if node.card_container and node.card_container.has_card(node):
		node.card_container.remove_card(node)
	screen.card_animator.prepare_for_play(node)
	screen.card_animator.enqueue_card(node)


func card_play_refused(card: Object) -> void:
	var node = screen.hand_view.node_of(card) if _alive() else null
	if node != null:
		screen.hand.add_card(node)


func card_resolving(card: Object) -> void:
	var node = screen.hand_view.node_of(card) if _alive() else null
	if node != null:
		await screen.card_animator.begin_resolving(node)


func card_finished(card: Object, pile: String) -> void:
	var node = screen.hand_view.node_of(card) if _alive() else null
	if node == null:
		return
	if node.card_container and node.card_container.has_card(node):
		node.card_container.remove_card(node)
	if pile == "exhaust":
		await screen.card_animator.burn_exhaust(node)
		screen.hand_view.forget(card)
		if is_instance_valid(node):
			node.queue_free()
	else:
		await screen.card_animator.fly_to_discard(node)
		if is_instance_valid(node):
			screen.discard_pile.add_card(node)
	if _alive():
		screen._update_ui_labels()


func cards_dropped(cards: Array) -> void:
	if not _alive():
		return
	screen.card_animator.drop_waiting()  # the waiting line empties; each card parks below
	var parks: Array = []
	for card in cards:
		var node = screen.hand_view.node_of(card)
		if node != null:
			parks.append(node)
	for node in parks:
		if node == parks[parks.size() - 1]:
			await screen.park_dropped_card(node)
		else:
			screen.park_dropped_card(node)


func cards_drawn(events: Array) -> void:
	if _alive():
		await screen.hand_view.animate_draw(events)


func hand_discarded(cards: Array) -> void:
	if _alive():
		await screen.hand_view.animate_discard(cards)


func card_created(card: Object, pile: String) -> void:
	if _alive():
		screen.hand_view.create_node(card, pile)


func discover(ids: Array, pool: String) -> String:
	if not _alive():
		return ""
	return await screen.open_discover_modal(ids, pool)


func _alive() -> bool:
	return screen != null and is_instance_valid(screen) and screen.is_inside_tree()
