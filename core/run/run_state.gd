extends RefCounted

## Everything a run is that outlives a scene (STS2 RunState): hero, health,
## map position, deck, equipment, backpack, relics, tools, progression, the
## RNG streams and the merchants' rolled stock. Plain data: no rules, no
## signals. RunManager (autoload) forwards its fields here; core/save/run_save.gd
## serializes it.

var is_run_active: bool = false
var hero_id: String = ""
var ascension: int = 0
var max_health: int = 50
var current_health: int = 50
var run_scrap: int = 0
var run_caps: int = 0
var current_floor: int = 0
var current_act: int = 1
var deck: Array = []  # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)
var equipped: Dictionary = {
	"head": {},
	"chest": {},
	"weapon": {},
	"hands": {},
	"accessory": {},
}
var backpack: Array = []
var relics: Array[String] = []
var tools: Array[String] = []
var xp: int = 0
var level: int = 1
var pending_attr_points: int = 0
var reward_rerolls: int = 0
var base_attributes: Dictionary = {
	"strength": 0,
	"constitution": 0,
	"intelligence": 0,
	"luck": 0,
	"charm": 0,
}
var player_attributes: Dictionary = {
	"strength": 0,
	"constitution": 0,
	"intelligence": 0,
	"luck": 0,
	"charm": 0,
}
var seen_event_ids: Array[String] = []
var demo_featured_set_id: String = ""
var demo_set_piece_ids_claimed: Array[String] = []
var current_encounter: Array[String] = ["base:trash_robot"]
var last_battle_node_type: String = "enemy"
var map_data: Array = []
var current_node_id: String = ""  ## "" means player hasn't chosen a floor-0 node yet
var visited_node_ids: Array[String] = []
var rng = null
## Merchant stock rolled this run, by map node id (reopening a merchant after a
## reload shows the same stock).
var shop_stock: Dictionary = {}
