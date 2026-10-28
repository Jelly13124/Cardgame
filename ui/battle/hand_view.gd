extends Node

## Shows the combat piles (core/combat/piles.gd) with card-framework nodes: one
## card node per card instance, kept in the Deck / Hand / DiscardPile
## containers, and the draw, reshuffle and discard animations. The piles are
## the truth; this view follows their events, one animation batch at a time.

var screen: Node
var deck: Node
var discard_pile: Node
var hand: Node
var card_factory: Node

var _nodes: Dictionary = {}  # card instance -> card node
var _busy := false
var _queue: Array = []  # [kind, payload]


## Card nodes for every card in the draw pile (hidden in the Deck container).
func build(piles: RefCounted) -> void:
	deck.clear_cards()
	discard_pile.clear_cards()
	for card in piles.draw.cards:
		create_node(card, "draw")
	screen._update_ui_labels()


func node_of(card: Object) -> Node:
	var node = _nodes.get(card)
	return node if node != null and is_instance_valid(node) else null


func forget(card: Object) -> void:
	_nodes.erase(card)


## A node for `card` in the container of `pile` ("hand", "draw", "discard").
func create_node(card: Object, pile: String) -> Node:
	var container: Node = hand if pile == "hand" else (deck if pile == "draw" else discard_pile)
	var node = card_factory.create_card(card.model_id, container)
	if node == null:
		return null
	node.instance = card
	if node.has_method("set_card_data"):
		node.set_card_data(card.card_info)
	_nodes[card] = node
	screen._update_ui_labels()
	return node


## Put a card node that just finished a flight into the container of the pile
## its card is in now.
func land(card: Object, node: Node) -> void:
	if node.card_container and node.card_container.has_card(node):
		return
	match screen.combat.state.piles.where(card):
		"hand":
			hand.add_card(node)
		"draw":
			deck.add_card(node)
		_:
			discard_pile.add_card(node)


## Play a draw's events (core/combat/piles.gd) after any batch still running.
func animate_draw(events: Array) -> void:
	await _run_queued("draw", events)


## End of turn: each discarded hand card flies to the discard pile.
func animate_discard(cards: Array) -> void:
	await _run_queued("discard", cards)


func _run_queued(kind: String, payload: Array) -> void:
	var done := [false]
	_queue.append([kind, payload, done])
	if not _busy:
		_drain()
	while not done[0] and is_inside_tree():
		await get_tree().process_frame


func _drain() -> void:
	_busy = true
	while not _queue.is_empty():
		var item: Array = _queue.pop_front()
		if item[0] == "draw":
			await _play_draw(item[1])
		else:
			await _play_discard(item[1])
		item[2][0] = true
	_busy = false


## Single draws are staggered 0.1 s. A reshuffle flies every discard card back
## to the deck first; the draws after it move in ONE batch so the hand re-fans
## once.
func _play_draw(events: Array) -> void:
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		match str(e["kind"]):
			"draw":
				var node = node_of(e["card"])
				if node != null:
					hand.move_cards([node])
				screen._update_ui_labels()
				if i < events.size() - 1 and events[i + 1]["kind"] == "draw":
					await _wait(0.1)
			"reshuffle":
				await _play_reshuffle(e["cards"])
				var batch: Array = []
				while i + 1 < events.size() and events[i + 1]["kind"] == "draw":
					i += 1
					var n = node_of(events[i]["card"])
					if n != null:
						batch.append(n)
				if not batch.is_empty():
					hand.move_cards(batch)
				screen._update_ui_labels()
			"hand_full":
				screen.show_notification("HAND FULL", Color(1, 0.4, 0.4))
		i += 1


func _play_reshuffle(cards: Array) -> void:
	screen.show_notification("RESHUFFLING", Color(0.4, 0.8, 1.0))
	var nodes: Array = []
	for c in cards:
		var n = node_of(c)
		if n != null:
			nodes.append(n)
	var start_positions: Array = nodes.map(func(n): return n.global_position)
	# Detach from the discard pile so its layout stops fighting the flight.
	for n in nodes:
		if n.card_container and n.card_container.has_card(n):
			n.card_container.remove_card(n)
	const RESHUFFLE_STAGGER := 0.04
	const RESHUFFLE_FLIGHT := 0.34
	for k in range(nodes.size()):
		if is_instance_valid(nodes[k]):
			screen.card_animator.fly_to_deck(nodes[k], start_positions[k])
		if k < nodes.size() - 1:
			await _wait(RESHUFFLE_STAGGER)
	await _wait(RESHUFFLE_FLIGHT)
	for n in nodes:
		if is_instance_valid(n):
			deck.add_card(n)
	screen._update_ui_labels()
	await _wait(0.15)


## Each card flies with a small stagger; the turn moves on once all landed.
func _play_discard(cards: Array) -> void:
	const STAGGER := 0.07
	var landed := [0]
	var flying := 0
	for k in range(cards.size()):
		var node = node_of(cards[k])
		if node == null:
			continue
		# Detach from the hand first so the other cards re-fan around the gap.
		if node.card_container and node.card_container.has_card(node):
			node.card_container.remove_card(node)
		flying += 1
		_discard_after_flight(node, landed)
		if k < cards.size() - 1:
			await _wait(STAGGER)
	while landed[0] < flying and is_inside_tree():
		await get_tree().process_frame


func _discard_after_flight(node: Node, landed: Array) -> void:
	await screen.card_animator.fly_to_discard(node)
	if is_instance_valid(node):
		discard_pile.add_card(node)
	landed[0] += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
