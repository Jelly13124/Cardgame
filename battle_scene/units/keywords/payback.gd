extends KeywordBase

func _init() -> void:
	# Passive marker keyword. Logic is handled directly in battle_scene.gd _perform_attack()
	pass

func setup(card_node: Control) -> void:
	super.setup(card_node)
	self.name = "Payback"
