extends Node2D

@onready var player1: Player = $Players/Player1
@onready var player2: Player = $Players/Player2
@onready var played_cards = $PlayedCards
@onready var turn_label = $UI/Turns
@onready var effect_popup = $UI/Effects
@onready var card_list_p1 = $Decks/CardDeck/Scroll/CardList
@onready var card_list_p2 = $Decks/CardDeck2/Scroll/CardList
@onready var win_screen = $WinScreen
@onready var hp_bar_p1 = $Players/Player1/HP
@onready var hp_bar_p2 = $Players/Player2/HP
@onready var reclaim_panel = $UI/ReclaimPanel
@onready var reclaim_list = $UI/ReclaimPanel/VBox/Scroll/Choices

enum BattleState { WAITING_FOR_CARD, RESOLVING, WAITING_FOR_RECLAIM, BATTLE_OVER }
var state = BattleState.WAITING_FOR_CARD
var current_turn: int = 0
var played_cards_list: Array = []
var animation_duration: float = 0.65
var _hp_tweens: Dictionary = {}
var _float_counts: Dictionary = {}
var _reclaim_targets: Array[Player] = []
var _messages: Array[String] = []
var _played_discard_index: int = -1
var _heal_block_at_start: bool = false
var _last_played_name: String = "Test effect"
var selected_item: String = ""
var _portraits: Array[AvatarPortrait] = []
var _play_button: Button
var _pool_label: Label
var _history_panel: PanelContainer
var _history_text: RichTextLabel
var _settings_panel: PanelContainer

var available_effects: Dictionary = {}
var used_effect_ids: Dictionary = {}
var effect_history: Array[Dictionary] = []

var effects_pool = {
	1:  {"name": "Next damage x2",                "category": "good", "type": "persistent", "effect_key": "dmg_mult", "value": 2.0},
	2:  {"name": "Next damage x1.25",               "category": "good", "type": "persistent", "effect_key": "dmg_mult", "value": 1.25},
	3:  {"name": "Next damage +6",           "category": "good", "type": "persistent", "effect_key": "dmg_flat", "value": 6},
	4:  {"name": "Next base damage becomes 30",      "category": "good", "type": "persistent", "effect_key": "dmg_crit", "value": true},
	5:  {"name": "Next damage +50%",              "category": "good", "type": "persistent", "effect_key": "dmg_twice", "value": true},
	6:  {"name": "Heal 8 HP",                     "category": "good", "type": "instant", "effect_key": "heal_flat", "value": 8},
	7:  {"name": "Heal 16 HP",                   "category": "good", "type": "instant", "effect_key": "heal_flat", "value": 16},
	8:  {"name": "Increase max HP by 6",          "category": "good", "type": "instant", "effect_key": "max_hp_up", "value": 6},
	9:  {"name": "Heal 15% of missing HP",          "category": "good", "type": "instant", "effect_key": "heal_pct_missing", "value": 0.15},
	10: {"name": "Reclaim 1 card from played",     "category": "good", "type": "special", "effect_key": "reclaim", "value": 1},
	11: {"name": "Duplicate a random card",        "category": "good", "type": "instant", "effect_key": "duplicate_card", "value": true},
	12: {"name": "Return played card to pool",     "category": "good", "type": "instant", "effect_key": "return_played", "value": true},
	13: {"name": "Play 1 more card",               "category": "good", "type": "instant", "effect_key": "extra_turn", "value": true},
	14: {"name": "Enemy skips next turn",          "category": "good", "type": "persistent", "effect_key": "enemy_skip_turn", "value": true},
	15: {"name": "Swap pools with opponent",       "category": "good", "type": "instant", "effect_key": "swap_pools", "value": true},
	16: {"name": "Deal damage x0.5",               "category": "bad", "type": "persistent", "effect_key": "dmg_mult", "value": 0.5},
	17: {"name": "Deal damage x0.75",              "category": "bad", "type": "persistent", "effect_key": "dmg_mult", "value": 0.75},
	18: {"name": "Miss your attack entirely",      "category": "bad", "type": "persistent", "effect_key": "dmg_miss", "value": true},
	19: {"name": "Lose 10 HP",                     "category": "bad", "type": "instant", "effect_key": "damage_flat", "value": 10},
	20: {"name": "Lose 20% current HP",             "category": "bad", "type": "instant", "effect_key": "damage_pct_current", "value": 0.2},
	21: {"name": "Cannot heal until your turn ends",          "category": "bad", "type": "persistent", "effect_key": "no_heal", "value": true},
	22: {"name": "Take 10% of max HP as damage",   "category": "bad", "type": "instant", "effect_key": "damage_pct_max", "value": 0.1},
	23: {"name": "Lose 1 card",                    "category": "bad", "type": "instant", "effect_key": "lose_card", "value": 1},
	24: {"name": "Lose 2 cards",                   "category": "bad", "type": "instant", "effect_key": "lose_card", "value": 2},
	25: {"name": "Next damage -4",                "category": "bad", "type": "persistent", "effect_key": "dmg_flat", "value": -4},
	26: {"name": "Destroy top card of pool",       "category": "bad", "type": "instant", "effect_key": "destroy_top_card", "value": true},
	27: {"name": "Skip your turn",                 "category": "bad", "type": "persistent", "effect_key": "skip_turn", "value": true},
	28: {"name": "Enemy gets an extra turn",       "category": "bad", "type": "instant", "effect_key": "enemy_extra_turn", "value": true},
	29: {"name": "Reverse next effect target",       "category": "bad", "type": "instant", "effect_key": "reverse_target", "value": true},
	30: {"name": "Lose 6 maximum HP",             "category": "bad", "type": "instant", "effect_key": "max_hp_down", "value": 6},
}

