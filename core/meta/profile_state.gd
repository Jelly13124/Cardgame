extends RefCounted

## Everything the player keeps between runs (STS2 ProfileSave / ProgressState):
## currencies, base upgrades and buildings, caps perks, the stash, the base
## backpack and the gear worn into the next run, bounties, the card codex and
## the run history. Plain data: no rules, no signals. MetaProgress (autoload)
## forwards its fields here, and RunManager its base loadout and equipped slots;
## core/save/profile_save.gd serializes it.

var caps: int = 0
var scrap: int = 0
var upgrades: Dictionary = {}
var facilities: Dictionary = {}
var caps_perk_levels: Dictionary = {}
var run_history: Array = []
var max_ascension: int = 0
var stash: Array = []
var buildings: Dictionary = {}
var tutorial_seen: bool = false
var active_bounties: Array = []
var bounty_shelf: Array = []
var bounty_shelf_date: String = ""
var cards_seen: Dictionary = {}
var base_loadout: Array = []
var base_equipped: Dictionary = {}
