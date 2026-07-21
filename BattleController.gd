extends Node2D

@onready var player1 = $Players/Player1
@onready var player2 = $Players/Player2
@onready var deck_left = $Decks/CardDeck
@onready var deck_right = $Decks/CardDeck2
@onready var played_cards = $PlayedCards
@onready var turn_label = $UI/Turns
@onready var action_button = $UI/ActionButton
@onready var effect_popup = $UI/Effects
@onready var card_list_p1 = $Decks/CardDeck/CardList
@onready var card_list_p2 = $Decks/CardDeck2/CardList
@onready var win_screen = $WinScreen

enum BattleState {
	WAITING_FOR_CARD,
	RESOLVING,
	WAITING_FOR_RECLAIM,
	BATTLE_OVER,
}

var state = BattleState.WAITING_FOR_CARD
var current_turn: int = 0
var played_cards_list: Array = []
var extra_turn: bool = false

var effects_pool = {
	1:  {"name": "Deal damage x2",                "category": "good", "type": "persistent", "effect_key": "dmg_mult", "value": 2.0},
	2:  {"name": "Deal damage x1.5",               "category": "good", "type": "persistent", "effect_key": "dmg_mult", "value": 1.5},
	3:  {"name": "Deal +10 flat damage",           "category": "good", "type": "persistent", "effect_key": "dmg_flat", "value": 10},
	4:  {"name": "Critical hit (max damage)",      "category": "good", "type": "persistent", "effect_key": "dmg_crit", "value": true},
	5:  {"name": "Deal damage twice",              "category": "good", "type": "persistent", "effect_key": "dmg_twice", "value": true},
	6:  {"name": "Heal 10 HP",                     "category": "good", "type": "instant", "effect_key": "heal_flat", "value": 10},
	7:  {"name": "Heal to full",                   "category": "good", "type": "instant", "effect_key": "heal_full", "value": true},
	8:  {"name": "Increase max HP by 10",          "category": "good", "type": "instant", "effect_key": "max_hp_up", "value": 10},
	9:  {"name": "Heal 5% of missing HP",          "category": "good", "type": "instant", "effect_key": "heal_pct_missing", "value": 0.05},
	10: {"name": "Reclaim 1 card from played",     "category": "good", "type": "special", "effect_key": "reclaim", "value": 1},
	11: {"name": "Duplicate a random card",        "category": "good", "type": "instant", "effect_key": "duplicate_card", "value": true},
	12: {"name": "Return played card to pool",     "category": "good", "type": "instant", "effect_key": "return_played", "value": true},
	13: {"name": "Play 1 more card",               "category": "good", "type": "instant", "effect_key": "extra_turn", "value": true},
	14: {"name": "Enemy skips next turn",          "category": "good", "type": "persistent", "effect_key": "skip_turn", "value": true},
	15: {"name": "Swap pools with opponent",       "category": "good", "type": "instant", "effect_key": "swap_pools", "value": true},
	16: {"name": "Deal damage x0.5",               "category": "bad", "type": "persistent", "effect_key": "dmg_mult", "value": 0.5},
	17: {"name": "Deal damage x0.75",              "category": "bad", "type": "persistent", "effect_key": "dmg_mult", "value": 0.75},
	18: {"name": "Miss your attack entirely",      "category": "bad", "type": "persistent", "effect_key": "dmg_miss", "value": true},
	19: {"name": "Lose 10 HP",                     "category": "bad", "type": "instant", "effect_key": "damage_flat", "value": 10},
	20: {"name": "Lose 20% current HP",             "category": "bad", "type": "instant", "effect_key": "damage_pct_current", "value": 0.2},
	21: {"name": "Cannot heal this turn",          "category": "bad", "type": "persistent", "effect_key": "no_heal", "value": true},
	22: {"name": "Take 10% of max HP as damage",   "category": "bad", "type": "instant", "effect_key": "damage_pct_max", "value": 0.1},
	23: {"name": "Lose 1 card",                    "category": "bad", "type": "instant", "effect_key": "lose_card", "value": 1},
	24: {"name": "Lose 2 cards",                   "category": "bad", "type": "instant", "effect_key": "lose_card", "value": 2},
	25: {"name": "Randomly discard a card",        "category": "bad", "type": "instant", "effect_key": "lose_card", "value": 1},
	26: {"name": "Destroy top card of pool",       "category": "bad", "type": "instant", "effect_key": "destroy_top_card", "value": true},
	27: {"name": "Skip your turn",                 "category": "bad", "type": "persistent", "effect_key": "skip_turn", "value": true},
	28: {"name": "Enemy gets an extra turn",       "category": "bad", "type": "instant", "effect_key": "enemy_extra_turn", "value": true},
	29: {"name": "Reverse who this targets",       "category": "bad", "type": "instant", "effect_key": "reverse_target", "value": true},
	30: {"name": "Copy opponent's last effect",    "category": "bad", "type": "instant", "effect_key": "copy_last_effect", "value": true},
}

