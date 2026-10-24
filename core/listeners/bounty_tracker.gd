extends "res://core/listeners/listener.gd"

## Bounty objectives as a run listener (STS2 collects stats through hooks, not
## call-site reports): each typed run event advances the objective it counts.
## `progress` is `func(kind: String, amount: int)` (MetaProgress.bounty_progress_add
## in the game; a recorder in tests). The objective list is the validator's.

const OBJECTIVES := [
	"play_attack_cards",
	"earn_gold",
	"kill_elites",
	"kill_boss",
	"extract_alive",
	"upgrade_cards",
	"kill_enemies",
]

var progress: Callable


func after_enemy_killed(_enemy) -> void:
	_add("kill_enemies", 1)


func after_combat_won(node_type: String) -> void:
	match node_type:
		"elite":
			_add("kill_elites", 1)
		"boss":
			_add("kill_boss", 1)


func after_card_played(card_info: Dictionary) -> void:
	if str(card_info.get("type", "")) == "attack":
		_add("play_attack_cards", 1)


func after_gold_earned(amount: int) -> void:
	_add("earn_gold", amount)


func after_card_upgraded(_entry: Dictionary) -> void:
	_add("upgrade_cards", 1)


func after_run_extracted() -> void:
	_add("extract_alive", 1)


func _add(kind: String, amount: int) -> void:
	if progress.is_valid() and amount > 0:
		progress.call(kind, amount)
