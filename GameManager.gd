extends Node

var items: Array = []
var theme_catalog: Dictionary = {}
var active_theme_id: String = "food"
const ITEM_COUNT_PER_MATCH = 21
var prefs_p1: Dictionary = {}
var prefs_p2: Dictionary = {}
var current_form_player: int = 1
var reduce_motion: bool = false
var sound_enabled: bool = true
const AVATARS = ["Pepper", "Miso", "Byte", "Mochi"]
const COLORS = [GameStyle.CORAL, GameStyle.MINT, GameStyle.LAVENDER, GameStyle.SKY, GameStyle.GOLD]
var profiles: Array[Dictionary] = []
var _sound_player: AudioStreamPlayer
var _sounds: Dictionary = {}
var _item_catalog: Dictionary = {}

# texture cache — loaded once at startup
var textures: Dictionary = {}

func _ready() -> void:
	reset_profiles()
	_load_theme_catalog()
	load_profiles()
	_sound_player = AudioStreamPlayer.new()
	_sound_player.volume_db = -18
	add_child(_sound_player)
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

func get_item(item_id: String) -> Item:
	for item in items:
		if item.id == item_id:
			return item
	return null

func get_catalog_item(theme_id: String, item_id: String) -> Item:
	var theme: Dictionary = theme_catalog.get(theme_id, {})
	for entry in theme.get("items", []):
		if entry.id == item_id:
			return Item.new(entry.id, entry.name, theme_id, entry.icon, entry.description)
	return null

func theme_ids() -> Array:
	return theme_catalog.keys()

func theme_items(theme_id: String) -> Array:
	var result: Array = []
	for entry in theme_catalog.get(theme_id, {}).get("items", []):
		result.append(Item.new(entry.id, entry.name, theme_id, entry.icon, entry.description))
	return result

func choose_theme(theme_id: String, redraw: bool = false) -> bool:
	if not theme_catalog.has(theme_id):
		return false
	if not redraw and active_theme_id == theme_id and items.size() == ITEM_COUNT_PER_MATCH:
		return true
	active_theme_id = theme_id
	var candidates = theme_items(theme_id)
	candidates.shuffle()
	items = candidates.slice(0, ITEM_COUNT_PER_MATCH)
	prefs_p1.clear()
	prefs_p2.clear()
	return items.size() == ITEM_COUNT_PER_MATCH

func get_item_name(item_id: String) -> String:
	var item = get_item(item_id)
	if item != null:
		return item.name
	return str(_item_catalog.get(item_id, {}).get("name", item_id))

func get_theme_info(theme_id: String = "") -> Dictionary:
	return theme_catalog.get(active_theme_id if theme_id.is_empty() else theme_id, {})

func _load_theme_catalog() -> void:
	var file = FileAccess.open("res://data/themes.json", FileAccess.READ)
	if file == null:
		push_error("Theme catalog missing: res://data/themes.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("themes", {}) is Dictionary:
		push_error("Theme catalog is not a valid JSON theme map")
		return
	theme_catalog = parsed.themes
	_item_catalog.clear()
	var global_ids: Dictionary = {}
	for theme_id in theme_catalog:
		var theme: Dictionary = theme_catalog[theme_id]
		var entries: Array = theme.get("items", [])
		if entries.size() != 50:
			push_error("Theme %s must contain exactly 50 items" % theme_id)
		var unique_ids: Dictionary = {}
		for entry in entries:
			if not entry is Dictionary or not entry.has("id") or not entry.has("name") or not entry.has("icon"):
				push_error("Malformed catalog entry in theme %s" % theme_id)
				continue
			if unique_ids.has(entry.id):
				push_error("Duplicate item ID in theme %s: %s" % [theme_id, entry.id])
			if global_ids.has(entry.id):
				push_error("Catalog IDs must be unique across all themes: %s" % entry.id)
			unique_ids[entry.id] = true
			global_ids[entry.id] = true
			_item_catalog[entry.id] = entry
	_load_textures()

func _build_items() -> void:
	if not choose_theme(active_theme_id, true):
		choose_theme("food", true)

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

func reset_profiles() -> void:
	profiles = [{"name": "Player 1", "avatar": 0, "color": 0}, {"name": "Player 2", "avatar": 1, "color": 1}]

func player_name(index: int) -> String:
	var value: String = profiles[index].name
	if profiles[0].name == profiles[1].name:
		value += " / P%d" % (index + 1)
	return value

func set_profile(index: int, display_name: String, avatar: int, color: int) -> void:
	var clean = display_name.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 16)
	profiles[index] = {"name": clean if not clean.is_empty() else "Player %d" % (index + 1), "avatar": clampi(avatar, 0, 3), "color": clampi(color, 0, COLORS.size() - 1)}

func save_profiles(path: String = "user://players.cfg") -> Error:
	var config = ConfigFile.new()
	for i in range(2):
		config.set_value("players", str(i), profiles[i])
	config.set_value("settings", "motion", reduce_motion)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "theme", active_theme_id)
	return config.save(path)

func load_profiles(path: String = "user://players.cfg") -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	for i in range(2):
		var value = config.get_value("players", str(i), {})
		if value is Dictionary:
			set_profile(i, str(value.get("name", "")), int(value.get("avatar", i)), int(value.get("color", i)))
	reduce_motion = bool(config.get_value("settings", "motion", false))
	sound_enabled = bool(config.get_value("settings", "sound", true))
	var saved_theme: String = str(config.get_value("settings", "theme", "food"))
	if theme_catalog.has(saved_theme):
		active_theme_id = saved_theme

func play_sound(cue: String) -> void:
	if not sound_enabled or DisplayServer.get_name() == "headless":
		return
	if not _sounds.has(cue):
		var data = PackedByteArray()
		var frequency: float = {"select": 520.0, "hit": 120.0, "heal": 740.0, "effect": 880.0, "win": 660.0}.get(cue, 440.0)
		for i in range(6600):
			var t = float(i) / 22050.0
			var envelope = minf(t * 80, 1.0) * pow(1.0 - float(i) / 6600.0, 3)
			var sample = int(sin(TAU * frequency * t + sin(t * 24) * 2) * envelope * 18000)
			data.append(sample & 255)
			data.append((sample >> 8) & 255)
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		_sounds[cue] = stream
	_sound_player.stream = _sounds[cue]
	_sound_player.play()