func _ready():
	_setup_from_game_manager()
	_start_battle()
 
func _setup_from_game_manager() -> void:
	var p1_prefs = GameManager.prefs_p1
	var p2_prefs = GameManager.prefs_p2
	var items = GameManager.items

	player1.setup(p1_prefs, items, effects_pool)
	player2.setup(p2_prefs, items, effects_pool)
 



func _start_battle() -> void:
	current_turn = 0
	_build_card_lists()
	_update_ui()
	_update_hp_bars()

func get_current_player() -> Player:
	if current_turn == 0:
		return player1
	return player2

func get_opponent() -> Player:
	if current_turn == 0:
		return player2
	return player1

func _build_card_lists() -> void:
	_populate_card_list(card_list_p1, player1)
	_populate_card_list(card_list_p2, player2)

func _populate_card_list(container: VBoxContainer, player: Player) -> void:
	for child in container.get_children():
		child.queue_free()
	for item in player.pool:
		var btn = Button.new()
		btn.text = item.name
		btn.pressed.connect(func(): play_item(item.id))
		container.add_child(btn)

func play_item(item_id: String) -> void:
	if state != BattleState.WAITING_FOR_CARD:
		return

	var attacker = get_current_player()
	var opponent = get_opponent()

	if "skip_turn" in attacker.active_buffs:
		attacker.active_buffs.erase("skip_turn")
		current_turn = (current_turn + 1) % 2
		_build_card_lists()
		_update_ui()
		return

	state = BattleState.RESOLVING

	var pref = opponent.get_preference(item_id)
	var damage_value = _calculate_hp(pref)

	damage_value = _apply_damage_modifiers(attacker, damage_value)

	print("\n==================== TURN LOG ====================")
	print("Attacker: ", attacker.name, "  |  Opponent: ", opponent.name)
	print("Dish played: ", item_id)
	print("Opponent's preference: category=", pref["category"], "  rank=", pref["rank"])
	print("Calculated value: ", damage_value)

	if pref["category"] != "neutral":
		if pref["category"] == "disliked":
			opponent.take_damage(damage_value)
			print("→ Result: dealt ", damage_value, " damage to ", opponent.name)
		elif pref["category"] == "liked":
			if not ("no_heal" in opponent.active_buffs):
				opponent.heal(damage_value)
				print("→ Result: healed ", opponent.name, " for ", damage_value)
			else:
				print("→ Result: heal blocked by 'cannot heal' debuff")
			opponent.active_buffs.erase("no_heal")
		if pref["rank"] < 4:
			var amount = 4 - pref["rank"]
			print("Rank ", pref["rank"], " triggers ", amount, " effect draw(s)")
			var drawn = draw_effect(amount, attacker.player_effect_pool)
			_log_drawn_effects(drawn)
			resolve_effects(drawn, pref["category"], attacker, opponent)
		else:
			print("Rank ", pref["rank"], " — no effects triggered")
	else:
		print("Neutral dish — drawing 1 effect")
		var drawn = draw_effect(1, attacker.player_effect_pool)
		_log_drawn_effects(drawn)
		resolve_effects(drawn, "neutral", attacker, opponent)

	print("HP after resolution — ", attacker.name, ": ", attacker.hp, "  |  ", opponent.name, ": ", opponent.hp)
	print("===================================================\n")

	played_cards_list.append(item_id)
	attacker.remove_from_pool(item_id)

	_update_hp_bars()

	if not opponent.is_alive():
		_end_battle()
		return

	if player1.pool.is_empty() and player2.pool.is_empty():
		_end_battle_by_hp()
		return

	if state != BattleState.WAITING_FOR_RECLAIM:
		state = BattleState.WAITING_FOR_CARD
		if not extra_turn:
			current_turn = (current_turn + 1) % 2
		else:
			extra_turn = false
		_build_card_lists()
		_update_ui()

