extends Control

@onready var form_container = $FormContainer

const PREFERENCE_FORM = preload("res://preferenceForm.tscn")
const BATTLE_SCENE = "res://battle.tscn"

var current_form: Control = null
var current_screen: String = "menu"
var _waiting_for_tap: bool = false
var _handoff_button: Button
var _leave_dialog: Control

func _ready() -> void:
	GameStyle.apply(self)
	GameManager.reset()
	_show_start_menu()

func _show_start_menu() -> void:
	_waiting_for_tap = false
	current_screen = "menu"
	_clear_form_container()
	form_container.add_child(preload("res://SceneBackdrop.gd").new())
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -278)
	panel.size = Vector2(620, 556)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LAVENDER, 8, 30))
	form_container.add_child(panel)
	GameStyle.center_panel(panel, Vector2(600, 640))
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var emblem = preload("res://SupperEmblem.gd").new()
	emblem.custom_minimum_size.y = 82
	content.add_child(emblem)
	var eyebrow = _label("THE LITTLE SUPPER CLUB", 12, GameStyle.GOLD)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title = _label("Taste Duel", 48, GameStyle.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle = _label("A good meal. A little mind-reading.", 16, GameStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var divider = ColorRect.new()
	divider.color = GameStyle.LINE
	divider.custom_minimum_size.y = 1
	content.add_child(divider)
	content.add_child(_menu_action("Let's play", "Start a new round", func(): _start_match(), true))
	content.add_child(_menu_action("Customize your table", "Choose your players and menu", func(): _show_customization()))
	content.add_child(_menu_action("Settings", "Sound, motion and display", func(): _show_settings()))
	content.add_child(_menu_action("Exit game", "Leave Taste Duel", func(): get_tree().quit()))
	var names = _label("AT THE TABLE     %s   &   %s" % [GameManager.player_name(0), GameManager.player_name(1)], 12, GameStyle.LAVENDER)
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(names)

func _menu_action(title: String, detail: String, action: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(420, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = title
	button.tooltip_text = detail
	button.add_theme_font_size_override("font_size", 18)
	if primary:
		button.add_theme_color_override("font_color", GameStyle.INK)
		button.add_theme_stylebox_override("normal", GameStyle.button_box(GameStyle.GOLD, GameStyle.GOLD, 5, 12))
		GameStyle.primary(button)
	button.pressed.connect(action)
	return button

func _show_customization() -> void:
	_waiting_for_tap = false
	current_screen = "customization"
	_clear_form_container()
	var lobby = preload("res://Lobby.gd").new()
	lobby.customization_only = true
	lobby.back_requested.connect(_show_start_menu)
	form_container.add_child(lobby)

func _show_settings() -> void:
	_waiting_for_tap = false
	current_screen = "settings"
	_clear_form_container()
	form_container.add_child(preload("res://SceneBackdrop.gd").new())
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-290, -230)
	panel.size = Vector2(580, 460)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LINE, 8, 26))
	form_container.add_child(panel)
	GameStyle.center_panel(panel, Vector2(580, 460))
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var header = HBoxContainer.new()
	content.add_child(header)
	var back = Button.new()
	back.text = "BACK"
	back.pressed.connect(_show_start_menu)
	header.add_child(back)
	var title = _label("SETTINGS", 25, GameStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 76
	header.add_child(spacer)
	var rule = ColorRect.new()
	rule.color = GameStyle.LINE
	rule.custom_minimum_size.y = 1
	content.add_child(rule)
	var sound = CheckButton.new()
	sound.text = "Sound effects"
	sound.button_pressed = GameManager.sound_enabled
	sound.toggled.connect(func(value): GameManager.sound_enabled = value)
	content.add_child(sound)
	GameStyle.motion_button(content)
	var fullscreen = Button.new()
	fullscreen.text = "Toggle fullscreen"
	fullscreen.pressed.connect(func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	content.add_child(fullscreen)
	var note = _label("Changes apply right away. Your player names and aprons are saved from Customization.", 13, GameStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

func _start_match() -> void:
	GameManager.reset()
	_show_form_for_player(1)

func _show_form_for_player(player_idx: int) -> void:
	_waiting_for_tap = false
	current_screen = "ranking"
	_clear_form_container()
	var form = PREFERENCE_FORM.instantiate()
	form_container.add_child(form)
	current_form = form
	form.form_submitted.connect(_on_form_submitted)
	form.back_requested.connect(_show_leave_round_dialog)
	form.setup(player_idx, GameManager.items)

func _on_form_submitted(player_idx: int, prefs: Dictionary) -> void:
	GameManager.store_preferences(player_idx, prefs)
	if player_idx == 1:
		_show_pass_device_prompt()
	else:
		get_tree().change_scene_to_file(BATTLE_SCENE)

func _show_pass_device_prompt() -> void:
	_waiting_for_tap = false
	current_screen = "handoff"
	_clear_form_container()
	form_container.add_child(preload("res://SceneBackdrop.gd").new())
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -235)
	panel.size = Vector2(660, 470)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.LAVENDER, 8, 30))
	form_container.add_child(panel)
	GameStyle.center_panel(panel, Vector2(660, 500))
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	var eyebrow = _label("A MOMENT OF PRIVACY", 12, GameStyle.GOLD)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title = _label("Nice picks, %s." % GameManager.player_name(0), 32, GameStyle.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var note = _label("Your menu is tucked away. Pass the device to\n%s for their turn at the table." % GameManager.player_name(1), 17, GameStyle.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var table = HBoxContainer.new()
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	table.add_theme_constant_override("separation", 30)
	content.add_child(table)
	for i in range(2):
		var seat = VBoxContainer.new()
		seat.alignment = BoxContainer.ALIGNMENT_CENTER
		seat.add_theme_constant_override("separation", 4)
		var portrait = AvatarPortrait.new()
		portrait.custom_minimum_size = Vector2(84, 84)
		portrait.configure(GameManager.profiles[i].avatar, GameManager.COLORS[GameManager.profiles[i].color])
		seat.add_child(portrait)
		var name = _label(GameManager.player_name(i), 15, GameStyle.TEXT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seat.add_child(name)
		name.custom_minimum_size.x = 200
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		table.add_child(seat)
		if i == 0:
			var arrow = _label("→", 25, GameStyle.LAVENDER)
			table.add_child(arrow)
	_handoff_button = Button.new()
	_handoff_button.text = "READY? PASS THE DEVICE"
	_handoff_button.custom_minimum_size = Vector2(310, 48)
	_handoff_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_handoff_button.disabled = true
	_handoff_button.add_theme_color_override("font_color", GameStyle.INK)
	_handoff_button.add_theme_stylebox_override("normal", GameStyle.button_box(GameStyle.GOLD, GameStyle.GOLD, 5, 10))
	GameStyle.primary(_handoff_button)
	_handoff_button.pressed.connect(_pass_device_to_player_two)
	content.add_child(_handoff_button)
	var back = Button.new()
	back.text = "BACK TO MENU"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_leave_round_dialog)
	content.add_child(back)
	await get_tree().create_timer(0.5).timeout
	if current_screen == "handoff":
		_waiting_for_tap = true
		_handoff_button.disabled = false

func _pass_device_to_player_two() -> void:
	if not _waiting_for_tap:
		return
	_waiting_for_tap = false
	_show_form_for_player(2)

func _show_leave_round_dialog() -> void:
	if _leave_dialog != null:
		return
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	form_container.add_child(overlay)
	_leave_dialog = overlay
	var dim = ColorRect.new()
	dim.color = Color(GameStyle.NIGHT_SHADOW, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -170)
	panel.size = Vector2(560, 340)
	panel.add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, GameStyle.GOLD, 7, 26))
	overlay.add_child(panel)
	GameStyle.center_panel(panel, Vector2(560, 340))
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var title = _label("LEAVE THIS ROUND?", 25, GameStyle.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note = _label("Your rankings and this round's progress will be lost.\nResume now, or quit back to the menu.", 15, GameStyle.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var choices = HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	content.add_child(choices)
	var resume = Button.new()
	resume.text = "RESUME ROUND"
	resume.custom_minimum_size = Vector2(200, 48)
	resume.pressed.connect(_close_leave_round_dialog)
	choices.add_child(resume)
	var quit = Button.new()
	quit.text = "QUIT TO MENU"
	quit.custom_minimum_size = Vector2(200, 48)
	quit.add_theme_color_override("font_color", GameStyle.INK)
	quit.add_theme_stylebox_override("normal", GameStyle.button_box(GameStyle.GOLD, GameStyle.GOLD, 5, 8))
	GameStyle.primary(quit)
	quit.pressed.connect(_quit_round_to_menu)
	choices.add_child(quit)
	resume.grab_focus()

func _close_leave_round_dialog() -> void:
	if _leave_dialog != null:
		_leave_dialog.queue_free()
		_leave_dialog = null

func _quit_round_to_menu() -> void:
	_close_leave_round_dialog()
	GameManager.reset()
	_show_start_menu()

func _clear_form_container() -> void:
	_leave_dialog = null
	for child in form_container.get_children():
		form_container.remove_child(child)
		child.queue_free()
	current_form = null

func _label(value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GameStyle.readable(color))
	return label

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _leave_dialog != null:
		_close_leave_round_dialog()
	elif current_screen in ["ranking", "handoff"]:
		_show_leave_round_dialog()
	elif current_screen in ["customization", "settings"]:
		_show_start_menu()
	else:
		return
	get_viewport().set_input_as_handled()