func _ready() -> void:
	_style_battle()
	player1.health_changed.connect(_health_feedback.bind(player1))
	player2.health_changed.connect(_health_feedback.bind(player2))
	$UI/ReclaimPanel/VBox/Skip.pressed.connect(_skip_reclaim)
	_reset_effect_pool()
	_setup_from_game_manager()
	_build_card_lists()
	_update_hp_bars()
	_update_ui()

func _setup_from_game_manager() -> void:
	var p1_prefs = GameManager.prefs_p1
	var p2_prefs = GameManager.prefs_p2
	var items = GameManager.items
	if p1_prefs.is_empty() or p2_prefs.is_empty():
		_setup_preview_data()
		return
	player1.setup(p1_prefs, items)
	player2.setup(p2_prefs, items)

func _setup_preview_data() -> void:
	_reset_effect_pool()
	# Running the battle scene directly uses the current catalog, regardless of theme.
	for player in [player1, player2]:
		var cards = GameManager.items.duplicate()
		cards.shuffle()
		var preferences = {}
		for i in range(cards.size()):
			var category = ["disliked", "neutral", "liked"][mini(int(i / 7), 2)]
			preferences[cards[i].id] = {"category": category, "rank": 0 if category == "neutral" else i % 7 + 1}
		player.setup(preferences, GameManager.items)

func get_current_player() -> Player:
	return player1 if current_turn == 0 else player2

func get_opponent() -> Player:
	return player2 if current_turn == 0 else player1

func _player_name(player: Player) -> String:
	return GameManager.player_name(0 if player == player1 else 1)

func _build_card_lists() -> void:
	_populate_card_list(card_list_p1, player1)
	_populate_card_list(card_list_p2, player2)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _populate_card_list(container: VBoxContainer, player: Player) -> void:
	_clear_children(container)
	for item in player.pool:
		var row = HBoxContainer.new()
		row.theme = GameStyle.theme()
		var icon = TextureRect.new()
		icon.material = GameStyle.art_material()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = GameManager.get_texture(item.id)
		if icon.texture == null:
			var fallback = Label.new()
			fallback.text = item.icon
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback.custom_minimum_size = Vector2(40, 40)
			fallback.add_theme_font_size_override("font_size", 27)
			row.add_child(fallback)
		else:
			row.add_child(icon)
		var button = Button.new()
		button.theme = GameStyle.theme()
		button.text = item.name
		button.tooltip_text = item.name + "\nSelect to preview, then play against your rival's secret ranking."
		button.toggle_mode = true
		button.button_pressed = selected_item == item.id and get_current_player() == player
		button.mouse_entered.connect(func(): row.modulate = Color(1.12, 1.12, 1.12))
		button.mouse_exited.connect(func(): row.modulate = Color.WHITE)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Bind the owner too: a stale button must never play for the other player.
		button.pressed.connect(func():
			if get_current_player() == player:
				select_item(item.id)
		)
		row.add_child(button)
		container.add_child(row)

