class_name Player
extends Node2D

signal health_changed(before: int, after: int)

var hp: int = 100
var max_hp: int = 100
var preferences: Dictionary = {}
var pool: Array = []
var active_buffs: Array = []
var active_buff_values: Dictionary = {}
var bonus_turns: int = 0
var bonus_turn_sources: Array[String] = []
var skip_turn_source: String = ""
var last_effect: Dictionary = {}
var reverse_next_effect: bool = false

func setup(prefs: Dictionary, items: Array) -> void:
	preferences = prefs.duplicate(true)
	# Items are immutable catalog entries; the players own separate pool arrays.
	pool = items.duplicate()
	max_hp = 100
	hp = max_hp
	active_buffs.clear()
	active_buff_values.clear()
	bonus_turns = 0
	bonus_turn_sources.clear()
	skip_turn_source = ""
	last_effect.clear()
	reverse_next_effect = false

func take_damage(amount: int) -> void:
	var before = hp
	hp = max(0, hp - max(0, amount))
	if hp != before:
		health_changed.emit(before, hp)

func heal(amount: int) -> void:
	var before = hp
	if "no_heal" not in active_buffs:
		hp = min(max_hp, hp + max(0, amount))
	if hp != before:
		health_changed.emit(before, hp)

func has_item(item_id: String) -> bool:
	return pool.any(func(item): return item.id == item_id)

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
