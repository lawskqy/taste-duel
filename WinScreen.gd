extends CanvasLayer

@onready var title_label = $Dim/Panel/VBox/TitleLabel
@onready var reason_label = $Dim/Panel/VBox/ReasonLabel
@onready var hp_label = $Dim/Panel/VBox/HPLabel
@onready var restart_button = $Dim/Panel/VBox/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	visible = false

func show_result(winner: String, reason: String, p1_hp: int, p2_hp: int) -> void:
	if winner == "Draw":
		title_label.text = "It's a draw!"
	else:
		title_label.text = winner + " wins!"
	reason_label.text = "(" + reason + ")"
	hp_label.text = "Final HP — Player 1: %d   Player 2: %d" % [p1_hp, p2_hp]
	visible = true

func _on_restart_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://Main.tscn")
