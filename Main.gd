extends Control

@onready var form_container = $FormContainer

const PREFERENCE_FORM = preload("res://preferenceForm.tscn")
const BATTLE_SCENE = "res://battle.tscn"

var current_form: Control = null

func _ready() -> void:
	GameManager.reset()
	_show_form_for_player(1)

func _show_form_for_player(player_idx: int) -> void:
	if current_form:
		current_form.queue_free()
		current_form = null

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
	if current_form:
		current_form.queue_free()
		current_form = null

	var label = Label.new()
	label.text = "Player 1 done!\nPass the device to Player 2.\n\nPress anywhere to continue."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	form_container.add_child(label)

	await get_tree().create_timer(0.5).timeout  
	set_process_input(true)

var _waiting_for_tap: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if form_container.get_child_count() > 0:
			var child = form_container.get_child(0)
			if child is Label: 
				set_process_input(false)
				_show_form_for_player(2)
