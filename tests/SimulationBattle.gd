extends "res://scripts/combat/BattleController.gd"

var profile: Dictionary = {}
var winner_name: String = ""
var end_reason: String = ""

func _ready() -> void:
	animation_duration = 0

func _build_card_lists() -> void:
	pass

func _update_ui() -> void:
	pass

func _update_hp_bars() -> void:
	pass

func _animate_card_to_table(_item_id: String) -> void:
	pass

func _end_battle(winner: String, reason: String) -> void:
	state = BattleState.BATTLE_OVER
	winner_name = winner
	end_reason = reason

func _show_reclaim_choices() -> void:
	state = BattleState.WAITING_FOR_RECLAIM

func _calculate_hp(pref: Dictionary) -> int:
	if profile.is_empty():
		return super._calculate_hp(pref)
	if pref.category == "neutral":
		return 0
	var values: Array = profile.damage if pref.category == "disliked" else profile.heal
	return values[clampi(int(pref.rank), 1, values.size()) - 1]

func _apply_damage_modifiers(attacker: Player, base_damage: int) -> int:
	if profile.is_empty():
		return super._apply_damage_modifiers(attacker, base_damage)
	var result: int = profile.damage[0] if "dmg_crit" in attacker.active_buffs else base_damage
	result = int(result * attacker.active_buff_values.get("dmg_mult", 1.0))
	result += int(attacker.active_buff_values.get("dmg_flat", 0))
	if "dmg_twice" in attacker.active_buffs:
		result = int(result * 1.5)
	if "dmg_miss" in attacker.active_buffs:
		result = 0
	for key in ["dmg_crit", "dmg_mult", "dmg_flat", "dmg_twice", "dmg_miss"]:
		attacker.active_buffs.erase(key)
		attacker.active_buff_values.erase(key)
	return clampi(result, 0, int(profile.cap))

func _effect_count(pref: Dictionary) -> int:
	if profile.is_empty():
		return super._effect_count(pref)
	return 1 if pref.category == "neutral" else [2, 2, 1, 1, 0, 0, 0, 0][clampi(int(pref.rank), 1, 8) - 1]

func prepare(config: Dictionary) -> void:
	_reset_effect_pool()
	profile = config
	if profile.is_empty():
		_setup_preview_data()
		return
	effects_pool[1].value = profile.multiplier
	effects_pool[6].value = profile.small_heal
	effects_pool[7].value = profile.big_heal
	effects_pool[8].value = profile.max_hp
	effects_pool[9].value = profile.missing_heal
	for player in [player1, player2]:
		var cards: Array = GameManager.items.duplicate()
		cards.shuffle()
		var prefs = {}
		var damage_count: int = profile.damage.size()
		var neutral_count: int = 21 - damage_count - profile.heal.size()
		for i in range(cards.size()):
			var category = "disliked" if i < damage_count else ("neutral" if i < damage_count + neutral_count else "liked")
			var rank = i + 1 if category == "disliked" else (0 if category == "neutral" else i - damage_count - neutral_count + 1)
			prefs[cards[i].id] = {"category": category, "rank": rank}
		player.setup(prefs, GameManager.items)
