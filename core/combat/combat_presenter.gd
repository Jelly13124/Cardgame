extends RefCounted

## Everything the combat rules show or wait for (STS2: commands skip animation
## in TestMode). This base class is the null presenter: every call returns at
## once, so a combat runs to its end with no scene, no time and no nodes. The
## battle screen's presenter (ui/battle/battle_presenter.gd) overrides these
## with the real animations and pacing. Rules never wait on anything else.


## A pacing pause (card and tool effects, the enemy turn).
func wait(_seconds: float) -> void:
	pass


func notify(_text: String, _color: Color = Color.WHITE) -> void:
	pass


func sfx(_name: String, _volume_db := 0.0, _pitch := 1.0, _variance := 0.0) -> void:
	pass


## Interface refresh after a rules step (energy, hand playability, intents).
func refresh() -> void:
	pass


func update_polarity() -> void:
	pass


## An equipment set's trigger callout above the player.
func set_callout(_set_id: String, _color: Color) -> void:
	pass


## A creature joined the fight (an enemy of the encounter or a summon).
func creature_added(_creature: Object) -> void:
	pass


## A creature left the field without dying (a dead boss's adds).
func creature_removed(_creature: Object) -> void:
	pass


## The player's gunshot before an attack card's effects hit `target`.
func card_windup(_dealer: Object, _target: Object) -> void:
	pass


## A hit already applied to `target` (`result`: damage_result.gd). Plays the
## hit feedback (awaited unless `tags.source` is a detached kind) and, when the
## hit killed, the death.
func hit(_target: Object, _result: Object, _tags: Dictionary) -> void:
	pass


## Direct HP loss already applied (damage number and flash; death when lethal).
func hp_lost(_creature: Object, _amount: int) -> void:
	pass


## Out-and-back tween on a creature's view (`property`: "scale" or "modulate").
func pulse(_creature: Object, _property: String, _peak: Variant, _rest: Variant, _seconds: float) -> void:
	pass


## An enemy's attack animation (or a short beat when it has none).
func enemy_attack(_enemy: Object) -> void:
	pass


## A play was accepted: the card leaves the hand for the play queue.
func card_play_started(_card: Object) -> void:
	pass


## A play was refused: the card goes back to the hand.
func card_play_refused(_card: Object) -> void:
	pass


## The queued play starts: the card moves to the play position.
func card_resolving(_card: Object) -> void:
	pass


## The played card goes to `pile` ("discard" or "exhaust").
func card_finished(_card: Object, _pile: String) -> void:
	pass


## The combat ended with plays still waiting: those cards go to the discard.
func cards_dropped(_cards: Array) -> void:
	pass


## Piles events from a draw (core/combat/piles.gd): draws and reshuffles.
func cards_drawn(_events: Array) -> void:
	pass


## End of turn: these hand cards go to the discard pile.
func hand_discarded(_cards: Array) -> void:
	pass


## A card created this combat joined `pile`.
func card_created(_card: Object, _pile: String) -> void:
	pass


## Discover: offer `ids`, return the picked id. Headless: the first one.
func discover(ids: Array, _pool: String) -> String:
	return str(ids[0]) if not ids.is_empty() else ""


func combat_ended(_outcome: String) -> void:
	pass
