extends CanvasLayer

@onready var title_label = $Dim/Panel/VBox/TitleLabel
@onready var reason_label = $Dim/Panel/VBox/ReasonLabel
@onready var hp_label = $Dim/Panel/VBox/HPLabel
@onready var restart_button = $Dim/Panel/VBox/RestartButton
var portrait: AvatarPortrait

func _ready() -> void:
	portrait = AvatarPortrait.new()
	portrait.custom_minimum_size = Vector2(130, 130)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Dim/Panel/VBox.add_child(portrait)
	$Dim/Panel/VBox.move_child(portrait, 0)
	$Dim/Panel.offset_top = -220
	$Dim/Panel.offset_bottom = 220
	GameStyle.center_panel($Dim/Panel, Vector2(560, 480))
	GameStyle.primary(restart_button)
	restart_button.text = "Set up another duel"
	restart_button.pressed.connect(_on_restart_pressed)
	visible = false

func show_result(winner: String, reason: String, p1_hp: int, p2_hp: int) -> void:
	portrait.visible = winner != "Draw"
	if winner != "Draw":
		var profile: Dictionary = GameManager.profiles[0 if winner == "Player 1" else 1]
		portrait.configure(profile.avatar, GameManager.COLORS[profile.color])
		portrait.active = true
		portrait.react("win")
	if winner == "Draw":
		title_label.text = "It's a draw!"
	else:
		title_label.text = GameManager.player_name(0 if winner == "Player 1" else 1) + " wins!"
	reason_label.text = reason
	hp_label.text = "FINAL SCORE     %s  %d HP     /     %s  %d HP" % [GameManager.player_name(0), p1_hp, GameManager.player_name(1), p2_hp]
	GameManager.play_sound("win")
	visible = true

func _on_restart_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
