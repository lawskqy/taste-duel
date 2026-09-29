extends Control

@onready var form_container = $FormContainer

const PREFERENCE_FORM = preload("res://preferenceForm.tscn")
const BATTLE_SCENE = "res://battle.tscn"

var current_form: Control = null
var _waiting_for_tap: bool = false

func _ready() -> void:
	GameStyle.apply(self)
	GameManager.reset()
	var lobby = preload("res://Lobby.gd").new()
	form_container.add_child(lobby)
	lobby.start_match.connect(_start_match)

func _start_match() -> void:
	_show_form_for_player(1)

func _show_form_for_player(player_idx: int) -> void:
	_waiting_for_tap = false
	_clear_form_container()

	var form = PREFERENCE_FORM.instantiate()
	form_container.add_child(form)
	current_form = form

	form.form_submitted.connect(_on_form_submitted)
	form.setup(player_idx, GameManager.items)

func _on_form_submitted(player_idx: int, prefs: Dictionary) -> void:
	GameManager.store_preferences(player_idx, prefs)

	if player_idx == 1:
		_show_pass_device_prompt()
	else:
		get_tree().change_scene_to_file(BATTLE_SCENE)

func _show_pass_device_prompt() -> void:
	_waiting_for_tap = false
	_clear_form_container()

	var label = Label.new()
	label.text = "%s is ready!\nPass the device to %s.\n\nPress anywhere to rank privately." % [GameManager.player_name(0), GameManager.player_name(1)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	form_container.add_child(label)

	await get_tree().create_timer(0.5).timeout  
	_waiting_for_tap = true

func _clear_form_container() -> void:
	for child in form_container.get_children():
		form_container.remove_child(child)
		child.queue_free()
	current_form = null

func _input(event: InputEvent) -> void:
	if not _waiting_for_tap:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_show_form_for_player(2)
