extends Control

signal start_match
var portraits: Array[AvatarPortrait] = []
var name_fields: Array[LineEdit] = []
var avatar_buttons: Array = []
var color_buttons: Array = []
var theme_picker: OptionButton
var theme_note: Label

func _theme_ids() -> Array:
	return GameManager.theme_ids()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GameStyle.theme()
	add_child(preload("res://SceneBackdrop.gd").new())
	var layout = VBoxContainer.new()
	layout.position = Vector2(70, 24)
	layout.size = Vector2(1140, 674)
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var eyebrow = _label("LOCAL MULTIPLAYER  /  A DUEL OF TASTE", 13, GameStyle.GOLD)
	layout.add_child(eyebrow)
	layout.add_child(_label("Taste Duel", 48, GameStyle.CREAM))
	layout.add_child(_label("Choose your character, a theme, then find out how well you know each other.", 18, GameStyle.MUTED))
	var theme_row = HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 14)
	layout.add_child(theme_row)
	theme_row.add_child(_label("PICK YOUR WORLD", 13, GameStyle.GOLD))
	theme_picker = OptionButton.new()
	theme_picker.custom_minimum_size = Vector2(250, 38)
	var ids = _theme_ids()
	for theme_id in ids:
		var info: Dictionary = GameManager.theme_catalog[theme_id]
		theme_picker.add_item("%s   %s" % [info.icon, info.name])
		theme_picker.set_item_metadata(theme_picker.item_count - 1, theme_id)
		if theme_id == GameManager.active_theme_id:
			theme_picker.select(theme_picker.item_count - 1)
	theme_row.add_child(theme_picker)
	theme_note = _label("50 cards / A fresh draw of 21 every match", 14, GameStyle.MUTED)
	theme_row.add_child(theme_note)
	_update_theme_note()
	theme_picker.item_selected.connect(_on_theme_selected)
	var players = HBoxContainer.new()
	players.add_theme_constant_override("separation", 24)
	layout.add_child(players)
	for i in range(2):
		players.add_child(_player_panel(i))
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	layout.add_child(footer)
	var start = Button.new()
	start.text = "START THE DUEL  >"
	start.custom_minimum_size = Vector2(360, 54)
	start.add_theme_color_override("font_color", GameStyle.INK)
	start.add_theme_stylebox_override("normal", GameStyle.box(GameStyle.GOLD, GameStyle.GOLD))
	start.pressed.connect(func():
		for i in range(2):
			var profile: Dictionary = GameManager.profiles[i]
			GameManager.set_profile(i, name_fields[i].text, profile.avatar, profile.color)
		GameManager.save_profiles()
		GameManager.play_sound("select")
		start_match.emit()
	)
	footer.add_child(start)
	GameStyle.motion_button(footer)
	var sound = CheckButton.new()
	sound.text = "Sound"
	sound.button_pressed = GameManager.sound_enabled
	sound.toggled.connect(func(value): GameManager.sound_enabled = value)
	footer.add_child(sound)
	layout.add_child(_label("1  Customize     /     2  Rank privately     /     3  Battle     •     100 HP. One shared pool of 30 unique effects.", 14, GameStyle.MUTED))

func _label(value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _on_theme_selected(index: int) -> void:
	var theme_id: String = str(theme_picker.get_item_metadata(index))
	if not GameManager.choose_theme(theme_id):
		return
	_update_theme_note()
	for i in range(2):
		var profile: Dictionary = GameManager.profiles[i]
		GameManager.set_profile(i, name_fields[i].text, profile.avatar, profile.color)
	GameManager.save_profiles()
	GameManager.play_sound("select")

func _update_theme_note() -> void:
	var info: Dictionary = GameManager.get_theme_info()
	theme_note.text = "%s / %d cards, %d drawn per match" % [info.get("tagline", "Pick a world"), info.get("items", []).size(), GameManager.items.size()]
	theme_note.modulate = Color(info.get("accent", "#a8bbc5"))

func _player_panel(index: int) -> PanelContainer:
	var profile: Dictionary = GameManager.profiles[index]
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(558, 406)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LINE, 20, 20))
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	stack.add_child(_label("PLAYER %02d   /   MAKE IT YOURS" % (index + 1), 13, GameStyle.GOLD))
	var hero = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 20)
	stack.add_child(hero)
	var portrait = AvatarPortrait.new()
	portrait.custom_minimum_size = Vector2(170, 185)
	portrait.avatar_index = profile.avatar
	portrait.accent = GameManager.COLORS[profile.color]
	portrait.active = true
	hero.add_child(portrait)
	portraits.append(portrait)
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(identity)
	identity.add_child(_label("YOUR NAME", 12, GameStyle.MUTED))
	var field = LineEdit.new()
	field.text = profile.name
	field.max_length = 16
	field.placeholder_text = "Player %d" % (index + 1)
	field.custom_minimum_size.y = 44
	identity.add_child(field)
	name_fields.append(field)
	identity.add_child(_label("A little personality.\nA lot of friendly rivalry.", 16, GameStyle.CREAM))
	stack.add_child(_label("CHARACTER", 12, GameStyle.MUTED))
	var choices = HBoxContainer.new()
	stack.add_child(choices)
	var buttons: Array[Button] = []
	for i in range(4):
		var button = Button.new()
		button.text = GameManager.AVATARS[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_select_avatar.bind(index, i))
		choices.add_child(button)
		buttons.append(button)
	avatar_buttons.append(buttons)
	var colors = HBoxContainer.new()
	colors.add_theme_constant_override("separation", 12)
	stack.add_child(colors)
	colors.add_child(_label("APRON", 12, GameStyle.MUTED))
	var swatches: Array[Button] = []
	for i in range(GameManager.COLORS.size()):
		var button = Button.new()
		button.custom_minimum_size = Vector2(54, 36)
		button.tooltip_text = ["Coral", "Mint", "Lilac", "Sky", "Gold"][i]
		button.add_theme_stylebox_override("normal", GameStyle.box(GameManager.COLORS[i], GameManager.COLORS[i], 12, 4))
		button.add_theme_color_override("font_color", GameStyle.INK)
		button.pressed.connect(_select_color.bind(index, i))
		colors.add_child(button)
		swatches.append(button)
	color_buttons.append(swatches)
	_update_selection(index)
	return panel

func _select_avatar(index: int, avatar: int) -> void:
	GameManager.profiles[index].avatar = avatar
	_update_selection(index)
	portraits[index].react("select")

func _select_color(index: int, color: int) -> void:
	GameManager.profiles[index].color = color
	_update_selection(index)
	portraits[index].react("select")

func _update_selection(index: int) -> void:
	var profile: Dictionary = GameManager.profiles[index]
	portraits[index].configure(profile.avatar, GameManager.COLORS[profile.color])
	for i in range(4):
		avatar_buttons[index][i].set_pressed_no_signal(i == profile.avatar)
	for i in range(5):
		color_buttons[index][i].text = "•" if i == profile.color else ""