func _set_cards_interactable(container: VBoxContainer, enabled: bool) -> void:
	for row in container.get_children():
		row.get_child(1).disabled = not enabled

func play_item(item_id: String) -> void:
	if state != BattleState.WAITING_FOR_CARD:
		return
	if _settings_panel and (_settings_panel.visible or _history_panel.visible):
		return
	var attacker = get_current_player()
	var opponent = get_opponent()
	if not attacker.has_item(item_id):
		return
	state = BattleState.RESOLVING
	selected_item = ""
	if not _portraits.is_empty():
		_portraits[current_turn].react("select")
	_messages.clear()
	_last_played_name = GameManager.get_item_name(item_id)
	_heal_block_at_start = "no_heal" in attacker.active_buffs
	# Commit the card before effects mutate, swap, or return cards to either pool.
	attacker.remove_from_pool(item_id)
	played_cards_list.append(item_id)
	_played_discard_index = played_cards_list.size() - 1
	_update_ui()
	_animate_card_to_table(item_id)
	if animation_duration > 0 and not GameManager.reduce_motion:
		await get_tree().create_timer(animation_duration * 0.55).timeout
	var pref = opponent.get_preference(item_id)
	_float_counts.clear()
	_messages.append("%s / %s #%d" % [GameManager.get_item_name(item_id), pref.category.to_upper(), pref.rank])
	var hp_amount = _calculate_hp(pref)
	if pref.category == "disliked":
		var base_damage = hp_amount
		hp_amount = _apply_damage_modifiers(attacker, hp_amount)
		opponent.take_damage(hp_amount)
		_messages.append("%s attacks %s: %d damage%s" % [_player_name(attacker), _player_name(opponent), hp_amount, " (base %d)" % base_damage if hp_amount != base_damage else ""])
	elif pref.category == "liked":
		var before = opponent.hp
		opponent.heal(hp_amount)
		_messages.append("%s: +%d HP%s" % [_player_name(opponent), opponent.hp - before, " (healing blocked)" if "no_heal" in opponent.active_buffs else ""])
	else:
		_messages.append("Neutral card: no HP change")
	# A knockout takes effect immediately; later effects cannot revive a player.
	if attacker.is_alive() and opponent.is_alive():
		var amount = _effect_count(pref)
		resolve_effects(draw_effect(amount), pref.category, attacker, opponent)
	_update_hp_bars()
	_update_ui()
	effect_popup.text = "\n".join(_messages)
	effect_popup.tooltip_text = effect_popup.text
	if animation_duration > 0:
		await get_tree().create_timer(animation_duration if GameManager.reduce_motion else animation_duration * 0.45).timeout
	if _check_knockout():
		return
	_continue_resolution()

func select_item(item_id: String) -> void:
	if state != BattleState.WAITING_FOR_CARD or not get_current_player().has_item(item_id):
		return
	if _settings_panel and (_settings_panel.visible or _history_panel.visible):
		return
	selected_item = item_id
	var duration = animation_duration
	animation_duration = 0
	_animate_card_to_table(item_id)
	animation_duration = duration
	effect_popup.text = "Selected: %s\nIts power depends on %s's secret ranking." % [GameManager.get_item_name(item_id), _player_name(get_opponent())]
	_build_card_lists()
	_update_ui()
	GameManager.play_sound("select")
	if _play_button:
		_play_button.grab_focus()

func _continue_resolution() -> void:
	while not _reclaim_targets.is_empty():
		if played_cards_list.is_empty():
			_reclaim_targets.pop_front()
		else:
			_show_reclaim_choices()
			return
	reclaim_panel.hide()
	_finish_turn()

