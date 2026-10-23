extends RefCounted

## What an effect handler needs to know about the effect it runs.

## "combat" (cards, tools, relics, sets, curses), "enemy" (enemy moves) or "run".
var kind: String = "combat"
var source = null  # combat_source.gd
## The creature using the effect (player for cards/tools/relics, the enemy for moves).
var actor: Object = null
## Chosen target, or null (self / all-enemy / no-target effects).
var target: Object = null
var play = null  # card_play.gd for card plays, else null
## Battle-side services (the battle scene) for combat handlers; null for "run".
var services: Object = null
## Wait the short pacing timers after notifications (card and tool use only).
var pace: bool = false


static func make(
	p_kind: String, p_source, p_actor: Object, p_target: Object, p_services: Object, p_play = null
) -> RefCounted:
	var ctx = new()
	ctx.kind = p_kind
	ctx.source = p_source
	ctx.actor = p_actor
	ctx.target = p_target
	ctx.services = p_services
	ctx.play = p_play
	ctx.pace = p_source != null and p_source.kind in ["card", "tool"]
	return ctx