func _apply_damage_modifiers(attacker: Player, base_damage: int) -> int:
	var result = base_damage

	if "dmg_miss" in attacker.active_buffs:
		attacker.active_buffs.erase("dmg_miss")
		return 0

	if attacker.active_buff_values.has("dmg_mult"):
		result = int(result * attacker.active_buff_values["dmg_mult"])
		attacker.active_buff_values.erase("dmg_mult")
		attacker.active_buffs.erase("dmg_mult")

	if attacker.active_buff_values.has("dmg_flat"):
		result += attacker.active_buff_values["dmg_flat"]
		attacker.active_buff_values.erase("dmg_flat")
		attacker.active_buffs.erase("dmg_flat")

	if "dmg_crit" in attacker.active_buffs:
		result = 35  
		attacker.active_buffs.erase("dmg_crit")

	if "dmg_twice" in attacker.active_buffs:
		result = result * 2
		attacker.active_buffs.erase("dmg_twice")

	return result

func _calculate_hp(pref: Dictionary) -> int:
	var rank = pref["rank"]
	if pref["category"] == "neutral":
		return 0
	if pref["category"] == "disliked":
		return 56 - (6 * rank)
	else:
		return 23 - (3 * rank)

func draw_effect(amount: int, pool: Dictionary) -> Array:
	var drawn = []
	var available_keys = pool.keys()
	available_keys.shuffle()
	var to_draw = min(amount, available_keys.size())
	for i in range(to_draw):
		var key = available_keys[i]
		drawn.append(key)
		pool.erase(key)
	return drawn

func resolve_effects(drawn_effects: Array, card_category: String, attacker: Player, opponent: Player) -> void:
	for effect_id in drawn_effects:
		var effect = effects_pool.get(effect_id)
		if effect == null:
			continue

		var target: Player
		var other: Player
		if card_category == "neutral":
			target = opponent
			other = attacker
		elif card_category == "disliked":
			if effect["category"] == "good":
				target = attacker
				other = opponent
			else:
				target = opponent
				other = attacker
		elif card_category == "liked":
			if effect["category"] == "good":
				target = opponent
				other = attacker
			else:
				target = attacker
				other = opponent

		_apply_effect(effect, target, other, attacker, opponent)

func _log_drawn_effects(drawn: Array) -> void:
	if drawn.is_empty():
		print("No effects drawn (pool may be empty)")
		return
	for effect_id in drawn:
		var effect = effects_pool.get(effect_id)
		if effect:
			print("  Drew: [", effect["category"], "/", effect["type"], "] ", effect["name"])

func _apply_effect(effect: Dictionary, target: Player, other: Player, attacker: Player, opponent: Player) -> void:
	var key = effect["effect_key"]
	var value = effect["value"]

	print("  Resolving '", effect["name"], "' → target: ", target.name)

	match effect["type"]:
		"persistent":
			if not (key in target.active_buffs):
				target.active_buffs.append(key)
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				target.active_buff_values[key] = value
		"instant":
			_apply_instant_effect(key, value, target, other)
		"special":
			_apply_special_effect(key, value, attacker)

