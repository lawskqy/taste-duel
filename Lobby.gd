extends Control

signal start_match
signal back_requested

var portraits: Array[AvatarPortrait] = []
var name_fields: Array[LineEdit] = []
var avatar_buttons: Array = []
var color_buttons: Array = []
var theme_picker: OptionButton
var theme_note: Label
var customization_only: bool = false

const AVATAR_NAMES = ["Pepper", "Miso", "Byte", "Mochi"]
const APRON_NAMES = ["Peach", "Mint", "Lavender", "Moon sky", "Butter"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GameStyle.theme()
	add_child(preload("res://SceneBackdrop.gd").new())

	var page = VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 48
	page.offset_right = -48
	page.offset_top = 24
	page.offset_bottom = -24
	page.add_theme_constant_override("separation", 12)
	add_child(page)

	var masthead = HBoxContainer.new()
	masthead.custom_minimum_size.y = 76
	masthead.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(masthead)
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 0)
	identity.add_child(_label("THE LITTLE SUPPER CLUB     /     LOCAL TWO PLAYER", 12, GameStyle.GOLD))
	identity.add_child(_label("Taste Duel", 38, GameStyle.TEXT))
	identity.add_child(_label("A good meal. A little mind-reading.", 15, GameStyle.MUTED))
	masthead.add_child(identity)
	var edition = PanelContainer.new()
	edition.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LINE, 6, 12))
	var edition_label = _label("PASS & PLAY\nONE DEVICE, TWO PALATES", 12, GameStyle.LAVENDER)
	edition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edition.add_child(edition_label)
	masthead.add_child(edition)
	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(84, 42)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_requested.emit())
	masthead.add_child(back)

	var menu_row = HBoxContainer.new()
	menu_row.custom_minimum_size.y = 52
	menu_row.add_theme_constant_override("separation", 14)
	page.add_child(menu_row)
	menu_row.add_child(_label("TONIGHT'S MENU", 12, GameStyle.GOLD))
	theme_picker = OptionButton.new()
	theme_picker.custom_minimum_size = Vector2(230, 40)
	for theme_id in GameManager.theme_ids():
		var info: Dictionary = GameManager.theme_catalog[theme_id]
		theme_picker.add_item("%s   %s" % [info.icon, info.name])
		theme_picker.set_item_metadata(theme_picker.item_count - 1, theme_id)
		if theme_id == GameManager.active_theme_id:
			theme_picker.select(theme_picker.item_count - 1)
	menu_row.add_child(theme_picker)
	theme_note = _label("", 14, GameStyle.MUTED)
	theme_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_row.add_child(theme_note)
	_update_theme_note()
	theme_picker.item_selected.connect(_on_theme_selected)
	var menu_rule = ColorRect.new()
	menu_rule.color = GameStyle.LINE
	menu_rule.custom_minimum_size.y = 1
	menu_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(menu_rule)

	var players = HBoxContainer.new()
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players.add_theme_constant_override("separation", 14)
	page.add_child(players)
	players.add_child(_player_panel(0))
	var versus = PanelContainer.new()
	versus.custom_minimum_size = Vector2(48, 48)
	versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	versus.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.SKY, GameStyle.LINE, 24, 0))
	var vs_label = _label("VS", 12, GameStyle.GOLD)
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.add_child(vs_label)
	players.add_child(versus)
	players.add_child(_player_panel(1))

	var footer = HBoxContainer.new()
	footer.custom_minimum_size.y = 76
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	page.add_child(footer)
	var start = Button.new()
	start.text = "SAVE & RETURN" if customization_only else "SET THE TABLE     →"
	start.custom_minimum_size = Vector2(292, 52)
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start.add_theme_color_override("font_color", GameStyle.INK)
	start.add_theme_stylebox_override("normal", GameStyle.button_box(GameStyle.GOLD, GameStyle.GOLD, 5, 12))
	GameStyle.primary(start)
	start.pressed.connect(func():
		for i in range(2):
			var profile: Dictionary = GameManager.profiles[i]
			GameManager.set_profile(i, name_fields[i].text, profile.avatar, profile.color)
		GameManager.save_profiles()
		GameManager.play_sound("select")
		if customization_only:
			back_requested.emit()
		else:
			start_match.emit()
	)
	footer.add_child(start)
	var footer_rule = ColorRect.new()
	footer_rule.color = GameStyle.LINE
	footer_rule.custom_minimum_size = Vector2(1, 34)
	footer.add_child(footer_rule)
	var steps = VBoxContainer.new()
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps.add_theme_constant_override("separation", 2)
	steps.add_child(_label("FIRST, MAKE YOURSELVES AT HOME", 11, GameStyle.LAVENDER))
	var hint = _label("Rank your favorites in private, then discover how well you know each other.", 13, GameStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steps.add_child(hint)
	footer.add_child(steps)
	var sound = CheckButton.new()
	sound.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sound.text = "Sound"
	sound.button_pressed = GameManager.sound_enabled
	sound.toggled.connect(func(value): GameManager.sound_enabled = value)
	footer.add_child(sound)
	GameStyle.motion_button(footer).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _label(value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GameStyle.readable(color))
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
	theme_note.text = "%s   ·   %d dishes, %d on the table" % [info.get("tagline", "Pick a world"), info.get("items", []).size(), GameManager.items.size()]
	theme_note.modulate = Color.WHITE

func _player_panel(index: int) -> PanelContainer:
	var profile: Dictionary = GameManager.profiles[index]
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 350)
	var accent = GameStyle.CORAL if index == 0 else GameStyle.SKY
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, accent.darkened(0.28), 7, 18))
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)
	var heading = HBoxContainer.new()
	stack.add_child(heading)
	var player_title = _label("0%d   /   PLAYER %s" % [index + 1, "ONE" if index == 0 else "TWO"], 12, accent)
	player_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(player_title)
	var privacy = _label("WARM SIDE" if index == 0 else "COOL SIDE", 10, GameStyle.MUTED)
	privacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(privacy)

	var hero = HBoxContainer.new()
	hero.custom_minimum_size.y = 152
	hero.add_theme_constant_override("separation", 18)
	stack.add_child(hero)
	var portrait = AvatarPortrait.new()
	portrait.custom_minimum_size = Vector2(152, 152)
	portrait.avatar_index = profile.avatar
	portrait.accent = GameManager.COLORS[profile.color]
	portrait.active = true
	hero.add_child(portrait)
	portraits.append(portrait)
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 6)
	hero.add_child(identity)
	identity.add_child(_label("WHAT SHOULD WE CALL YOU?", 10, GameStyle.MUTED))
	var field = LineEdit.new()
	field.text = profile.name
	field.max_length = 16
	field.placeholder_text = "Your name"
	field.custom_minimum_size.y = 42
	identity.add_child(field)
	var mood = _label("Here for the snacks. Staying\nfor the friendly competition.", 13, GameStyle.TEXT)
	mood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(mood)
	name_fields.append(field)

	var divider = ColorRect.new()
	divider.color = GameStyle.LINE
	divider.custom_minimum_size.y = 1
	stack.add_child(divider)
	stack.add_child(_label("PICK YOUR LITTLE SOUS-CHEF", 10, GameStyle.MUTED))
	var choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	stack.add_child(choices)
	var buttons: Array[Button] = []
	for i in range(GameManager.AVATARS.size()):
		var button = Button.new()
		button.tooltip_text = AVATAR_NAMES[i]
		button.custom_minimum_size = Vector2(100, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_select_avatar.bind(index, i))
		choices.add_child(button)
		var content = HBoxContainer.new()
		content.name = "Content"
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.offset_top = 6
		content.offset_bottom = -6
		content.add_theme_constant_override("separation", 4)
		button.add_child(content)
		var icon = TextureRect.new()
		icon.name = "Avatar"
		icon.texture = load("res://assets/avatars/%d.svg" % i)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size.x = 28
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tint = ShaderMaterial.new()
		tint.shader = preload("res://assets/avatar_tint.gdshader")
		icon.material = tint
		content.add_child(icon)
		var name_label = _label(AVATAR_NAMES[i], 11, GameStyle.TEXT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)
		buttons.append(button)
	avatar_buttons.append(buttons)

	var color_row = HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 9)
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(color_row)
	color_row.add_child(_label("APRON COLOR", 10, GameStyle.MUTED))
	var swatches: Array[Button] = []
	for i in range(GameManager.COLORS.size()):
		var button = Button.new()
		button.custom_minimum_size = Vector2(32, 27)
		button.tooltip_text = APRON_NAMES[i]
		button.add_theme_stylebox_override("normal", GameStyle.box(GameManager.COLORS[i], GameManager.COLORS[i], 5, 2))
		button.add_theme_stylebox_override("pressed", GameStyle.box(GameManager.COLORS[i], GameStyle.TEXT, 5, 2))
		button.add_theme_stylebox_override("hover", GameStyle.box(GameManager.COLORS[i], GameStyle.TEXT, 5, 2))
		button.add_theme_color_override("font_color", GameStyle.INK)
		button.pressed.connect(_select_color.bind(index, i))
		color_row.add_child(button)
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
	for i in range(GameManager.AVATARS.size()):
		avatar_buttons[index][i].set_pressed_no_signal(i == profile.avatar)
		avatar_buttons[index][i].get_node("Content/Avatar").material.set_shader_parameter("accent", GameManager.COLORS[profile.color])
	for i in range(GameManager.COLORS.size()):
		color_buttons[index][i].text = "•" if i == profile.color else ""
