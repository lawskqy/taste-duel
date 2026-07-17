class_name Player
extends Node2D

var hp: int = 100
var max_hp: int = 100
var preferences: Dictionary = {}
var player_effect_pool: Dictionary = {}
var pool: Array = []
var active_buffs: Array = []
var active_buff_values: Dictionary = {}

func setup(prefs: Dictionary, items: Array, effect_pool: Dictionary) -> void:
	preferences = prefs
	pool = items.duplicate(true)
	hp = max_hp
	player_effect_pool = effect_pool.duplicate()

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)

func is_alive() -> bool:
	return hp > 0

func get_preference(item_id: String) -> Dictionary:
	if preferences.has(item_id):
		return preferences[item_id]
	return { "category": "neutral", "rank": 0 }

func remove_from_pool(item_id: String) -> void:
	for i in range(pool.size()):
		if pool[i].id == item_id:
			pool.remove_at(i)
			return