func _finish_turn() -> void:
	if _heal_block_at_start:
		get_current_player().active_buffs.erase("no_heal")
	if _check_knockout():
		return
	if player1.pool.is_empty() and player2.pool.is_empty():
		_end_battle_by_hp()
		return
	_advance_turn()
	# Consume skipped turns automatically, including when the other pool is empty.
	while true:
		var player = get_current_player()
		if player.pool.is_empty():
			player.bonus_turns = 0
			player.active_buffs.erase("no_heal")
			player.active_buffs.erase("skip_turn")
			current_turn = 1 - current_turn
		elif "skip_turn" in player.active_buffs:
			player.active_buffs.erase("skip_turn")
			player.active_buffs.erase("no_heal")
			_advance_turn()
		else:
			break
	state = BattleState.WAITING_FOR_CARD
	_build_card_lists()
	_update_ui()

func _advance_turn() -> void:
	var player = get_current_player()
	if player.bonus_turns > 0 and not player.pool.is_empty():
		player.bonus_turns -= 1
	else:
		current_turn = 1 - current_turn

func _calculate_hp(pref: Dictionary) -> int:
	return CardBalance.hp(pref.category, int(pref.rank))

func _effect_count(pref: Dictionary) -> int:
	return CardBalance.effects(pref.category, int(pref.rank))

func _apply_damage_modifiers(attacker: Player, base_damage: int) -> int:
	var result = CardBalance.DAMAGE[0] if "dmg_crit" in attacker.active_buffs else base_damage
	result = int(result * attacker.active_buff_values.get("dmg_mult", 1.0))
	result += int(attacker.active_buff_values.get("dmg_flat", 0))
	if "dmg_twice" in attacker.active_buffs:
		result = int(result * 1.5)
	if "dmg_miss" in attacker.active_buffs:
		result = 0
	for key in ["dmg_crit", "dmg_mult", "dmg_flat", "dmg_twice", "dmg_miss"]:
		attacker.active_buffs.erase(key)
		attacker.active_buff_values.erase(key)
	return clampi(result, 0, CardBalance.MAX_HIT)

func _reset_effect_pool() -> void:
	available_effects = effects_pool.duplicate(true)
	used_effect_ids.clear()
	effect_history.clear()

func draw_effect(amount: int) -> Array:
	var available = available_effects.keys().filter(func(id): return not used_effect_ids.has(id))
	available.shuffle()
	var drawn = available.slice(0, mini(amount, available.size()))
	for key in drawn:
		available_effects.erase(key)
	return drawn

func resolve_effects(drawn_effects: Array, card_category: String, attacker: Player, opponent: Player) -> void:
	for effect_id in drawn_effects:
		if not attacker.is_alive() or not opponent.is_alive():
			break
		var effect: Dictionary = effects_pool.get(effect_id, {})
		if effect.is_empty() or used_effect_ids.has(effect_id):
			continue
		var target = _effect_recipient(card_category, effect.category, attacker, opponent)
		var other = opponent if target == attacker else attacker
		available_effects.erase(effect_id)
		used_effect_ids[effect_id] = true
		var recipient = _apply_effect(effect, target, other)
		effect_history.append({"id": effect_id, "card": _last_played_name, "recipient": _player_name(recipient), "effect": effect.name})
		if animation_duration > 0 and not _portraits.is_empty():
			_portraits[0 if recipient == player1 else 1].react("effect")

func _effect_recipient(card_category: String, effect_category: String, attacker: Player, opponent: Player) -> Player:
	# The recipient owns the modifier. Only their future outgoing attack consumes it.
	if card_category == "disliked":
		return attacker if effect_category == "good" else opponent
	if card_category == "liked":
		return opponent if effect_category == "good" else attacker
	return opponent

func _apply_effect(effect: Dictionary, target: Player, other: Player) -> Player:
	# Reflect once, avoiding ping-pong if both players hold a reversal.
	if target.reverse_next_effect:
		target.reverse_next_effect = false
		var original = target
		target = other
		other = original
	target.last_effect = effect.duplicate(true)
	_messages.append("%s: %s" % [_player_name(target), effect.name])
	var key: String = effect.effect_key
	var value = effect.value
	match effect.type:
		"persistent":
			var recipient = other if key == "enemy_skip_turn" else target
			var buff_key = "skip_turn" if key == "enemy_skip_turn" else key
			if buff_key not in recipient.active_buffs:
				recipient.active_buffs.append(buff_key)
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				recipient.active_buff_values[buff_key] = value
		"instant":
			_apply_instant_effect(key, value, target, other)
		"special":
			if key == "reclaim":
				for i in range(int(value)):
					_reclaim_targets.append(target)
	return target

