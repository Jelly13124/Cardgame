extends Node

func setup(card: Control) -> void:
    # 'one-time' is a passive keyword that routes spells to the discard pile upon casting.
    # The actual behavior is managed directly inside battle_scene.gd's _execute_spell_with_target.
    pass
