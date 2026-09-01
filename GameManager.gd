extends Node

var items: Array = []
var prefs_p1: Dictionary = {}
var prefs_p2: Dictionary = {}
var current_form_player: int = 1

# texture cache — loaded once at startup
var textures: Dictionary = {}

func _ready() -> void:
	_load_textures()
	_build_items()

func _load_textures() -> void:
	var dish_ids = [
		"margherita_pizza", "cheeseburger", "caesar_salad", "spaghetti_carbonara",
		"beef_lasagna", "tikka_masala", "california_roll", "ramen",
		"french_onion_soup", "tomato_basil_soup", "beef_tacos", "chicken_burrito",
		"pad_thai", "butter_chicken", "fish_and_chips", "beef_steak",
		"chicken_alfredo", "mushroom_risotto", "apple_pie", "chocolate_brownie",
		"vanilla_ice_cream",
	]
	for id in dish_ids:
		var path = "res://assets/%s.png" % id
		if ResourceLoader.exists(path):
			textures[id] = load(path)
		else:
			textures[id] = null  # graceful fallback if image missing

func get_texture(dish_id: String) -> Texture2D:
	return textures.get(dish_id, null)

func _build_items() -> void:
	var dish_data = [
		["margherita_pizza",   "Margherita Pizza"],
		["cheeseburger",       "Cheeseburger"],
		["caesar_salad",       "Chicken Caesar Salad"],
		["spaghetti_carbonara","Spaghetti Carbonara"],
		["beef_lasagna",       "Beef Lasagna"],
		["tikka_masala",       "Chicken Tikka Masala"],
		["california_roll",    "California Roll"],
		["ramen",              "Ramen"],
		["french_onion_soup",  "French Onion Soup"],
		["tomato_basil_soup",  "Tomato Basil Soup"],
		["beef_tacos",         "Beef Tacos"],
		["chicken_burrito",    "Chicken Burrito"],
		["pad_thai",           "Pad Thai"],
		["butter_chicken",     "Butter Chicken"],
		["fish_and_chips",     "Fish and Chips"],
		["beef_steak",         "Beef Steak"],
		["chicken_alfredo",    "Chicken Alfredo"],
		["mushroom_risotto",   "Mushroom Risotto"],
		["apple_pie",          "Apple Pie"],
		["chocolate_brownie",  "Chocolate Brownie"],
		["vanilla_ice_cream",  "Vanilla Ice Cream"],
	]
	items.clear()
	for d in dish_data:
		items.append(Item.new(d[0], d[1]))

func store_preferences(player_idx: int, prefs: Dictionary) -> void:
	if player_idx == 1:
		prefs_p1 = prefs
	else:
		prefs_p2 = prefs

func reset() -> void:
	prefs_p1 = {}
	prefs_p2 = {}
	current_form_player = 1
	_build_items()