func _apply_instant_effect(key: String, value, target: Player, other: Player) -> void:
	match key:
		"max_hp_down":
			target.max_hp = maxi(1, target.max_hp - int(value))
			target.take_damage(maxi(0, target.hp - target.max_hp))
		"heal_flat":
			target.heal(value)
		"heal_full":
			target.heal(target.max_hp)
		"max_hp_up":
			var increase = mini(int(value), 150 - target.max_hp)
			target.max_hp += increase
			target.heal(increase)
		"heal_pct_missing":
			target.heal(int((target.max_hp - target.hp) * value))
		"duplicate_card":
			if not target.pool.is_empty():
				target.pool.append(target.pool.pick_random())
		"return_played":
			# Track this exact discarded copy, even if other copies share its ID.
			if _played_discard_index >= 0:
				_return_card_at(_played_discard_index, target)
		"extra_turn":
			target.bonus_turns += 1
		"enemy_extra_turn":
			other.bonus_turns += 1
		"swap_pools":
			var temp = target.pool
			target.pool = other.pool
			other.pool = temp
		"damage_flat":
			target.take_damage(value)
		"damage_pct_current":
			target.take_damage(int(target.hp * value))
		"damage_pct_max":
			target.take_damage(int(target.max_hp * value))
		"lose_card":
			for i in range(int(value)):
				if not target.pool.is_empty():
					var index = randi_range(0, target.pool.size() - 1)
					played_cards_list.append(target.pool[index].id)
					target.pool.remove_at(index)
		"destroy_top_card":
			if not target.pool.is_empty():
				target.pool.remove_at(0)
		"reverse_target":
			target.reverse_next_effect = true

func _return_card(item_id: String, target: Player) -> bool:
	var index = played_cards_list.rfind(item_id)
	return _return_card_at(index, target)

func _return_card_at(index: int, target: Player) -> bool:
	if index < 0 or index >= played_cards_list.size():
		return false
	var item = GameManager.get_item(played_cards_list[index])
	if item == null:
		return false
	played_cards_list.remove_at(index)
	if index == _played_discard_index:
		_played_discard_index = -1
	elif index < _played_discard_index:
		_played_discard_index -= 1
	target.pool.append(item)
	return true

func _show_reclaim_choices() -> void:
	state = BattleState.WAITING_FOR_RECLAIM
	_clear_children(reclaim_list)
	$UI/ReclaimPanel/VBox/Title.text = "%s — reclaim a card" % _player_name(_reclaim_targets[0])
	var shown: Array = []
	for item_id in played_cards_list:
		if item_id in shown:
			continue
		shown.append(item_id)
		var button = Button.new()
		button.theme = GameStyle.theme()
		button.text = GameManager.get_item_name(item_id)
		button.pressed.connect(reclaim_card.bind(item_id))
		reclaim_list.add_child(button)
	reclaim_panel.show()
	_update_ui()

func reclaim_card(item_id: String) -> void:
	if state != BattleState.WAITING_FOR_RECLAIM or _reclaim_targets.is_empty():
		return
	if not _return_card(item_id, _reclaim_targets[0]):
		return
	_reclaim_targets.pop_front()
	_continue_resolution()

func _skip_reclaim() -> void:
	if state == BattleState.WAITING_FOR_RECLAIM and not _reclaim_targets.is_empty():
		_reclaim_targets.pop_front()
		_continue_resolution()

func _check_knockout() -> bool:
	if player1.is_alive() and player2.is_alive():
		return false
	var winner = "Draw"
	if player1.is_alive():
		winner = "Player 1"
	elif player2.is_alive():
		winner = "Player 2"
	_end_battle(winner, "Reached 0 HP")
	return true

func _end_battle_by_hp() -> void:
	var winner = "Draw"
	if player1.hp > player2.hp:
		winner = "Player 1"
	elif player2.hp > player1.hp:
		winner = "Player 2"
	_end_battle(winner, "Both pools exhausted — higher HP wins")

