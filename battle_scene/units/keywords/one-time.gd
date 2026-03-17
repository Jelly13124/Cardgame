extends KeywordBase

## "One-Time" is a passive spell keyword.
## When a spell with this keyword is cast it goes to the discard pile instead
## of being shuffled back into the deck.
## The actual routing logic lives in battle_scene.gd > _execute_spell_with_target().
## This class exists so _load_keywords() can find and register it correctly
## (giving the keyword a proper name for future _has_keyword() lookups).

func setup(card_node: UnitCard) -> void:
	super.setup(card_node)
	self.name = "one-time"