func _apply_instant_effect(key: String, value, target: Player, other: Player) -> void:
	match key:
		"heal_flat":
			target.heal(value)
		"heal_full":
			target.heal(target.max_hp)
		"max_hp_up":
			target.max_hp = min(target.max_hp + value, 150)
			target.hp = min(target.hp + value, target.max_hp)
		"heal_full":
			target.heal(target.max_hp)
		"heal_pct_missing":
			var missing = target.max_hp - target.hp
			target.heal(int(missing * value))
		"duplicate_card":
			if target.pool.size() > 0:
				var random_item = target.pool[randi() % target.pool.size()]
				target.pool.append(Item.new(random_item.id, random_item.name))
		"return_played":
			if not played_cards_list.is_empty():
				var last_id = played_cards_list[played_cards_list.size() - 1]
				played_cards_list.remove_at(played_cards_list.size() - 1)
				target.pool.append(Item.new(last_id, last_id))
		"extra_turn":
			extra_turn = true
		"swap_pools":
			var temp = player1.pool
			player1.pool = player2.pool
			player2.pool = temp
		"damage_flat":
			target.take_damage(value)
		"damage_pct_current":
			target.take_damage(int(target.hp * value))
		"damage_pct_max":
			target.take_damage(int(target.max_hp * value))
		"lose_card":
			for i in range(value):
				if target.pool.size() > 0:
					var idx = randi() % target.pool.size()
					target.pool.remove_at(idx)
		"destroy_top_card":
			if target.pool.size() > 0:
				target.pool.remove_at(0)
		"enemy_extra_turn":
			extra_turn = false
		"reverse_target":
			var tmp_buffs = target.active_buffs
			target.active_buffs = other.active_buffs
			other.active_buffs = tmp_buffs
		"copy_last_effect":
			pass 

func _apply_special_effect(key: String, value, attacker: Player) -> void:
	match key:
		"reclaim":
			pass  

func reclaim_card(item_id: String) -> void:
	if state != BattleState.WAITING_FOR_RECLAIM:
		return
	var attacker = get_current_player()
	if item_id in played_cards_list:
		played_cards_list.erase(item_id)
		attacker.pool.append(Item.new(item_id, item_id))
	state = BattleState.WAITING_FOR_CARD
	if not extra_turn:
		current_turn = (current_turn + 1) % 2
	else:
		extra_turn = false
	_build_card_lists()
	_update_ui()

func _end_battle() -> void:
	state = BattleState.BATTLE_OVER
	var winner = "Player 1" if player2.hp <= 0 else "Player 2"
	action_button.disabled = true
	win_screen.show_result(winner, "reached 0 HP", player1.hp, player2.hp)

func _end_battle_by_hp() -> void:
	state = BattleState.BATTLE_OVER
	var winner: String
	if player1.hp > player2.hp:
		winner = "Player 1"
	elif player2.hp > player1.hp:
		winner = "Player 2"
	else:
		winner = "Draw"
	action_button.disabled = true
	win_screen.show_result(winner, "pools exhausted, higher HP", player1.hp, player2.hp)
	
func _update_ui() -> void:
	if current_turn == 0:
		turn_label.text = "Player 1's Turn"
		_set_cards_interactable(card_list_p1, true)
		_set_cards_interactable(card_list_p2, false)
	else:
		turn_label.text = "Player 2's Turn"
		_set_cards_interactable(card_list_p1, false)
		_set_cards_interactable(card_list_p2, true)

func _set_cards_interactable(container: VBoxContainer, enabled: bool) -> void:
	for child in container.get_children():
		if child is Button:
			child.disabled = !enabled

func _update_hp_bars() -> void:
	$Players/Player1/HP.value = player1.hp
	$Players/Player2/HP.value = player2.hp