func _end_battle(winner: String, reason: String) -> void:
	state = BattleState.BATTLE_OVER
	_reclaim_targets.clear()
	reclaim_panel.hide()
	_update_hp_bars()
	_update_ui()
	win_screen.show_result(winner, reason, player1.hp, player2.hp)

func _update_hp_bars() -> void:
	hp_bar_p1.max_value = player1.max_hp
	_animate_hp(hp_bar_p1, player1.hp)
	hp_bar_p2.max_value = player2.max_hp
	_animate_hp(hp_bar_p2, player2.hp)
	$Players/Player1/HPText.text = "%s / %d of %d HP" % [_player_name(player1), player1.hp, player1.max_hp]
	$Players/Player2/HPText.text = "%s / %d of %d HP" % [_player_name(player2), player2.hp, player2.max_hp]

func _buff_text(player: Player) -> String:
	var names: Array[String] = []
	for key in player.active_buffs:
		for effect in effects_pool.values():
			if effect.effect_key == key:
				if player.active_buff_values.has(key) and effect.value != player.active_buff_values[key]:
					continue
				names.append(effect.name)
				break
	if player.reverse_next_effect:
		names.append("Reverse next effect target")
	if player.bonus_turns > 0:
		names.append("Bonus turns: %d" % player.bonus_turns)
	return " • ".join(names) if not names.is_empty() else "No active effects"

func _update_ui() -> void:
	var ready_for_card = state == BattleState.WAITING_FOR_CARD
	turn_label.text = "%s's turn" % _player_name(get_current_player())
	if state == BattleState.RESOLVING:
		turn_label.text = "Resolving card…"
	elif state == BattleState.WAITING_FOR_RECLAIM:
		turn_label.text = "Choose a card to reclaim"
	elif state == BattleState.BATTLE_OVER:
		turn_label.text = "Match finished"
	_set_cards_interactable(card_list_p1, ready_for_card and current_turn == 0)
	_set_cards_interactable(card_list_p2, ready_for_card and current_turn == 1)
	$Decks/CardDeck/Count.text = "%s / %d cards" % [_player_name(player1), player1.pool.size()]
	$Decks/CardDeck2/Count.text = "%s / %d cards" % [_player_name(player2), player2.pool.size()]
	$Players/Player1/Buffs.text = _player_name(player1) + " effects: " + _buff_text(player1)
	$Players/Player2/Buffs.text = _player_name(player2) + " effects: " + _buff_text(player2)
	$Decks/CardDeck/Count.modulate = GameStyle.GOLD if current_turn == 0 else GameStyle.MUTED
	$Decks/CardDeck2/Count.modulate = GameStyle.GOLD if current_turn == 1 else GameStyle.MUTED
	turn_label.modulate = GameStyle.GOLD
	if _play_button:
		_play_button.visible = ready_for_card and not selected_item.is_empty()
	if _pool_label:
		_pool_label.text = "%s  /  UNIQUE EFFECTS  %02d / 30" % [GameManager.get_theme_info().get("name", "TASTE DUEL").to_upper(), available_effects.size()]
	for i in range(_portraits.size()):
		_portraits[i].active = ready_for_card and current_turn == i
		_portraits[i].queue_redraw()

