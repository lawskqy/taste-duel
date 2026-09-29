class_name DishCard
extends PanelContainer

@onready var rank_label = $HBox/RankLabel
@onready var dish_icon = $HBox/DishIcon
@onready var dish_name = $HBox/DishName
@onready var art_mark = $HBox/ArtMark

var item_id: String = ""
var current_container = null

func _ready() -> void:
	theme = GameStyle.theme()
	dish_icon.material = GameStyle.art_material()
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_entered.connect(func(): self_modulate = Color(1.15, 1.15, 1.15))
	mouse_exited.connect(func(): self_modulate = Color.WHITE)

func setup(id: String, display_name: String, texture: Texture2D = null, icon: String = "") -> void:
	item_id = id
	dish_name.text = display_name
	tooltip_text = display_name
	if texture:
		dish_icon.texture = texture
		dish_icon.visible = true
		art_mark.hide()
	else:
		dish_icon.visible = false
		art_mark.text = icon if not icon.is_empty() else "✦"
		art_mark.show()
	hide_rank()

func show_rank(rank: int, category: String = "neutral") -> void:
	rank_label.text = str(rank)
	rank_label.visible = true
	var tint = GameStyle.CORAL if category == "disliked" else (GameStyle.MINT if category == "liked" else GameStyle.GOLD)
	rank_label.modulate = tint
	$HBox/Power.text = "%d %s · %d FX" % [CardBalance.hp(category, rank), "DMG" if category == "disliked" else "HP", CardBalance.effects(category, rank)] if category != "neutral" else "1 FX"
	$HBox/Power.modulate = tint
	$HBox/Power.show()
	tooltip_text = "%s\nRank %d · %s\nWhen your opponent plays this card against you." % [dish_name.text, rank, CardBalance.summary(category, rank)]
	add_theme_stylebox_override("panel", GameStyle.box(GameStyle.PANEL, tint.darkened(0.45), 8, 6))

func hide_rank() -> void:
	rank_label.visible = false
	$HBox/Power.hide()
	remove_theme_stylebox_override("panel")
	tooltip_text = dish_name.text
