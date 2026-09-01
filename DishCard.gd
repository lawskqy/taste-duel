class_name DishCard
extends PanelContainer

@onready var rank_label = $HBox/RankLabel
@onready var dish_icon = $HBox/DishIcon
@onready var dish_name = $HBox/DishName

var item_id: String = ""
var current_container = null

func setup(id: String, display_name: String, texture: Texture2D = null) -> void:
	item_id = id
	dish_name.text = display_name
	if texture:
		dish_icon.texture = texture
		dish_icon.visible = true
	else:
		dish_icon.visible = false
	hide_rank()

func show_rank(rank: int) -> void:
	rank_label.text = str(rank)
	rank_label.visible = true

func hide_rank() -> void:
	rank_label.visible = false