func _animate_card_to_table(item_id: String) -> void:
	_clear_children(played_cards)
	var card = PanelContainer.new()
	card.theme = GameStyle.theme()
	card.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.GOLD, 14, 8))
	card.custom_minimum_size = Vector2(200, 150)
	card.size = Vector2(200, 150)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var icon = TextureRect.new()
	icon.material = GameStyle.art_material()
	icon.custom_minimum_size = Vector2(180, 98)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = GameManager.get_texture(item_id)
	if icon.texture == null:
		var fallback = Label.new()
		var catalog_item = GameManager.get_catalog_item(GameManager.active_theme_id, item_id)
		fallback.text = catalog_item.icon if catalog_item != null else "✦"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.custom_minimum_size = Vector2(180, 98)
		fallback.add_theme_font_size_override("font_size", 60)
		content.add_child(fallback)
	else:
		content.add_child(icon)
	var label = Label.new()
	label.text = GameManager.get_item_name(item_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(180, 24)
	label.clip_text = true
	label.tooltip_text = label.text
	content.add_child(label)
	played_cards.add_child(card)
	card.position = Vector2(240 if current_turn == 0 else -240, 120 if current_turn == 0 else -120)
	card.pivot_offset = card.size / 2
	if animation_duration > 0 and not GameManager.reduce_motion:
		card.scale = Vector2(0.8, 0.8)
		create_tween().tween_property(card, "scale", Vector2.ONE, animation_duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(card, "position", Vector2.ZERO, animation_duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		card.position = Vector2.ZERO

func _style_battle() -> void:
	GameStyle.apply(self)
	$Background/ColorRect.color = GameStyle.INK
	$Table.hide()
	# Procedural table and deck wells keep the artwork visually consistent.
	for rect in [Rect2(12, 18, 328, 688), Rect2(940, 18, 328, 688), Rect2(350, 250, 580, 278)]:
		var panel = Panel.new()
		panel.position = rect.position
		panel.size = rect.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL.darkened(0.25), GameStyle.LINE, 18))
		$Background.add_child(panel)
	for i in range(2):
		var original = $Players/Player1/Player1 if i == 0 else $Players/Player2/Player2
		original.hide()
		var portrait = AvatarPortrait.new()
		portrait.position = original.position - Vector2(4, 16)
		portrait.size = Vector2(104, 120)
		portrait.avatar_index = GameManager.profiles[i].avatar
		portrait.accent = GameManager.COLORS[GameManager.profiles[i].color]
		original.get_parent().add_child(portrait)
		_portraits.append(portrait)
	for label in [$Players/Player1/Buffs, $Players/Player2/Buffs]:
		label.tooltip_text = "These effects belong to the named player. Damage modifiers apply only to that player's next damaging attack, then expire. Healing and neutral cards preserve them. Card hits are capped at %d damage." % CardBalance.MAX_HIT
	effect_popup.add_theme_font_size_override("font_size", 14)
	_build_battle_controls()
	for panel in [reclaim_panel, $WinScreen/Dim/Panel]:
		panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.GOLD, 16, 18))
	var title = Label.new()
	title.text = "TASTE / DUEL"
	title.position = Vector2(366, 680)
	title.modulate = GameStyle.MUTED
	title.add_theme_font_size_override("font_size", 13)
	$UI.add_child(title)

