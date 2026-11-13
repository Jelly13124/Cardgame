extends Node

## The battle hand uses STS2's layout (ui/battle/sts2_hand.gd, from
## HandPosHelper / NPlayerHand.RefreshLayout): per-size positions and angles
## in STS2 pixels; our 208 px card is drawn at STS2's 300 px width, so it rests
## at 0.8 of that and the hovered card shows at full STS2 size, angle 0
## showing fully, neighbours pushed aside, held cards left alone.

const STS2_HAND = preload("uid://bys4oyehlumcn")  # res://ui/battle/sts2_hand.gd
## Our card face drawn at STS2's card width.
const FACE := 300.0 / 208.0

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var s0: Dictionary = STS2_HAND.slot(5, 0)
	_expect(s0.position.is_equal_approx(Vector2(-340, 10)) and is_equal_approx(s0.angle_deg, -8.0) and is_equal_approx(s0.scale, 0.8 * FACE), "slot(5, 0) is STS2's (%s)" % [s0])
	var s1: Dictionary = STS2_HAND.slot(3, 1)
	_expect(s1.position.is_equal_approx(Vector2(0, -59)) and is_equal_approx(s1.angle_deg, 0.0), "slot(3, 1) is STS2's (%s)" % [s1])
	_expect(is_equal_approx(STS2_HAND.slot(10, 9).scale, 0.68 * FACE), "ten cards rest at 0.68 (%s)" % [STS2_HAND.slot(10, 9)])

	RunManager.start_new_run("base:cowboy_bill", [], 0, "HANDLAYOUT1")
	var battle = load("uid://dnhj5pp3c1v2l").instantiate()  # res://ui/battle/battle_screen.tscn
	add_child(battle)
	for i in 90:
		await get_tree().process_frame
	var hand = battle.find_child("Hand", true, false)
	_expect(hand != null and hand.has_method("set_hovered"), "the battle hand is the STS2 hand")
	var cards: Array = hand._held_cards
	_expect(cards.size() == 5, "the opening hand holds 5 cards (%d)" % cards.size())
	if cards.size() == 5:
		var anchor: Vector2 = hand.anchor_point()
		for i in 5:
			var t: Dictionary = hand.target_of(cards[i])
			var want: Dictionary = STS2_HAND.slot(5, i)
			_expect(t.center.is_equal_approx(anchor + want.position) and is_equal_approx(t.angle_deg, want.angle_deg) and is_equal_approx(t.scale, 0.8 * FACE), "card %d targets STS2's slot (%s vs %s)" % [i, t, want])
		hand.set_hovered(cards[2])
		var hovered: Dictionary = hand.target_of(cards[2])
		_expect(is_equal_approx(hovered.scale, FACE) and is_equal_approx(hovered.angle_deg, 0.0), "the hovered card is full size and straight")
		_expect(is_equal_approx(hovered.center.y, anchor.y - 286.0 * FACE / 2.0 + 2.0), "the hovered card shows fully (y %.1f)" % hovered.center.y)
		var pushed: float = (anchor + STS2_HAND.slot(5, 1).position).x - lerpf(100.0, 0.0, 0.25)
		_expect(is_equal_approx(hand.target_of(cards[1]).center.x, pushed), "the left neighbour makes way (%.1f vs %.1f)" % [hand.target_of(cards[1]).center.x, pushed])
		# held card keeps its drag position
		cards[0].current_state = cards[0].DraggableState.HOLDING
		var held_at: Vector2 = cards[0].global_position
		hand.update_card_ui()
		_expect(cards[0].global_position == held_at, "a held card is not pulled back by a relayout")
		cards[0].current_state = cards[0].DraggableState.IDLE
		# hover clears when the card leaves
		hand.remove_card(cards[2])
		var rest: Array = hand._held_cards
		for i in rest.size():
			_expect(hand.target_of(rest[i]).center.is_equal_approx(anchor + STS2_HAND.slot(4, i).position), "after the hovered card leaves, card %d uses the 4-card slot" % i)
		# A relayout while a card is hovered moves its return spot (drop on
		# nothing) to its new rest slot.
		var kept = rest[1]
		hand.set_hovered(kept)
		hand.remove_card(rest[3])
		var rest_top_left: Vector2 = anchor + STS2_HAND.slot(3, 1).position - kept.size * 0.5
		_expect(kept.original_destination.is_equal_approx(rest_top_left), "a hovered card returns to its new rest slot (%s vs %s)" % [kept.original_destination, rest_top_left])
	battle.queue_free()
	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] sts2 hand layout passed")
		get_tree().quit(0)
		return
	push_error("sts2 hand layout failed: %s" % "; ".join(failures))
	get_tree().quit(1)