func _animate_hp(bar: ProgressBar, value: int) -> void:
	if _hp_tweens.has(bar):
		_hp_tweens[bar].kill()
	var tint = GameStyle.CORAL if value <= 30 else GameStyle.MINT
	bar.add_theme_stylebox_override("fill", GameStyle.box(tint, tint, 8, 0))
	if animation_duration <= 0 or GameManager.reduce_motion:
		bar.value = value
	else:
		_hp_tweens[bar] = create_tween()
		_hp_tweens[bar].tween_property(bar, "value", value, animation_duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _health_feedback(before: int, after: int, player: Player) -> void:
	if animation_duration <= 0:
		return
	if not _portraits.is_empty():
		_portraits[0 if player == player1 else 1].react("hit" if after < before else "heal")
	var tint = GameStyle.CORAL if after < before else GameStyle.MINT
	var origin = Vector2(650, 567 if player == player1 else 102)
	var offset = int(_float_counts.get(player, 0))
	_float_counts[player] = offset + 1
	var label = Label.new()
	label.text = "%+d HP" % (after - before)
	label.position = origin + Vector2(offset * 100 - 40, 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", GameStyle.INK)
	label.add_theme_constant_override("shadow_offset_y", 2)
	$UI.add_child(label)
	var tween = label.create_tween()
	if not GameManager.reduce_motion:
		var trail = preload("res://CombatTrail.gd").new()
		trail.position = Vector2(640, 330)
		trail.destination = origin - trail.position
		trail.tint = tint
		$UI.add_child(trail)
		var burst = preload("res://CombatVFX.gd").new()
		burst.position = origin
		burst.tint = tint
		$UI.add_child(burst)
		tween.tween_property(label, "position:y", label.position.y - 8, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_interval(0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)

func _build_battle_controls() -> void:
	_pool_label = Label.new()
	_pool_label.position = Vector2(366, 218)
	_pool_label.add_theme_font_size_override("font_size", 13)
	_pool_label.modulate = GameStyle.GOLD
	$UI.add_child(_pool_label)
	_play_button = Button.new()
	_play_button.theme = GameStyle.theme()
	_play_button.position = Vector2(530, 478)
	_play_button.size = Vector2(220, 40)
	_play_button.text = "PLAY THIS CARD  >"
	_play_button.add_theme_color_override("font_color", GameStyle.MINT)
	_play_button.pressed.connect(func():
		if not selected_item.is_empty():
			play_item(selected_item)
	)
	$UI.add_child(_play_button)
	_play_button.hide()
	_history_panel = _make_overlay("EFFECT JOURNAL")
	_history_text = RichTextLabel.new()
	_history_text.custom_minimum_size = Vector2(590, 320)
	_history_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_text.bbcode_enabled = false
	_history_panel.get_child(0).add_child(_history_text)
	var close_history = Button.new()
	close_history.text = "Back to the duel"
	close_history.pressed.connect(func(): _history_panel.hide())
	_history_panel.get_child(0).add_child(close_history)
	_settings_panel = _make_overlay("THE KITCHEN / SETTINGS")
	var settings = _settings_panel.get_child(0)
	GameStyle.motion_button(settings)
	var sound = CheckButton.new()
	sound.text = "Sound effects"
	sound.button_pressed = GameManager.sound_enabled
	sound.toggled.connect(func(value): GameManager.sound_enabled = value)
	settings.add_child(sound)
	var fullscreen = Button.new()
	fullscreen.text = "Toggle fullscreen"
	fullscreen.pressed.connect(func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	settings.add_child(fullscreen)
	var rules = Label.new()
	rules.text = "Select a card, then play it.\nDisliked cards hurt your rival; liked cards heal them.\nEach effect can be drawn only once across both players.\nDamage buffs belong to their named recipient.\nZero HP loses. If both pools empty, higher HP wins."
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size.y = 180
	settings.add_child(rules)
	var resume = Button.new()
	resume.text = "Resume duel"
	resume.pressed.connect(func():
		_settings_panel.hide()
		GameManager.save_profiles()
	)
	settings.add_child(resume)
	for entry in [["Effect journal", Vector2(680, 208)], ["Settings", Vector2(817, 208)]]:
		var button = Button.new()
		button.theme = GameStyle.theme()
		button.position = entry[1]
		button.text = entry[0]
		button.add_theme_font_size_override("font_size", 13)
		if entry[0] == "Effect journal":
			button.pressed.connect(_show_history)
		else:
			button.pressed.connect(_open_settings)
		$UI.add_child(button)

func _make_overlay(title: String) -> PanelContainer:
	# Higher layer blocks card clicks while a journal/settings panel is open.
	var layer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel = PanelContainer.new()
	panel.theme = GameStyle.theme()
	panel.position = Vector2(320, 130)
	panel.size = Vector2(640, 470)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.INK, GameStyle.GOLD, 18, 24))
	layer.add_child(panel)
	panel.visibility_changed.connect(func(): dim.visible = panel.visible)
	var stack = VBoxContainer.new()
	panel.add_child(stack)
	panel.move_child(stack, 0)
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = GameStyle.GOLD
	stack.add_child(label)
	panel.hide()
	return panel

func _show_history() -> void:
	var entries: Array[String] = ["%d effects remaining. Spent effects never return this match.\n" % available_effects.size()]
	for entry in effect_history:
		entries.append("#%02d  %s\n%s  >  %s\n" % [entry.id, entry.effect, entry.card, entry.recipient])
	if effect_history.is_empty():
		entries.append("Play your first card to start the journal.")
	_history_text.text = "\n".join(entries)
	_history_panel.show()
	_history_panel.get_child(0).get_children().back().grab_focus()

func _open_settings() -> void:
	_settings_panel.show()
	_settings_panel.get_child(0).get_children().back().grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and state != BattleState.BATTLE_OVER:
		if _history_panel.visible:
			_history_panel.hide()
		elif _settings_panel.visible:
			_settings_panel.hide()
			GameManager.save_profiles()
		else:
			_open_settings()
		get_viewport().set_input_as_handled()
